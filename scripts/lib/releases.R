# All writers must hold this lock from reading the parent to replacing the pointer.
with_data_lock <- function(root, action) {
  dir.create(file.path(root, '.locks'), showWarnings = FALSE)
  lock <- file.path(root, '.locks', 'data')
  if (!dir.create(lock, showWarnings = FALSE)) stop('Another data writer holds .locks/data; inspect its owner before recovery', call. = FALSE)
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  write_json(list(pid = Sys.getpid(), host = Sys.info()[['nodename']], acquired_at = utc_now()), file.path(lock, 'owner.json'))
  action()
}
release_inventory <- function(path) {
  inventory <- file_inventory(path)
  inventory[setdiff(names(inventory), 'manifest.json')]
}
verify_release <- function(path) {
  manifest <- read_json(file.path(path, 'manifest.json'))
  if (!identical(manifest$files, release_inventory(path))) stop('Immutable release has changed: ', basename(path), call. = FALSE)
  invisible(manifest)
}
seal_release <- function(stage, root, parent, metadata = list()) {
  dir.create(file.path(stage, 'contract'), showWarnings = FALSE)
  if (!all(file.copy(file.path(root, 'config', c('schema.json','methodology.json')), file.path(stage, 'contract'), overwrite = TRUE))) stop('Cannot freeze release contract')
  inventory <- release_inventory(stage)
  id <- paste0('r2-', substr(sha_value(inventory), 1, 20))
  write_json(list(release_id = id, parent_release = parent, schema_version = read_json(file.path(root,'config/schema.json'))$schema_version,
                  method_version = read_json(file.path(root,'config/methodology.json'))$method_version,
                  metadata = metadata, files = inventory), file.path(stage, 'manifest.json'))
  id
}
publish_state <- function(stage, root, id, failpoint = NULL) {
  destination <- file.path(root, 'data', 'releases', id)
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  if (dir.exists(destination)) {
    verify_release(destination)
    if (!identical(release_inventory(stage), release_inventory(destination))) stop('Release ID collision')
    unlink(stage, recursive = TRUE)
  } else if (!file.rename(stage, destination)) stop('Cannot install staged release')
  if (identical(failpoint, 'before_pointer')) stop('Injected interruption before pointer replacement')
  temporary <- tempfile('.tmp-current-', tmpdir = file.path(root, 'data'))
  on.exit(unlink(temporary), add = TRUE)
  if (!file.symlink(file.path('releases', id), temporary)) stop('Cannot create release pointer')
  if (!file.rename(temporary, file.path(root, 'data', 'current'))) stop('Cannot atomically select release')
  invisible(destination)
}
state_transaction <- function(root, mutate, expected_release, apply = FALSE, metadata = list(), failpoint = NULL, replay_check = NULL) {
  with_data_lock(root, function() {
    parent <- current_state(root); verify_release(parent)
    if (!is.null(replay_check)) {
      replay <- replay_check(load_state(parent, read_json(file.path(root,'config/schema.json'))))
      if (!is.null(replay)) return(list(applied = FALSE, replay = TRUE, release_id = basename(parent), details = replay))
    }
    if (!identical(basename(parent), expected_release)) stop('Input release is stale; review against current data before applying', call. = FALSE)
    schema <- read_json(file.path(root, 'config/schema.json'))
    validate_state(parent, root, schema)
    staging_root <- file.path(root, '.staging'); dir.create(staging_root, showWarnings = FALSE)
    stage <- tempfile('data-', staging_root)
    on.exit(unlink(stage, recursive = TRUE), add = TRUE)
    copy_directory(parent, stage)
    unlink(file.path(stage, 'manifest.json'))
    change <- mutate(load_state(stage, schema), stage, schema)
    if (isTRUE(change$replay)) return(list(applied = FALSE, replay = TRUE, release_id = basename(parent), details = change$details))
    write_state_tables(change$tables, stage, schema)
    if (identical(failpoint, 'after_tables')) stop('Injected interruption after table writes')
    validation <- validate_state(stage, root, schema)
    id <- seal_release(stage, root, basename(parent), metadata)
    verify_release(stage)
    # Defend against a writer that ignored the lock or modified immutable files.
    if (current_state(root) != parent) stop('Current release changed during transaction')
    verify_release(parent)
    if (apply) publish_state(stage, root, id, failpoint)
    list(applied = apply, replay = FALSE, release_id = id, parent_release = basename(parent),
         validation = validation, details = change$details)
  })
}
