#!/usr/bin/env Rscript
# Run from the repository root. check never writes data or a public result.
source('scripts/model.R')
args<-commandArgs(trailingOnly=TRUE)
command<-if(length(args))args[1] else 'check'
opts<-list()
for (a in args[-1]) {
  if(!grepl('^--[^=]+=.+$',a))stop('Use --name=value')
  kv<-strsplit(sub('^--','',a),'=',fixed=TRUE)[[1]]
  if(kv[1] %in% names(opts))stop('Duplicate option')
  opts[[kv[1]]]<-paste(kv[-1],collapse='=')
}
if(any(!names(opts) %in% c('data','output','country')))stop('Unknown option')
data_dir<-opts$data %||% 'data'
if(command=='check') {
  r<-build_result('.',data_dir)
  cat(jsonlite::toJSON(list(valid=TRUE,coverage=r$coverage,map_zones=length(r$bidding_zones$features)),auto_unbox=TRUE,pretty=TRUE),'\n')
} else if(command=='build') {
  r<-build_result('.',data_dir);path<-opts$output %||% 'assets/datacenters.json'
  atomic_output(r,path);cat('Built ',path,'; ',r$coverage$projects,' projects represented in every scenario.\n',sep='')
} else if(command=='packet') {
  x<-read_inputs('.',data_dir);validate_inputs(x);country<-opts$country
  if(is.null(country)||!country %in% names(x$config$countries))stop('Choose --country=SE, NO or FI')
  selected<-x$projects$project_id[x$projects$country==country]
  source_ids<-unique(c(unlist(lapply(x$projects$source_ids[x$projects$project_id %in% selected],ids)),unlist(lapply(x$capacity$source_ids[x$capacity$project_id %in% selected],ids))))
  path<-opts$output %||% file.path(tempdir(),paste0(country,'-packet.json'))
  packet<-list(country=country,input_hashes=input_hashes('.',data_dir),method=x$config,
    instructions=readLines('prompts/update.md',warn=FALSE),
    projects=x$projects[x$projects$project_id %in% selected,],capacity=x$capacity[x$capacity$project_id %in% selected,],
    sources=x$sources[x$sources$source_id %in% source_ids,],
    identity_index=x$projects[,c('project_id','country','project_name','developer','municipality','related_project_id')])
  atomic_output(packet,path);cat('Prepared ',path,'\n',sep='')
} else stop('Commands: check, build, packet')
