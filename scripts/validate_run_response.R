#!/usr/bin/env Rscript
source('scripts/lib/common.R'); source('scripts/lib/runs.R'); source('scripts/lib/runtime.R')
root <- pipeline_root(); check_runtime(root); args <- cli_args(); check_args(args,c('run-id','response'))
run_id <- arg(args,'run-id','')
if(!is.character(run_id) || !grepl('^[A-Za-z0-9][A-Za-z0-9._-]{2,100}$',run_id)) stop('Use --run-id=<safe run directory name>')
path <- file.path(root,'data/runs',run_id)
result <- validate_run_response(path,arg(args,'response',file.path(path,'work/response.json')))
cat(jsonlite::toJSON(result,auto_unbox=TRUE,pretty=TRUE),'\n')
