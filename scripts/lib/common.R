# Shared, deterministic IO. No script in this directory executes work on source().
pipeline_root <- function(start = getwd()) {
  current <- normalizePath(start, mustWork = TRUE)
  if (!dir.exists(current)) current <- dirname(current)
  repeat {
    if (file.exists(file.path(current, 'config', 'schema.json'))) return(current)
    parent <- dirname(current)
    if (identical(parent, current)) stop('Cannot locate config/schema.json', call. = FALSE)
    current <- parent
  }
}
cli_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list()
  for (arg in args) {
    if (!startsWith(arg, '--')) stop('Expected --name=value: ', arg, call. = FALSE)
    pair <- strsplit(sub('^--', '', arg), '=', fixed = TRUE)[[1]]
    if (pair[1] %in% names(out)) stop('Duplicate argument: ', pair[1], call. = FALSE)
    out[[pair[1]]] <- if (length(pair) == 1) TRUE else paste(pair[-1], collapse = '=')
  }
  out
}
arg <- function(args, key, default = NULL) if (is.null(args[[key]])) default else args[[key]]
check_args <- function(args, allowed) {
  unknown <- setdiff(names(args), allowed)
  if (length(unknown)) stop('Unknown argument(s): ', paste(unknown, collapse = ', '), call. = FALSE)
}
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x
utc_now <- function() format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')
read_json <- function(path) jsonlite::fromJSON(path, simplifyVector = FALSE)
write_json <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(value, path, pretty = TRUE, auto_unbox = TRUE, na = 'null', null = 'null', digits = NA)
}
read_table <- function(path) {
  if (!file.exists(path)) stop('Missing table: ', path, call. = FALSE)
  d <- utils::read.csv(path, colClasses = 'character', na.strings = NULL,
                       check.names = FALSE, stringsAsFactors = FALSE, fileEncoding = 'UTF-8',
                       comment.char = '', strip.white = FALSE, blank.lines.skip = FALSE)
  if (anyDuplicated(names(d)) || any(!nzchar(names(d)))) stop('Invalid CSV header: ', path, call. = FALSE)
  if (anyNA(d)) stop('Malformed CSV or incomplete row: ', path, call. = FALSE)
  d
}
write_table <- function(value, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.table(value, path, sep = ',', row.names = FALSE, col.names = TRUE,
                     na = '', quote = TRUE, qmethod = 'double', fileEncoding = 'UTF-8')
}
empty_table <- function(columns) {
  as.data.frame(setNames(rep(list(character()), length(columns)), columns), stringsAsFactors = FALSE)
}
bind_tables <- function(a, b) {
  cols <- union(names(a), names(b))
  for (c in setdiff(cols, names(a))) a[[c]] <- rep('', nrow(a))
  for (c in setdiff(cols, names(b))) b[[c]] <- rep('', nrow(b))
  rbind(a[, cols, drop = FALSE], b[, cols, drop = FALSE])
}
row_frame <- function(values, columns) {
  result <- setNames(as.list(rep('', length(columns))), columns)
  for (name in intersect(names(values), columns)) result[[name]] <- as.character(values[[name]] %||% '')
  as.data.frame(result, stringsAsFactors = FALSE)
}
split_values <- function(value) {
  value <- value %||% ''
  parts <- trimws(unlist(strsplit(value, '[;,]')))
  unique(parts[!is.na(parts) & nzchar(parts)])
}
num <- function(x) suppressWarnings(as.numeric(x))
sha_file <- function(path) digest::digest(file = path, algo = 'sha256', serialize = FALSE)
sha_value <- function(value) digest::digest(value, algo = 'sha256', serialize = TRUE)
file_inventory <- function(path) {
  files <- sort(list.files(path, recursive = TRUE, all.files = TRUE, no.. = TRUE))
  files <- files[!dir.exists(file.path(path, files)) & basename(files) != '.DS_Store']
  setNames(lapply(files, function(p) sha_file(file.path(path, p))), files)
}
copy_directory <- function(from, to) {
  if (!dir.exists(from)) stop('Missing directory: ', from, call. = FALSE)
  dir.create(to, recursive = TRUE, showWarnings = FALSE)
  entries <- list.files(from, all.files = TRUE, no.. = TRUE, full.names = TRUE)
  entries <- entries[basename(entries) != '.DS_Store']
  if (length(entries) && !all(file.copy(entries, to, recursive = TRUE, copy.date = TRUE))) {
    stop('Incomplete state copy', call. = FALSE)
  }
  invisible(to)
}
current_state <- function(root) {
  pointer <- file.path(root, 'data', 'current')
  if (!is_symlink(pointer)) stop('data/current must be a release symlink', call. = FALSE)
  state <- normalizePath(pointer, mustWork = TRUE)
  releases <- normalizePath(file.path(root, 'data', 'releases'), mustWork = TRUE)
  if (!startsWith(state, paste0(releases, '/'))) stop('State pointer escapes data/releases', call. = FALSE)
  state
}
is_symlink <- function(path) {
  link <- Sys.readlink(path)
  !is.na(link) & nzchar(link)
}
load_state <- function(path, schema) {
  setNames(lapply(schema$tables, function(spec) read_table(file.path(path, spec$path))), names(schema$tables))
}
write_state_tables <- function(tables, path, schema) {
  for (name in names(tables)) write_table(tables[[name]], file.path(path, schema$tables[[name]]$path))
}
valid_date <- function(x) {
  out <- rep(FALSE, length(x)); matches <- grepl('^[0-9]{4}-[0-9]{2}-[0-9]{2}$', x)
  parsed <- suppressWarnings(as.Date(x[matches], format = '%Y-%m-%d'))
  out[matches] <- !is.na(parsed) & format(parsed, '%Y-%m-%d') == x[matches]
  out
}
