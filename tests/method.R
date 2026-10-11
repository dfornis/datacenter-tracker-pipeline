source('scripts/model.R')
count<-0
test<-function(name,fn) {
  fn();count<<-count+1;cat('PASS ',name,'\n',sep='')
}
fails<-function(fn,pattern) {
  message<-tryCatch({fn();NULL},error=function(e)conditionMessage(e))
  stopifnot(!is.null(message),grepl(pattern,message,fixed=TRUE))
}
# Arithmetic fixtures are synthetic and never written into the live CSV files.
# Future country research must not fail merely because a real project's facts changed.
live<-read_inputs();live_result<-calculate(live)
fixture_row<-function(table,values) {
  d<-as.data.frame(setNames(rep(list(''),length(live$config$tables[[table]])),unlist(live$config$tables[[table]])),stringsAsFactors=FALSE)
  for(k in names(values))d[[k]]<-as.character(values[[k]])
  d
}
claim<-function(id,project,mw=100,basis='unspecified',status='Planned',decision='no',...) {
  v<-list(claim_id=id,project_id=project,phase='Synthetic test phase',mw=mw,basis=basis,
    qualifier='exact',status=status,decision=decision,timing='unknown',relation='independent',
    baseline_scope='new_capacity',source_ids='S001')
  more<-list(...);v[names(more)]<-more
  fixture_row('capacity',v)
}
claims<-do.call(rbind,list(
  claim('C001','P001',1000),claim('C003','P002',750),
  claim('C006','P002',300,parent_id='C003',relation='included_in'),
  claim('C004','P003',600),claim('C014','P010',23,decision='yes',parent_id='C004',relation='possibly_included_in'),
  claim('C011','P007',55,'generation','Concept study'),
  claim('C013','P009',28,'it_nameplate',decision='yes',first_year='2027',last_year='2027',timing='full_capacity'),
  claim('C022','P015',1500,'backup','Permitted'),claim('C024','P016',240,'grid','Under construction','yes'),
  claim('C025','P017',90,'it_nameplate','Operational','yes'),
  claim('C026','P017',150,'it_nameplate',decision='unclear',baseline_id='C025',baseline_scope='existing_known'),
  claim('C030','P021',80,'grid','Operational','yes'),
  claim('C031','P021',200,'grid',decision='unclear',baseline_id='C030',baseline_scope='existing_unknown'),
  claim('C032','P022',42,'it_nameplate','Under construction','yes',parent_id='C033',relation='included_in'),
  claim('C033','P022',1000,baseline_scope='existing_unknown'),
  claim('C040','P035',310,decision='yes',first_year='2027',last_year='2027',timing='first_capacity'),
  claim('C041','P036',70,status='Under construction',decision='yes',construction_year='2026'),
  claim('C044','P025',10,'facility_nameplate','Operational','yes'),
  claim('C045','P026',200,'facility_nameplate'),claim('C047','P028',220,'facility_peak'),
  claim('C009','P006',150,status='Cancelled'),
  claim('C042','P030',100,'it_nameplate','Under construction','yes',issue='identity_conflict')))
projects<-do.call(rbind,lapply(unique(c(claims$project_id,'P038','P023','P090')),function(id) {
  status<-if(id %in% c('P003','P015','P016','P022','P030','P036','P038'))'Under construction' else if(id %in% c('P017','P021','P025'))'Operational' else if(id=='P006')'Cancelled' else 'Planned'
  fixture_row('projects',list(project_id=id,country='SE',bidding_zone=if(id=='P090')'' else 'SE3',
    project_name=paste('Synthetic',id),developer='Synthetic',municipality='Synthetic',status=status,
    record_type=if(id=='P090')'candidate' else 'existing',related_project_id=if(id=='P090')'P023' else '',source_ids='S001'))
}))
cfg<-live$config
cfg$assumptions$pue<-list(1.1,1.5);cfg$assumptions$nameplate_annual_fraction<-list(.57,.75);cfg$assumptions$peak_annual_fraction<-list(.88,.94)
cfg$assumptions$peak_to_nameplate_fraction<-list(.62,.80)
cfg$assumptions$first_to_full_years<-5;cfg$assumptions$small_scope_years<-2;cfg$assumptions$campus_threshold_mw<-100;cfg$assumptions$construction_to_first_years<-2
cfg$scenarios<-list(
  list(id='low_2030',year=2030,share=list(construction=.9,advanced=.25,early=0)),
  list(id='planning_2030',year=2030,share=list(construction=1,advanced=.75,early=.1)),
  list(id='planning_2035',year=2035,share=list(construction=1,advanced=1,early=.3)),
  list(id='high_2035',year=2035,share=list(construction=1,advanced=1,early=.6)),
  list(id='potential',year=NULL,share=list(construction=1,advanced=1,early=1)))
