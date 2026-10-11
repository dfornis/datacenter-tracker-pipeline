#!/usr/bin/env Rscript
# Integration and domain regression tests; synthetic evidence never reaches live data.
source('scripts/lib/common.R'); source('scripts/lib/validation.R')
source('scripts/lib/releases.R'); source('scripts/lib/migration_v2.R'); source('scripts/lib/promotion.R')
source('scripts/lib/accounting.R')
source('scripts/lib/geometry.R'); source('scripts/lib/export.R'); source('scripts/lib/runtime.R')
source('scripts/lib/runs.R')
source('scripts/lib/run_review.R')
source('scripts/lib/admin.R')
root <- pipeline_root(); schema <- read_json(file.path(root,'config/schema.json'))
check_runtime(root)
scratch <- tempfile('datacenter-tests-'); dir.create(scratch)
passed <- 0L
test <- function(name, action) {
  tryCatch({ action(); passed <<- passed + 1L; cat('PASS ',name,'\n',sep='') },error=function(e) {
    cat('FAIL ',name,': ',conditionMessage(e),'\nScratch: ',scratch,'\n',sep=''); quit(status=1)
  })
}
expect_error <- function(action, pattern) {
  message <- tryCatch({ action(); NULL },error=conditionMessage)
  if (is.null(message) || !grepl(pattern,message)) stop('Expected error /',pattern,'/; got ',message %||% 'success')
}
legacy <- if (dir.exists(file.path(root,'data','legacy-v1'))) file.path(root,'data','legacy-v1') else file.path(root,'data')
migrated <- file.path(scratch,'migration'); migrate_v1_tables(legacy,migrated,root)
tables <- load_state(migrated,schema)
fixture <- function(edit=function(t) t) {
  f <- tempfile('repo-',scratch); dir.create(f); copy_directory(file.path(root,'config'),file.path(f,'config'))
  stage <- file.path(f,'.staging','initial'); copy_directory(migrated,stage)
  write_state_tables(edit(load_state(stage,schema)),stage,schema); validate_state(stage,f)
  id <- seal_release(stage,f,'test-parent'); publish_state(stage,f,id)
  f
}
test('migration preserves counts, retires wrong FI sources and closes stale suggestions',function() {
  stopifnot(validate_state(migrated,root)$valid,nrow(tables$projects_master)==38,nrow(tables$capacity_master)==46,
    nrow(tables$sources_master)==70,!any(sprintf('S%03d',44:56) %in% tables$sources_master$source_id),
    all(tables$sources_master$project_id[match(sprintf('S%03d',58:70),tables$sources_master$source_id)]==sprintf('P%03d',26:38)),
    sum(tables$suggested_capacity_updates$review_state=='already_applied')==26,
    sum(tables$suggested_capacity_updates$review_state=='pending')==4)
})
test('partial dates and source summaries are not fabricated into exact evidence',function() {
  s <- tables$sources_master
  stopifnot(s$source_date_raw[s$source_id=='S070']=='2026-04',s$source_date[s$source_id=='S070']=='',
    s$source_date_precision[s$source_id=='S078']=='year',all(s$review_state=='legacy_unverified'),all(s$original_excerpt==''))
})
test('identities include retired IDs when allocating',function() {
  t <- tables; t$identity_registry <- rbind(t$identity_registry,row_frame(list(entity_type='claim',entity_id='C100',state='retired',created_in='test',retired_in='test'),names(t$identity_registry)))
  stopifnot(allocate_identity(t,'claim','test')$id=='C101',allocate_identity(t,'source','test')$id=='S084')
})
test('migration preserves first-capacity timing, thermal unit and ambiguous overlap',function() {
  c <- tables$capacity_master
  stopifnot(c$timing_scope[c$claim_id=='C040']=='first_capacity',c$capacity_unit[c$claim_id=='C022']=='MW_thermal',
    c$relation[c$claim_id=='C014']=='possibly_included_in',c$baseline_scope[c$claim_id=='C031']=='existing_unknown',
    c$baseline_comparable[c$claim_id=='C026']=='TRUE',!any(grepl('AI/HPC',c$type,fixed=TRUE)),
    c$business_model[c$claim_id=='C040']=='unknown',c$workload[c$claim_id=='C040']=='ai_unspecified')
})
invalid <- function(edit, pattern) {
  path <- tempfile('invalid-',scratch); copy_directory(migrated,path)
  t <- edit(load_state(path,schema)); write_state_tables(t,path,schema)
  expect_error(function() validate_state(path,root),pattern)
}
test('negative numbers, invalid numeric strings, unknown enums and duplicate keys fail',function() {
  invalid(function(t) {t$capacity_master$reported_capacity_mw[1]<-'-1';t},'reported_capacity_mw')
  invalid(function(t) {t$capacity_master$reported_capacity_mw[1]<-'1,000';t},'reported_capacity_mw')
  invalid(function(t) {t$capacity_master$capacity_type[1]<-'campus_typo';t},'capacity_type')
  invalid(function(t) {t$capacity_master$claim_id[2]<-t$capacity_master$claim_id[1];t},'duplicate primary key')
})
test('orphaned or misbound sources and retired active IDs fail',function() {
  invalid(function(t) {t$sources_master$project_id[1]<-'P999';t},'source project_id')
  invalid(function(t) {t$sources_master$project_id[1]<-'P002';t},'Source claim/project mismatch')
  invalid(function(t) {t$identity_registry$state[t$identity_registry$entity_id=='S001' & t$identity_registry$entity_type=='source']<-'reserved';t},'identity ledger')
})
test('dates, cycles, thermal electric confusion and incomparable baselines fail',function() {
  invalid(function(t) {t$sources_master$access_date[1]<-'2026-02-30';t},'access_date')
  invalid(function(t) {t$capacity_master$parent_claim_id[1]<-'C001';t$capacity_master$relation[1]<-'included_in';t},'Cyclic')
  invalid(function(t) {t$capacity_master$capacity_unit[1]<-'MW_thermal';t},'Thermal capacity')
  invalid(function(t) {i<-match('C026',t$capacity_master$claim_id);t$capacity_master$baseline_claim_id[i]<-'C030';t},'crosses physical sites')
})
test('same-phase alternate facility observation is retained, not an extra claim',function() {
  stopifnot(nrow(tables$capacity_observations)==1,tables$capacity_observations$claim_id=='C042',tables$capacity_observations$value=='130')
  invalid(function(t) {t$capacity_observations$basis[1]<-'it_load';t},'duplicates primary measure')
})
approve_fixture <- function(t) {
  d <- t$suggested_capacity_updates
  c <- t$capacity_master[t$capacity_master$claim_id=='C040',,drop=FALSE]
  r <- row_frame(list(audit_id='TEST-AC001',country='FI',claim_id='C040',project_id=c$project_id,project_name=c$project_name,phase=c$phase,
    field='investment_decision',current_value='yes',suggested_value='unclear',source_url='https://example.org/test-evidence',source_title='Synthetic regression evidence',source_type='company',source_date='2026-10-11',access_date='2026-10-11',
    original_excerpt='Synthetic test: commitment to the full 310 MW has not been established.',original_language='en',locator='Test paragraph 1',evidence_kind='verbatim',supports_fields='investment_decision',confidence='high',rationale='Regression fixture only.',
    run_id='fixture-run',review_state='approved',reviewed_by='test-reviewer',reviewed_at='2026-10-11T12:00:00Z'),names(d))
  t$suggested_capacity_updates <- rbind(d,r); t
}
promote_fixture <- function(f, expected=basename(current_state(f)),apply=FALSE,failpoint=NULL,request='test-request') {
  promote_rows(f,'audit','capacity','TEST-AC001','FI','test-reviewer',request,expected,apply,failpoint)
}
test('dry run validates evidence and staged state without changing current',function() {
  f <- fixture(approve_fixture); before <- file_inventory(current_state(f)); pointer <- current_state(f)
  result <- promote_fixture(f)
  stopifnot(!result$applied,result$validation$valid,identical(before,file_inventory(current_state(f))),current_state(f)==pointer)
})
test('apply moves sources, master data, field evidence and audit state together; replay is idempotent',function() {
  f <- fixture(approve_fixture); expected <- basename(current_state(f)); result <- promote_fixture(f,expected,TRUE)
  t <- load_state(current_state(f),schema)
  stopifnot(result$applied,t$capacity_master$investment_decision[t$capacity_master$claim_id=='C040']=='unclear',
    'S084' %in% t$sources_master$source_id,nrow(t$field_reviews)==1,
    t$suggested_capacity_updates$review_state[t$suggested_capacity_updates$audit_id=='TEST-AC001']=='applied')
  replay <- promote_fixture(f,expected,TRUE)
  stopifnot(replay$replay,!replay$applied,basename(current_state(f))==result$release_id)
  expect_error(function() promote_fixture(f,expected,TRUE,request='another-request'),'Input release is stale')
  expect_error(function() promote_rows(f,'audit','capacity','TEST-AC001','FI','test-reviewer','test-request',result$release_id,TRUE),'different payload')
})
test('stale values, unapproved rows and summary-only evidence fail equally in dry run and apply',function() {
  variants <- list(
    list(edit=function(t) {t<-approve_fixture(t);t$suggested_capacity_updates$current_value[nrow(t$suggested_capacity_updates)]<-'no';t},error='Stale current_value'),
    list(edit=function(t) {t<-approve_fixture(t);t$suggested_capacity_updates$review_state[nrow(t$suggested_capacity_updates)]<-'pending';t},error='explicitly approved'),
    list(edit=function(t) {t<-approve_fixture(t);t$suggested_capacity_updates$evidence_kind[nrow(t$suggested_capacity_updates)]<-'summary';t},error='verbatim evidence'))
  for (v in variants) {
    f <- fixture(v$edit); before <- current_state(f)
    for (apply in c(FALSE,TRUE)) expect_error(function() promote_fixture(f,apply=apply),v$error)
    stopifnot(current_state(f)==before)
  }
})
test('interruptions before publication never select a partial release',function() {
  for (point in c('after_tables','before_pointer')) {
    f <- fixture(approve_fixture); before <- current_state(f)
    expect_error(function() promote_fixture(f,apply=TRUE,failpoint=point),'Injected interruption')
    stopifnot(current_state(f)==before,verify_release(before)$release_id==basename(before),!dir.exists(file.path(f,'.locks','data')))
  }
})
test('concurrent writer is rejected; an immutable release cannot be edited undetected',function() {
  f <- fixture(approve_fixture); before <- current_state(f)
  with_data_lock(f,function() expect_error(function() promote_fixture(f,apply=TRUE),'Another data writer'))
  stopifnot(current_state(f)==before)
  cat('\n',file=file.path(before,'master','projects_master.csv'),append=TRUE)
  expect_error(function() promote_fixture(f,apply=TRUE),'Immutable release has changed')
})
test('field review becomes invalid when its value changes without review',function() {
  f <- fixture(approve_fixture); promote_fixture(f,apply=TRUE)
  path <- tempfile('review-tamper-',scratch); copy_directory(current_state(f),path)
  t <- load_state(path,schema); t$capacity_master$investment_decision[t$capacity_master$claim_id=='C040']<-'yes'; write_state_tables(t,path,schema)
  expect_error(function() validate_state(path,root),'Stale field review')
})
test('unchanged facts can receive new evidence through an explicit confirmation',function() {
  f <- fixture(function(t) {
    t <- approve_fixture(t); i <- nrow(t$suggested_capacity_updates)
    t$suggested_capacity_updates$suggested_value[i] <- 'yes'
    t$suggested_capacity_updates$change_kind[i] <- 'confirmation'
    t$suggested_capacity_updates$original_excerpt[i] <- 'Synthetic evidence confirms the existing commitment classification.'
    t
  })
  promote_fixture(f,apply=TRUE); t <- load_state(current_state(f),schema)
  stopifnot(t$capacity_master$investment_decision[t$capacity_master$claim_id=='C040']=='yes',nrow(t$field_reviews)==1,'S084' %in% t$sources_master$source_id)
})
test('source-level metadata corrections are supported and leave an evidence trail',function() {
  f <- fixture(approve_fixture); promote_fixture(f,apply=TRUE)
  before <- basename(current_state(f))
  staged <- state_transaction(f,function(t,stage,schema) {
    s <- t$sources_master[t$sources_master$source_id=='S084',,drop=FALSE]
    values <- as.list(s); values$audit_id <- 'TEST-AS001'; values$country <- 'FI'; values$field <- 'source_title'
    values$current_value <- s$source_title; values$suggested_value <- 'Corrected synthetic source title'
    values$source_title <- values$suggested_value; values$supports_fields <- 'source_title'
    values$run_id <- 'fixture-source'; values$review_state <- 'approved'; values$reviewed_by <- 'test-reviewer'; values$reviewed_at <- '2026-10-11T12:00:00Z'
    t$suggested_source_updates <- rbind(t$suggested_source_updates,row_frame(values,names(t$suggested_source_updates)))
    list(tables=t)
  },before,TRUE)
  result <- promote_rows(f,'audit','source','TEST-AS001','FI','test-reviewer','test-source-request',staged$release_id,TRUE)
  t <- load_state(current_state(f),schema)
  stopifnot(result$applied,t$sources_master$source_title[t$sources_master$source_id=='S084']=='Corrected synthetic source title',nrow(t$field_reviews)==2)
})
candidate_fixture <- function(t) {
  p <- t$projects_master[t$projects_master$project_id=='P038',,drop=FALSE]
  values <- as.list(p); values$project_candidate_id <- 'TEST-NP001'; values$project_name <- 'Synthetic new site'
  values$physical_site_id <- ''; values$run_id <- 'fixture-candidate'; values$review_state <- 'approved'
  values$decision_basis <- 'execution_evidence'
  values$source_type <- 'company'; values$source_url <- 'https://example.org/candidate'; values$source_title <- 'Synthetic candidate source'
  values$source_date <- ''; values$access_date <- '2026-10-11'; values$original_excerpt <- 'Synthetic candidate used only for regression testing.'
  values$original_language <- 'en'; values$locator <- 'Test paragraph'; values$evidence_kind <- 'verbatim'; values$confidence <- 'high'
  values$reviewed_by <- 'test-reviewer'; values$reviewed_at <- '2026-10-11T12:00:00Z'
  values$supports_fields <- 'project_name;developer;municipality;county;bidding_zone;project_status;investment_decision;decision_basis'
  t$new_project_candidates <- rbind(t$new_project_candidates,row_frame(values,names(t$new_project_candidates)))
  c <- t$capacity_master[t$capacity_master$claim_id=='C043',,drop=FALSE]
  capacity <- as.list(c)
  for (field in c('run_id','source_type','source_url','source_title','source_date','access_date','original_excerpt','original_language','locator','evidence_kind','confidence','reviewed_by','reviewed_at')) capacity[[field]] <- values[[field]]
  capacity$capacity_candidate_id <- 'TEST-NC001'; capacity$project_candidate_id <- 'TEST-NP001'; capacity$project_id <- ''
  capacity$source_ids <- ''; capacity$review_state <- 'approved'; capacity$project_name <- values$project_name
  capacity$decision_basis <- 'execution_evidence'
  capacity$supports_fields <- 'reported_capacity_mw;reported_capacity_basis;capacity_unit;measurement_kind;capacity_type;capacity_status;investment_decision;decision_basis;timing_scope;baseline_scope;relation;operation_year_min;operation_year_max'
  t$new_capacity_claim_candidates <- rbind(t$new_capacity_claim_candidates,row_frame(capacity,names(t$new_capacity_claim_candidates)))
  t
}
test('candidate project, claim, source, site and phase IDs promote in one transaction',function() {
  f <- fixture(candidate_fixture); before <- basename(current_state(f))
  expect_error(function() promote_rows(f,'candidates','','TEST-NC001','FI','test-reviewer','candidate-missing-parent',before,FALSE),'dependency must be')
  ids <- c('TEST-NP001','TEST-NC001')
  dry <- promote_rows(f,'candidates','',ids,'FI','test-reviewer','test-candidate-request',before,FALSE)
  stopifnot(!dry$applied,basename(current_state(f))==before)
  applied <- promote_rows(f,'candidates','',ids,'FI','test-reviewer','test-candidate-request',before,TRUE)
  t <- load_state(current_state(f),schema)
  stopifnot(applied$applied,'P039' %in% t$projects_master$project_id,'C048' %in% t$capacity_master$claim_id,
    t$capacity_master$project_id[t$capacity_master$claim_id=='C048']=='P039',
    all(c('S084','S085') %in% t$sources_master$source_id),validate_state(current_state(f),f)$valid)
})
method <- read_json(file.path(root,'config/methodology.json'))
ledger <- account_all(tables,method)$ledger
row <- function(ledger,id,scenario='pipeline_potential') ledger[ledger$claim_id==id & ledger$scenario_id==scenario,,drop=FALSE]
test('first-capacity dates, construction starts and long intervals do not date full campuses',function() {
  stopifnot(!row(ledger,'C040','stated_2030')$counted,!row(ledger,'C040','low_2030')$counted,
    !row(ledger,'C003','stated_2035')$counted,!row(ledger,'C005','stated_2030')$counted)
  t <- tables; i <- match('C043',t$capacity_master$claim_id)
  t$capacity_master$construction_start_year[i] <- '2029'; t$capacity_master$operation_year_min[i] <- t$capacity_master$operation_year_max[i] <- '2034'
  result <- account_all(t,method)$ledger
  stopifnot(!row(result,'C043','stated_2030')$counted,row(result,'C043','stated_2035')$counted)
})
test('operational campus keeps a future increment; available power is not installed baseline',function() {
  stopifnot(row(ledger,'C026')$counted,row(ledger,'C026')$incremental_reported_mw==60,
    !row(ledger,'C031')$counted,row(ledger,'C031')$reason=='installed_baseline_unknown',!row(ledger,'C025')$counted)
})
test('explicit containment and unresolved customer/campus overlap prevent double counting',function() {
  stopifnot(!row(ledger,'C018')$counted,row(ledger,'C018')$reason=='contained_in:C013',
    row(ledger,'C014')$reason=='unresolved_overlap',row(ledger,'C004')$reason=='unresolved_overlap',
    row(ledger,'C014','stated_2030')$counted)
  t <- tables; i <- match('C014',t$capacity_master$claim_id)
  t$capacity_master$relation[i] <- 'incremental_to'; t$capacity_master$capacity_type[i] <- 'incremental_expansion'
  result <- account_all(t,method)$ledger
  stopifnot(row(result,'C014')$counted,row(result,'C004')$counted)
})
test('legacy assumptions, unknown MW basis and grid connections do not create energy estimates',function() {
  legacy_method <- method; legacy_method$energy_assumptions <- list(pue_id='PUE_AI_HPC',load_factor_id='LF_AI_HPC')
  legacy_ledger <- account_all(tables,legacy_method)$ledger
  stopifnot(is.na(row(ledger,'C040')$it_load_mw),is.na(row(ledger,'C040')$conditional_mature_annual_twh_low),
    row(ledger,'C024')$grid_connection_mw==240,is.na(row(ledger,'C024')$modelled_facility_equivalent_mw_low),
    is.na(row(legacy_ledger,'C043','stated_2030')$conditional_mature_annual_twh_low))
})
model_fixture <- function(t) {
  a <- t$assumptions
  for (id in c('TEST_PUE','TEST_LF')) {
    pue <- id=='TEST_PUE'
    a <- rbind(a,row_frame(list(assumption_id=id,assumption_type=if(pue)'PUE' else 'Annual load factor',low=if(pue)'1.2' else '0.5',high=if(pue)'1.4' else '0.75',
      denominator='Synthetic sensitivity fixture',denominator_kind=if(pue)'annual_IT_energy' else 'nameplate_capacity',parameter_status='illustrative_sensitivity',population='Test only',version='test',valid_from='2026-10-11'),names(a)))
  }
  t$assumptions <- a; t
}
energy_method <- method; energy_method$energy_assumptions <- list(pue_id='TEST_PUE',load_factor_id='TEST_LF')
test('same-scope facility observation takes precedence; peak and nameplate denominators stay distinct',function() {
  t <- model_fixture(tables); result <- account_all(t,energy_method)$ledger
  c <- row(result,'C042','stated_2030')
  stopifnot(c$it_load_mw==100,c$facility_power_mw==130,c$modelled_facility_equivalent_mw_low==130,
    abs(c$conditional_mature_annual_twh_low-130*.5*8760/1e6)<1e-12,
    row(result,'C047')$energy_status=='load_factor_denominator_mismatch',is.na(row(result,'C040')$conditional_mature_annual_twh_low))
})
test('capacity intervals and design PUE upper limits are not flattened to point estimates',function() {
  t <- model_fixture(tables); i <- match('C013',t$capacity_master$claim_id)
  t$capacity_master$capacity_qualifier[i] <- 'range'; t$capacity_master$capacity_max_mw[i] <- '40'
  result <- account_all(t,energy_method)$ledger; c <- row(result,'C013')
  stopifnot(c$modelled_facility_equivalent_mw_low==28*1.2,c$modelled_facility_equivalent_mw_high==40*1.4)
  t$capacity_master$site_pue[i] <- '1.2'; t$capacity_master$site_pue_kind[i] <- 'design'; t$capacity_master$site_pue_qualifier[i] <- 'up_to'
  c <- row(account_all(t,energy_method)$ledger,'C013')
  stopifnot(c$modelled_facility_equivalent_mw_low==28,c$modelled_facility_equivalent_mw_high==48)
})
test('target-year electricity needs average deployment and uses the correct hours in a leap year',function() {
  t <- model_fixture(tables)
  t$deployment_schedule <- rbind(t$deployment_schedule,row_frame(list(claim_id='C042',year='2032',year_end_fraction='0.6',average_year_fraction='0.3',basis='source',source_ids='S078',review_state='verified'),names(t$deployment_schedule)))
  scenario <- list(scenario_id='test_2032',year=2032,require_decision=FALSE)
  c <- row(account_scenario(t,energy_method,scenario),'C042','test_2032')
  stopifnot(c$facility_power_mw==78,abs(c$target_year_energy_twh_low-130*.3*.5*8784/1e6)<1e-12,
    abs(c$conditional_mature_annual_twh_low-78*.5*8760/1e6)<1e-12,
    is.na(row(account_all(t,energy_method)$ledger,'C042','stated_2030')$target_year_energy_twh_low))
})
test('every configured zone and every claim/scenario has an accounting record',function() {
  result <- account_all(tables,method)
  stopifnot(nrow(result$scenario_zone)==40,nrow(result$ledger)==46*4,
    !'high_2035' %in% result$ledger$scenario_id,all(is.na(result$scenario_zone$target_year[result$scenario_zone$scenario_id=='pipeline_potential'])))
})
test('full export is reproducible and includes every map, source and accounting row',function() {
  f <- fixture(); copy_directory(file.path(root,'data/reference'),file.path(f,'data/reference'))
  file.copy(file.path(root,'renv.lock'),f)
  output <- file.path(scratch,'public-data')
  a <- build_export(f,current_state(f),output,TRUE)
  first <- file_inventory(normalizePath(output))
  b <- build_export(f,current_state(f),output,TRUE)
  stopifnot(a$build_id==b$build_id,identical(first,file_inventory(normalizePath(output))),
    length(read_json(file.path(output,'bidding_zones.geojson'))$features)==10,
    length(read_json(file.path(output,'accounting_ledger.json')))==184,verify_output(output)$build_id==a$build_id)
  original_pointer <- Sys.readlink(output)
  expect_error(function() build_export(f,current_state(f),output,TRUE,failpoint='after_json'),'Injected output interruption')
  stopifnot(Sys.readlink(output)==original_pointer)
  unlink(file.path(f,'data/reference/bidding-zones/NO-NO5.geojson'))
  expect_error(function() build_export(f,current_state(f),output,TRUE),'Missing configured map')
  stopifnot(Sys.readlink(output)==original_pointer,identical(first,file_inventory(normalizePath(output))))
})
test('map validation rejects wrong identities, invalid coordinates and non-WGS84 CRS',function() {
  g <- assemble_geometry(tables,root)
  polygon <- list(type='Polygon',coordinates=list(list(c(0,0),c(1,0),c(1,1),c(0,0))))
  validate_geometry(polygon,'valid-test')
  polygon$coordinates[[1]][[4]] <- c(2,2)
  expect_error(function() validate_geometry(polygon,'test'),'Unclosed')
  polygon$coordinates[[1]][[4]] <- c(181,0)
  expect_error(function() validate_geometry(polygon,'test'),'Invalid WGS84')
  t <- tables; t$geography_config$geojson_file[t$geography_config$bidding_zone=='NO1'] <- 'data/reference/bidding-zones/FI.geojson'
  expect_error(function() assemble_geometry(t,root),'exactly one named feature')
})
run_fixture <- function(task='audit') {
  f <- fixture(); copy_directory(file.path(root,'prompts'),file.path(f,'prompts'))
  dir.create(file.path(f,'docs'))
  file.copy(file.path(root,'docs',c('methodology.md','energy-assumptions.md','status_rules.md')),file.path(f,'docs'))
  created <- create_country_run(f,current_state(f),'FI',task,'test-fi-run','unit-test','synthetic-fixture')
  list(root=f,path=created$path)
}
complete_response_fixture <- function(path) {
  p <- read_table(file.path(path,'input/projects_master.csv')); c <- read_table(file.path(path,'input/capacity_master.csv'))
  w <- read_json(file.path(path,'input/run_workflow.json')); manifest <- verify_run(path)
  response <- list(run_id=manifest$run_id,searches=list(),evidence=list(),coverage=list(),proposals=list(),conflicts=list(),summary='Synthetic response validator fixture; not research.',limitations=list('All findings here are artificial test data.'))
  for (id in c(p$project_id,'FI')) {
    languages <- if(id=='FI') c('fi','sv') else 'en'
    for (language in languages) response$searches[[length(response$searches)+1]] <- list(search_id=paste('Q',id,language,sep='-'),action='search',query=paste('Synthetic',id,'query'),language=language,engine='unit-test',searched_at='2026-10-11T12:00:00Z',route='operator',scope_id=id,result_urls=list(),outcome='Synthetic test result',limitations='No real web search')
  }
  for (type in c('project','claim')) {
    entities <- if(type=='project') p else c; key <- if(type=='project') 'project_id' else 'claim_id'
    for (i in seq_len(nrow(entities))) {
      search <- paste('Q',entities$project_id[i],'en',sep='-')
      fields <- lapply(unlist(w$audit_required_fields[[type]]),function(field)list(field=field,outcome='unknown',evidence_ids=list(),search_ids=list(search),review_kind='interpretation',notes='Synthetic unresolved field; no evidence claimed.'))
      response$coverage[[length(response$coverage)+1]] <- list(entity_type=type,entity_id=entities[[key]][i],result='unresolved',field_outcomes=fields,search_ids=list(search),notes='Synthetic coverage only.')
    }
  }
  response
}
test('country packets are filtered, chunked, frozen and cannot be silently replaced',function() {
  r <- run_fixture(); path <- r$path
  stopifnot(nrow(read_table(file.path(path,'input/projects_master.csv')))==14,nrow(read_table(file.path(path,'input/capacity_master.csv')))==13,
    nrow(read_table(file.path(path,'input/sources_master.csv')))==27,length(list.files(file.path(path,'input'),pattern='^packet-'))==3,
    nrow(read_table(file.path(path,'input/global_identity_index.csv')))==38)
  expect_error(function() create_country_run(r$root,current_state(r$root),'FI','audit','test-fi-run','test','test'),'already exists')
  cat('tamper',file=file.path(path,'instructions/prompt.md'),append=TRUE)
  expect_error(function() verify_run(path),'were modified')
})
test('run validation requires languages, targeted searches and complete no-change coverage',function() {
  r <- run_fixture(); response <- complete_response_fixture(r$path)
  file <- file.path(r$path,'work/response.json'); write_json(response,file)
  stopifnot(validate_run_response(r$path)$valid)
  response$coverage <- response$coverage[-1]; write_json(response,file)
  expect_error(function() validate_run_response(r$path),'Coverage missing')
  response <- complete_response_fixture(r$path); response$searches <- Filter(function(s)s$language!='sv',response$searches); write_json(response,file)
  expect_error(function() validate_run_response(r$path),'search languages')
})
test('model self-approval, unknown keys and unsupported confirmed fields are rejected',function() {
  r <- run_fixture(); response <- complete_response_fixture(r$path); file <- file.path(r$path,'work/response.json')
  response$approved <- TRUE; write_json(response,file)
  expect_error(function() validate_run_response(r$path),'unknown keys')
  response$approved <- NULL; response$coverage[[1]]$field_outcomes[[1]]$outcome <- 'confirmed'; write_json(response,file)
  expect_error(function() validate_run_response(r$path),'lacks accessible same-entity evidence')
})
reviewable_response_fixture <- function(path) {
  response <- complete_response_fixture(path)
  response$evidence <- list(list(evidence_id='E001',project_id='P035',claim_id='C040',url='https://example.org/run-fixture',title='Synthetic fixture source',source_type='company',publication_date='2026-10-11',access_date='2026-10-11',original_language='en',original_excerpt='Synthetic test evidence: commitment to the full scope has not been established.',translation='',locator='Fixture paragraph 1',retrieval_status='accessible',independence_group='test-announcement',supports_fields=list('investment_decision','decision_basis'),confidence='high',limitations='Synthetic fixture; never real research.'))
  response$proposals <- list(
    list(proposal_id='PR001',table='suggested_capacity_updates',values=list(claim_id='C040',field='investment_decision',current_value='yes',suggested_value='unclear'),evidence_ids=list('E001'),rationale='Synthetic revision.',review_kind='interpretation'),
    list(proposal_id='PR002',table='suggested_capacity_updates',values=list(claim_id='C040',field='decision_basis',current_value='legacy_unverified',suggested_value='no_public_evidence'),evidence_ids=list('E001'),rationale='Synthetic absence classification.',review_kind='interpretation'))
  response
}
test('frozen response review imports selected approvals without changing masters, then promotes evidence',function() {
  r <- run_fixture(); response <- reviewable_response_fixture(r$path)
  write_json(response,file.path(r$path,'work/response.json'))
  decisions <- data.frame(proposal_id=c('PR001','PR002'),decision=c('approved','needs_review'),reviewer='test-reviewer',reviewed_at='2026-10-11T12:00:00Z',reason=c('Checked fixture evidence','Deliberately not approved'),stringsAsFactors=FALSE)
  decision_path <- file.path(r$path,'work/decisions.csv'); write_table(decisions,decision_path)
  reviewed <- freeze_run_review(r$path,decision_path,'test-reviewer')
  initial <- basename(current_state(r$root)); before <- file_inventory(file.path(current_state(r$root),'master'))
  dry <- import_run_review(r$root,'test-fi-run',reviewed$review_id,initial,FALSE)
  stopifnot(!dry$applied,basename(current_state(r$root))==initial)
  imported <- import_run_review(r$root,'test-fi-run',reviewed$review_id,initial,TRUE)
  stopifnot(identical(before,file_inventory(file.path(current_state(r$root),'master'))),import_run_review(r$root,'test-fi-run',reviewed$review_id,initial,TRUE)$replay)
  expect_error(function() promote_rows(r$root,'audit','capacity','test-fi-run--PR002','FI','test-reviewer','unapproved-run-row',imported$release_id,TRUE),'explicitly approved')
  result <- promote_rows(r$root,'audit','capacity','test-fi-run--PR001','FI','test-reviewer','run-fixture-promotion',imported$release_id,TRUE)
  t <- load_state(current_state(r$root),schema)
  stopifnot(result$applied,t$capacity_master$investment_decision[t$capacity_master$claim_id=='C040']=='unclear',t$sources_master$independence_group[t$sources_master$source_id=='S084']=='test-announcement')
  cat('\n',file=file.path(r$path,'reviews',reviewed$review_id,'response.json'),append=TRUE)
  expect_error(function() verify_review(r$path,reviewed$review_id),'was modified')
})
test('one verified source can support several approved fields without duplicate source records',function() {
  f <- fixture(function(t) {
    t <- approve_fixture(t); row <- tail(t$suggested_capacity_updates,1)
    row$audit_id <- 'TEST-AC002'; row$field <- 'decision_basis'; row$current_value <- 'legacy_unverified'; row$suggested_value <- 'no_public_evidence'
    row$supports_fields <- 'investment_decision;decision_basis'
    t$suggested_capacity_updates <- rbind(t$suggested_capacity_updates,row);t
  })
  result <- promote_rows(f,'audit','capacity',c('TEST-AC001','TEST-AC002'),'FI','test-reviewer','deduplicated-evidence-request',basename(current_state(f)),TRUE)
  t <- load_state(current_state(f),schema)
  stopifnot(result$applied,nrow(t$sources_master)==71,nrow(t$field_reviews)==2,setequal(split_values(t$sources_master$supports_fields[t$sources_master$source_id=='S084']),c('investment_decision','decision_basis')))
})
test('official reference refresh validates year/counts, preserves configuration and rejects tampering',function() {
  f <- fixture(); old <- file_inventory(file.path(current_state(f),'master'))
  proposal <- file.path(f,'admin-proposal')
  result <- prepare_admin_reference(f,current_state(f),'2026',file.path(root,'data/reference/admin/2026/raw'),proposal)
  stopifnot(result$counts$SE==290,result$counts$FI==308,result$counts$NO==357,result$semantic_changes==0)
  initial <- basename(current_state(f)); dry <- apply_admin_reference(f,proposal,initial,'test-reviewer',FALSE)
  stopifnot(!dry$applied,basename(current_state(f))==initial)
  applied <- apply_admin_reference(f,proposal,initial,'test-reviewer',TRUE)
  stopifnot(applied$applied,sha_file(file.path(current_state(f),'master/country_config.csv'))==old[['country_config.csv']])
  expect_error(function()prepare_admin_reference(f,current_state(f),'2027',file.path(root,'data/reference/admin/2026/raw'),file.path(f,'new')),'not configured')
  cat('tamper',file=file.path(proposal,'admin_units.csv'),append=TRUE)
  expect_error(function()apply_admin_reference(f,proposal,applied$release_id,'test-reviewer',TRUE),'changed since preparation')
})
test('partial evidence stays partial and automatically supplies scoped decision references',function() {
  f <- fixture(approve_fixture)
  promote_rows(f,'audit','capacity','TEST-AC001','FI','test-reviewer','scoped-reference-test',basename(current_state(f)),TRUE)
  t <- load_state(current_state(f),schema); c <- t$capacity_master[t$capacity_master$claim_id=='C040',,drop=FALSE]
  stopifnot(c$review_state=='needs_review',c$decision_source_ids=='S084',c$reviewed_by=='test-reviewer')
  invalid(function(t) {t$capacity_master$decision_basis[1]<-'explicit_decision';t$capacity_master$investment_decision[1]<-'unclear';t},'Decision value contradicts')
})
test('publication precision and correction coverage cannot bypass response checks',function() {
  r <- run_fixture(); response <- reviewable_response_fixture(r$path); file <- file.path(r$path,'work/response.json')
  response$evidence[[1]]$publication_date <- '2027'; write_json(response,file)
  expect_error(function()validate_run_response(r$path),'after as-of')
  response <- complete_response_fixture(r$path); response$coverage[[1]]$field_outcomes[[1]]$outcome <- 'correction_proposed';write_json(response,file)
  expect_error(function()validate_run_response(r$path),'matching proposal')
})
test('selected-project pilot freezes its scope and accepts only unchanged scoped inputs',function() {
  r <- run_fixture(); created <- create_country_run(r$root,current_state(r$root),'FI','audit','test-pilot-run','test','synthetic',c('P033','P035'))
  stopifnot(created$project_count==2,created$packet_count==1,verify_run(created$path)$scope=='selected_project_pilot')
  t <- load_state(current_state(r$root),schema); assert_run_still_current(created$path,t,schema,r$root)
  t$capacity_master$reported_capacity_mw[t$capacity_master$claim_id=='C040'] <- '999'
  expect_error(function()assert_run_still_current(created$path,t,schema,r$root),'Country input changed')
})
test('unresolved source identity blocks a wrongly attributed claim in every scenario',function() {
  t <- tables
  t$source_conflicts <- rbind(t$source_conflicts,row_frame(list(conflict_id='TEST-IDENTITY',run_id='test',review_state='needs_review',country='FI',project_id='P030',claim_id='C042',field='project_id',conflict_summary='Evidence describes the neighbouring site.'),names(t$source_conflicts)))
  result <- account_all(t,read_json(file.path(root,'config/methodology.json')))
  rows <- result$ledger[result$ledger$claim_id=='C042',,drop=FALSE]
  stopifnot(nrow(rows)==4,all(!rows$counted),all(rows$reason=='unresolved_source_identity'),all(is.na(rows$facility_power_mw)))
  t$source_conflicts$review_state[t$source_conflicts$conflict_id=='TEST-IDENTITY'] <- 'superseded'
  cleared <- account_all(t,read_json(file.path(root,'config/methodology.json')))$ledger
  stopifnot(!any(cleared$reason[cleared$claim_id=='C042']=='unresolved_source_identity'))
})
test('reviewed timing changes refresh the legacy year alias in dry run and apply',function() {
  for (year in c('2029','')) {
    f <- fixture(function(t) {
      t <- approve_fixture(t); template <- t$suggested_capacity_updates[t$suggested_capacity_updates$audit_id=='TEST-AC001',,drop=FALSE]
      for(field in c('operation_year_min','operation_year_max')) {
        r <- template; r$audit_id <- paste0('TEST-',field); r$field <- field
        r$current_value <- t$capacity_master[[field]][t$capacity_master$claim_id=='C040']; r$suggested_value <- year
        r$supports_fields <- field; r$original_excerpt <- 'Synthetic timing revision for the scoped claim.'
        t$suggested_capacity_updates <- rbind(t$suggested_capacity_updates,r)
      }; t
    })
    ids <- paste0('TEST-',c('operation_year_min','operation_year_max')); parent <- basename(current_state(f))
    before <- current_state(f)
    promote_rows(f,'audit','capacity',ids,'FI','test-reviewer','test-timing',parent,FALSE)
    stopifnot(current_state(f)==before)
    promote_rows(f,'audit','capacity',ids,'FI','test-reviewer','test-timing',parent,TRUE)
    t <- load_state(current_state(f),schema); stopifnot(t$capacity_master$start_year[t$capacity_master$claim_id=='C040']==year)
  }
})
test('an empty committed subset with evidence gaps is not a complete zero estimate',function() {
  z <- account_all(tables,read_json(file.path(root,'config/methodology.json')))$scenario_zone
  z <- z[z$scenario_id=='low_2030' & z$evidence_gap_claims>0,,drop=FALSE]
  stopifnot(nrow(z)>0,all(!z$capacity_estimate_complete),all(!z$annual_equivalent_complete),all(!z$target_year_energy_complete))
})
test('IT peak and unspecified IT measures cannot inherit a nameplate load factor',function() {
  t <- tables; i <- match('C040',t$capacity_master$claim_id); t$capacity_master$reported_capacity_basis[i] <- 'it_load'
  for(kind in c('peak_demand','available_power','unspecified_capacity')) {
    t$capacity_master$measurement_kind[i] <- kind
    l <- account_all(t,read_json(file.path(root,'config/methodology.json')))$ledger
    r <- l[l$claim_id=='C040' & l$scenario_id=='pipeline_potential',,drop=FALSE]
    stopifnot(r$counted,is.na(r$conditional_mature_annual_twh_low),is.na(r$conditional_mature_annual_twh_high))
    stopifnot(r$energy_status==if(kind=='peak_demand')'load_factor_denominator_mismatch' else 'measurement_kind_not_convertible')
  }
})
cat('\n',passed,' tests passed.\n',sep='')
unlink(scratch,recursive=TRUE)
