#!/usr/bin/env Rscript
source('scripts/lib/common.R'); source('scripts/lib/validation.R'); source('scripts/lib/releases.R')
source('scripts/lib/runtime.R'); source('scripts/lib/runs.R')
root <- pipeline_root(); check_runtime(root); args <- cli_args()
check_args(args,c('task','country','run-id','engine','model','state','project-ids'))
required <- c('task','country','run-id','engine','model')
if(any(!required %in% names(args)) || any(vapply(args[required],is.logical,logical(1)))) stop('Required: --task, --country, --run-id, --engine, --model')
result <- create_country_run(root,arg(args,'state',current_state(root)),toupper(args$country),args$task,args[['run-id']],args$engine,args$model,split_values(arg(args,'project-ids','')))
cat(jsonlite::toJSON(result,auto_unbox=TRUE,pretty=TRUE),'\n')
