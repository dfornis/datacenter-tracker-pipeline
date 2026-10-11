#!/usr/bin/env Rscript
source('scripts/lib/common.R'); source('scripts/lib/validation.R'); source('scripts/lib/releases.R')
source('scripts/lib/runs.R'); source('scripts/lib/run_review.R'); source('scripts/lib/runtime.R')
root <- pipeline_root(); check_runtime(root); args <- cli_args()
check_args(args,c('run-id','decisions','reviewer'))
if(any(!c('run-id','decisions','reviewer') %in% names(args))) stop('Use --run-id, --decisions=<CSV>, --reviewer=<reviewing identity>')
if(!grepl('^[A-Za-z0-9][A-Za-z0-9._-]{2,100}$',args[['run-id']])) stop('Invalid run ID')
result <- freeze_run_review(file.path(root,'data/runs',args[['run-id']]),args$decisions,args$reviewer)
cat(jsonlite::toJSON(result,auto_unbox=TRUE,pretty=TRUE),'\n')
