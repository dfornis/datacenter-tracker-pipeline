# Project, capacity, source and actor tables; one capacity calculation path.
`%||%` <- function(x,y) if (is.null(x) || !length(x)) y else x
# Console output (check/packet summaries) in UTF-8 even when the agent shell has no locale set.
if (!isTRUE(l10n_info()$`UTF-8`)) for (loc in c('C.UTF-8','en_US.UTF-8','UTF-8'))
  if (nzchar(suppressWarnings(Sys.setlocale('LC_CTYPE',loc)))) break
number <- function(x) suppressWarnings(as.numeric(x))
ids <- function(x) unique(Filter(nzchar,trimws(unlist(strsplit(x %||% '', ';', fixed=TRUE)))))
json_read <- function(path) jsonlite::fromJSON(path,simplifyVector=FALSE)
json_write <- function(value,path) jsonlite::write_json(value,path,pretty=TRUE,auto_unbox=TRUE,na='null',null='null',digits=NA)
file_hash <- function(path) digest::digest(file=path,algo='sha256',serialize=FALSE)
read_inputs <- function(root='.',data_dir=file.path(root,'data')) {
  cfg <- json_read(file.path(root,'config/pipeline.json'))
  tables <- lapply(names(cfg$tables),function(name) {
    path <- file.path(data_dir,paste0(name,'.csv'))
    # encoding= (not fileEncoding=) reads UTF-8 correctly under any locale, including C/POSIX.
    d <- read.csv(path,colClasses='character',na.strings=NULL,check.names=FALSE,
                  stringsAsFactors=FALSE,encoding='UTF-8',comment.char='')
    if (!identical(names(d),unlist(cfg$tables[[name]],use.names=FALSE)) || anyNA(d)) stop('Invalid columns/CSV: ',path)
    d
  })
  names(tables) <- names(cfg$tables)
  # Advance with capacity evidence, never the clock or an actor-only review. The baseline year stays fixed.
  refs<-unique(unlist(lapply(tables$capacity$source_ids,ids)))
  dates<-c(cfg$timeline$assessment_date,tables$capacity$status_as_of,tables$sources$accessed[tables$sources$source_id %in% refs])
  cfg$timeline$assessment_date<-max(dates[valid_date(dates)])
  c(list(config=cfg),tables)
}
empty_actors <- function(cfg) {
  as.data.frame(setNames(rep(list(character()),length(cfg$tables$actors)),unlist(cfg$tables$actors)),stringsAsFactors=FALSE)
}
csv_field <- function(v) {
  v <- enc2utf8(as.character(v))
  q <- grepl('[",\r\n]',v)
  ifelse(q,paste0('"',gsub('"','""',v,fixed=TRUE),'"'),v)
}
write_csv_table <- function(d,path) {
  # Minimal quoting, LF, UTF-8: the same layout as the committed register, so diffs show real changes only.
  lines <- c(paste(csv_field(names(d)),collapse=','),
             if(nrow(d))do.call(paste,c(lapply(d,csv_field),sep=',')))
  writeBin(charToRaw(enc2utf8(paste0(paste(lines,collapse='\n'),'\n'))),path)
}
input_hashes <- function(root='.',data_dir=file.path(root,'data')) {
  cfg<-json_read(file.path(root,'config/pipeline.json'))
  maps<-unique(vapply(cfg$zones,function(z)z$geometry,character(1)))
  paths <- c(file.path(data_dir,paste0(names(cfg$tables),'.csv')),
             file.path(root,c('config/pipeline.json','scripts/model.R','scripts/tracker.R','scripts/pipeline.R','renv.lock',
                              'prompts/update.md','prompts/actors.md','AGENTS.md','README.md',maps)))
  setNames(lapply(paths,file_hash),c(names(cfg$tables),'method','model','tracker','command','environment',
                                   'prompt','actor_prompt','instructions','readme',maps))
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
  for (key in c('mw','mw_max','pue','construction_year','first_year','last_year','full_capacity_year','full_capacity_last_year')) {
    v<-c[[key]];parsed<-number(v)
    require_true(!nzchar(v) | (is.finite(parsed) & parsed>=0),paste('Invalid number:',key))
    if (grepl('year',key)) require_true(!nzchar(v) | (parsed==floor(parsed) & parsed>=1900 & parsed<=2200),'Invalid year')
  }
  require_true(!nzchar(c$pue) | (number(c$pue)>=1 & number(c$pue)<=3),'Invalid PUE')
  require_true(!nzchar(c$mw_max) | (nzchar(c$mw) & number(c$mw_max)>=number(c$mw)),'Reversed capacity interval')
  require_true(c$qualifier!='range' | nzchar(c$mw_max),'Range needs upper value')
  require_true(!nzchar(c$first_year) | !nzchar(c$last_year) | number(c$first_year)<=number(c$last_year),'Reversed timing interval')
  for(key in c('construction_event','timing_event')) require_true(c[[key]] %in% unlist(cfg$values$event_kind),'Unknown event kind')
  require_true(c$delivery_profile %in% unlist(cfg$values$delivery_profile),'Unknown delivery profile')
  require_true(c$grid_status %in% unlist(cfg$values$grid_status),'Unknown grid status')
  require_true(!nzchar(c$full_capacity_last_year) | (nzchar(c$full_capacity_year) & number(c$full_capacity_last_year)>=number(c$full_capacity_year)),'Reversed full-capacity interval')
  require_true(!nzchar(c$full_capacity_year) | c$timing=='first_capacity','Additional full-capacity year needs a first-capacity anchor')
  require_true(!nzchar(c$status_as_of) | valid_date(c$status_as_of),'Invalid status date')
  require_true(!nzchar(c$status_as_of) | c$status_as_of<=cfg$timeline$assessment_date,'Status date is after assessment date')
  require_true(c$construction_event!='actual' | (nzchar(c$construction_year) & number(c$construction_year)<=assessment_year(cfg)),'Actual construction needs a non-future year')
  require_true(c$timing_event!='actual' | (c$timing!='unknown' & nzchar(c$first_year) & number(c$first_year)<=assessment_year(cfg) & (!nzchar(c$last_year) | number(c$last_year)<=assessment_year(cfg))),'Actual timing needs a non-future interval')
  for (d in list(p,c)) for (ref in d$source_ids) require_true(ids(ref) %in% s$source_id,'Missing source reference')
  a<-x$actors %||% empty_actors(cfg)
  require_true(!anyDuplicated(paste(a$project_id,tolower(trimws(a$actor_name)),sep=':')),'Duplicate project/actor key')
  require_true(a$project_id %in% p$project_id,'Orphaned actor: use project_id, never claim_id')
  require_true(nzchar(trimws(a$actor_name)),'Actor name is required')
  require_true(a$identity_status %in% unlist(cfg$actor_classification$identity_status),'Unknown actor identity status')
  require_true(!nzchar(a$hq_country) | grepl('^[A-Z]{2}$',a$hq_country),'Invalid HQ country code')
  require_true(!nzchar(a$hq_city) | nzchar(a$hq_country),'HQ city needs a known country')
  require_true(a$identity_status!='unresolved' | (!nzchar(a$hq_country) & !nzchar(a$hq_city)),'Unresolved actor cannot have an assigned HQ')
  require_true(nzchar(a$hq_country) | nzchar(a$notes),'Unknown HQ needs an explanation')
  for(field in c('role','actor_type')) {
    allowed<-names(cfg$actor_classification[[if(field=='role')'roles' else 'types']])
    require_true(vapply(a[[field]],function(v)length(ids(v))>0 && all(ids(v) %in% allowed),TRUE),paste('Unknown actor',field))
  }
  require_true(nzchar(a$source_ids),'Actor classification needs sources')
  for(ref in a$source_ids)require_true(ids(ref) %in% s$source_id,'Missing actor source reference')
  dates<-suppressWarnings(as.Date(a$checked_at,format='%Y-%m-%d'))
  require_true(grepl('^[0-9]{4}-[0-9]{2}-[0-9]{2}$',a$checked_at) & !is.na(dates) & format(dates,'%Y-%m-%d')==a$checked_at,'Invalid actor check date')
  for (i in seq_len(nrow(c))) {
    if(nzchar(c$grid_claim_id[i])) {
      k<-match(c$grid_claim_id[i],c$claim_id)
      require_true(!is.na(k) && c$grid_claim_id[i]!=c$claim_id[i],'Missing/self grid constraint')
      require_true(c$basis[k]=='grid' && c$timing[k]=='grid_availability' && c$project_id[k]==c$project_id[i],'Grid constraint must be a scoped grid observation on the same project')
      require_true(!nzchar(c$grid_claim_id[k]),'Grid constraints cannot form chains')
      require_true(!c$status[k] %in% c('Cancelled','Dormant') && c$issue[k]!='identity_conflict','Invalid grid constraint evidence')
    }
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
  for(i in which(nzchar(c$grid_claim_id))) {
    k<-match(c$grid_claim_id[i],c$claim_id)
    require_true(top_claim(c,i)==top_claim(c,k),'Grid constraint and load must share one physical envelope')
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
  for (k in names(cfg$type_assumptions$categories)) {
    a<-cfg$type_assumptions$categories[[k]];pl<-unlist(a$peak_load_factor)
    require_true(is.finite(a$load_factor) && a$load_factor>0 && a$load_factor<=1 &&
      length(pl)==2 && all(pl>0 & pl<=1) && pl[1]<=pl[2],paste('Invalid type assumption:',k))
  }
  require_true(!nzchar(p$type) | !is.na(vapply(p$type,type_category,'')),'Unknown project type tags')
  require_true(is.finite(cfg$assumptions$first_to_full_years) && cfg$assumptions$first_to_full_years>0,'Invalid ramp duration')
  lag<-unlist(cfg$assumptions$construction_to_first_years)
  require_true(length(lag)==2 && all(is.finite(lag)) && lag[1]>0 && lag[2]>=lag[1],'Invalid construction lag')
  require_true(valid_date(cfg$timeline$assessment_date),'Invalid assessment date')
  require_true(cfg$timeline$base_year==floor(cfg$timeline$base_year) && cfg$timeline$base_year<assessment_year(cfg) && cfg$timeline$end_year>=assessment_year(cfg),'Invalid timeline years')
  require_true(setequal(vapply(cfg$timeline$families,`[[`,'','id'),c('low','stated','high')),'Invalid timeline families')
  for(stage in lifecycle) for(key in c('to_construction','remaining_construction')) {
    v<-unlist(cfg$assumptions$stage_lead_times[[stage]][[key]])
    require_true(length(v)==2 && all(is.finite(v)) && all(v>=0) && all(v==floor(v)) && v[1]<=v[2],'Invalid stage lead time')
  }
  invisible(TRUE)
}
valid_date <- function(x) {
  d<-suppressWarnings(as.Date(x,format='%Y-%m-%d'))
  grepl('^[0-9]{4}-[0-9]{2}-[0-9]{2}$',x) & !is.na(d) & format(d,'%Y-%m-%d')==x
}
assessment_year <- function(cfg) as.integer(substr(cfg$timeline$assessment_date,1,4))
field <- function(row,key) as.character(row[[key]] %||% '')
year_interval <- function(first,last='') {
  v<-number(c(first,last));if(!is.finite(v[2]))v[2]<-v[1];if(!is.finite(v[1]))v[1]<-v[2];v
}
source_dated <- function(row) {
  (row$timing!='unknown' && any(is.finite(number(c(row$first_year,row$last_year))))) ||
    is.finite(number(row$construction_year)) || is.finite(number(field(row,'full_capacity_year')))
}
observed_delivery <- function(row) field(row,'timing_event')=='actual' && row$timing %in% c('first_capacity','full_capacity')
post_baseline_operation <- function(row,cfg) {
  # Status is not the historical cohort boundary. A verified delivery after the fixed baseline remains.
  if(!observed_delivery(row) || row$baseline_scope!='new_capacity')return(FALSE)
  t<-timing_schedule(row,cfg)
  any(t$full>cfg$timeline$base_year)
}
timing_schedule <- function(row,cfg,claims=NULL) {
  now<-assessment_year(cfg);years<-if(field(row,'delivery_profile')=='single_phase')1 else cfg$assumptions$first_to_full_years
  lag<-unlist(cfg$assumptions$construction_to_first_years)
  stage<-cfg$assumptions$stage_lead_times[[row$status]]
  lead<-unlist(stage$to_construction)+unlist(stage$remaining_construction)
  feasible<-now+lead;flags<-character();rule<-'remaining_lead_time_from_stage'
  supplied<-year_interval(row$first_year,row$last_year);built<-number(row$construction_year)
  actual<-observed_delivery(row)
  fully_observed<-actual && (row$timing=='full_capacity' || field(row,'delivery_profile')=='single_phase')
  if(is.finite(built)) {
    feasible<-built+lag;rule<-'construction_plus_build_time'
    if(field(row,'construction_event')!='actual' && built<now) {
      flags<-c(flags,'past_construction_target');feasible<-now+lead
    } else if(!actual && feasible[2]<now && row$status!='Operational') {
      flags<-c(flags,'construction_overdue');feasible<-now+unlist(stage$remaining_construction)
    }
    if(!actual)feasible<-pmax(feasible,now)
  }
  first<-feasible;full<-first+years-1;has_full_target<-FALSE
  if(row$timing=='first_capacity' && all(is.finite(supplied))) {
    first<-supplied;rule<-if(actual)'observed_first_capacity' else 'source_first_capacity'
    if(!actual && supplied[1]<now) {
      flags<-c(flags,'past_operation_target');first<-pmax(supplied,feasible)
    }
    # A source commissioning schedule supersedes a generic build duration, but not a later construction start.
    if(is.finite(built) && supplied[1]<built) {
      flags<-c(flags,'operation_before_construction');if(!actual)first<-pmax(first,feasible)
    }
    full<-first+years-1
    explicit_full<-year_interval(field(row,'full_capacity_year'),field(row,'full_capacity_last_year'))
    if(all(is.finite(explicit_full))) {
      has_full_target<-TRUE
      if(any(explicit_full<first))flags<-c(flags,'full_before_first')
      full<-pmax(explicit_full,first);rule<-paste0(rule,'_and_scoped_full_schedule')
    }
  } else if(row$timing=='full_capacity' && all(is.finite(supplied))) {
    if(actual) {first<-full<-supplied;rule<-'observed_full_capacity_step'} else {
      has_full_target<-TRUE
      if(supplied[2]<now) {
        # An elapsed plan is not evidence of commissioning. Re-estimate from the current stage.
        flags<-c(flags,'past_full_target');rule<-'elapsed_full_target_remaining_delivery'
      } else {
        # The scoped source target overrides generic stage/duration assumptions. Compress the
        # inferred buildout before it; do not invent a delay just because the proxy is longer.
        full<-pmax(supplied,now)
        first<-pmin(pmax(full-years+1,feasible,now),full)
        rule<-'source_full_target_inferred_first'
        if(is.finite(built) && any(built>full)) {
          flags<-c(flags,'full_before_construction');first<-pmax(first,built);full<-pmax(full,built)
        }
      }
    }
  }
  grid<-NULL
  if(row$basis=='grid' || row$timing=='grid_availability')grid<-row
  if(nzchar(field(row,'grid_claim_id')) && !is.null(claims))grid<-claims[match(row$grid_claim_id,claims$claim_id),,drop=FALSE]
  zero_lower<-FALSE
  if(!is.null(grid)) {
    if(fully_observed && nzchar(field(row,'grid_claim_id'))) {
      observed_mw<-electrical_range(row,cfg);grid_mw<-electrical_range(grid,cfg)
      if(is.finite(observed_mw[1]) && is.finite(grid_mw[2]) && observed_mw[1]>grid_mw[2])
        flags<-c(flags,'observed_capacity_grid_conflict')
    }
    g<-year_interval(grid$first_year,grid$last_year)
    if(all(is.finite(g))) {
      if(any(g>first)) {
        flags<-c(flags,if(actual)'observed_delivery_grid_conflict' else 'grid_delays_delivery')
        if(!actual) {
          shift<-pmax(0,g-first);first<-first+shift
          # A later grid opening can shorten the inferred ramp without invalidating a full target.
          if(has_full_target) {
            if(any(g>full))flags<-c(flags,'full_before_grid')
            full<-pmax(full,first)
          } else full<-full+shift
        }
      }
      if(g[1]<now && field(grid,'grid_status')!='available')flags<-c(flags,'past_grid_target')
    } else flags<-c(flags,'grid_date_unknown')
    zero_lower<-!field(grid,'grid_status') %in% c('reserved','contracted','available') && !fully_observed
  }
  list(first=first,full=full,dated=source_dated(row),rule=rule,flags=unique(flags),zero_lower=zero_lower,
       actual=actual,fully_observed=fully_observed,grid=grid,reference_date=cfg$timeline$assessment_date)
}
schedule_share <- function(schedule,year) {
  ramp<-function(i)max(0,min(1,(year-schedule$first[i]+1)/(schedule$full[i]-schedule$first[i]+1)))
  c(if(schedule$zero_lower)0 else ramp(2),ramp(1))
}
timing_share <- function(row,year,cfg,claims=NULL) {
  t<-timing_schedule(row,cfg,claims);t$share<-schedule_share(t,year);t
}
scenario_selected <- function(row,scenario,timing) {
  switch(scenario$selection,all=TRUE,dated=timing$dated,decided_dated=timing$dated && row$decision=='yes')
}
type_category <- function(type) {
  # Shared mapping from project type tags to an annual-use assumption category.
  tags <- tolower(trimws(unlist(strsplit(type %||% '', ';', fixed=TRUE))))
  if (!length(tags) || all(!nzchar(tags))) return(NA_character_)
  if (any(c('research','smr-linked') %in% tags)) return('Research_SMR')
  if ('colocation' %in% tags && 'ai' %in% tags) return('Colocation_AI')
  if ('colocation' %in% tags) return('Colocation')
  if ('ai' %in% tags && 'hpc' %in% tags) return('AI_HPC')
  if ('hyperscale' %in% tags && 'ai' %in% tags) return('Hyperscale_AI')
  if ('hyperscale' %in% tags) return('Hyperscale')
  if (any(c('ai','hpc') %in% tags)) return('AI_HPC')
  'Hyperscale'
}
annual_fraction <- function(row,type,cfg) {
  # Type-specific annual load factor (EPRI 2026 p.15); generic range only when type is unknown.
  peak <- grepl('_peak$',row$basis)
  category <- type_category(type)
  if (is.na(category)) {
    v <- unlist(cfg$assumptions[[if(peak)'peak_annual_fraction' else 'nameplate_annual_fraction']])
    return(list(value=v,rule='load_factor_range_type_unknown'))
  }
  a <- cfg$type_assumptions$categories[[category]]
  v <- if(peak) unlist(a$peak_load_factor) else rep(a$load_factor,2)
  list(value=v,rule=paste0('load_factor_',category))
}
capacity_without_upper_limit <- function(row) row$qualifier=='at_least' && !nzchar(row$mw_max)
electrical_range <- function(row,cfg,net=FALSE,claims=NULL,normalize_peak=TRUE) {
  # "At least X" preserves a useful source fact, but without a finite project scope it is not a
  # project capacity measure. Keep it in the ledger and source detail; do not turn the
  # lower bound into a full-build or scenario value.
  if (row$basis %in% c('backup','generation','density') || row$issue=='identity_conflict' || !nzchar(row$mw) || capacity_without_upper_limit(row)) return(c(NA_real_,NA_real_))
  v<-number(row$mw);top<-if(row$qualifier=='range')number(row$mw_max) else if(row$qualifier=='at_least')NA_real_ else v
  if (net && row$baseline_scope=='existing_known') {
    b<-claims[match(row$baseline_id,claims$claim_id),]
    bottom_b<-number(b$mw);top_b<-if(b$qualifier=='range')number(b$mw_max) else if(b$qualifier=='at_least')Inf else bottom_b
    v<-max(0,v-top_b);top<-max(0,top-bottom_b)
  }
  pue<-unlist(cfg$assumptions$pue)
  if (nzchar(row$pue)) pue<-c(min(pue[1],number(row$pue)),number(row$pue))
  if (startsWith(row$basis,'it_')) {v<-v*pue[1];top<-top*pue[2]}
  # Preserve an unspecified source MW as stated. PUE conversion requires an explicit IT basis.
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
calculate <- function(x,approved_only=TRUE) {
  validate_inputs(x);p<-x$projects;c<-x$capacity;cfg<-x$config
  all_rows<-list();overview<-list();zone_rows<-list()
  schedules<-lapply(seq_len(nrow(c)),function(i)timing_schedule(c[i,],cfg,c))
  for (scenario in cfg$scenarios) {
    rows<-lapply(seq_len(nrow(c)),function(i) {
      r<-c[i,];pr<-p[match(r$project_id,p$project_id),]
      group<-c$claim_id[top_claim(c,i)]
      gross<-electrical_range(r,cfg);net<-electrical_range(r,cfg,TRUE,c)
      timing<-schedules[[i]];timing$share<-schedule_share(timing,scenario$year)
      baseline_share<-if(r$baseline_scope=='new_capacity')schedule_share(timing,cfg$timeline$base_year) else c(0,0)
      path_shares<-pmax(0,timing$share-baseline_share);timing$share<-sort(path_shares)
      selected<-scenario_selected(r,scenario,timing)
      share<-if(selected)timing$share else c(0,0)
      reason<-'modelled';assumptions<-timing$rule
      if (r$status %in% c('Cancelled','Dormant') || (r$status=='Operational' && !post_baseline_operation(r,cfg))) reason<-tolower(r$status)
      if (pr$status %in% c('Cancelled','Dormant')) reason<-tolower(pr$status)
      if (r$issue=='identity_conflict') reason<-'identity_conflict'
      if (nzchar(pr$related_project_id)) reason<-'related_identity'
      if (r$basis %in% c('backup','generation','density')) reason<-'no_datacenter_load'
      if (capacity_without_upper_limit(r)) reason<-'capacity_without_upper_limit'
      if (!nzchar(r$mw)) reason<-'capacity_unknown'
      if (approved_only && pr$record_type!='existing') reason<-'pending_approval'
      in_envelope<-reason=='modelled'
      nameplate<-if(in_envelope)net*sort(1-baseline_share) else c(0,0)
      if (reason!='modelled') share<-c(0,0)
      if (reason=='modelled' && !selected) reason<-'outside_scenario_selection'
      if (reason=='modelled' && share[2]==0) reason<-'after_target_year'
      if (r$basis %in% c('unspecified','it_unspecified','facility_unspecified')) assumptions<-c(assumptions,'capacity_definition_assumed')
      if (r$basis=='unspecified') assumptions<-c(assumptions,'unspecified_source_MW_preserved')
      if (r$basis=='grid') assumptions<-c(assumptions,'connection_deployment_assumed')
      if (startsWith(r$basis,'it_')) assumptions<-c(assumptions,'PUE_conversion')
      if (grepl('_peak$',r$basis)) assumptions<-c(assumptions,'peak_to_nameplate_equivalent')
      if (r$baseline_scope=='existing_unknown') assumptions<-c(assumptions,'increment_unknown_0_to_site_envelope')
      if (r$relation=='possibly_included_in') assumptions<-c(assumptions,'overlap_assumed_contained')
      if (nzchar(pr$related_project_id)) assumptions<-c(assumptions,'related_identity_unresolved')
      value<-ifelse(share>0,net*share,0)
      path_values<-sapply(if(selected && in_envelope)path_shares else c(0,0),function(v)if(v>0)net*v else c(0,0))
      af<-annual_fraction(r,pr$type,cfg);lf<-af$value;assumptions<-c(assumptions,af$rule)
      energy_power<-ifelse(share>0,electrical_range(r,cfg,TRUE,c,normalize_peak=FALSE)*share,0)
      energy<-energy_power*lf*8760/1e6
      # Grid MW is already on the facility side. Apply the scoped ceiling once, after PUE conversion.
      if(!is.null(timing$grid) && nzchar(field(r,'grid_claim_id')) && !timing$fully_observed) {
        cap<-electrical_range(timing$grid,cfg)
        for(j in 1:2)if(is.finite(cap[j]) && is.finite(value[j]) && value[j]>cap[j]) {
          energy[j]<-energy[j]*cap[j]/value[j];value[j]<-cap[j]
        }
        for(j in 1:2)if(is.finite(cap[j]))path_values[j,]<-pmin(path_values[j,],cap[j])
        assumptions<-c(assumptions,'scoped_grid_capacity_ceiling')
      }
      # Annual electricity if the whole envelope row were built: same conversion, no timing.
      buildout<-if(in_envelope)electrical_range(r,cfg,TRUE,c,normalize_peak=FALSE)*sort(1-baseline_share)*lf*8760/1e6 else c(0,0)
      data.frame(scenario=scenario$id,project_id=r$project_id,claim_id=r$claim_id,group_id=group,
        share_low=share[1],share_high=share[2],reason=reason,assumptions=paste(assumptions,collapse=';'),
        source_dated=timing$dated,selected=selected,first_early=timing$first[1],first_late=timing$first[2],
        full_early=timing$full[1],full_late=timing$full[2],timing_flags=paste(timing$flags,collapse=';'),
        source_basis=r$basis,reported_mw=number(r$mw),gross_mw_low=gross[1],gross_mw_high=gross[2],
        nameplate_mw_low=nameplate[1],nameplate_mw_high=nameplate[2],
        buildout_twh_low=buildout[1],buildout_twh_high=buildout[2],
        direct_mw_low=value[1],direct_mw_high=value[2],direct_twh_low=energy[1],direct_twh_high=energy[2],
        direct_late_mw_low=path_values[1,1],direct_late_mw_high=path_values[2,1],direct_early_mw_low=path_values[1,2],direct_early_mw_high=path_values[2,2],
        counted_late_mw_low=0,counted_late_mw_high=0,counted_early_mw_low=0,counted_early_mw_high=0,
        counted_mw_low=0,counted_mw_high=0,annual_twh_low=0,annual_twh_high=0,stringsAsFactors=FALSE)
    })
    ledger<-if(length(rows))do.call(rbind,rows) else as.data.frame(c(
      setNames(rep(list(character()),8),c('scenario','project_id','claim_id','group_id','reason','assumptions','source_basis','timing_flags')),
      setNames(rep(list(logical()),2),c('source_dated','selected')),
      setNames(rep(list(numeric()),8),c('direct_late_mw_low','direct_late_mw_high','direct_early_mw_low','direct_early_mw_high','counted_late_mw_low','counted_late_mw_high','counted_early_mw_low','counted_early_mw_high')),
      setNames(rep(list(numeric()),21),c('first_early','first_late','full_early','full_late','share_low','share_high','reported_mw','gross_mw_low','gross_mw_high','nameplate_mw_low','nameplate_mw_high','buildout_twh_low','buildout_twh_high','direct_mw_low','direct_mw_high','direct_twh_low','direct_twh_high','counted_mw_low','counted_mw_high','annual_twh_low','annual_twh_high'))),stringsAsFactors=FALSE)
    # One electrical envelope per containment tree. A tenant never removes its campus.
    # Explicit independent/incremental rows remain separate; contained alternatives use max.
    owner_claim<-ledger$group_id
    if (nrow(ledger)) for (group in unique(ledger$group_id)) {
      members<-which(ledger$group_id==group);owner<-match(group,ledger$claim_id)
      # A pending campus cannot own the approved contribution of its tenant/phase.
      # Keep the original containment tree, and assign its envelope to the closest
      # approved member. Unapproved claims remain available as source facts only.
      if(approved_only && p$record_type[match(ledger$project_id[owner],p$project_id)]!='existing') {
        allowed<-members[p$record_type[match(ledger$project_id[members],p$project_id)]=='existing']
        if(!length(allowed))next
        depth<-vapply(allowed,function(j) {
          k<-match(ledger$claim_id[j],c$claim_id);n<-0L
          while(c$relation[k] %in% c('included_in','possibly_included_in')) {k<-match(c$parent_id[k],c$claim_id);n<-n+1L}
          n
        },0L)
        owner<-allowed[order(depth,ledger$claim_id[allowed])][1]
      }
      owner_claim[members]<-ledger$claim_id[owner]
      if(approved_only)members<-members[p$record_type[match(ledger$project_id[members],p$project_id)]=='existing']
      for(key in c('nameplate_mw_low','nameplate_mw_high','buildout_twh_low','buildout_twh_high')) {
        v<-ledger[[key]][members]
        ledger[[key]][members]<-0
        ledger[[key]][owner]<-if(anyNA(v) && grepl('high$',key))NA_real_ else maximum_known(v)
      }
      a<-unique(unlist(lapply(ledger$assumptions[members],ids)))
      if(!any(is.finite(c(ledger$gross_mw_low[owner],ledger$gross_mw_high[owner])))) a<-c(a,'only_contained_capacity_known')
      ledger$assumptions[owner]<-paste(a,collapse=';')
      active<-members[ledger$share_high[members]>0]
      if (!length(active)) next
      pairs<-list(c('direct_mw_low','counted_mw_low'),c('direct_mw_high','counted_mw_high'),c('direct_twh_low','annual_twh_low'),c('direct_twh_high','annual_twh_high'))
      for(path in c('early','late'))for(bound in c('low','high'))pairs<-c(pairs,list(c(paste0('direct_',path,'_mw_',bound),paste0('counted_',path,'_mw_',bound))))
      for (pair in pairs) {
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
      scope<-ledger[ledger$project_id==pr$project_id | owner_claim %in% lr$claim_id,,drop=FALSE]
      if(approved_only && pr$record_type=='existing')
        scope<-scope[p$record_type[match(scope$project_id,p$project_id)]=='existing',,drop=FALSE]
      # Capacity is known only when a usable new-load claim survives the model rules.
      # An operating baseline or an "at least" source without an upper value must not turn an
      # otherwise unquantified expansion into a displayed zero.
      # Candidate status controls whether a claim is included in approved totals. A quantified
      # candidate claim still tells us that the project's capacity is known.
      excluded_capacity_reasons<-c('operational','cancelled','dormant','identity_conflict','related_identity',
        'no_datacenter_load','capacity_unknown','capacity_without_upper_limit')
      usable<-!scope$reason %in% excluded_capacity_reasons
      has_load<-any(usable & (is.finite(scope$gross_mw_high)|is.finite(scope$gross_mw_low)))
      sr<-c[match(scope$claim_id,c$claim_id),,drop=FALSE]
      active_unknown<-!sr$status %in% c('Cancelled','Dormant','Operational') |
        vapply(seq_len(nrow(sr)),function(j)post_baseline_operation(sr[j,],cfg),TRUE)
      partial_capacity<-!pr$status %in% c('Cancelled','Dormant') &&
        any(active_unknown & scope$reason=='capacity_unknown' & scope$selected & scenario$year>=scope$first_early)
      category<-if(pr$record_type=='out_of_scope')'out_of_scope' else if(pr$status %in% c('Cancelled','Dormant'))tolower(pr$status) else if(pr$status=='Operational')'operational' else if(pr$record_type=='candidate')'candidate' else if(!has_load)'unquantified' else 'pipeline'
      missing_load<-!has_load && !pr$status %in% c('Cancelled','Dormant','Operational')
      project_sum<-function(key) if(missing_load || anyNA(lr[[key]]))NA_real_ else sum(lr[[key]])
      overview[[length(overview)+1]]<-data.frame(scenario=scenario$id,project_id=pr$project_id,country=pr$country,
        bidding_zone=if(nzchar(pr$bidding_zone))pr$bidding_zone else paste0(pr$country,'-unassigned'),
        record_type=pr$record_type,included_in_result=!approved_only || pr$record_type=='existing',
        indicator=category,capacity_known=has_load,partial_capacity=partial_capacity,participates=live,related_project_id=pr$related_project_id,
        nameplate_mw_low=project_sum('nameplate_mw_low'),nameplate_mw_high=project_sum('nameplate_mw_high'),
        buildout_twh_low=project_sum('buildout_twh_low'),buildout_twh_high=project_sum('buildout_twh_high'),
        mw_low=project_sum('counted_mw_low'),mw_high=project_sum('counted_mw_high'),
        early_mw_low=project_sum('counted_early_mw_low'),early_mw_high=project_sum('counted_early_mw_high'),
        late_mw_low=project_sum('counted_late_mw_low'),late_mw_high=project_sum('counted_late_mw_high'),
        annual_twh_low=project_sum('annual_twh_low'),annual_twh_high=project_sum('annual_twh_high'),
        note=if(nzchar(pr$related_project_id))'Related identity retained; not a separate quantified addition.' else if(!nrow(lr))'No capacity claim; project remains visible.' else paste(unique(lr$reason),collapse=';'),stringsAsFactors=FALSE)
    }
  }
  project_scenarios<-do.call(rbind,overview);ledger<-do.call(rbind,all_rows)
  zone_ids<-c(vapply(cfg$zones,function(z)z$id,character(1)),paste0(names(cfg$countries),'-unassigned'))
  for (scenario in cfg$scenarios) for (zone in zone_ids) {
    all_d<-project_scenarios[project_scenarios$scenario==scenario$id & project_scenarios$bidding_zone==zone,,drop=FALSE]
    d<-all_d[all_d$included_in_result,,drop=FALSE]
    sum_known<-function(key) if(!nrow(d))0 else if(all(is.na(d[[key]]))||any(is.na(d[[key]]) & d$capacity_known))NA_real_ else sum(d[[key]],na.rm=TRUE)
    active<-!d$indicator %in% c('cancelled','dormant','operational')
    partial<-any(ledger$scenario==scenario$id & ledger$project_id %in% d$project_id & grepl('only_contained_capacity_known',ledger$assumptions,fixed=TRUE))
    zone_rows[[length(zone_rows)+1]]<-data.frame(scenario=scenario$id,bidding_zone=zone,projects=nrow(d),
      pending_projects=sum(all_d$record_type=='candidate'),participating_projects=sum(d$participates),candidate_projects=sum(p$record_type[match(d$project_id,p$project_id)]=='candidate'),
      operating_projects=sum(d$indicator=='operational'),cancelled_or_dormant=sum(d$indicator %in% c('cancelled','dormant')),
      projects_without_mw=sum(active & !d$capacity_known),projects_with_unknown_phases=sum(d$partial_capacity & d$capacity_known),
      nameplate_mw_low=sum_known('nameplate_mw_low'),nameplate_mw_high=sum_known('nameplate_mw_high'),
      buildout_twh_low=sum_known('buildout_twh_low'),buildout_twh_high=sum_known('buildout_twh_high'),
      mw_low=sum_known('mw_low'),mw_high=sum_known('mw_high'),
      annual_twh_low=sum_known('annual_twh_low'),annual_twh_high=sum_known('annual_twh_high'),
      scope=if(!nrow(d))'no_inventory' else if(partial||any(d$partial_capacity)||sum(active & !d$capacity_known)||anyNA(d$mw_high))'quantified_subset' else 'modelled_inventory',stringsAsFactors=FALSE)
  }
  # Coverage is a product requirement, not a claim that unknown MW has become zero.
  expected<-nrow(p)*length(cfg$scenarios)
  if(nrow(project_scenarios)!=expected || anyDuplicated(paste(project_scenarios$scenario,project_scenarios$project_id))) stop('A project disappeared or was duplicated')
  list(scenarios=do.call(rbind,zone_rows),project_scenarios=project_scenarios,ledger=ledger)
}
calculate_timeline <- function(x,input_hashes=NULL) {
  cfg<-x$config;years<-seq(cfg$timeline$base_year,cfg$timeline$end_year)
  families<-cfg$timeline$families
  x$config$scenarios<-unlist(lapply(families,function(f)lapply(years,function(y)
    list(id=paste0(f$id,'_',y),label=f$label,year=y,selection=f$selection))),recursive=FALSE)
  d<-calculate(x)$project_scenarios
  d$year<-as.integer(sub('.*_','',d$scenario));d$family<-sub('_.*','',d$scenario)
  d<-d[order(d$project_id,d$family,d$year),,drop=FALSE]
  for(key in c('annual_addition_mw_low','annual_addition_mw_high','future_addition_mw_low','future_addition_mw_high','remaining_mw_low','remaining_mw_high'))d[[key]]<-NA_real_
  for(id in unique(d$project_id))for(f in families) {
    k<-which(d$project_id==id & d$family==f$id);a<-d[k,]
    # Differences are calculated on the two complete paths, then ordered as an annual range.
    # The resulting annual interval bounds need not sum to a cumulative interval bound.
    paths<-c('early_mw_low','early_mw_high','late_mw_low','late_mw_high')
    changes<-lapply(paths,function(key)c(0,pmax(0,diff(a[[key]]))))
    d$annual_addition_mw_low[k]<-do.call(pmin,changes);d$annual_addition_mw_high[k]<-do.call(pmax,changes)
    at<-match(assessment_year(cfg),a$year)
    changes<-lapply(paths,function(key)pmax(0,a[[key]]-a[[key]][at]))
    d$future_addition_mw_low[k]<-do.call(pmin,changes);d$future_addition_mw_high[k]<-do.call(pmax,changes)
    # Cross-bound subtraction preserves capacity and timing uncertainty in the remainder.
    d$remaining_mw_low[k]<-pmax(0,a$nameplate_mw_low-a$mw_high)
    d$remaining_mw_high[k]<-pmax(0,a$nameplate_mw_high-a$mw_low)
  }
  d<-d[d$year>cfg$timeline$base_year,,drop=FALSE];d$scenario<-NULL;rownames(d)<-NULL
  list(version=3,as_of=cfg$as_of,assessment_date=cfg$timeline$assessment_date,base_year=cfg$timeline$base_year,
    source_hashes=input_hashes[c('projects','capacity','sources','actors','model','method')],
    years=as.list(years[-1]),families=families,
    measures=list(mw='Cumulative commissioned capacity added after the fixed baseline year-end.',
      annual_addition_mw='Capacity added during the calendar year; interval across early/late paths, not the difference between independent interval bounds.',
      future_addition_mw='Additional deployment after the end of the assessment calendar year; not a reconstruction of delivery within that year.',
      remaining_mw='Announced incremental capacity not yet delivered at year-end; includes scopes outside Low/Stated selection.'),rows=d)
}
timing_diagnostics <- function(x) {
  lapply(setNames(list('existing',c('existing','candidate')),c('approved','including_candidates')),function(types) {
    c<-x$capacity[x$capacity$project_id %in% x$projects$project_id[x$projects$record_type %in% types] &
      !x$capacity$status %in% c('Operational','Cancelled','Dormant') & nzchar(x$capacity$mw),,drop=FALSE]
    list(active_rows_with_mw=nrow(c),without_construction_or_timing_year=sum(!nzchar(c$construction_year)&!nzchar(c$first_year)&!nzchar(c$last_year)),
      full_capacity_without_construction=sum(c$timing=='full_capacity' & (nzchar(c$first_year)|nzchar(c$last_year)) & !nzchar(c$construction_year)))
  })
}
timing_followups <- function(x,countries=names(x$config$countries)) {
  p<-x$projects;c<-x$capacity;s<-x$sources;cfg<-x$config;out<-list()
  questions<-c(missing_first_operation='Find actual/planned construction and first-operation dates for this MW scope; distinguish the first building from the campus.',
    missing_event_kind='Establish whether each reported year is a target or an observed event; retain its exact scope and source.',
    missing_status_date='Verify the current implementation stage and its observation date; a source access date alone does not date the stage.',
    earlier_status_year='Refresh the implementation stage: its recorded observation predates the assessment calendar year.',
    unclear_implementation='Find current planning, permit, FID, contractor or commissioning evidence for this scope.',
    unknown_delivery_profile='Find MW and opening dates of named phases, and whether this figure is one commissioned phase or a staged campus.',
    phase_without_mw='Find the executed phase MW and measure in permits/EIA/YVA, connection agreements or the operator announcement.',
    grid_scope_missing='Find the site-specific grid status, available MW, connection dates and reinforcements; link the matching grid claim explicitly.',
    operational_history_unknown='Find actual delivery dates and the already-operating baseline; retain any post-baseline addition when status changes.',
    passed_target='Verify whether the dated milestone happened, was revised or remains unconfirmed; find a current operator, permit or grid update.',
    schedule_conflict='Reconcile contradictory scoped dates with actual construction and grid restrictions; generic lead times alone do not invalidate a source target.')
  for(i in seq_len(nrow(c))) {
    r<-c[i,];pr<-p[match(r$project_id,p$project_id),]
    if(!pr$country %in% countries || pr$record_type=='out_of_scope' || pr$status %in% c('Cancelled','Dormant') ||
       r$status %in% c('Cancelled','Dormant') || r$basis %in% c('backup','generation','density') || r$issue=='identity_conflict')next
    t<-timing_schedule(r,cfg,c);reasons<-character()
    if(!source_dated(r) || r$timing %in% c('full_capacity','grid_availability'))reasons<-c(reasons,'missing_first_operation')
    if((nzchar(r$construction_year) && !field(r,'construction_event') %in% c('planned','actual')) ||
       (r$timing!='unknown' && nzchar(r$first_year) && !field(r,'timing_event') %in% c('planned','actual')))reasons<-c(reasons,'missing_event_kind')
    if(!nzchar(field(r,'status_as_of')))reasons<-c(reasons,'missing_status_date')
    if(nzchar(field(r,'status_as_of')) && substr(r$status_as_of,1,4)<substr(cfg$timeline$assessment_date,1,4))reasons<-c(reasons,'earlier_status_year')
    if(r$status %in% c('Unclear','Concept study'))reasons<-c(reasons,'unclear_implementation')
    if(!field(r,'delivery_profile') %in% c('single_phase','staged'))reasons<-c(reasons,'unknown_delivery_profile')
    if(!nzchar(r$mw) && (r$status=='Under construction' || r$decision=='yes'))reasons<-c(reasons,'phase_without_mw')
    if((r$basis=='grid' && !field(r,'grid_status') %in% c('requested','reserved','contracted','available')) ||
       (r$basis!='grid' && !nzchar(field(r,'grid_claim_id'))))reasons<-c(reasons,'grid_scope_missing')
    if(r$status=='Operational' && !observed_delivery(r))reasons<-c(reasons,'operational_history_unknown')
    if(any(grepl('^past_|overdue',t$flags)))reasons<-c(reasons,'passed_target')
    if(length(t$flags))reasons<-c(reasons,'schedule_conflict')
    if(!length(reasons))next
    refs<-unique(c(ids(r$source_ids),if(nzchar(r$grid_claim_id))ids(c$source_ids[match(r$grid_claim_id,c$claim_id)])))
    evidence<-s[s$source_id %in% refs,,drop=FALSE]
    factual_notes<-gsub('Timing review [0-9-]+ \\[[a-f0-9]+\\]: [^\\n]+','',r$notes,perl=TRUE)
    key<-substr(digest::digest(list(r[,setdiff(names(r),'notes'),drop=FALSE],trimws(factual_notes),evidence,cfg$timeline,cfg$assumptions),algo='sha256'),1,12)
    pattern<-paste0('Timing review ([0-9]{4}-[0-9]{2}-[0-9]{2}) \\[',key,'\\]: ([^\\n]+)')
    m<-regmatches(r$notes,regexec(pattern,r$notes,perl=TRUE))[[1]]
    documented<-length(m)==3 && valid_date(m[2]) && m[2]>=cfg$timeline$assessment_date && nchar(trimws(m[3]))>=20
    v<-electrical_range(r,cfg,TRUE,c);sh<-schedule_share(t,2030)
    near_years<-seq(assessment_year(cfg),max(2030,assessment_year(cfg)))
    spreads<-vapply(near_years,function(y)diff(schedule_share(t,y)),0)
    largest<-which.max(spreads)
    out[[length(out)+1]]<-list(project_id=r$project_id,claim_id=r$claim_id,country=pr$country,bidding_zone=pr$bidding_zone,
      project_name=pr$project_name,developer=pr$developer,municipality=pr$municipality,phase=r$phase,
      source_mw=r$mw,basis=r$basis,record_type=pr$record_type,reasons=as.list(unique(reasons)),timing_flags=as.list(t$flags),
      first_early=t$first[1],first_late=t$first[2],full_early=t$full[1],full_late=t$full[2],
      timing_spread_mw_2030=if(is.finite(v[2]))v[2]*(sh[2]-sh[1]) else NA_real_,scope_mw_high=v[2],
      timing_spread_mw_near_term=if(is.finite(v[2]))v[2]*spreads[largest] else NA_real_,timing_spread_year=near_years[largest],
      review_key=key,review_status=if(documented)'documented_uncertainty' else 'open',
      questions=as.list(unname(questions[unique(reasons)])),
      search_terms=paste(pr$developer,pr$municipality,r$phase,'construction commissioning phase MW grid connection permit'),
      sources=evidence[,c('source_id','url','published','accessed','excerpt','locator'),drop=FALSE])
  }
  if(length(out))out<-out[order(-vapply(out,function(z)if(is.finite(z$timing_spread_mw_near_term))z$timing_spread_mw_near_term else -1,0),
                              -vapply(out,function(z)if(is.finite(z$scope_mw_high))z$scope_mw_high else -1,0))]
  out
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
classify_actors <- function(projects,actors,cfg) {
  p<-projects
  for(field in c('actor_hq_countries','actor_hq_origin','actor_hq_groups','actor_types'))p[[field]]<-rep('',nrow(p))
  for(i in seq_len(nrow(p))) {
    a<-actors[actors$project_id==p$project_id[i],,drop=FALSE]
    countries<-sort(unique(a$hq_country[nzchar(a$hq_country)]))
    complete<-nrow(a)>0 && all(a$identity_status=='identified' & nzchar(a$hq_country))
    origin<-if(!complete)'unknown' else if(all(countries==p$country[i]))'domestic' else if(all(countries!=p$country[i]))'foreign' else 'mixed'
    groups<-origin
    for(region in names(cfg$actor_classification$regions))if(any(countries %in% unlist(cfg$actor_classification$regions[[region]])))groups<-c(groups,region)
    if(any(!countries %in% unlist(cfg$actor_classification$regions$eu)))groups<-c(groups,'outside_eu')
    if(any(countries %in% unlist(cfg$actor_classification$regions$europe) & countries!=p$country[i]))groups<-c(groups,'other_europe')
    if(any(!countries %in% unlist(cfg$actor_classification$regions$europe)))groups<-c(groups,'outside_europe')
    p$actor_hq_countries[i]<-paste(countries,collapse=';')
    p$actor_hq_origin[i]<-origin
    p$actor_hq_groups[i]<-paste(unique(groups),collapse=';')
    p$actor_types[i]<-if(nrow(a))paste(sort(unique(unlist(lapply(a$actor_type,ids)))),collapse=';') else 'unknown'
  }
  p
}
actor_display <- function(actors,cfg) {
  a<-actors;a$hq_facets<-rep('',nrow(a))
  for(i in seq_len(nrow(a))) {
    country<-a$hq_country[i]
    facets<-if(nzchar(country))paste0('country:',country) else 'unknown'
    if(nzchar(country)) {
      for(region in names(cfg$actor_classification$regions))if(country %in% unlist(cfg$actor_classification$regions[[region]]))facets<-c(facets,paste0('region:',region))
      if(!country %in% unlist(cfg$actor_classification$regions$eu))facets<-c(facets,'region:outside_eu')
      if(!country %in% unlist(cfg$actor_classification$regions$europe))facets<-c(facets,'region:outside_europe')
    }
    a$hq_facets[i]<-paste(facets,collapse=';')
  }
  a
}
actor_worklist <- function(x,countries=names(x$config$countries)) {
  p<-classify_actors(x$projects,x$actors %||% empty_actors(x$config),x$config)
  p<-p[p$country %in% countries & p$record_type!='out_of_scope',,drop=FALSE]
  lapply(seq_len(nrow(p)),function(i)list(project_id=p$project_id[i],project_name=p$project_name[i],developer=p$developer[i],
    hq_origin=p$actor_hq_origin[i],reviewed=p$project_id[i] %in% (x$actors %||% empty_actors(x$config))$project_id))
}
actor_coverage <- function(projects,actors,cfg=NULL) {
  p<-projects[projects$record_type!='out_of_scope',,drop=FALSE]
  if(!'actor_hq_origin' %in% names(p))p<-classify_actors(p,actors,cfg)
  countries<-if(is.null(cfg))sort(unique(p$country)) else names(cfg$countries)
  if(!length(countries))return(data.frame(country=character(),projects=integer(),reviewed=integer(),complete_hq=integer()))
  do.call(rbind,lapply(countries,function(country) {
    own<-p[p$country==country,,drop=FALSE]
    data.frame(country=country,projects=nrow(own),reviewed=sum(own$project_id %in% actors$project_id),
      complete_hq=sum(own$actor_hq_origin!='unknown'),stringsAsFactors=FALSE)
  }))
}
build_result <- function(root='.',data_dir=file.path(root,'data')) {
  before<-input_hashes(root,data_dir);x<-read_inputs(root,data_dir);result<-calculate(x,approved_only=TRUE);map<-assemble_map(x$config,root)
  timeline<-calculate_timeline(x,before)
  if(!identical(before,input_hashes(root,data_dir)))stop('Inputs changed during build; retry after edits finish')
  list(version=x$config$version,as_of=x$config$as_of,input_hashes=before,
    scope='manually_approved_projects',
    method=list(scenarios=x$config$scenarios,assumptions=x$config$assumptions,timeline=x$config$timeline,type_assumptions=x$config$type_assumptions,geography_note=x$config$geography_note,actor_classification=x$config$actor_classification),
    approval=list(approved_project_ids=as.list(x$projects$project_id[x$projects$record_type=='existing']),
      pending_project_ids=as.list(x$projects$project_id[x$projects$record_type=='candidate']),
      out_of_scope_project_ids=as.list(x$projects$project_id[x$projects$record_type=='out_of_scope'])),
    projects=classify_actors(x$projects,x$actors,x$config),capacity=x$capacity,sources=x$sources,actors=actor_display(x$actors,x$config),
    actor_coverage=actor_coverage(x$projects,x$actors,x$config),
    scenarios=result$scenarios,project_scenarios=result$project_scenarios,ledger=result$ledger,
    timeline=timeline,timing_diagnostics=timing_diagnostics(x),
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
