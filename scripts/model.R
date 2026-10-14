# Three input tables, one method configuration, one calculation path.
`%||%` <- function(x,y) if (is.null(x) || !length(x)) y else x
number <- function(x) suppressWarnings(as.numeric(x))
ids <- function(x) unique(Filter(nzchar,trimws(unlist(strsplit(x %||% '', ';', fixed=TRUE)))))
json_read <- function(path) jsonlite::fromJSON(path,simplifyVector=FALSE)
json_write <- function(value,path) jsonlite::write_json(value,path,pretty=TRUE,auto_unbox=TRUE,na='null',null='null',digits=NA)
file_hash <- function(path) digest::digest(file=path,algo='sha256',serialize=FALSE)
read_inputs <- function(root='.',data_dir=file.path(root,'data')) {
  cfg <- json_read(file.path(root,'config/pipeline.json'))
  tables <- lapply(names(cfg$tables),function(name) {
    path <- file.path(data_dir,paste0(name,'.csv'))
    d <- read.csv(path,colClasses='character',na.strings=NULL,check.names=FALSE,
                  stringsAsFactors=FALSE,fileEncoding='UTF-8',comment.char='')
    if (!identical(names(d),unlist(cfg$tables[[name]],use.names=FALSE)) || anyNA(d)) stop('Invalid columns/CSV: ',path)
    d
  })
  names(tables) <- names(cfg$tables)
  list(config=cfg,projects=tables$projects,capacity=tables$capacity,sources=tables$sources)
}
input_hashes <- function(root='.',data_dir=file.path(root,'data')) {
  cfg<-json_read(file.path(root,'config/pipeline.json'))
  maps<-unique(vapply(cfg$zones,function(z)z$geometry,character(1)))
  paths <- c(file.path(data_dir,c('projects.csv','capacity.csv','sources.csv')),
             file.path(root,c('config/pipeline.json','scripts/model.R','scripts/pipeline.R','renv.lock',
                              'prompts/update.md','AGENTS.md','README.md',maps)))
  setNames(lapply(paths,file_hash),c('projects','capacity','sources','method','model','command','environment',
                                   'prompt','instructions','readme',maps))
}
validate_inputs <- function(x,allow_empty=FALSE) {
  p<-x$projects;c<-x$capacity;s<-x$sources;cfg<-x$config
  require_true <- function(ok,message) if (!isTRUE(all(ok))) stop(message,call.=FALSE)
  require_true(allow_empty || nrow(p)>0,'Project inventory is empty')
  for (d in list(p,c,s)) require_true(!anyDuplicated(d[[1]]) && all(nzchar(d[[1]])),'Missing/duplicate permanent ID')
  require_true(grepl('^P[0-9]{3,}$',p$project_id),'Invalid project ID')
  require_true(grepl('^C[0-9]{3,}$',c$claim_id),'Invalid claim ID')
  require_true(grepl('^S[0-9]{3,}$',s$source_id),'Invalid source ID')
  require_true(p$country %in% names(cfg$countries),'Unknown country')
  for (i in seq_len(nrow(p))) {
    allowed<-vapply(Filter(function(z) z$country==p$country[i],cfg$zones),function(z)z$id,character(1))
    require_true(!nzchar(p$bidding_zone[i]) || p$bidding_zone[i] %in% allowed,paste('Wrong country/zone:',p$project_id[i]))
  }
  lifecycle<-unlist(cfg$values$status)
  require_true(all(p$status %in% lifecycle) && all(c$status %in% lifecycle),'Unknown lifecycle status')
  require_true(p$record_type %in% unlist(cfg$values$record_type),'Unknown record type')
  require_true(c$project_id %in% p$project_id,'Orphaned capacity')
  require_true(!nzchar(p$related_project_id) | p$related_project_id %in% p$project_id,'Orphaned related project')
  require_true(p$project_id!=p$related_project_id,'Project cannot refer to itself')
  require_true(c$basis %in% names(cfg$values$basis),'Unknown capacity basis')
  for (key in c('decision','qualifier','timing','relation','baseline_scope','issue')) require_true(c[[key]] %in% unlist(cfg$values[[key]]),paste('Unknown',key))
  require_true(s$kind %in% unlist(cfg$values$source_kind),'Unknown excerpt kind')
  require_true(s$kind!='quote' | (nzchar(s$excerpt)&nzchar(s$locator)),'An exact quotation needs text and a locator')
  require_true(grepl('^https?://',s$url),'Invalid source URL')
  for (key in c('mw','mw_max','pue','construction_year','first_year','last_year')) {
    v<-c[[key]];parsed<-number(v)
    require_true(!nzchar(v) | (is.finite(parsed) & parsed>=0),paste('Invalid number:',key))
    if (grepl('year',key)) require_true(!nzchar(v) | (parsed==floor(parsed) & parsed>=1900 & parsed<=2200),'Invalid year')
  }
  require_true(!nzchar(c$pue) | (number(c$pue)>=1 & number(c$pue)<=3),'Invalid PUE')
  require_true(!nzchar(c$mw_max) | (nzchar(c$mw) & number(c$mw_max)>=number(c$mw)),'Reversed capacity interval')
  require_true(c$qualifier!='range' | nzchar(c$mw_max),'Range needs upper value')
  require_true(!nzchar(c$first_year) | !nzchar(c$last_year) | number(c$first_year)<=number(c$last_year),'Reversed timing interval')
  for (d in list(p,c)) for (ref in d$source_ids) require_true(ids(ref) %in% s$source_id,'Missing source reference')
  for (i in seq_len(nrow(c))) {
    for (field in c('parent_id','baseline_id')) require_true(!nzchar(c[[field]][i]) || c[[field]][i] %in% c$claim_id,paste('Missing',field))
    require_true(!c$relation[i] %in% c('included_in','possibly_included_in') || nzchar(c$parent_id[i]),'Containment needs parent')
    require_true(c$baseline_scope[i]!='existing_known' || nzchar(c$baseline_id[i]),'Known baseline needs a claim')
    if (c$baseline_scope[i]=='existing_known') {
      b<-c[match(c$baseline_id[i],c$claim_id),]
      require_true(b$basis==c$basis[i] && b$status=='Operational' && b$project_id==c$project_id[i],'Incomparable installed baseline')
      require_true(is.finite(number(b$mw)) && number(b$mw)<=number(c$mw[i]),'Invalid installed baseline size')
    }
    seen<-c$claim_id[i];j<-i
    while (c$relation[j] %in% c('included_in','possibly_included_in')) {
      parent<-c$parent_id[j];require_true(!parent %in% seen,'Containment cycle')
      k<-match(parent,c$claim_id);a<-p[match(c$project_id[j],p$project_id),];b<-p[match(c$project_id[k],p$project_id),]
      require_true(a$country==b$country && (!nzchar(a$bidding_zone)||!nzchar(b$bidding_zone)||a$bidding_zone==b$bidding_zone),'Containment crosses country/zone')
      seen<-c(seen,parent);j<-k
    }
  }
  for (field in c('latitude','longitude')) {
    value<-number(p[[field]]);limit<-if(field=='latitude')90 else 180
    require_true(!nzchar(p[[field]]) | (is.finite(value) & abs(value)<=limit),'Invalid display coordinate')
  }
  require_true(nzchar(p$latitude)==nzchar(p$longitude),'Both display coordinates are required together')
  require_true(!anyDuplicated(vapply(cfg$scenarios,function(v)v$id,character(1))),'Duplicate scenario')
  for (scenario in cfg$scenarios) {
    require_true(scenario$selection %in% c('decided_dated','dated','all'),'Invalid scenario selection')
    require_true(is.finite(scenario$year) && scenario$year==floor(scenario$year),'Invalid scenario year')
  }
  for (field in c('pue','nameplate_annual_fraction','peak_annual_fraction','peak_to_nameplate_fraction')) {
    v<-unlist(cfg$assumptions[[field]]);require_true(length(v)==2 && all(is.finite(v)) && v[1]<=v[2] && v[1]>=0,'Invalid assumption range')
  }
  require_true(unlist(cfg$assumptions$pue)>=1,'PUE must be at least one')
  require_true(all(unlist(cfg$assumptions$nameplate_annual_fraction)<=1) && all(unlist(cfg$assumptions$peak_annual_fraction)<=1),'Annual use fraction exceeds one')
  require_true(all(unlist(cfg$assumptions$peak_to_nameplate_fraction)>0 & unlist(cfg$assumptions$peak_to_nameplate_fraction)<=1),'Invalid peak/nameplate conversion')
  require_true(is.finite(cfg$assumptions$first_to_full_years) && cfg$assumptions$first_to_full_years>0,'Invalid ramp duration')
  lag<-unlist(cfg$assumptions$construction_to_first_years)
  require_true(length(lag)==2 && all(is.finite(lag)) && lag[1]>0 && lag[2]>=lag[1],'Invalid construction lag')
  invisible(TRUE)
}
timing_share <- function(row,year,cfg) {
  first<-number(row$first_year);last<-number(row$last_year);built<-number(row$construction_year)
  if (!is.finite(last)) last<-first
  if (!is.finite(first)) first<-last
  years<-cfg$assumptions$first_to_full_years
  lag<-unlist(cfg$assumptions$construction_to_first_years)
  ramp<-function(start) max(0,min(1,(year-start+1)/years))
  answer<-function(v,rule,dated=TRUE) list(share=v,rule=rule,dated=dated)
  if (row$timing=='full_capacity' && is.finite(first)) {
    backcast<-function(end,delay) {
      if (year>=end) return(1)
      start<-end-years+1
      if (is.finite(built)) start<-min(end,max(start,built+delay))
      max(0,min(1,(year-start+1)/(end-start+1)))
    }
    return(answer(c(backcast(last,lag[2]),backcast(first,lag[1])),'full_capacity_anchor_with_modelled_backcast'))
  }
  if (row$timing=='first_capacity' && is.finite(first))
    return(answer(c(ramp(last),ramp(first)),'EPRI_five_year_ramp'))
  if (row$timing=='grid_availability' && is.finite(first)) {
    start<-if(is.finite(built))max(first,built+lag[1]) else first
    return(answer(c(0,ramp(start)),'grid_year_is_only_earliest_start'))
  }
  if (is.finite(built)) return(answer(c(ramp(built+lag[2]),ramp(built+lag[1])),'IEA_construction_lag_and_EPRI_ramp'))
  answer(c(0,1),'undated_deployment_0_to_1',FALSE)
}
scenario_selected <- function(row,scenario,timing) {
  switch(scenario$selection,all=TRUE,dated=timing$dated,decided_dated=timing$dated && row$decision=='yes')
}
electrical_range <- function(row,cfg,net=FALSE,claims=NULL,normalize_peak=TRUE) {
  if (row$basis %in% c('backup','generation','density') || row$issue=='identity_conflict' || !nzchar(row$mw)) return(c(NA_real_,NA_real_))
  v<-number(row$mw);top<-if(row$qualifier=='range')number(row$mw_max) else if(row$qualifier=='at_least')NA_real_ else v
  if (net && row$baseline_scope=='existing_known') {
    b<-claims[match(row$baseline_id,claims$claim_id),]
    bottom_b<-number(b$mw);top_b<-if(b$qualifier=='range')number(b$mw_max) else if(b$qualifier=='at_least')Inf else bottom_b
    v<-max(0,v-top_b);top<-max(0,top-bottom_b)
  }
  pue<-unlist(cfg$assumptions$pue)
  if (nzchar(row$pue)) pue<-c(min(pue[1],number(row$pue)),number(row$pue))
  if (startsWith(row$basis,'it_')) {v<-v*pue[1];top<-top*pue[2]}
  if (normalize_peak && grepl('_peak$',row$basis)) {
    factors<-unlist(cfg$assumptions$peak_to_nameplate_fraction)
    v<-v/factors[2];top<-top/factors[1]
  }
  if (net && row$baseline_scope=='existing_unknown') v<-0
  c(v,top)
}
top_claim <- function(claims,index) {
  while (claims$relation[index] %in% c('included_in','possibly_included_in')) index<-match(claims$parent_id[index],claims$claim_id)
  index
}
maximum_known <- function(values) if(all(is.na(values))) NA_real_ else max(values,na.rm=TRUE)
calculate <- function(x) {
  validate_inputs(x);p<-x$projects;c<-x$capacity;cfg<-x$config
  all_rows<-list();overview<-list();zone_rows<-list()
  for (scenario in cfg$scenarios) {
    rows<-lapply(seq_len(nrow(c)),function(i) {
      r<-c[i,];pr<-p[match(r$project_id,p$project_id),]
      group<-c$claim_id[top_claim(c,i)]
      gross<-electrical_range(r,cfg);net<-electrical_range(r,cfg,TRUE,c)
      timing<-timing_share(r,scenario$year,cfg)
      selected<-scenario_selected(r,scenario,timing)
      share<-if(selected)timing$share else c(0,0)
      reason<-'modelled';assumptions<-timing$rule
      if (r$status %in% c('Operational','Cancelled','Dormant')) reason<-tolower(r$status)
      if (pr$status %in% c('Cancelled','Dormant')) reason<-tolower(pr$status)
      if (r$issue=='identity_conflict') reason<-'identity_conflict'
      if (nzchar(pr$related_project_id)) reason<-'related_identity'
      if (r$basis %in% c('backup','generation','density')) reason<-'no_datacenter_load'
      if (!nzchar(r$mw)) reason<-'capacity_unknown'
      nameplate<-if(reason=='modelled')net else c(0,0)
      if (reason!='modelled') share<-c(0,0)
      if (reason=='modelled' && !selected) reason<-'outside_scenario_selection'
      if (reason=='modelled' && share[2]==0) reason<-'after_target_year'
      if (r$basis %in% c('unspecified','it_unspecified','facility_unspecified')) assumptions<-c(assumptions,'capacity_definition_assumed')
      if (r$basis=='grid') assumptions<-c(assumptions,'connection_deployment_assumed')
      if (startsWith(r$basis,'it_')) assumptions<-c(assumptions,'PUE_conversion')
      if (grepl('_peak$',r$basis)) assumptions<-c(assumptions,'peak_to_nameplate_equivalent')
      if (r$baseline_scope=='existing_unknown') assumptions<-c(assumptions,'increment_unknown_0_to_site_envelope')
      if (r$relation=='possibly_included_in') assumptions<-c(assumptions,'overlap_assumed_contained')
      if (nzchar(pr$related_project_id)) assumptions<-c(assumptions,'related_identity_unresolved')
      # A zero deployment is known even when an at-least claim has no upper MW.
      value<-ifelse(share>0,net*share,0)
      lf<-unlist(cfg$assumptions[[if(grepl('_peak$',r$basis))'peak_annual_fraction' else 'nameplate_annual_fraction']])
      energy_power<-ifelse(share>0,electrical_range(r,cfg,TRUE,c,normalize_peak=FALSE)*share,0)
      energy<-energy_power*lf*8760/1e6
      data.frame(scenario=scenario$id,project_id=r$project_id,claim_id=r$claim_id,group_id=group,
        share_low=share[1],share_high=share[2],reason=reason,assumptions=paste(assumptions,collapse=';'),
        source_basis=r$basis,reported_mw=number(r$mw),gross_mw_low=gross[1],gross_mw_high=gross[2],
        nameplate_mw_low=nameplate[1],nameplate_mw_high=nameplate[2],
        direct_mw_low=value[1],direct_mw_high=value[2],direct_twh_low=energy[1],direct_twh_high=energy[2],
        counted_mw_low=0,counted_mw_high=0,annual_twh_low=0,annual_twh_high=0,stringsAsFactors=FALSE)
    })
    ledger<-if(length(rows))do.call(rbind,rows) else as.data.frame(c(
      setNames(rep(list(character()),7),c('scenario','project_id','claim_id','group_id','reason','assumptions','source_basis')),
      setNames(rep(list(numeric()),15),c('share_low','share_high','reported_mw','gross_mw_low','gross_mw_high','nameplate_mw_low','nameplate_mw_high','direct_mw_low','direct_mw_high','direct_twh_low','direct_twh_high','counted_mw_low','counted_mw_high','annual_twh_low','annual_twh_high'))),stringsAsFactors=FALSE)
    # One electrical envelope per containment tree. A tenant never removes its campus.
    # Explicit independent/incremental rows remain separate; contained alternatives use max.
    if (nrow(ledger)) for (group in unique(ledger$group_id)) {
      members<-which(ledger$group_id==group);owner<-match(group,ledger$claim_id)
      for(key in c('nameplate_mw_low','nameplate_mw_high')) {
        v<-ledger[[key]][members]
        ledger[[key]][members]<-0
        ledger[[key]][owner]<-if(anyNA(v) && grepl('high$',key))NA_real_ else maximum_known(v)
      }
      a<-unique(unlist(lapply(ledger$assumptions[members],ids)))
      if(!any(is.finite(c(ledger$gross_mw_low[owner],ledger$gross_mw_high[owner])))) a<-c(a,'only_contained_capacity_known')
      ledger$assumptions[owner]<-paste(a,collapse=';')
      active<-members[ledger$share_high[members]>0]
      if (!length(active)) next
      for (pair in list(c('direct_mw_low','counted_mw_low'),c('direct_mw_high','counted_mw_high'),c('direct_twh_low','annual_twh_low'),c('direct_twh_high','annual_twh_high'))) {
        v<-ledger[[pair[1]]][active]
        ledger[[pair[2]]][owner]<-if(anyNA(v) && grepl('high$',pair[2]))NA_real_ else maximum_known(v)
      }
      if (ledger$share_high[owner]==0) ledger$reason[owner]<-'contains_modelled_phase'
      children<-setdiff(active,owner);ledger$reason[children]<-paste0('included_in:',group)
    }
    all_rows[[length(all_rows)+1]]<-ledger
    for (i in seq_len(nrow(p))) {
      pr<-p[i,];lr<-ledger[ledger$project_id==pr$project_id,,drop=FALSE]
      live<-any(lr$share_high>0 | lr$reason=='contains_modelled_phase')
      # The physical owner also represents quantified contained phases, even
      # when the owner's own headline MW is missing. Otherwise the known phase
      # is assigned to an owner that is then replaced by NA in zone totals.
      scope<-ledger[ledger$project_id==pr$project_id | ledger$group_id %in% lr$claim_id,,drop=FALSE]
      has_load<-any(is.finite(scope$gross_mw_high)|is.finite(scope$gross_mw_low))
      category<-if(pr$status %in% c('Cancelled','Dormant'))tolower(pr$status) else if(pr$status=='Operational')'operational' else if(pr$record_type=='candidate')'candidate' else if(!has_load)'unquantified' else 'pipeline'
      missing_load<-!has_load && !pr$status %in% c('Cancelled','Dormant','Operational')
      project_sum<-function(key) if(missing_load || anyNA(lr[[key]]))NA_real_ else sum(lr[[key]])
      overview[[length(overview)+1]]<-data.frame(scenario=scenario$id,project_id=pr$project_id,country=pr$country,
        bidding_zone=if(nzchar(pr$bidding_zone))pr$bidding_zone else paste0(pr$country,'-unassigned'),
        indicator=category,capacity_known=has_load,participates=live,related_project_id=pr$related_project_id,
        nameplate_mw_low=project_sum('nameplate_mw_low'),nameplate_mw_high=project_sum('nameplate_mw_high'),
        mw_low=project_sum('counted_mw_low'),mw_high=project_sum('counted_mw_high'),
        annual_twh_low=project_sum('annual_twh_low'),annual_twh_high=project_sum('annual_twh_high'),
        note=if(nzchar(pr$related_project_id))'Related identity retained; not a separate quantified addition.' else if(!nrow(lr))'No capacity claim; project remains visible.' else paste(unique(lr$reason),collapse=';'),stringsAsFactors=FALSE)
    }
  }
  project_scenarios<-do.call(rbind,overview);ledger<-do.call(rbind,all_rows)
  zone_ids<-c(vapply(cfg$zones,function(z)z$id,character(1)),paste0(names(cfg$countries),'-unassigned'))
  for (scenario in cfg$scenarios) for (zone in zone_ids) {
    d<-project_scenarios[project_scenarios$scenario==scenario$id & project_scenarios$bidding_zone==zone,,drop=FALSE]
    sum_known<-function(key) if(!nrow(d)||all(is.na(d[[key]]))||any(is.na(d[[key]]) & d$capacity_known))NA_real_ else sum(d[[key]],na.rm=TRUE)
    active<-!d$indicator %in% c('cancelled','dormant')
    partial<-any(ledger$scenario==scenario$id & ledger$project_id %in% d$project_id & grepl('only_contained_capacity_known',ledger$assumptions,fixed=TRUE))
    zone_rows[[length(zone_rows)+1]]<-data.frame(scenario=scenario$id,bidding_zone=zone,projects=nrow(d),
      participating_projects=sum(d$participates),candidate_projects=sum(p$record_type[match(d$project_id,p$project_id)]=='candidate'),
      operating_projects=sum(d$indicator=='operational'),cancelled_or_dormant=sum(!active),
      projects_without_mw=sum(active & !d$capacity_known),
      nameplate_mw_low=sum_known('nameplate_mw_low'),nameplate_mw_high=sum_known('nameplate_mw_high'),
      mw_low=sum_known('mw_low'),mw_high=sum_known('mw_high'),
      annual_twh_low=sum_known('annual_twh_low'),annual_twh_high=sum_known('annual_twh_high'),
      scope=if(!nrow(d))'no_inventory' else if(partial||sum(active & !d$capacity_known)||anyNA(d$mw_high))'quantified_subset' else 'modelled_inventory',stringsAsFactors=FALSE)
  }
  # Coverage is a product requirement, not a claim that unknown MW has become zero.
  expected<-nrow(p)*length(cfg$scenarios)
  if(nrow(project_scenarios)!=expected || anyDuplicated(paste(project_scenarios$scenario,project_scenarios$project_id))) stop('A project disappeared or was duplicated')
  list(scenarios=do.call(rbind,zone_rows),project_scenarios=project_scenarios,ledger=ledger)
}
assemble_map <- function(cfg,root='.') {
  features<-list()
  for (zone in cfg$zones) {
    doc<-json_read(file.path(root,zone$geometry))
    crs<-doc$crs$properties$name
    if(!is.null(crs) && !crs %in% c('urn:ogc:def:crs:OGC:1.3:CRS84','urn:ogc:def:crs:EPSG::4326','EPSG:4326'))stop('Map requires reprojection')
    candidates<-if(doc$type=='FeatureCollection')doc$features else if(doc$type=='Feature')list(doc) else stop('Map needs features')
    names<-vapply(candidates,function(f)gsub('_','',sub('^NO-','',f$properties$bidding_zone %||% f$properties$zoneName %||% '')),character(1))
    found<-which(names==zone$id);if(length(found)!=1)stop('Missing/duplicate map zone: ',zone$id)
    f<-candidates[[found]];g<-f$geometry
    if(!g$type %in% c('Polygon','MultiPolygon'))stop('Invalid geometry')
    polygons<-if(g$type=='Polygon')list(g$coordinates) else g$coordinates
    if(!length(polygons))stop('Empty geometry')
    for(poly in polygons) {
      if(!length(poly))stop('Empty polygon')
      for(ring in poly) {
        if(length(ring)<4 || any(lengths(ring)!=2))stop('Invalid polygon ring')
        xy<-do.call(rbind,lapply(ring,unlist))
        if(!is.numeric(xy)||any(!is.finite(xy))||any(abs(xy[,1])>180)||any(abs(xy[,2])>90)||any(xy[1,]!=xy[nrow(xy),])||nrow(unique(xy))<3)stop('Invalid WGS84 ring')
      }
    }
    f$id<-zone$id;f$properties<-list(bidding_zone=zone$id,country=zone$country,provenance='inherited_unverified')
    features[[length(features)+1]]<-f
  }
  list(type='FeatureCollection',features=features)
}
capacity_followups <- function(x) {
  # Discovery aid, not a gate on calculation and not proof that all facts were extracted.
  # It catches MW-bearing sources retained on a project without a corresponding claim.
  findings<-list()
  for(i in seq_len(nrow(x$projects))) {
    p<-x$projects[i,]
    if(p$status %in% c('Cancelled','Dormant')) next
    c<-x$capacity[x$capacity$project_id==p$project_id,,drop=FALSE]
    linked<-unique(c(ids(p$source_ids),unlist(lapply(c$source_ids,ids))))
    s<-x$sources[x$sources$source_id %in% linked,,drop=FALSE]
    text<-paste(s$title,s$excerpt)
    power<-s$source_id[grepl('[0-9][0-9.,[:space:]]*([MG]W(e|th)?|(mega|giga)wat{1,2}[[:alpha:]]*)\\b',text,ignore.case=TRUE,perl=TRUE)]
    represented<-unique(unlist(lapply(c$source_ids[nzchar(c$mw) & c$issue!='identity_conflict'],ids)))
    missing<-setdiff(power,represented)
    if(length(missing)) findings[[length(findings)+1]]<-list(project_id=p$project_id,source_ids=as.list(missing))
  }
  findings
}
build_result <- function(root='.',data_dir=file.path(root,'data')) {
  before<-input_hashes(root,data_dir);x<-read_inputs(root,data_dir);result<-calculate(x);map<-assemble_map(x$config,root)
  if(!identical(before,input_hashes(root,data_dir)))stop('Inputs changed during build; retry after edits finish')
  list(version=x$config$version,as_of=x$config$as_of,input_hashes=before,
    method=list(scenarios=x$config$scenarios,assumptions=x$config$assumptions,geography_note=x$config$geography_note),
    projects=x$projects,capacity=x$capacity,sources=x$sources,
    scenarios=result$scenarios,project_scenarios=result$project_scenarios,ledger=result$ledger,
    coverage=list(projects=nrow(x$projects),claims=nrow(x$capacity),sources=nrow(x$sources),
      scenario_rows=nrow(result$project_scenarios),every_project_represented=TRUE,
      projects_without_mw=as.list(unique(result$project_scenarios$project_id[!result$project_scenarios$capacity_known & !result$project_scenarios$indicator %in% c('cancelled','dormant','operational')])),
      capacity_sources_to_reconcile=capacity_followups(x)),bidding_zones=map)
}
atomic_output <- function(result,path) {
  dir.create(dirname(path),recursive=TRUE,showWarnings=FALSE)
  tmp<-tempfile('.datacenters-',dirname(path));on.exit(unlink(tmp),add=TRUE)
  json_write(result,tmp)
  json_read(tmp)
  if(!file.rename(tmp,path))stop('Could not replace output')
  invisible(path)
}
