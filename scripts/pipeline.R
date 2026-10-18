#!/usr/bin/env Rscript
# Shared country workflow; web research is performed by the agent using packet instructions.
source('scripts/model.R')
source('scripts/tracker.R')

country_selection <- function(cfg,country='all') {
  if(!country %in% c('all',names(cfg$countries)))stop('Unknown country: ',country)
  if(country=='all')names(cfg$countries)else country
}
table_files <- function(cfg) paste0(names(cfg$tables),'.csv')
write_tables <- function(x,path) {
  dir.create(path,recursive=TRUE,showWarnings=FALSE)
  for(n in names(x$config$tables))write_csv_table(x[[n]],file.path(path,paste0(n,'.csv')))
}
run_worklist <- function(x,countries) {
  # The concrete to-do list for a country run. Recomputed from the tables, so it shrinks as work is done.
  # Out-of-scope rows are kept for identity only and never generate work.
  p<-x$projects[x$projects$country %in% countries & x$projects$record_type!='out_of_scope',,drop=FALSE];c<-x$capacity[x$capacity$project_id %in% p$project_id,,drop=FALSE]
  s<-x$sources;excluded<-c('Operational','Dormant','Cancelled')
  load<-nzchar(c$mw) & !c$basis %in% c('backup','generation','density') & c$issue!='identity_conflict'
  excerpt<-function(ref)lapply(ids(ref),function(id)list(source_id=id,excerpt=s$excerpt[match(id,s$source_id)],url=s$url[match(id,s$source_id)]))
  live<-p[!p$status %in% c('Cancelled','Dormant'),,drop=FALSE]
  public<-p[p$record_type=='existing' & !p$status %in% excluded,,drop=FALSE]
  active<-!c$status %in% c('Operational','Cancelled','Dormant') &
    !p$status[match(c$project_id,p$project_id)] %in% c('Cancelled','Dormant') &
    !c$basis %in% c('backup','generation','density') & c$issue!='identity_conflict'
  row_dated<-vapply(seq_len(nrow(c)),function(i)timing_share(c[i,],x$config$scenarios[[1]]$year,x$config)$dated,TRUE)
  dated<-unique(c$project_id[active & row_dated])
  inside<-function(k,i){j<-k;n<-0L;while(c$relation[j] %in% c('included_in','possibly_included_in') && n<50L){j<-match(c$parent_id[j],c$claim_id);n<-n+1L;if(is.na(j))return(FALSE);if(j==i)return(TRUE)};FALSE}
  detail<-function(j)c(as.list(c[j,c('claim_id','phase','mw','basis','status','decision','timing','first_year','last_year',
    'construction_year','parent_id','relation','notes')]),list(sources=excerpt(c$source_ids[j])))
  # Phases being executed without a disclosed MW: find the phase size (EIA/YVA, permits, grid agreements).
  executing<-which(!nzchar(c$mw) & (c$status=='Under construction' | c$decision=='yes') &
    !c$status %in% c('Operational','Cancelled','Dormant') & !c$basis %in% c('backup','generation','density'))
  phases_without_mw<-lapply(executing,detail)
  # A dated envelope that shares its year with a contained phase may carry a borrowed date.
  borrowed<-Filter(Negate(is.null),lapply(which(load & active & (nzchar(c$first_year)|nzchar(c$construction_year))),function(i) {
    k<-which(vapply(seq_len(nrow(c)),function(k)k!=i && c$project_id[k]==c$project_id[i] && inside(k,i),TRUE))
    same<-k[(nzchar(c$first_year[k]) & c$first_year[k]==c$first_year[i]) | (nzchar(c$construction_year[k]) & c$construction_year[k]==c$construction_year[i])]
    if(!length(same) || grepl('own date verified',c$notes[i],ignore.case=TRUE))return(NULL)
    list(project_id=c$project_id[i],envelope=detail(i),phases_with_same_date=lapply(same,detail))
  }))
  missing_display<-p[!nzchar(p$type)|!nzchar(p$county)|!nzchar(p$bidding_zone)|!nzchar(p$latitude),,drop=FALSE]
  list(
    reclassify_unspecified=lapply(which(c$basis=='unspecified'),function(i)list(claim_id=c$claim_id[i],project_id=c$project_id[i],
      mw=c$mw[i],phase=c$phase[i],sources=excerpt(c$source_ids[i]))),
    projects_without_mw=as.list(setdiff(live$project_id,c$project_id[load])),
    capacity_sources_to_reconcile=Filter(function(f)f$project_id %in% p$project_id,capacity_followups(x)),
    phases_without_mw=phases_without_mw,
    envelope_dates_to_verify=borrowed,
    timing_followups=timing_followups(x,countries),
    public_projects_without_dates=as.list(setdiff(public$project_id[public$project_id %in% c$project_id[load]],dated)),
    candidates_to_assess=as.list(p$project_id[p$record_type=='candidate']),
    missing_display_fields=lapply(seq_len(nrow(missing_display)),function(i)list(project_id=missing_display$project_id[i],
      missing=as.list(c('type','county','bidding_zone','latitude')[!nzchar(unlist(missing_display[i,c('type','county','bidding_zone','latitude')]))]))))
}
worklist_counts <- function(w) vapply(w,length,0L)
make_packet <- function(root='.',data_dir=file.path(root,'data'),country='all') {
  before<-input_hashes(root,data_dir);x<-read_inputs(root,data_dir);validate_inputs(x,allow_empty=TRUE)
  countries<-country_selection(x$config,country)
  selected<-x$projects$project_id[x$projects$country %in% countries]
  permanent<-c('projects','capacity','sources')
  limits<-setNames(lapply(permanent,function(n)
    max(c(x$config$workflow$id_floor[[n]],number(sub('^[PCS]','',x[[n]][[1]]))))),permanent)
  packet<-list(country=country,countries=as.list(countries),run_date=as.character(Sys.Date()),
    input_hashes=before,id_above=limits,method=x$config,
    instructions=readLines(file.path(root,'prompts/update.md'),warn=FALSE),
    actor_instructions=readLines(file.path(root,'prompts/actors.md'),warn=FALSE),
    actors=x$actors[x$actors$project_id %in% selected,,drop=FALSE],actor_worklist=actor_worklist(x,countries),
    projects=x$projects[x$projects$project_id %in% selected,,drop=FALSE],
    capacity=x$capacity[x$capacity$project_id %in% selected,,drop=FALSE],sources=x$sources,
    capacity_sources_to_reconcile=Filter(function(f)f$project_id %in% selected,capacity_followups(x)),
    identity_index=x$projects[,c('project_id','country','project_name','developer','municipality','related_project_id','notes')],
    timing_diagnostics=timing_diagnostics(x),worklist=run_worklist(x,countries))
  if(!identical(before,input_hashes(root,data_dir)))stop('Inputs changed during preparation; retry')
  packet
}
git_uncommitted <- function(root='.') {
  # A country run starts from a committed state, so each run is one reviewable diff.
  if(!nzchar(Sys.which('git')))return(character())
  inside<-suppressWarnings(tryCatch(system2('git',c('-C',shQuote(root),'rev-parse','--is-inside-work-tree'),stdout=TRUE,stderr=FALSE),error=function(e)''))
  if(!identical(inside,'true'))return(character())
  paths<-c('data','config','scripts','prompts','tests','web','assets','runs','AGENTS.md','README.md')
  suppressWarnings(system2('git',c('-C',shQuote(root),'status','--porcelain','--untracked-files=all','--',paths),stdout=TRUE,stderr=FALSE))
}
same_data_snapshot <- function(path,sources,files) {
  copies<-file.path(path,'data',files)
  all(file.exists(copies)) && all(vapply(seq_along(files),function(i)
    identical(file_hash(copies[i]),file_hash(sources[i])),TRUE))
}
data_snapshot <- function(root='.',country='all',run_date=Sys.Date()) {
  x<-read_inputs(root);validate_inputs(x,allow_empty=TRUE)
  country_selection(x$config,country)
  stamp<-format(as.Date(run_date),'%Y-%m-%d')
  if(is.na(stamp))stop('Invalid snapshot date')
  files<-table_files(x$config);sources<-file.path(root,'data',files)
  base<-file.path(root,'runs','snapshots',paste0(stamp,'-',tolower(country),'-before-discovery'))
  target<-base;suffix<-1L
  while(dir.exists(target) && !same_data_snapshot(target,sources,files)) {
    suffix<-suffix+1L;target<-paste0(base,'-',suffix)
  }
  relative<-file.path('runs','snapshots',basename(target))
  if(dir.exists(target))return(relative)
  dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
  stage<-tempfile('.snapshot-',dirname(target));dir.create(stage)
  complete<-FALSE
  on.exit(if(!complete)unlink(stage,recursive=TRUE),add=TRUE)
  for(i in seq_along(files)) {
    destination<-file.path(stage,'data',files[i]);dir.create(dirname(destination),recursive=TRUE,showWarnings=FALSE)
    if(!file.copy(sources[i],destination) || !identical(file_hash(destination),file_hash(sources[i])))stop('Could not preserve data snapshot: ',files[i])
  }
  if(!file.rename(stage,target))stop('Could not install snapshot: ',relative)
  complete<-TRUE
  relative
}
prepare_run <- function(root='.',path,country='all',mode='refresh') {
  if(!mode %in% c('refresh','scratch'))stop('Choose --mode=refresh or scratch')
  if(file.exists(path))stop('Work directory already exists; resume it or choose a new path')
  dirty<-git_uncommitted(root)
  if(length(dirty))stop('Commit the previous run and any code changes before a new country run:\n',paste(dirty,collapse='\n'))
  packet<-make_packet(root,country=country);packet$mode<-mode
  x<-read_inputs(root)
  if(mode=='scratch') {
    selected<-x$projects$project_id[x$projects$country %in% unlist(packet$countries)]
    x$projects<-x$projects[!x$projects$project_id %in% selected,,drop=FALSE]
    x$capacity<-x$capacity[!x$capacity$project_id %in% selected,,drop=FALSE]
    x$actors<-x$actors[!x$actors$project_id %in% selected,,drop=FALSE]
    refs<-unique(c(unlist(lapply(x$projects$source_ids,ids)),unlist(lapply(x$capacity$source_ids,ids)),unlist(lapply(x$actors$source_ids,ids))))
    x$sources<-x$sources[x$sources$source_id %in% refs,,drop=FALSE]
  }
  complete<-FALSE
  on.exit(if(!complete)unlink(path,recursive=TRUE),add=TRUE)
  write_tables(x,path)
  if(!identical(packet$input_hashes,input_hashes(root)))stop('Inputs changed during preparation; retry')
  packet$baseline_snapshot<-data_snapshot(root,country=country,run_date=packet$run_date)
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
same_actor_rows <- function(a,b,projects) {
  select<-function(d) {
    d<-d[d$project_id %in% projects,,drop=FALSE]
    d<-d[order(d$project_id,d$actor_name),,drop=FALSE];rownames(d)<-NULL;d
  }
  identical(select(a),select(b))
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
    unlist(lapply(old$capacity$source_ids[old$capacity$project_id %in% other],ids)),
    unlist(lapply(old$actors$source_ids[old$actors$project_id %in% other],ids))))
  protected<-list(projects=other,capacity=old$capacity$claim_id[old$capacity$project_id %in% other],sources=protected_sources)
  changes<-list()
  for(n in c('projects','capacity','sources')) {
    a<-old[[n]];b<-new[[n]];missing<-setdiff(a[[1]],b[[1]])
    if(length(missing))stop('Rows disappeared from ',n,': ',paste(missing,collapse=', '),'; reconcile and retain their IDs')
    added<-setdiff(b[[1]],a[[1]])
    if(any(number(sub('^[PCS]','',added))<=packet$id_above[[n]]))stop('Reused historical ID in ',n)
    if(!same_rows(a,b,protected[[n]]))stop('Changes outside selected countries in ',n)
    changed<-a[[1]][vapply(a[[1]],function(id)!same_rows(a,b,id),logical(1))]
    changes[[n]]<-list(added=as.list(added),changed=as.list(changed))
  }
  if(!same_actor_rows(old$actors,new$actors,other))stop('Changes outside selected countries in actors')
  lost_actors<-setdiff(unique(old$actors$project_id),unique(new$actors$project_id))
  if(length(lost_actors))stop('Actor rows disappeared from project(s): ',paste(lost_actors,collapse=', '),'; reconcile the actor register too')
  actor_projects<-union(old$actors$project_id,new$actors$project_id)
  changes$actors<-list(changed_projects=as.list(actor_projects[!vapply(actor_projects,function(id)same_actor_rows(old$actors,new$actors,id),TRUE)]))
  added_projects<-new$projects[!new$projects$project_id %in% old$projects$project_id,,drop=FALSE]
  if(any(!added_projects$country %in% countries))stop('New project outside selected countries')
  if(any(added_projects$record_type!='candidate'))stop('New projects enter as candidate; out-of-scope leads belong in the run log')
  owned<-new$projects$project_id[new$projects$country %in% countries]
  if(any(!old$projects$project_id[old$projects$country %in% countries] %in% owned) ||
     any(!new$capacity$project_id[!new$capacity$claim_id %in% old$capacity$claim_id] %in% owned))
    stop('Country/claim ownership changed outside selected countries; use an all-country run')
  if(any(old$capacity$project_id!=new$capacity$project_id[match(old$capacity$claim_id,new$capacity$claim_id)]))
    stop('Existing claim reassigned to another project; retain it and use a new claim ID')
  # Inventory runs may add facts, but only the separate manual approval step may promote projects.
  promoted<-new$projects$project_id[new$projects$record_type=='existing' &
    !new$projects$project_id %in% old$projects$project_id[old$projects$record_type=='existing']]
  if(length(promoted))stop('Manual chat approval required; use review then approve for: ',paste(promoted,collapse=', '))
  demoted<-old$projects$project_id[old$projects$record_type=='existing' &
    new$projects$record_type[match(old$projects$project_id,new$projects$project_id)]!='existing']
  if(length(demoted))stop('Inventory cannot revoke manual approval for: ',paste(demoted,collapse=', '))
  list(packet=packet,changes=changes)
}
with_writer <- function(root,fn) {
  lock<-file.path(root,'.locks','pipeline');dir.create(dirname(lock),showWarnings=FALSE,recursive=TRUE)
  if(!dir.create(lock,showWarnings=FALSE))stop('Another update is active (or an interrupted update needs inspection): ',lock)
  on.exit(unlink(lock,recursive=TRUE),add=TRUE)
  fn()
}
site_checkout <- function(root='.',site=NULL) {
  # The existing sibling checkout convention also used by the site's compatibility script.
  if(is.null(site)) {
    sibling<-file.path(dirname(normalizePath(root)),'dfornis.github.io')
    if(!dir.exists(sibling))return(NULL)
    site<-sibling
  }
  if(!file.exists(file.path(site,'_config.yml')))stop('Expected the local Jekyll site checkout: ',site)
  normalizePath(site)
}
site_presentation <- function(root,site) {
  shared<-c('assets/js/datacenter-tracker.js','assets/js/datacenter-tracker/scenario-map-d3.js',
            'assets/css/datacenter-tracker-map.css','assets/js/datacenter-tracker/timeline.js','assets/css/datacenter-tracker-timeline.css')
  setNames(file.path(root,c(shared,'web/datacenter-tracker.md','web/build_datacenter_data.R','web/build_datacenter_timeline.R')),
    file.path(site,c(shared,'_projects/datacenter-tracker.md','scripts/build_datacenter_data.R','scripts/build_datacenter_timeline.R')))
}
install_result <- function(root,result,data_dir=NULL,output=file.path(root,'assets/datacenters.json'),site=NULL) {
  staged<-tempfile('datacenter-install-');dir.create(staged);on.exit(unlink(staged,recursive=TRUE),add=TRUE)
  tracker<-build_tracker(root,data_dir %||% file.path(root,'data'),result)
  atomic_output(result,file.path(staged,'result.json'))
  write_tracker(tracker,file.path(staged,'tracker'))
  cfg<-read_inputs(root,data_dir %||% file.path(root,'data'))$config
  generated<-list.files(file.path(staged,'tracker'),full.names=TRUE)
  replacements<-c(file.path(staged,'result.json'),generated)
  canonical<-file.path(root,'assets/datacenters.json')
  destinations<-c(canonical,file.path(root,cfg$tracker$output_dir,basename(generated)))
  if(path_id(output)!=path_id(canonical)) {
    json_destination(output,root,data_dir)
    replacements<-c(replacements,file.path(staged,'result.json'));destinations<-c(destinations,output)
  }
  site<-site_checkout(root,site)
  if(!is.null(site)) {
    presentation<-site_presentation(root,site)
    local_files<-file.path(staged,paste0('presentation-',seq_along(presentation)))
    if(!all(file.copy(presentation,local_files)))stop('Could not stage site presentation')
    replacements<-c(replacements,generated,local_files)
    destinations<-c(destinations,file.path(site,cfg$tracker$output_dir,basename(generated)),names(presentation))
  }
  if(!is.null(data_dir)) {
    files<-table_files(cfg)
    stopifnot(all(file.copy(file.path(data_dir,files),staged)))
    for(i in seq_along(files))if(file_hash(file.path(staged,files[i]))!=result$input_hashes[[i]])stop('Work tables changed during installation')
    replacements<-c(file.path(staged,files),replacements)
    destinations<-c(file.path(root,'data',files),destinations)
  }
  if(anyDuplicated(vapply(destinations,path_id,'')))stop('Output destinations overlap')
  existing<-file.exists(destinations);backups<-file.path(staged,paste0(seq_along(destinations),'.backup'))
  if(any(existing)&&!all(file.copy(destinations[existing],backups[existing])))stop('Could not back up destinations')
  installed<-integer();complete<-FALSE
  on.exit(if(!complete)for(i in rev(installed)) {
    if(existing[i])install_file(backups[i],destinations[i]) else unlink(destinations[i])
  },add=TRUE,after=FALSE)
  for(i in seq_along(destinations)) {
    dir.create(dirname(destinations[i]),recursive=TRUE,showWarnings=FALSE)
    install_file(replacements[i],destinations[i]);installed<-c(installed,i)
  }
  complete<-TRUE
  invisible(tracker)
}
previous_inventory <- function(root,result) {
  path<-file.path(root,'assets/datacenters.json')
  if(file.exists(path))result$inventory_run<-json_read(path)$inventory_run
  result
}
apply_run <- function(root='.',path,output=file.path(root,'assets/datacenters.json'),site=NULL) {
  with_writer(root,function() {
    review<-review_run(root,path);r<-build_result(root,path)
    r$inventory_run<-list(date=review$packet$run_date,countries=review$packet$countries,mode=review$packet$mode)
    if(!identical(review$packet$input_hashes,input_hashes(root)))stop('Register changed during apply; retry')
    install_result(root,r,path,output,site)
    invisible(list(result=r,changes=review$changes,tracker=file.path(root,read_inputs(root)$config$tracker$output_dir)))
  })
}
result_totals <- function(result,country) {
  d<-result$project_scenarios
  d<-d[d$country==country & d$included_in_result,,drop=FALSE]
  do.call(rbind,lapply(result$method$scenarios,function(sc) {
    rows<-d[d$scenario==sc$id,,drop=FALSE]
    total<-function(key)if(any(is.na(rows[[key]]) & rows$capacity_known))NA_real_ else sum(rows[[key]],na.rm=TRUE)
    data.frame(scenario=sc$id,nameplate_mw_low=total('nameplate_mw_low'),nameplate_mw_high=total('nameplate_mw_high'),
      mw_low=total('mw_low'),mw_high=total('mw_high'),annual_twh_low=total('annual_twh_low'),annual_twh_high=total('annual_twh_high'),
      projects_without_mw=sum(!rows$capacity_known & !rows$indicator %in% c('operational','cancelled','dormant')),stringsAsFactors=FALSE)
  }))
}
review_candidates <- function(root='.',country='SE') {
  before<-input_hashes(root);x<-read_inputs(root);validate_inputs(x)
  countries<-country_selection(x$config,country)
  base<-build_result(root)
  pending<-x$projects[x$projects$country %in% countries & x$projects$record_type=='candidate',,drop=FALSE]
  shape<-function(r)list(project_scenarios=r$project_scenarios,method=list(scenarios=x$config$scenarios))
  candidates<-lapply(seq_len(nrow(pending)),function(i) {
    p<-pending[i,];trial<-x;trial$projects$record_type[trial$projects$project_id==p$project_id]<-'existing'
    after<-calculate(trial,approved_only=TRUE)
    old<-result_totals(base,p$country);new<-result_totals(shape(after),p$country)
    delta<-new
    for(k in setdiff(names(delta),'scenario'))delta[[k]]<-new[[k]]-old[[k]]
    own<-after$project_scenarios[after$project_scenarios$project_id==p$project_id,,drop=FALSE]
    if(any(!own$capacity_known) && !p$status %in% c('Operational','Cancelled','Dormant'))
      for(k in c('nameplate_mw_low','nameplate_mw_high','mw_low','mw_high','annual_twh_low','annual_twh_high'))delta[[k]]<-NA_real_
    claims<-x$capacity[x$capacity$project_id==p$project_id,,drop=FALSE]
    refs<-unique(c(ids(p$source_ids),unlist(lapply(claims$source_ids,ids))))
    list(project=as.list(p),reported_capacity=claims,
      project_scenarios=after$project_scenarios[after$project_scenarios$project_id==p$project_id,,drop=FALSE],
      country_totals_before=old,country_totals_after=new,delta_if_approved=delta,
      sources=x$sources[x$sources$source_id %in% refs,,drop=FALSE])
  })
  if(!identical(before,input_hashes(root)))stop('Inputs changed during candidate review; regenerate')
  list(scope='manual_candidate_review',instruction='Present project sources and MW impact in chat; wait for explicit user approval of IDs. Individual deltas are conditional and must not be added when projects overlap.',
    input_hashes=before,countries=as.list(countries),candidates=candidates)
}
approve_candidates <- function(root='.',project_ids,review_path,site=NULL) {
  with_writer(root,function() {
    review<-json_read(review_path)
    if(!identical(review$scope,'manual_candidate_review') || !identical(review$input_hashes,input_hashes(root)))
      stop('Candidate review is stale or invalid; regenerate review and present it in chat')
    if(!length(project_ids)||anyDuplicated(project_ids))stop('Provide unique explicitly approved project IDs')
    allowed<-vapply(review$candidates,function(c)c$project$project_id,'')
    if(any(!project_ids %in% allowed))stop('IDs were not candidates in this review: ',paste(setdiff(project_ids,allowed),collapse=', '))
    x<-read_inputs(root);x$projects$record_type[x$projects$project_id %in% project_ids]<-'existing'
    work<-tempfile('datacenter-approval-');dir.create(work);on.exit(unlink(work,recursive=TRUE),add=TRUE)
    write_tables(x,work);r<-previous_inventory(root,build_result(root,work))
    if(!identical(review$input_hashes,input_hashes(root)))stop('Register changed during approval; regenerate review')
    install_result(root,r,work,site=site)
    invisible(r)
  })
}
exclude_projects <- function(root='.',project_ids,reason,site=NULL) {
  # Manual, user-instructed scope decision (also for previously approved rows). Rows stay for identity.
  with_writer(root,function() {
    if(!length(project_ids)||anyDuplicated(project_ids))stop('Provide unique project IDs')
    if(!nzchar(trimws(reason %||% '')))stop('exclude needs --reason')
    x<-read_inputs(root)
    if(any(!project_ids %in% x$projects$project_id))stop('Unknown IDs: ',paste(setdiff(project_ids,x$projects$project_id),collapse=', '))
    hit<-x$projects$project_id %in% project_ids
    x$projects$record_type[hit]<-'out_of_scope'
    x$projects$notes[hit]<-trimws(paste0(x$projects$notes[hit],' Out of scope (',Sys.Date(),'): ',reason))
    work<-tempfile('datacenter-scope-');dir.create(work);on.exit(unlink(work,recursive=TRUE),add=TRUE)
    before<-input_hashes(root)
    write_tables(x,work);r<-previous_inventory(root,build_result(root,work))
    if(!identical(before,input_hashes(root)))stop('Register changed during exclusion; retry')
    install_result(root,r,work,site=site)
    invisible(r)
  })
}
rebuild_run <- function(root='.',site=NULL) {
  with_writer(root,function() {
    r<-previous_inventory(root,build_result(root));install_result(root,r,site=site);invisible(r)
  })
}
install_site <- function(root='.',site) {
  rebuild_run(root,site)
  invisible(site)
}
path_id <- function(path) {
  if(file.exists(path)||dir.exists(path))return(normalizePath(path,mustWork=TRUE))
  if(basename(path)=='.')return(path_id(dirname(path)))
  if(basename(path)=='..')return(dirname(path_id(dirname(path))))
  file.path(path_id(dirname(path)),basename(path))
}
preview_destination <- function(path,root='.',data_dir=NULL) {
  target<-path_id(path)
  within<-function(dir)target==path_id(dir)||startsWith(target,paste0(path_id(dir),'/'))
  if(any(vapply(file.path(root,c('data','config','scripts','web','.git')),within,TRUE)) ||
     target==path_id(file.path(root,'renv.lock')))stop('Output would overwrite an input')
  cfg<-read_inputs(root)$config
  if(target==path_id(file.path(root,'assets/datacenters.json')) || within(file.path(root,cfg$tracker$output_dir)) ||
     within(file.path(root,'assets/js')))stop('Preview cannot overwrite active outputs; use build without preview options')
  site<-site_checkout(root)
  if(!is.null(site)&&within(site))stop('Preview cannot overwrite the local site')
  if(!is.null(data_dir) && target==path_id(file.path(data_dir,'packet.json')))stop('Output would overwrite the work packet')
  path
}
json_destination <- function(path,root='.',data_dir=NULL) {
  if(!grepl('\\.json$',path))stop('Output must be a .json file')
  preview_destination(path,root,data_dir)
}
check_outputs <- function(root='.',result=build_result(root),site=NULL) {
  # Compare the persisted artifacts, not just a successful in-memory calculation.
  stage<-tempfile('datacenter-check-');dir.create(stage);on.exit(unlink(stage,recursive=TRUE))
  result<-previous_inventory(root,result)
  atomic_output(result,file.path(stage,'analysis.json'))
  write_tracker(build_tracker(root,result=result),file.path(stage,'tracker'))
  files<-list.files(file.path(stage,'tracker'),full.names=TRUE)
  expected<-c(file.path(stage,'analysis.json'),files)
  cfg<-read_inputs(root)$config
  actual<-c(file.path(root,'assets/datacenters.json'),file.path(root,cfg$tracker$output_dir,basename(files)))
  site<-site_checkout(root,site)
  if(!is.null(site)) {
    presentation<-site_presentation(root,site)
    expected<-c(expected,files,unname(presentation))
    actual<-c(actual,file.path(site,cfg$tracker$output_dir,basename(files)),names(presentation))
  }
  good<-vapply(seq_along(actual),function(i)file.exists(actual[i])&&!dir.exists(actual[i])&&
    file_hash(actual[i])==file_hash(expected[i]),TRUE)
  if(!all(good))stop('Saved outputs are missing or stale; run build. Files: ',paste(actual[!good],collapse=', '))
  list(saved_outputs_current=TRUE,local_site=site %||% 'not_present')
}
pipeline_main <- function(args=commandArgs(trailingOnly=TRUE)) {
  command<-if(length(args))args[1] else 'check';opts<-list()
  for(a in args[-1]) {
    if(!grepl('^--[^=]+=.+$',a))stop('Use --name=value')
    kv<-strsplit(sub('^--','',a),'=',fixed=TRUE)[[1]]
    if(kv[1] %in% names(opts))stop('Duplicate option')
    opts[[kv[1]]]<-paste(kv[-1],collapse='=')
  }
  allowed<-list(check=c('data','site'),build=c('data','output','site'),packet=c('data','output','country'),
                prepare=c('output','country','mode'),apply=c('data','output','site'),tracker=c('data','output-dir','site'),
                review=c('country','output'),approve=c('ids','review','site'),exclude=c('ids','reason','site'))
  if(!command %in% names(allowed))stop('Commands: check, build, packet, prepare, apply, tracker, review, approve, exclude')
  if(any(!names(opts) %in% allowed[[command]]))stop('Unknown option for ',command)
  data_dir<-opts$data %||% 'data'
  if(command=='review') {
    r<-review_candidates(country=opts$country %||% 'SE')
    if(is.null(opts$output))cat(jsonlite::toJSON(r,auto_unbox=TRUE,pretty=TRUE,na='null'), '\n')
    else {path<-json_destination(opts$output);atomic_output(r,path);cat('Review ready for manual approval in chat: ',path,'\n',sep='')}
    return(invisible(r))
  }
  if(command=='approve') {
    if(is.null(opts$ids)||is.null(opts$review))stop('approve needs --ids=<IDs explicitly approved in chat> and --review=<review.json>')
    r<-approve_candidates(project_ids=trimws(strsplit(opts$ids,',',fixed=TRUE)[[1]]),review_path=opts$review,site=opts$site)
    cat('Applied manual candidate approval; rebuilt the shared result and site files. No publication.\n')
    return(invisible(r))
  }
  if(command=='exclude') {
    if(is.null(opts$ids)||is.null(opts$reason))stop('exclude needs --ids=<IDs the user named> and --reason=<short reason>')
    exclude_projects(project_ids=trimws(strsplit(opts$ids,',',fixed=TRUE)[[1]]),reason=opts$reason,site=opts$site)
    cat('Marked out of scope; rebuilt the shared result and site files. No publication.\n')
    return(invisible(NULL))
  }
  if(command=='tracker') {
    dir<-opts[['output-dir']]
    if(!is.null(opts$data)&&is.null(dir))stop('Preview with --data requires --output-dir outside active outputs')
    if(is.null(dir)) {
      rebuild_run(site=opts$site)
      cat('Built approved results and local site when present. No publication.\n')
    } else {
      if(!is.null(opts$site))stop('Preview cannot be combined with --site')
      preview_destination(dir)
      files<-c('results.json','projects.json','capacity.json','scenario_zone.json','timeline.json','bidding_zones.geojson')
      for(f in files)preview_destination(file.path(dir,f),data_dir=data_dir)
      write_tracker(build_tracker('.',data_dir),dir)
      cat('Built standalone tracker preview: ',dir,'\n',sep='')
    }
    return(invisible(NULL))
  }
  if(command=='prepare') {
    path<-opts$output %||% tempfile('datacenter-run-',tmpdir=Sys.getenv('TMPDIR',unset='/tmp'))
    prepare_run(path=path,country=opts$country %||% 'all',mode=opts$mode %||% 'refresh')
    cat('Prepared work directory ',path,'; read packet.json and follow prompts/update.md. No research performed.\n',sep='')
    w<-worklist_counts(json_read(file.path(path,'packet.json'))$worklist)
    cat('Worklist: ',paste(names(w),w,sep='=',collapse=', '),'\n',sep='')
  } else if(command=='packet') {
    path<-json_destination(opts$output %||% tempfile('datacenter-packet-',tmpdir=Sys.getenv('TMPDIR',unset='/tmp'),fileext='.json'),data_dir=data_dir)
    atomic_output(make_packet(data_dir=data_dir,country=opts$country %||% 'all'),path);cat('Prepared ',path,'\n',sep='')
  } else if(command=='apply') {
    if(is.null(opts$data))stop('apply needs --data=<prepared work directory>')
    path<-opts$output %||% 'assets/datacenters.json'
    r<-apply_run(path=data_dir,output=path,site=opts$site)
    cat('Applied tables and rebuilt all active outputs; ',r$result$coverage$projects,' projects represented in every scenario.\n',sep='')
  } else {
    if(command=='build'&&!is.null(opts$data)&&is.null(opts$output))stop('Preview with --data requires --output outside active outputs')
    if(command=='build'&&!is.null(opts$output)&&!is.null(opts$site))stop('Preview cannot be combined with --site')
    if(command=='build'&&is.null(opts$output)) {
      r<-rebuild_run(site=opts$site)
      cat('Built all approved results and local site when present. No publication.\n')
      return(invisible(r))
    }
    review<-if(file.exists(file.path(data_dir,'packet.json')))review_run(path=data_dir) else NULL
    r<-build_result('.',data_dir)
    countries<-if(!is.null(review))unlist(review$packet$countries) else names(read_inputs()$config$countries)
    wl<-run_worklist(read_inputs('.',data_dir),countries)
    if(command=='check') {
      live<-path_id(data_dir)==path_id('data')
      if(!live&&!is.null(opts$site))stop('A work-copy check cannot verify the active site')
      outputs<-if(live)check_outputs(result=r,site=opts$site) else list(saved_outputs_current=NA,scope='work_copy_only')
      cat(jsonlite::toJSON(list(valid=TRUE,outputs=outputs,coverage=r$coverage,changes=review$changes,
        timing_diagnostics=r$timing_diagnostics,timing_followups_open=sum(vapply(wl$timing_followups,function(z)z$review_status=='open',TRUE)),
        timing_followups_documented=sum(vapply(wl$timing_followups,function(z)z$review_status=='documented_uncertainty',TRUE)),
        containment_conflicts=sum(vapply(wl$timing_followups,function(z)'containment_conflict' %in% z$reasons,TRUE)),
        worklist_remaining=as.list(worklist_counts(wl)),worklist=wl,
        map_zones=length(r$bidding_zones$features)),auto_unbox=TRUE,pretty=TRUE),'\n')
    } else {
      path<-json_destination(opts$output,data_dir=data_dir)
      atomic_output(r,path)
      cat('Built standalone preview: ',path,'\n',sep='')
    }
  }
}
if(sys.nframe()==0L)pipeline_main()
