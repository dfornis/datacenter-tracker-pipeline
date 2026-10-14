#!/usr/bin/env Rscript
# Shared country workflow; web research is performed by the agent using packet instructions.
source('scripts/model.R')

country_selection <- function(cfg,country='all') {
  if(!country %in% c('all',names(cfg$countries)))stop('Unknown country: ',country)
  if(country=='all')names(cfg$countries)else country
}
table_files <- function(cfg) paste0(names(cfg$tables),'.csv')
write_tables <- function(x,path) {
  dir.create(path,recursive=TRUE,showWarnings=FALSE)
  for(n in names(x$config$tables))write.csv(x[[n]],file.path(path,paste0(n,'.csv')),row.names=FALSE,na='',fileEncoding='UTF-8')
}
make_packet <- function(root='.',data_dir=file.path(root,'data'),country='all') {
  before<-input_hashes(root,data_dir);x<-read_inputs(root,data_dir);validate_inputs(x,allow_empty=TRUE)
  countries<-country_selection(x$config,country)
  selected<-x$projects$project_id[x$projects$country %in% countries]
  limits<-setNames(lapply(names(x$config$tables),function(n)
    max(c(x$config$workflow$id_floor[[n]],number(sub('^[PCS]','',x[[n]][[1]]))))),names(x$config$tables))
  packet<-list(country=country,countries=as.list(countries),run_date=as.character(Sys.Date()),
    input_hashes=before,id_above=limits,method=x$config,
    instructions=readLines(file.path(root,'prompts/update.md'),warn=FALSE),
    projects=x$projects[x$projects$project_id %in% selected,,drop=FALSE],
    capacity=x$capacity[x$capacity$project_id %in% selected,,drop=FALSE],sources=x$sources,
    capacity_sources_to_reconcile=Filter(function(f)f$project_id %in% selected,capacity_followups(x)),
    identity_index=x$projects[,c('project_id','country','project_name','developer','municipality','related_project_id','notes')])
  if(!identical(before,input_hashes(root,data_dir)))stop('Inputs changed during preparation; retry')
  packet
}
prepare_run <- function(root='.',path,country='all',mode='refresh') {
  if(!mode %in% c('refresh','scratch'))stop('Choose --mode=refresh or scratch')
  if(file.exists(path))stop('Work directory already exists; resume it or choose a new path')
  packet<-make_packet(root,country=country);packet$mode<-mode
  x<-read_inputs(root)
  if(mode=='scratch') {
    selected<-x$projects$project_id[x$projects$country %in% unlist(packet$countries)]
    x$projects<-x$projects[!x$projects$project_id %in% selected,,drop=FALSE]
    x$capacity<-x$capacity[!x$capacity$project_id %in% selected,,drop=FALSE]
    refs<-unique(c(unlist(lapply(x$projects$source_ids,ids)),unlist(lapply(x$capacity$source_ids,ids))))
    x$sources<-x$sources[x$sources$source_id %in% refs,,drop=FALSE]
  }
  complete<-FALSE
  on.exit(if(!complete)unlink(path,recursive=TRUE),add=TRUE)
  write_tables(x,path)
  atomic_output(packet,file.path(path,'packet.json'))
  if(!identical(packet$input_hashes,input_hashes(root)))stop('Inputs changed during preparation; retry')
  complete<-TRUE
  invisible(packet)
}
same_rows <- function(a,b,keys) {
  aa<-a[match(keys,a[[1]]),,drop=FALSE];bb<-b[match(keys,b[[1]]),,drop=FALSE]
  rownames(aa)<-rownames(bb)<-NULL
  identical(aa,bb)
}
install_file <- function(from,to) {
  tmp<-tempfile('.datacenters-install-',dirname(to));on.exit(unlink(tmp))
  if(!file.copy(from,tmp)||!file.rename(tmp,to))stop('Could not install ',to)
}
review_run <- function(root='.',path) {
  packet<-json_read(file.path(path,'packet.json'))
  if(!identical(packet$input_hashes,input_hashes(root)))stop('Register or instructions changed since prepare; reconcile in a new work directory')
  old<-read_inputs(root);new<-read_inputs(root,path);validate_inputs(new)
  countries<-unlist(packet$countries)
  if(!length(countries)||any(!countries %in% names(old$config$countries)))stop('Invalid packet countries')
  other<-old$projects$project_id[!old$projects$country %in% countries]
  protected_sources<-unique(c(unlist(lapply(old$projects$source_ids[old$projects$project_id %in% other],ids)),
    unlist(lapply(old$capacity$source_ids[old$capacity$project_id %in% other],ids))))
  protected<-list(projects=other,capacity=old$capacity$claim_id[old$capacity$project_id %in% other],sources=protected_sources)
  changes<-list()
  for(n in names(old$config$tables)) {
    a<-old[[n]];b<-new[[n]];missing<-setdiff(a[[1]],b[[1]])
    if(length(missing))stop('Rows disappeared from ',n,': ',paste(missing,collapse=', '),'; reconcile and retain their IDs')
    added<-setdiff(b[[1]],a[[1]])
    if(any(number(sub('^[PCS]','',added))<=packet$id_above[[n]]))stop('Reused historical ID in ',n)
    if(!same_rows(a,b,protected[[n]]))stop('Changes outside selected countries in ',n)
    changed<-a[[1]][vapply(a[[1]],function(id)!same_rows(a,b,id),logical(1))]
    changes[[n]]<-list(added=as.list(added),changed=as.list(changed))
  }
  added_projects<-new$projects[!new$projects$project_id %in% old$projects$project_id,,drop=FALSE]
  if(any(!added_projects$country %in% countries))stop('New project outside selected countries')
  owned<-new$projects$project_id[new$projects$country %in% countries]
  if(any(!old$projects$project_id[old$projects$country %in% countries] %in% owned) ||
     any(!new$capacity$project_id[!new$capacity$claim_id %in% old$capacity$claim_id] %in% owned))
    stop('Country/claim ownership changed outside selected countries; use an all-country run')
  if(any(old$capacity$project_id!=new$capacity$project_id[match(old$capacity$claim_id,new$capacity$claim_id)]))
    stop('Existing claim reassigned to another project; retain it and use a new claim ID')
  list(packet=packet,changes=changes)
}
apply_run <- function(root='.',path,output=file.path(root,'assets/datacenters.json')) {
  # One writer, complete validation before replacement, and rollback on a normal I/O error.
  lock<-file.path(root,'.locks','pipeline');dir.create(dirname(lock),showWarnings=FALSE,recursive=TRUE)
  if(!dir.create(lock,showWarnings=FALSE))stop('Another apply is active (or an interrupted apply needs inspection): ',lock)
  on.exit(unlink(lock,recursive=TRUE),add=TRUE)
  review<-review_run(root,path);r<-build_result(root,path)
  r$inventory_run<-list(date=review$packet$run_date,countries=review$packet$countries,mode=review$packet$mode)
  files<-table_files(read_inputs(root)$config)
  staged<-tempfile('datacenter-apply-');dir.create(staged);on.exit(unlink(staged,recursive=TRUE),add=TRUE)
  if(!all(file.copy(file.path(path,files),staged)))stop('Could not stage input tables')
  for(i in seq_along(files))if(file_hash(file.path(staged,files[i]))!=r$input_hashes[[i]])stop('Work tables changed during apply; retry')
  atomic_output(r,file.path(staged,'result.json'))
  destinations<-c(file.path(root,'data',files),output)
  existing<-file.exists(destinations);backups<-file.path(staged,paste0(seq_along(destinations),'.backup'))
  if(any(existing)&&!all(file.copy(destinations[existing],backups[existing])))stop('Could not back up destinations')
  if(!identical(review$packet$input_hashes,input_hashes(root)))stop('Register changed during apply; retry')
  complete<-FALSE
  on.exit(if(!complete) {
    for(i in which(existing))install_file(backups[i],destinations[i])
    unlink(destinations[!existing])
  },add=TRUE,after=FALSE)
  dir.create(dirname(output),recursive=TRUE,showWarnings=FALSE)
  replacements<-c(file.path(staged,files),file.path(staged,'result.json'))
  for(i in seq_along(destinations))install_file(replacements[i],destinations[i])
  complete<-TRUE
  invisible(list(result=r,changes=review$changes))
}
json_destination <- function(path,root='.') {
  if(!grepl('\\.json$',path))stop('Output must be a .json file')
  protected<-c('config/pipeline.json','renv.lock',file.path('data',table_files(read_inputs(root)$config)))
  if(normalizePath(path,mustWork=FALSE) %in% normalizePath(file.path(root,protected),mustWork=FALSE))stop('Output would overwrite an input')
  path
}
pipeline_main <- function(args=commandArgs(trailingOnly=TRUE)) {
  command<-if(length(args))args[1] else 'check';opts<-list()
  for(a in args[-1]) {
    if(!grepl('^--[^=]+=.+$',a))stop('Use --name=value')
    kv<-strsplit(sub('^--','',a),'=',fixed=TRUE)[[1]]
    if(kv[1] %in% names(opts))stop('Duplicate option')
    opts[[kv[1]]]<-paste(kv[-1],collapse='=')
  }
  allowed<-list(check='data',build=c('data','output'),packet=c('data','output','country'),
                prepare=c('output','country','mode'),apply=c('data','output'))
  if(!command %in% names(allowed))stop('Commands: check, build, packet, prepare, apply')
  if(any(!names(opts) %in% allowed[[command]]))stop('Unknown option for ',command)
  data_dir<-opts$data %||% 'data'
  if(command=='prepare') {
    path<-opts$output %||% tempfile('datacenter-run-',tmpdir=Sys.getenv('TMPDIR',unset='/tmp'))
    prepare_run(path=path,country=opts$country %||% 'all',mode=opts$mode %||% 'refresh')
    cat('Prepared work directory ',path,'; read packet.json and follow prompts/update.md. No research performed.\n',sep='')
  } else if(command=='packet') {
    path<-json_destination(opts$output %||% tempfile('datacenter-packet-',tmpdir=Sys.getenv('TMPDIR',unset='/tmp'),fileext='.json'))
    atomic_output(make_packet(data_dir=data_dir,country=opts$country %||% 'all'),path);cat('Prepared ',path,'\n',sep='')
  } else if(command=='apply') {
    if(is.null(opts$data))stop('apply needs --data=<prepared work directory>')
    path<-json_destination(opts$output %||% 'assets/datacenters.json')
    if(normalizePath(path,mustWork=FALSE)==normalizePath(file.path(data_dir,'packet.json'),mustWork=FALSE))stop('Output would overwrite the work packet')
    r<-apply_run(path=data_dir,output=path)
    cat('Applied tables and built ',path,'; ',r$result$coverage$projects,' projects represented in every scenario.\n',sep='')
  } else {
    review<-if(file.exists(file.path(data_dir,'packet.json')))review_run(path=data_dir) else NULL
    r<-build_result('.',data_dir)
    if(command=='check')cat(jsonlite::toJSON(list(valid=TRUE,coverage=r$coverage,changes=review$changes,
      map_zones=length(r$bidding_zones$features)),auto_unbox=TRUE,pretty=TRUE),'\n')
    else {
      path<-json_destination(opts$output %||% 'assets/datacenters.json')
      if(normalizePath(path,mustWork=FALSE)==normalizePath(file.path(data_dir,'packet.json'),mustWork=FALSE))stop('Output would overwrite the work packet')
      atomic_output(r,path);cat('Built ',path,'; ',r$coverage$projects,' projects represented in every scenario.\n',sep='')
    }
  }
}
if(sys.nframe()==0L)pipeline_main()
