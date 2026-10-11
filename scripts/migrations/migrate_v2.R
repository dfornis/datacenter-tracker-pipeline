#!/usr/bin/env Rscript
source('scripts/lib/common.R'); source('scripts/lib/validation.R')
source('scripts/lib/releases.R'); source('scripts/lib/migration_v2.R')
source('scripts/lib/runtime.R')
root <- pipeline_root(); check_runtime(root); args <- cli_args(); check_args(args, c('input','output','apply'))
input <- arg(args, 'input', file.path(root,'data'))
output <- arg(args, 'output', file.path(root,'.staging','migration-v2'))
if (dir.exists(output)) stop('Output already exists; choose a fresh migration staging directory')
if (is_symlink(file.path(root,'data','current'))) stop('Version 2 already initialised; do not rerun migration against live data')
with_data_lock(root, function() {
  dir.create(output, recursive = TRUE)
  migrate_v1_tables(input, output, root)
  validation <- validate_state(output, root)
  id <- seal_release(output, root, 'legacy-e3b85cc', list(action = 'schema migration', web_verified = FALSE))
  verify_release(output)
  if (isTRUE(arg(args, 'apply', FALSE))) {
    if (normalizePath(input) != normalizePath(file.path(root,'data'))) stop('Apply only supports in-place initial migration')
    legacy <- file.path(root,'data','legacy-v1')
    if (dir.exists(legacy)) stop('Legacy backup already exists; inspect incomplete initialisation')
    dir.create(legacy)
    moved <- character(); finished <- FALSE
    on.exit({
      if (!finished) {
        for (name in moved) { unlink(file.path(root,'data',name)); file.rename(file.path(legacy,name),file.path(root,'data',name)) }
        unlink(file.path(root,'data','current'))
      }
    }, add = TRUE)
    for (name in c('master','audit')) {
      if (!file.rename(file.path(root,'data',name), file.path(legacy,name))) stop('Cannot preserve original directory')
      moved <- c(moved,name)
      if (!file.symlink(file.path('current',name), file.path(root,'data',name))) stop('Cannot install stable alias')
    }
    publish_state(output, root, id)
    finished <- TRUE
  }
  cat(jsonlite::toJSON(list(release_id = id, applied = isTRUE(arg(args,'apply',FALSE)), validation = validation), auto_unbox=TRUE,pretty=TRUE),'\n')
})
