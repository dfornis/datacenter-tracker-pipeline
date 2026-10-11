check_runtime <- function(root) {
  if (!requireNamespace('jsonlite',quietly=TRUE)) stop('Restore the locked environment first: Rscript -e "renv::restore()"')
  lock <- read_json(file.path(root,'renv.lock'))
  if (as.character(getRversion()) != lock$R$Version) stop('R version mismatch: expected ',lock$R$Version,'; found ',getRversion())
  for (name in c('jsonlite','digest')) {
    expected <- lock$Packages[[name]]$Version
    if (!requireNamespace(name,quietly=TRUE) || as.character(utils::packageVersion(name)) != expected) stop('Restore locked package ',name,' ',expected)
  }
  invisible(TRUE)
}