x<-list(config=cfg,projects=projects,capacity=claims,sources=fixture_row('sources',list(source_id='S001',url='https://example.org/synthetic-test',title='Synthetic test, not evidence',kind='summary')))
result<-calculate(x)
row<-function(r,id,scenario='potential')r$ledger[r$ledger$claim_id==id & r$ledger$scenario==scenario,,drop=FALSE]
project<-function(r,id,scenario='potential')r$project_scenarios[r$project_scenarios$project_id==id & r$project_scenarios$scenario==scenario,,drop=FALSE]
edit<-function(x,id,...) {
  values<-list(...);i<-match(id,x$capacity$claim_id)
  for(k in names(values))x$capacity[i,k]<-as.character(values[[k]])
  x
}
test('every registered project and candidate appears exactly once in every scenario',function() {
  stopifnot(nrow(live_result$project_scenarios)==nrow(live$projects)*length(live$config$scenarios))
  for(sc in live$config$scenarios)stopifnot(setequal(live$projects$project_id,live_result$project_scenarios$project_id[live_result$project_scenarios$scenario==sc$id]))
  stopifnot(!anyDuplicated(paste(live_result$project_scenarios$scenario,live_result$project_scenarios$project_id)))
})
test('unknown full commissioning date does not remove a funded or building phase',function() {
  t<-edit(x,'C041',first_year='',last_year='',construction_year='',timing='unknown')
  r<-calculate(t);stopifnot(row(r,'C041','low_2030')$counted_mw_high>0,row(r,'C041','planning_2030')$counted_mw_high>0)
})
test('missing review metadata has no scenario gate',function() {
  stopifnot(!any(grepl('review',unlist(x$config$tables))))
  stopifnot(row(result,'C013','low_2030')$counted_mw_low>0)
})
test('early undated projects remain in planning and potential',function() {
  stopifnot(row(result,'C001','planning_2030')$counted_mw_high>0,row(result,'C001')$counted_mw_high>0)
})
test('first capacity is phased without pretending that it dates the whole campus',function() {
  r<-x$capacity[x$capacity$claim_id=='C040',]
  stopifnot(timing_cap(r,2026,x$config)==0,timing_cap(r,2027,x$config)==.2,timing_cap(r,2030,x$config)==.8,timing_cap(r,2035,x$config)==1)
  stopifnot(row(result,'C040','planning_2030')$share==.75)
})
test('completion share and phasing cap are not two multiplicative completion discounts',function() {
  stopifnot(row(result,'C040','planning_2030')$share==min(.75,.8))
})
test('explicit future commissioning constrains the time scenario but preserves potential',function() {
  t<-edit(x,'C013',first_year='2040',last_year='2040',construction_year='',timing='full_capacity')
  r<-calculate(t);stopifnot(row(r,'C013','planning_2030')$direct_mw_high==0,row(r,'C013')$counted_mw_high>0)
  t<-edit(t,'C013',last_year='');r<-calculate(t)
  stopifnot(row(r,'C013','planning_2030')$direct_mw_high==0)
})
test('unknown MW meaning is modelled as a declared range while source wording is preserved',function() {
  r<-row(result,'C001');stopifnot(r$counted_mw_low==1000,r$counted_mw_high==1500,r$source_basis=='unspecified',grepl('capacity_definition_assumed',r$assumptions))
})
test('grid power is an explicit deployment assumption, never an extra IT claim',function() {
  r<-row(result,'C024');stopifnot(r$counted_mw_low==240,r$counted_mw_high==240,grepl('connection_deployment_assumed',r$assumptions))
})
test('same-basis installed baseline is subtracted before PUE conversion',function() {
  r<-row(result,'C026');stopifnot(abs(r$counted_mw_low-66)<1e-8,abs(r$counted_mw_high-90)<1e-8)
  t<-edit(x,'C025',qualifier='at_least');r<-row(calculate(t),'C026')
  stopifnot(r$counted_mw_low==0,abs(r$counted_mw_high-90)<1e-8)
})
test('unknown installed baseline retains gross site scope and a 0-to-envelope increment',function() {
  r<-row(result,'C031');stopifnot(r$counted_mw_low==0,r$counted_mw_high==200,r$gross_mw_high==200)
})
test('a known new phase anchors an uncertain existing campus instead of disappearing',function() {
  r<-row(result,'C033');stopifnot(r$counted_mw_low>=42*1.1,r$counted_mw_high==1500,row(result,'C032')$counted_mw_high==0)
})
test('tenant/campus ambiguity retains one envelope and both project indicators',function() {
  r<-row(result,'C004');stopifnot(r$counted_mw_low==600,r$counted_mw_high==900,row(result,'C014')$counted_mw_high==0)
  stopifnot(project(result,'P003')$participates,project(result,'P010')$participates)
})
test('contained phases cannot make dated planning exceed the undated envelope',function() {
  for(id in unique(result$ledger$group_id)) {
    cap<-row(result,id)$counted_mw_high
    for(sc in x$config$scenarios) {
      v<-row(result,id,sc$id)$counted_mw_high
      if(is.finite(cap)&&is.finite(v))stopifnot(v<=cap+1e-8)
    }
  }
})
test('cancelled and operating rows stay visible without becoming new capacity',function() {
  stopifnot(all(result$project_scenarios$mw_high[result$project_scenarios$project_id=='P006']==0))
  stopifnot(project(result,'P006')$indicator=='cancelled',project(result,'P025')$indicator=='operational',row(result,'C044')$counted_mw_high==0)
})
test('backup/reactor power and wrong-site claims remain visible without fabricated load',function() {
  for(id in c('C011','C022','C042'))stopifnot(row(result,id)$counted_mw_high==0,is.na(row(result,id)$gross_mw_high))
  for(id in c('P007','P015','P030','P038'))stopifnot(nrow(project(result,id))==1,!project(result,id)$capacity_known)
})
test('candidates with unknown zones stay in country-unassigned buckets',function() {
  candidate<-x$projects$project_id[x$projects$record_type=='candidate' & x$projects$country=='SE'][1]
  stopifnot(project(result,candidate)$bidding_zone=='SE-unassigned')
  stopifnot(sum(result$scenarios$projects[result$scenarios$scenario=='potential'])==nrow(x$projects))
  stopifnot(is.na(project(result,candidate)$mw_high),is.na(project(result,'P038')$mw_high))
})
test('a register without any MW claims still produces complete project indicators',function() {
  t<-x;t$capacity<-t$capacity[FALSE,];r<-calculate(t)
  stopifnot(nrow(r$project_scenarios)==nrow(t$projects)*length(t$config$scenarios))
  stopifnot(is.na(project(r,'P038')$mw_high))
})
test('a lower-bound-only capacity does not become a fabricated finite upper total',function() {
  t<-edit(x,'C001',qualifier='at_least');r<-calculate(t)
  stopifnot(is.na(row(r,'C001')$counted_mw_high))
  stopifnot(is.na(r$scenarios$mw_high[r$scenarios$scenario=='potential' & r$scenarios$bidding_zone=='SE3']))
})
test('related candidate cannot silently create a second quantified campus',function() {
  t<-x;id<-t$projects$project_id[nzchar(t$projects$related_project_id)][1]
  t$capacity$project_id[t$capacity$claim_id=='C001']<-id
  r<-calculate(t);stopifnot(row(r,'C001')$counted_mw_high==0,row(r,'C001')$reason=='related_identity')
})
test('peak-based and nameplate-based annual equivalents use compatible denominators',function() {
  r<-row(result,'C047');stopifnot(abs(r$annual_twh_low-220*.88*8760/1e6)<1e-8)
  stopifnot(abs(r$counted_mw_low-220/.80)<1e-8,abs(r$counted_mw_high-220/.62)<1e-8)
  r<-row(result,'C045');stopifnot(abs(r$annual_twh_low-200*.57*8760/1e6)<1e-8)
})
test('planning increases monotonically with horizon and ambition on identical input',function() {
  for(zone in unique(result$scenarios$bidding_zone)) {
    d<-result$scenarios[result$scenarios$bidding_zone==zone,]
    for(key in c('mw_low','mw_high'))stopifnot(all(diff(d[[key]])>=-1e-8,na.rm=TRUE))
  }
})
test('real inventory produces useful cautious and planning outputs without tuning to an old total',function() {
  d<-live_result$scenarios
  stopifnot(sum(d$mw_high[d$scenario=='low_2030'],na.rm=TRUE)>0)
  stopifnot(sum(d$mw_high[d$scenario=='planning_2035'],na.rm=TRUE)>sum(d$mw_high[d$scenario=='planning_2030'],na.rm=TRUE))
})
test('structural errors still stop a build',function() {
  t<-x;t$capacity$project_id[1]<-'P999';fails(function()validate_inputs(t),'Orphaned capacity')
  t<-x;t$capacity$mw[1]<-'-1';fails(function()validate_inputs(t),'Invalid number')
  t<-x;t$projects$bidding_zone[1]<-'FI';fails(function()validate_inputs(t),'Wrong country/zone')
  t<-edit(x,'C003',parent_id='C006',relation='included_in');fails(function()validate_inputs(t),'Containment cycle')
  t<-edit(x,'C026',baseline_id='C030');fails(function()validate_inputs(t),'Incomparable installed baseline')
  t<-x;t$capacity$source_ids[1]<-'S999';fails(function()validate_inputs(t),'Missing source reference')
})
test('all ten map areas are assembled before publishing',function() {
  m<-assemble_map(x$config);stopifnot(length(m$features)==10)
  t<-x$config;t$zones[[1]]$id<-'DOES_NOT_EXIST';fails(function()assemble_map(t),'Missing/duplicate map zone')
})
test('the complete single-file output is deterministic and contains project coverage',function() {
  a<-build_result();b<-build_result();stopifnot(identical(a,b),a$coverage$every_project_represented)
  f<-tempfile(fileext='.json');on.exit(unlink(f));atomic_output(a,f);read<-json_read(f)
  stopifnot(length(read$projects)==nrow(live$projects),length(read$bidding_zones$features)==length(live$config$zones),length(read$project_scenarios)==nrow(live$projects)*length(live$config$scenarios))
})
cat(count,' meaningful method and integration checks passed.\n')
