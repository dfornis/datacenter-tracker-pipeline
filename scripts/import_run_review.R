#!/usr/bin/env Rscript
source('scripts/lib/common.R'); source('scripts/lib/validation.R'); source('scripts/lib/releases.R')
source('scripts/lib/runs.R'); source('scripts/lib/run_review.R'); source('scripts/lib/runtime.R')
root <- pipeline_root(); check_runtime(root); args <- cli_args()
check_args(args,c('run-id','review-id','expected-release','apply'))
if(any(!c('run-id','review-id','expected-release') %in% names(args))) stop('Use --run-id, --review-id and --expected-release')
result <- import_run_review(root,args[['run-id']],args[['review-id']],args[['expected-release']],isTRUE(arg(args,'apply',FALSE)))
cat(jsonlite::toJSON(result,auto_unbox=TRUE,pretty=TRUE),'\n')
