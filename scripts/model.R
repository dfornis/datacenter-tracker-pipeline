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
             file.path(root,c('config/pipeline.json','scripts/model.R','scripts/pipeline.R','renv.lock',maps)))
  setNames(lapply(paths,file_hash),c('projects','capacity','sources','method','model','command','environment',maps))
}
validate_inputs <- function(x) {
  p<-x$projects;c<-x$capacity;s<-x$sources;cfg<-x$config
  require_true <- function(ok,message) if (!isTRUE(all(ok))) stop(message,call.=FALSE)
  require_true(nrow(p)>0,'Project inventory is empty')
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
    w<-unlist(scenario$share);require_true(all(c('construction','advanced','early') %in% names(w)) && all(is.finite(w)&w>=0&w<=1),'Invalid scenario shares')
  }
  for (field in c('pue','nameplate_annual_fraction','peak_annual_fraction','peak_to_nameplate_fraction')) {
    v<-unlist(cfg$assumptions[[field]]);require_true(length(v)==2 && all(is.finite(v)) && v[1]<=v[2] && v[1]>=0,'Invalid assumption range')
  }
  require_true(unlist(cfg$assumptions$pue)>=1,'PUE must be at least one')
  require_true(all(unlist(cfg$assumptions$nameplate_annual_fraction)<=1) && all(unlist(cfg$assumptions$peak_annual_fraction)<=1),'Annual use fraction exceeds one')
  require_true(all(unlist(cfg$assumptions$peak_to_nameplate_fraction)>0 & unlist(cfg$assumptions$peak_to_nameplate_fraction)<=1),'Invalid peak/nameplate conversion')
  for (key in c('first_to_full_years','small_scope_years','campus_threshold_mw','construction_to_first_years')) require_true(is.finite(cfg$assumptions[[key]]) && cfg$assumptions[[key]]>0,paste('Invalid assumption',key))
  invisible(TRUE)
}
stage_of <- function(row,project=NULL) {
  if (row$status=='Under construction') 'construction'
  else if (row$decision=='yes' || row$status=='Permitted') 'advanced'
  else if (!is.null(project) && row$status=='Planned' && project$status %in% c('Under construction','Operational')) 'advanced'
  else 'early'
}
timing_cap <- function(row,year,cfg) {
  if (is.null(year)) return(1)
  first<-number(row$first_year);last<-number(row$last_year);built<-number(row$construction_year)
  if (!is.finite(last) && is.finite(first)) last<-first
  if (row$timing %in% c('first_capacity','grid_availability') && is.finite(last)) first<-last
  years<-if(is.finite(number(row$mw)) && number(row$mw)<cfg$assumptions$campus_threshold_mw) cfg$assumptions$small_scope_years else cfg$assumptions$first_to_full_years
  if (row$timing=='full_capacity' && is.finite(last)) {
    if (year>=last) return(1)
    start<-if(is.finite(built)) min(last,built+cfg$assumptions$construction_to_first_years) else last-years+1
    return(max(0,min(1,(year-start+1)/(last-start+1))))
  }
  if (row$timing=='grid_availability' && is.finite(first)) {
    # Availability constrains a possible start; it is not a statement of full deployment.
    first<-first+1
  } else if (!(row$timing=='first_capacity' && is.finite(first))) {
    first<-if(is.finite(built)) built+cfg$assumptions$construction_to_first_years else NA_real_
  }
  if (!is.finite(first)) return(1) # Maturity share already accounts for undated delivery.
  max(0,min(1,(year-first+1)/years))
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
  if (row$basis=='unspecified') top<-top*pue[2]
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
      r<-c[i,];pr<-p[match(r$project_id,p$project_id),];stage<-stage_of(r,pr)
      group<-c$claim_id[top_claim(c,i)]
      gross<-electrical_range(r,cfg);net<-electrical_range(r,cfg,TRUE,c)
      share<-min(scenario$share[[stage]],timing_cap(r,scenario$year,cfg))
      reason<-'modelled';assumptions<-character()
      if(stage!=stage_of(r)) assumptions<-c(assumptions,'site_maturity_only_not_full_phase_commitment')
      if (r$status %in% c('Operational','Cancelled','Dormant')) {reason<-tolower(r$status);share<-0}
      if (pr$status %in% c('Cancelled','Dormant')) {reason<-tolower(pr$status);share<-0}
      if (r$issue=='identity_conflict') {reason<-'identity_conflict';share<-0}
      if (nzchar(pr$related_project_id)) {reason<-'related_identity';share<-0}
      if (r$basis %in% c('backup','generation','density')) {reason<-'no_datacenter_load';share<-0}
      if (!nzchar(r$mw)) {reason<-'capacity_unknown';share<-0}
      if (reason=='modelled' && share==0) reason<-'outside_scenario'
      if (r$timing!='full_capacity' || !nzchar(r$last_year)) assumptions<-c(assumptions,'maturity_or_phasing_assumption')
      if (r$basis %in% c('unspecified','it_unspecified','facility_unspecified')) assumptions<-c(assumptions,'capacity_definition_assumed')
      if (r$basis=='grid') assumptions<-c(assumptions,'connection_deployment_assumed')
      if (startsWith(r$basis,'it_')) assumptions<-c(assumptions,'PUE_conversion')
      if (grepl('_peak$',r$basis)) assumptions<-c(assumptions,'peak_to_nameplate_equivalent')
      if (r$baseline_scope=='existing_unknown') assumptions<-c(assumptions,'increment_unknown_0_to_site_envelope')
      if (r$relation=='possibly_included_in') assumptions<-c(assumptions,'overlap_assumed_contained')
      if (nzchar(pr$related_project_id)) assumptions<-c(assumptions,'related_identity_unresolved')
      value<-if (share>0) net*share else c(0,0)
      lf<-unlist(cfg$assumptions[[if(grepl('_peak$',r$basis))'peak_annual_fraction' else 'nameplate_annual_fraction']])
      energy_power<-if(share>0)electrical_range(r,cfg,TRUE,c,normalize_peak=FALSE)*share else c(0,0)
      energy<-energy_power*lf*8760/1e6
      data.frame(scenario=scenario$id,project_id=r$project_id,claim_id=r$claim_id,group_id=group,
        stage=stage,share=share,reason=reason,assumptions=paste(assumptions,collapse=';'),
        source_basis=r$basis,reported_mw=number(r$mw),gross_mw_low=gross[1],gross_mw_high=gross[2],
        direct_mw_low=value[1],direct_mw_high=value[2],direct_twh_low=energy[1],direct_twh_high=energy[2],
        counted_mw_low=0,counted_mw_high=0,annual_twh_low=0,annual_twh_high=0,stringsAsFactors=FALSE)
    })
    ledger<-if(length(rows))do.call(rbind,rows) else as.data.frame(c(
      setNames(rep(list(character()),8),c('scenario','project_id','claim_id','group_id','stage','reason','assumptions','source_basis')),
      setNames(rep(list(numeric()),12),c('share','reported_mw','gross_mw_low','gross_mw_high','direct_mw_low','direct_mw_high','direct_twh_low','direct_twh_high','counted_mw_low','counted_mw_high','annual_twh_low','annual_twh_high'))),stringsAsFactors=FALSE)
    # One electrical envelope per containment tree. A tenant never removes its campus.
    # Explicit independent/incremental rows remain separate; contained alternatives use max.
    if (nrow(ledger)) for (group in unique(ledger$group_id)) {
      members<-which(ledger$group_id==group);owner<-match(group,ledger$claim_id)
      active<-members[ledger$share[members]>0]
      if (!length(active)) next
      for (pair in list(c('direct_mw_low','counted_mw_low'),c('direct_mw_high','counted_mw_high'),c('direct_twh_low','annual_twh_low'),c('direct_twh_high','annual_twh_high'))) {
        v<-ledger[[pair[1]]][active]
        ledger[[pair[2]]][owner]<-if(anyNA(v) && grepl('high$',pair[2]))NA_real_ else maximum_known(v)
      }
      if (owner %in% members && ledger$share[owner]==0) ledger$reason[owner]<-'contains_modelled_phase'
      children<-setdiff(active,owner);ledger$reason[children]<-paste0('included_in:',group)
      a<-unique(unlist(lapply(ledger$assumptions[members],ids)));ledger$assumptions[owner]<-paste(a,collapse=';')
    }
    all_rows[[length(all_rows)+1]]<-ledger
    for (i in seq_len(nrow(p))) {
      pr<-p[i,];lr<-ledger[ledger$project_id==pr$project_id,,drop=FALSE]
      live<-any(lr$share>0);has_load<-any(is.finite(lr$gross_mw_high)|is.finite(lr$gross_mw_low))
      category<-if(pr$record_type=='candidate')'candidate' else if(pr$status %in% c('Cancelled','Dormant'))tolower(pr$status) else if(pr$status=='Operational')'operational' else if(!has_load)'unquantified' else 'pipeline'
      missing_load<-!has_load && !pr$status %in% c('Cancelled','Dormant','Operational')
      project_sum<-function(key) if(missing_load || anyNA(lr[[key]]))NA_real_ else sum(lr[[key]])
      overview[[length(overview)+1]]<-data.frame(scenario=scenario$id,project_id=pr$project_id,country=pr$country,
        bidding_zone=if(nzchar(pr$bidding_zone))pr$bidding_zone else paste0(pr$country,'-unassigned'),
        indicator=category,capacity_known=has_load,participates=live,related_project_id=pr$related_project_id,
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
    zone_rows[[length(zone_rows)+1]]<-data.frame(scenario=scenario$id,bidding_zone=zone,projects=nrow(d),
      participating_projects=sum(d$participates),candidate_projects=sum(d$indicator=='candidate'),
      operating_projects=sum(d$indicator=='operational'),cancelled_or_dormant=sum(!active),
      projects_without_mw=sum(active & !d$capacity_known),
      mw_low=sum_known('mw_low'),mw_high=sum_known('mw_high'),
      annual_twh_low=sum_known('annual_twh_low'),annual_twh_high=sum_known('annual_twh_high'),
      scope=if(!nrow(d))'no_inventory' else if(sum(active & !d$capacity_known)||anyNA(d$mw_high))'quantified_subset' else 'modelled_inventory',stringsAsFactors=FALSE)
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
build_result <- function(root='.',data_dir=file.path(root,'data')) {
  before<-input_hashes(root,data_dir);x<-read_inputs(root,data_dir);result<-calculate(x);map<-assemble_map(x$config,root)
  if(!identical(before,input_hashes(root,data_dir)))stop('Inputs changed during build; retry after edits finish')
  list(version=x$config$version,as_of=x$config$as_of,input_hashes=before,
    method=list(scenarios=x$config$scenarios,assumptions=x$config$assumptions,geography_note=x$config$geography_note),
    projects=x$projects,capacity=x$capacity,sources=x$sources,
    scenarios=result$scenarios,project_scenarios=result$project_scenarios,ledger=result$ledger,
    coverage=list(projects=nrow(x$projects),claims=nrow(x$capacity),sources=nrow(x$sources),
      scenario_rows=nrow(result$project_scenarios),every_project_represented=TRUE),bidding_zones=map)
}
atomic_output <- function(result,path) {
  dir.create(dirname(path),recursive=TRUE,showWarnings=FALSE)
  tmp<-tempfile('.datacenters-',dirname(path));on.exit(unlink(tmp),add=TRUE)
  json_write(result,tmp)
  json_read(tmp)
  if(!file.rename(tmp,path))stop('Could not replace output')
  invisible(path)
}
