#!/usr/bin/env Rscript
source('scripts/lib/common.R'); source('scripts/lib/validation.R'); source('scripts/lib/releases.R')
source('scripts/lib/runtime.R'); source('scripts/lib/admin.R')
root <- pipeline_root(); check_runtime(root); args <- cli_args()
check_args(args,c('year','raw-dir','output','proposal','expected-release','reviewer','fetch','apply'))
if (!is.null(args$proposal)) {
  required <- c('proposal','expected-release','reviewer')
  if (any(!required %in% names(args)) || any(vapply(args[required],is.logical,logical(1)))) stop('Apply/dry run requires --proposal, --expected-release, --reviewer')
  if(any(c('year','raw-dir','output','fetch') %in% names(args))) stop('Do not combine preparation and application arguments')
  result <- apply_admin_reference(root,args$proposal,args[['expected-release']],args$reviewer,isTRUE(arg(args,'apply',FALSE)))
} else {
  required <- c('year','raw-dir','output')
  if(any(!required %in% names(args)) || any(vapply(args[required],is.logical,logical(1)))) stop('Prepare requires --year, --raw-dir, --output; --fetch downloads sources into an empty cache')
  if(any(c('expected-release','reviewer','apply') %in% names(args))) stop('Prepare the proposal before application')
  config <- read_json(file.path(root,'config/admin_sources.json'))[[args$year]]
  if(is.null(config))stop('Year not configured')
  if(isTRUE(arg(args,'fetch',FALSE)))fetch_admin_inputs(config,args[['raw-dir']])
  result <- prepare_admin_reference(root,current_state(root),args$year,args[['raw-dir']],args$output)
}
cat(jsonlite::toJSON(result,auto_unbox=TRUE,pretty=TRUE),'\n')
