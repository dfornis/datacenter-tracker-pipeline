source('scripts/pipeline.R')
count<-0
test<-function(name,fn) {fn();count<<-count+1;cat('PASS ',name,'\n',sep='')}
fails<-function(fn,pattern) {
  message<-tryCatch({fn();NULL},error=function(e)conditionMessage(e))
  stopifnot(!is.null(message),grepl(pattern,message,fixed=TRUE))
}
live<-read_inputs()
fixture_row<-function(table,values) {
  d<-as.data.frame(setNames(rep(list(''),length(live$config$tables[[table]])),unlist(live$config$tables[[table]])),stringsAsFactors=FALSE)
  for(k in names(values))d[[k]]<-as.character(values[[k]])
  d
}
claim<-function(id='C001',project='P001',mw=100,basis='facility_nameplate',...) {
  v<-list(claim_id=id,project_id=project,phase='Synthetic scope',mw=mw,basis=basis,qualifier='exact',
    status='Planned',decision='yes',timing='full_capacity',first_year='2030',last_year='2030',
    relation='independent',baseline_scope='new_capacity',source_ids='S001')
  more<-list(...);v[names(more)]<-more;fixture_row('capacity',v)
}
fixture<-function(claims=claim()) {
  p<-do.call(rbind,lapply(unique(c(claims$project_id,'P099')),function(id)
    fixture_row('projects',list(project_id=id,country='SE',bidding_zone='SE3',project_name=paste('Synthetic',id),
      status='Planned',record_type=if(id=='P099')'candidate' else 'existing',source_ids='S001',
      type='hyperscale',municipality='Synthetic',latitude='59.3',longitude='18.0'))))
  list(config=live$config,projects=p,capacity=claims,sources=fixture_row('sources',list(source_id='S001',
    url='https://example.org/synthetic',title='Synthetic fixture, not evidence',kind='summary')))
}
row<-function(r,id='C001',sc='high_2035')r$ledger[r$ledger$claim_id==id & r$ledger$scenario==sc,,drop=FALSE]
project<-function(r,id='P001',sc='high_2035')r$project_scenarios[r$project_scenarios$project_id==id & r$project_scenarios$scenario==sc,,drop=FALSE]
share<-function(r,year)timing_share(r,year,live$config)$share
same<-function(a,b)stopifnot(isTRUE(all.equal(as.numeric(a),as.numeric(b))))

test('the original scenario IDs, names and horizons are preserved',function() {
  stopifnot(identical(vapply(live$config$scenarios,function(s)s$id,''),c('low_2030','stated_2030','stated_2035','high_2035')))
  stopifnot(identical(vapply(live$config$scenarios,function(s)s$label,''),c('Low','Stated','Stated','High')))
  same(vapply(live$config$scenarios,function(s)s$year,0),c(2030,2030,2035,2035))
})
test('default deployment follows the published EPRI five-year ramp exactly',function() {
  r<-claim(timing='first_capacity',first_year='2027',last_year='2027')
  expected<-c(0,.2,.4,.6,.8,1,1)
  for(i in seq_along(expected))same(share(r,2025+i),rep(expected[i],2))
})
test('ramp timing does not change at arbitrary MW or IT/facility thresholds',function() {
  for(mw in c(15,99,100,1000))for(basis in c('it_nameplate','facility_nameplate','unspecified'))
    same(share(claim(mw=mw,basis=basis,timing='first_capacity',first_year=2027,last_year=2027),2030),c(.8,.8))
})
test('construction-only timing uses the sourced two-to-three-year sensitivity',function() {
  r<-claim(timing='unknown',first_year='',last_year='',construction_year=2026)
  same(share(r,2030),c(.4,.6));stopifnot(r$first_year=='',r$last_year=='')
})
test('both endpoints of source timing intervals enter the result',function() {
  r<-claim(timing='first_capacity',first_year=2027,last_year=2029)
  same(share(r,2030),c(.4,.8))
})
test('source-dated full capacity anchors completion, with explicit backcasting beforehand',function() {
  r<-claim();same(share(r,2030),c(1,1));same(share(r,2025),c(0,0));same(share(r,2028),c(.6,.6))
  r$construction_year<-'2028';same(share(r,2029),c(0,0))
  same(share(r,2030),c(1,1)) # A supplied full date overrides generic construction duration.
})
test('grid availability constrains earliest deployment without inventing commissioning',function() {
  r<-claim(timing='grid_availability',first_year=2027,last_year=2027)
  same(share(r,2030),c(0,.8));r$construction_year<-'2029';same(share(r,2030),c(0,0))
})
test('undated capacity remains in the pipeline and High without an invented start year',function() {
  x<-fixture(claim(timing='unknown',first_year='',last_year=''));r<-calculate(x)
  h<-row(r);same(c(h$counted_mw_low,h$counted_mw_high),c(0,100))
  for(sc in live$config$scenarios) same(row(r,sc=sc$id)$nameplate_mw_high,100)
  same(row(r,sc='stated_2030')$counted_mw_high,0)
  stopifnot(grepl('undated_deployment_0_to_1',h$assumptions),project(r)$participates)
})
test('Low uses the decision for the actual scope, without generic maturity percentages',function() {
  x<-fixture(claim(decision='no',status='Permitted',timing='first_capacity',first_year=2027,last_year=2027))
  x$projects$status[1]<-'Under construction';r<-calculate(x)
  same(row(r,sc='low_2030')$counted_mw_high,0)
  same(row(r,sc='stated_2030')$counted_mw_high,80)
  x$capacity$decision<-'yes';same(row(calculate(x),sc='low_2030')$counted_mw_high,80)
})
test('future starts cannot appear as target-year deployment but preserve full pipeline capacity',function() {
  r<-calculate(fixture(claim(timing='first_capacity',first_year=2040,last_year=2040)))
  same(row(r)$counted_mw_high,0);same(row(r)$nameplate_mw_high,100)
})
test('unknown MW remains unknown and all projects appear in each scenario',function() {
  x<-fixture(claim(mw=''));r<-calculate(x)
  stopifnot(nrow(r$project_scenarios)==nrow(x$projects)*length(x$config$scenarios))
  stopifnot(all(is.na(r$project_scenarios$mw_high)),all(is.na(r$project_scenarios$nameplate_mw_high)))
  stopifnot(!any(grepl('review',unlist(x$config$tables))))
})
test('unspecified headline spans facility to IT reading; explicit IT gets PUE; facility MW is kept',function() {
  r<-row(calculate(fixture(claim(basis='unspecified'))));same(c(r$nameplate_mw_low,r$nameplate_mw_high),c(100,150))
  r<-row(calculate(fixture(claim(basis='unspecified',pue='1.2'))));same(c(r$nameplate_mw_low,r$nameplate_mw_high),c(100,120))
  r<-row(calculate(fixture(claim(basis='facility_nameplate'))));same(c(r$nameplate_mw_low,r$nameplate_mw_high),c(100,100))
  r<-row(calculate(fixture(claim(basis='it_nameplate'))));same(c(r$nameplate_mw_low,r$nameplate_mw_high),c(110,150))
  stopifnot(r$reported_mw==100,r$source_basis=='it_nameplate')
})
test('known installed baseline is subtracted in the source basis before PUE',function() {
  x<-fixture(rbind(claim('C001',mw=90,basis='it_nameplate',status='Operational'),
    claim('C002',mw=150,basis='it_nameplate',baseline_scope='existing_known',baseline_id='C001')))
  r<-row(calculate(x),'C002');same(c(r$counted_mw_low,r$counted_mw_high),c(66,90))
  x$capacity$qualifier[1]<-'at_least';same(row(calculate(x),'C002')$counted_mw_low,0)
})
test('unknown baseline retains its envelope while a known new phase anchors the lower case',function() {
  x<-fixture(rbind(claim('C001',mw=1000,baseline_scope='existing_unknown'),
    claim('C002',mw=42,basis='it_nameplate',parent_id='C001',relation='included_in')))
  r<-row(calculate(x));same(c(r$nameplate_mw_low,r$nameplate_mw_high),c(46.2,1000))
  same(c(r$counted_mw_low,r$counted_mw_high),c(46.2,1000))
})
test('tenant and campus form one envelope while both remain visible',function() {
  x<-fixture(rbind(claim(mw=600),claim('C002','P002',23,parent_id='C001',relation='possibly_included_in')))
  r<-calculate(x);same(row(r)$counted_mw_high,600);same(row(r,'C002')$counted_mw_high,0)
  same(project(r,'P002')$nameplate_mw_high,0);stopifnot(project(r,'P002')$participates)
})
test('a known child reaches the zone total even when campus MW is unknown',function() {
  x<-fixture(rbind(claim(mw=''),claim('C002','P002',23,parent_id='C001',relation='included_in')))
  x$projects<-x$projects[x$projects$project_id!='P099',];r<-calculate(x)
  d<-r$scenarios[r$scenarios$scenario=='high_2035' & r$scenarios$bidding_zone=='SE3',]
  same(c(d$mw_high,d$nameplate_mw_high),c(23,23));stopifnot(project(r)$capacity_known,d$scope=='quantified_subset')
})
test('cancelled and operating inventory cannot become new capacity',function() {
  for(status in c('Cancelled','Dormant','Operational')) {
    x<-fixture(claim(status=status));x$projects$status[1]<-status;r<-calculate(x)
    same(c(project(r)$nameplate_mw_high,project(r)$mw_high),c(0,0))
    stopifnot(project(r)$indicator==tolower(status))
  }
})
test('non-load and misattributed claims never fabricate datacenter capacity',function() {
  for(basis in c('backup','generation','density')) {
    r<-calculate(fixture(claim(basis=basis)));stopifnot(!project(r)$capacity_known,is.na(project(r)$mw_high))
  }
  r<-calculate(fixture(claim(issue='identity_conflict')));stopifnot(!project(r)$capacity_known)
})
test('unresolved related identities cannot count as a second campus',function() {
  x<-fixture();x$projects$related_project_id[1]<-'P099';r<-calculate(x)
  same(row(r)$nameplate_mw_high,0);same(row(r)$counted_mw_high,0);stopifnot(row(r)$reason=='related_identity')
})
test('lower-bound-only capacity has no invented upper value, but zero deployment stays zero',function() {
  x<-fixture(claim(qualifier='at_least'));r<-calculate(x)
  stopifnot(is.na(row(r)$nameplate_mw_high),is.na(row(r)$counted_mw_high))
  x$capacity$first_year<-x$capacity$last_year<-'2040';r<-calculate(x)
  same(row(r)$counted_mw_high,0);stopifnot(is.na(row(r)$nameplate_mw_high))
})
test('energy uses the type load factor, the right denominator and exactly one operational ramp',function() {
  # Fixture projects are typed 'hyperscale': EPRI hyperscale 0.75 of nameplate, 0.94 of realised peak.
  r<-row(calculate(fixture(claim(mw=220,basis='facility_peak'))))
  same(r$counted_mw_low,220/.8);same(r$annual_twh_low,220*.94*8760/1e6)
  r<-row(calculate(fixture(claim(timing='first_capacity',first_year=2027,last_year=2027))),sc='stated_2030')
  same(c(r$annual_twh_low,r$annual_twh_high),rep(100*.8*.75*8760/1e6,2))
  x<-fixture();x$projects$type<-'colocation';same(row(calculate(x))$annual_twh_low,100*.57*8760/1e6)
  x$projects$type<-'';r<-row(calculate(x))
  same(c(r$annual_twh_low,r$annual_twh_high),100*c(.57,.75)*8760/1e6)
  stopifnot(grepl('load_factor_range_type_unknown',r$assumptions))
})
test('empty claims and unknown zones retain their project indicators',function() {
  x<-fixture();x$capacity<-x$capacity[FALSE,];x$projects$bidding_zone<-'';r<-calculate(x)
  stopifnot(nrow(r$project_scenarios)==8,all(r$project_scenarios$bidding_zone=='SE-unassigned'),all(is.na(r$project_scenarios$mw_high)))
})
test('a first inventory can start from empty tables while empty final builds still fail',function() {
  x<-fixture();x$projects<-x$projects[FALSE,];x$capacity<-x$capacity[FALSE,];x$sources<-x$sources[FALSE,]
  validate_inputs(x,allow_empty=TRUE)
  fails(function()calculate(x),'Project inventory is empty')
})
test('phased totals stay within the pipeline envelope and grow with horizon/selection',function() {
  r<-calculate(fixture(rbind(claim(timing='first_capacity',first_year=2029,last_year=2031),
    claim('C002','P002',timing='unknown',first_year='',last_year=''))))
  d<-r$scenarios[r$scenarios$bidding_zone=='SE3',]
  stopifnot(all(d$mw_high<=d$nameplate_mw_high),all(diff(d$mw_high)>=0))
})
test('broken identities, quantities, source references and containment stop calculation',function() {
  x<-fixture();x$capacity$project_id<-'P999';fails(function()calculate(x),'Orphaned capacity')
  x<-fixture(claim(mw=-1));fails(function()calculate(x),'Invalid number')
  x<-fixture();x$capacity$source_ids<-'S999';fails(function()calculate(x),'Missing source reference')
  x<-fixture(rbind(claim(parent_id='C002',relation='included_in'),claim('C002',parent_id='C001',relation='included_in')))
  fails(function()calculate(x),'Containment cycle')
  x<-fixture(claim(first_year=2035,last_year=2030));fails(function()calculate(x),'Reversed timing interval')
})
test('all ten map areas are present and invalid geometry identities fail',function() {
  stopifnot(length(assemble_map(live$config)$features)==10)
  cfg<-live$config;cfg$zones[[1]]$id<-'UNKNOWN';fails(function()assemble_map(cfg),'Missing/duplicate map zone')
})
test('MW-bearing project sources without capacity claims are surfaced for automatic follow-up',function() {
  x<-fixture();x$sources$excerpt<-'Planned datacenter: 1 GW.'
  f<-capacity_followups(x)
  stopifnot(length(f)==1,f[[1]]$project_id=='P099',f[[1]]$source_ids[[1]]=='S001')
  for(unit in c('MW','megawatt','megawatts','megawattia','megawatin','gigawatt')) {
    x$sources$excerpt<-paste('250',unit);stopifnot(length(capacity_followups(x))==1)
  }
  x$capacity$issue<-'identity_conflict';stopifnot(length(capacity_followups(x))==2)
  x$sources$excerpt<-'Construction has started.';stopifnot(length(capacity_followups(x))==0)
})
test('an undated MW envelope is reviewed even when its first phase already dates the project',function() {
  x<-fixture(rbind(claim(mw=500,decision='unclear',timing='unknown',first_year='',last_year=''),
    claim('C002',mw='',status='Under construction',timing='first_capacity',first_year=2028,last_year=2028,
      parent_id='C001',relation='included_in')))
  before<-x$capacity;w<-run_worklist(x,'SE')
  stopifnot(length(w$public_projects_without_dates)==0,length(w$capacity_timing_to_reconcile)==1)
  f<-w$capacity_timing_to_reconcile[[1]]
  stopifnot(f$claim_id=='C001',f$undated_capacity$mw=='500',f$dated_claims[[1]]$claim_id=='C002',
    f$dated_claims[[1]]$first_year=='2028',identical(before,x$capacity))
})
test('timing review excludes backup, inactive claims and dates on another project',function() {
  campus<-claim(mw=500,timing='unknown',first_year='',last_year='')
  phase<-claim('C002',mw='',timing='first_capacity',first_year=2028,last_year=2028)
  for(basis in c('backup','generation','density')) {
    r<-phase;r$basis<-basis
    w<-run_worklist(fixture(rbind(campus,r)),'SE')
    stopifnot(length(w$capacity_timing_to_reconcile)==0,'P001' %in% unlist(w$public_projects_without_dates))
  }
  for(status in c('Operational','Cancelled','Dormant')) {
    r<-phase;r$status<-status
    stopifnot(length(run_worklist(fixture(rbind(campus,r)),'SE')$capacity_timing_to_reconcile)==0)
  }
  phase$project_id<-'P002'
  x<-fixture(rbind(campus,phase))
  stopifnot(length(run_worklist(x,'SE')$capacity_timing_to_reconcile)==0,
    length(run_worklist(x,'NO')$capacity_timing_to_reconcile)==0)
})
test('a reviewed first-phase anchor ramps the campus without inheriting its full date or decision',function() {
  x<-fixture(rbind(claim(mw=500,decision='unclear',timing='first_capacity',first_year=2028,last_year=2028),
    claim('C002',mw=24,status='Under construction',timing='full_capacity',first_year=2028,last_year=2028,
      parent_id='C001',relation='included_in')))
  r<-calculate(x)
  same(project(r,sc='low_2030')$mw_high,24)
  same(project(r,sc='stated_2030')$mw_high,300)
  same(project(r,sc='stated_2035')$mw_high,500)
  same(project(r)$mw_high,500)
  stopifnot(x$capacity$decision[1]=='unclear',x$capacity$timing[2]=='full_capacity',
    length(run_worklist(x,'SE')$capacity_timing_to_reconcile)==0)
})
test('complete output is deterministic, includes all projects and leaves source tables intact',function() {
  before<-lapply(c('projects','capacity','sources'),function(n)file_hash(file.path('data',paste0(n,'.csv'))))
  a<-build_result();b<-build_result();stopifnot(identical(a,b),a$coverage$every_project_represented)
  stopifnot(nrow(a$project_scenarios)==nrow(live$projects)*4)
  for(sc in live$config$scenarios)stopifnot(setequal(a$project_scenarios$project_id[a$project_scenarios$scenario==sc$id],live$projects$project_id))
  f<-tempfile(fileext='.json');on.exit(unlink(f));atomic_output(a,f)
  stopifnot(length(json_read(f)$project_scenarios)==nrow(live$projects)*4)
  stopifnot(identical(before,lapply(c('projects','capacity','sources'),function(n)file_hash(file.path('data',paste0(n,'.csv'))))))
})
# Exercise the real workflow against an isolated synthetic repository, never live data.
with_workflow <- function(fn,empty=FALSE) {
  sandbox<-tempfile('datacenter-workflow-test-');dir.create(sandbox)
  root<-file.path(sandbox,'pipeline');dir.create(root)
  on.exit(unlink(sandbox,recursive=TRUE))
  paths<-c('config/pipeline.json','scripts/model.R','scripts/tracker.R','scripts/pipeline.R','renv.lock',
           'assets/js/datacenter-tracker.js','web/datacenter-tracker.md','web/build_datacenter_data.R',
           'prompts/update.md','AGENTS.md','README.md',unique(vapply(live$config$zones,function(z)z$geometry,'')))
  for(f in paths) {
    target<-file.path(root,f);dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
    stopifnot(file.copy(f,target))
  }
  x<-fixture()
  if(empty)for(n in names(x$config$tables))x[[n]]<-x[[n]][FALSE,,drop=FALSE]
  write_tables(x,file.path(root,'data'))
  fn(root,file.path(root,'work'))
}
test('prepare retains split timing evidence and the reviewed anchor survives check and apply',function() {
  with_workflow(function(root,work) {
    x<-fixture(rbind(claim(mw=500,decision='unclear',timing='unknown',first_year='',last_year=''),
      claim('C002',mw='',status='Under construction',timing='first_capacity',first_year=2028,last_year=2028,
        parent_id='C001',relation='included_in')))
    write_tables(x,file.path(root,'data'));prepare_run(root,work,country='SE')
    w<-json_read(file.path(work,'packet.json'))$worklist
    stopifnot(length(w$capacity_timing_to_reconcile)==1,w$capacity_timing_to_reconcile[[1]]$claim_id=='C001')
    x<-read_inputs(root,work);x$capacity$first_year[1]<-x$capacity$last_year[1]<-'2028'
    x$capacity$timing[1]<-'first_capacity';write_tables(x,work)
    stopifnot(length(run_worklist(read_inputs(root,work),'SE')$capacity_timing_to_reconcile)==0)
    review_run(root,work);r<-apply_run(root,work)$result
    same(project(r,sc='stated_2030')$mw_high,300)
    same(project(r,sc='low_2030')$mw_high,0)
    stopifnot(read_inputs(root)$capacity$decision[1]=='unclear')
  })
})
test('empty first installation reaches applied output with quantified and unquantified projects',function() {
  with_workflow(function(root,work) {
    prepare_run(root,work,mode='scratch')
    packet<-json_read(file.path(work,'packet.json'))
    stopifnot(setequal(unlist(packet$countries),c('SE','NO','FI')),length(packet$projects)==0,
      packet$id_above$sources==143,length(list.files(work))==4)
    x<-fixture(claim('C048','P053',timing='unknown',first_year='',last_year=''))
    x$projects$project_id[x$projects$project_id=='P099']<-'P054'
    x$projects$record_type<-'candidate'
    x$projects$source_ids<-x$capacity$source_ids<-'S144';x$sources$source_id<-'S144'
    write_tables(x,work);r<-apply_run(root,work)$result
    stopifnot(r$coverage$projects==2,r$coverage$scenario_rows==8,
      json_read(file.path(root,'assets/datacenters.json'))$inventory_run$mode=='scratch')
    same(project(r,'P053')$nameplate_mw_high,0)
    same(project(r,'P053')$mw_high,0)
    same(project(r,'P053',sc='stated_2035')$mw_high,0)
    stopifnot(is.na(project(r,'P054')$mw_high),identical(r$input_hashes,input_hashes(root)))
  },empty=TRUE)
})
test('refresh follows the same path, preserves undated capacity, and applies all three tables',function() {
  with_workflow(function(root,work) {
    prepare_run(root,work);x<-read_inputs(root,work)
    x$capacity$mw<-'150';x$capacity<-rbind(x$capacity,claim('C048','P099',200,timing='unknown',first_year='',last_year=''))
    write_tables(x,work);review<-review_run(root,work)
    stopifnot(identical(unlist(review$changes$capacity$changed),'C001'))
    r<-apply_run(root,work)$result
    same(project(r,'P099')$nameplate_mw_high,0)
    for(n in names(x$config$tables))stopifnot(identical(read_inputs(root)[[n]],x[[n]]))
    stopifnot(!dir.exists(file.path(root,'.locks/pipeline')))
  })
})
test('scratch retains the old identity context and requires reconciliation before replacing data',function() {
  with_workflow(function(root,work) {
    prepare_run(root,work,mode='scratch');packet<-json_read(file.path(work,'packet.json'))
    stopifnot(nrow(read_inputs(root,work)$projects)==0,length(packet$projects)==2,length(packet$identity_index)==2)
    x<-read_inputs(root);x$projects<-x$projects[x$projects$project_id!='P099',];write_tables(x,work)
    fails(function()review_run(root,work),'Rows disappeared from projects')
    write_tables(read_inputs(root),work);apply_run(root,work)
    stopifnot(nrow(read_inputs(root)$projects)==2)
  })
})
test('country packets restore local languages and source routes while retaining a global identity index',function() {
  with_workflow(function(root,work) {
    x<-read_inputs(root);p<-x$projects[2,];p$project_id<-'P100';p$country<-'FI';p$bidding_zone<-'FI'
    x$projects<-rbind(x$projects,p);write_tables(x,file.path(root,'data'))
    prepare_run(root,work,country='FI');packet<-json_read(file.path(work,'packet.json'))
    stopifnot(length(packet$projects)==1,length(packet$identity_index)==3,
      setequal(unlist(packet$method$countries$FI$languages),c('fi','sv','en')),
      length(packet$method$workflow$discovery_routes)==5)
    for(country in names(packet$method$countries)) {
      profile<-packet$method$countries[[country]]
      stopifnot(all(unlist(profile$languages) %in% names(profile$search_terms)),length(profile$capacity_terms)==4,
        length(profile$source_routes)>0)
    }
    x<-read_inputs(root,work);x$projects$notes[1]<-'Outside-country edit';write_tables(x,work)
    fails(function()review_run(root,work),'Changes outside selected countries')
    write_tables(read_inputs(root),work);x<-read_inputs(root,work)
    extra<-x$projects[1,];extra$project_id<-'P101';x$projects<-rbind(x$projects,extra);write_tables(x,work)
    fails(function()review_run(root,work),'New project outside selected countries')
  })
})
test('lost claims and reused historical IDs cannot silently replace a prepared register',function() {
  with_workflow(function(root,work) {
    prepare_run(root,work);x<-read_inputs(root,work);x$capacity<-x$capacity[FALSE,];write_tables(x,work)
    fails(function()review_run(root,work),'Rows disappeared from capacity')
    x<-read_inputs(root);x$capacity<-rbind(x$capacity,claim('C047','P099'));write_tables(x,work)
    fails(function()review_run(root,work),'Reused historical ID')
    x<-read_inputs(root);x$capacity$project_id<-'P099';write_tables(x,work)
    fails(function()review_run(root,work),'Existing claim reassigned')
  })
})
test('changed instructions or live data invalidate prepared work without overwriting anything',function() {
  for(change in c('prompt','data'))with_workflow(function(root,work) {
    prepare_run(root,work)
    if(change=='prompt')cat('Changed instruction',file=file.path(root,'prompts/update.md'),append=TRUE)
    else {x<-read_inputs(root);x$projects$notes[1]<-'Concurrent edit';write_tables(x,file.path(root,'data'))}
    before<-input_hashes(root)
    fails(function()apply_run(root,work),'Register or instructions changed')
    stopifnot(identical(before,input_hashes(root)),!file.exists(file.path(root,'assets/datacenters.json')))
  })
})
test('an installation error restores the original tables and removes its writer lock',function() {
  with_workflow(function(root,work) {
    prepare_run(root,work);x<-read_inputs(root,work);x$capacity$mw<-'999';write_tables(x,work)
    before<-input_hashes(root);cat('Not a directory',file=file.path(root,'blocked'))
    suppressWarnings(fails(function()apply_run(root,work,file.path(root,'blocked/result.json')),'Could not install'))
    stopifnot(identical(before,input_hashes(root)),!dir.exists(file.path(root,'.locks/pipeline')))
  })
})
test('the command interface executes prepare, check and apply in an isolated repository',function() {
  with_workflow(function(root,work) {
    previous<-getwd();setwd(root);on.exit(setwd(previous))
    invisible(capture.output(pipeline_main(c('prepare','--country=SE',paste0('--output=',work)))))
    invisible(capture.output(pipeline_main(c('check',paste0('--data=',work)))))
    invisible(capture.output(pipeline_main(c('apply',paste0('--data=',work)))))
    stopifnot(file.exists('assets/datacenters.json'))
    fails(function()pipeline_main(c('build','--country=FI')),'Unknown option')
    fails(function()pipeline_main(c('apply')),'apply needs')
    fails(function()pipeline_main(c('build','--output=config/pipeline.json')),'overwrite an input')
  })
})
test('website export is a filtered view of the approved model including all approved indicators',function() {
  r<-build_result();t<-build_tracker(result=r);p<-read_inputs()$projects
  stopifnot(setequal(t$projects$project_id,p$project_id[p$record_type=='existing']),
    identical(t$results$project_scenarios,r$project_scenarios[r$project_scenarios$record_type=='existing',,drop=FALSE]),
    identical(t$results$scope,'manually_approved_projects'),all(t$results$project_scenarios$included_in_result),
    length(t$bidding_zones$features)==10,nrow(t$scenario_zone)==52)
  same(t$scenario_zone$mw_low,r$scenarios$mw_low)
  same(t$scenario_zone$mw_high,r$scenarios$mw_high)
  same(t$scenario_zone$annual_twh_high,r$scenarios$annual_twh_high)
})
test('pending candidates cannot affect approved totals but retain all scenario indicators',function() {
  x<-fixture(rbind(claim(mw=100),claim('C002','P099',500)))
  r<-calculate(x,approved_only=TRUE)
  same(project(r,'P099')$mw_high,0)
  stopifnot(!project(r,'P099')$included_in_result,nrow(r$project_scenarios)==8)
  same(sum(r$scenarios$mw_high[r$scenarios$scenario=='high_2035']),100)
  x$projects$record_type[x$projects$project_id=='P099']<-'existing'
  r<-calculate(x,approved_only=TRUE)
  same(sum(r$scenarios$mw_high[r$scenarios$scenario=='high_2035']),600)
})
test('an approved tenant survives a pending campus without importing its unapproved envelope',function() {
  x<-fixture(rbind(claim(mw=600),claim('C002','P002',23,parent_id='C001',relation='included_in')))
  x$projects$record_type[x$projects$project_id=='P001']<-'candidate'
  r<-calculate(x,approved_only=TRUE)
  same(project(r,'P002')$mw_high,23);same(project(r,'P001')$mw_high,0)
  same(sum(r$scenarios$mw_high[r$scenarios$scenario=='high_2035']),23)
  x$projects$record_type[x$projects$project_id=='P001']<-'existing'
  r<-calculate(x,approved_only=TRUE)
  same(project(r,'P001')$mw_high,600);same(project(r,'P002')$mw_high,0)
})
test('a pending tenant cannot raise an approved campus through containment',function() {
  x<-fixture(rbind(claim(mw=10),claim('C002','P099',23,parent_id='C001',relation='included_in')))
  r<-calculate(x,approved_only=TRUE)
  same(project(r)$mw_high,10)
})
test('pending MW cannot turn an unknown approved campus into known zero',function() {
  x<-fixture(rbind(claim(mw=''),claim('C002','P099',50,parent_id='C001',relation='included_in')))
  r<-calculate(x)
  for(sc in x$config$scenarios) {
    p<-project(r,sc=sc$id)
    stopifnot(!p$capacity_known,is.na(p$mw_high),is.na(p$nameplate_mw_high),
      r$scenarios$projects_without_mw[r$scenarios$scenario==sc$id & r$scenarios$bidding_zone=='SE3']==1)
  }
  x$projects$record_type[x$projects$project_id=='P099']<-'existing'
  r<-calculate(x);same(project(r)$mw_high,50);stopifnot(project(r)$capacity_known)
})
test('known approved capacity reaches an unknown approved owner under a pending campus',function() {
  x<-fixture(rbind(claim(project='P099',mw=600),
    claim('C002','P001',mw='',parent_id='C001',relation='included_in'),
    claim('C003','P002',23,parent_id='C001',relation='included_in')))
  r<-calculate(x)
  same(project(r)$mw_high,23);stopifnot(project(r)$capacity_known)
  same(sum(r$scenarios$mw_high[r$scenarios$scenario=='high_2035']),23)
})
test('inventory apply cannot approve candidates or introduce preapproved new projects',function() {
  with_workflow(function(root,work) {
    prepare_run(root,work);x<-read_inputs(root,work)
    x$projects$record_type[x$projects$project_id=='P099']<-'existing';write_tables(x,work)
    fails(function()apply_run(root,work),'Manual chat approval required')
    x<-read_inputs(root,work);p<-x$projects[1,];p$project_id<-'P100';x$projects<-rbind(read_inputs(root)$projects,p)
    write_tables(x,work);fails(function()apply_run(root,work),'Manual chat approval required')
  })
})
test('inventory cannot revoke approval while factual construction status can change',function() {
  with_workflow(function(root,work) {
    prepare_run(root,work);before<-input_hashes(root);x<-read_inputs(root,work)
    x$projects$record_type[x$projects$project_id=='P001']<-'candidate';write_tables(x,work)
    fails(function()apply_run(root,work),'cannot revoke manual approval')
    stopifnot(identical(before,input_hashes(root)))
    x$projects$record_type[x$projects$project_id=='P001']<-'existing'
    x$projects$status[x$projects$project_id=='P001']<-'Cancelled';write_tables(x,work)
    r<-apply_run(root,work)$result
    stopifnot(project(r)$included_in_result,project(r)$indicator=='cancelled')
    same(project(r)$mw_high,0)
  })
})
test('manual approval uses a fresh review and rebuilds exactly the selected candidates with shared MW',function() {
  with_workflow(function(root,work) {
    x<-read_inputs(root);x$capacity<-rbind(x$capacity,claim('C048','P099',500,timing='first_capacity',first_year=2028,last_year=2028))
    write_tables(x,file.path(root,'data'))
    before<-input_hashes(root);review<-review_candidates(root,'SE')
    stopifnot(identical(before,input_hashes(root)),length(review$candidates)==1)
    same(review$candidates[[1]]$delta_if_approved$mw_high,c(300,300,500,500))
    f<-file.path(root,'review.json');atomic_output(review,f)
    fails(function()approve_candidates(root,'P404',f),'IDs were not candidates')
    r<-approve_candidates(root,'P099',f)
    stopifnot(all(read_inputs(root)$projects$record_type=='existing'),
      identical(r$capacity,x$capacity),nrow(r$project_scenarios)==8)
    same(project(r,'P099',sc='stated_2030')$mw_high,300)
    pub<-json_read(file.path(root,'assets/data/datacenters/results.json'))
    stopifnot(length(pub$projects)==2,length(pub$project_scenarios)==8)
    fails(function()approve_candidates(root,'P099',f),'stale or invalid')
  })
})
test('manual review retains unknown MW and approvals with unknown geography remain visible',function() {
  with_workflow(function(root,work) {
    x<-read_inputs(root);i<-x$projects$project_id=='P099'
    x$projects$bidding_zone[i]<-x$projects$latitude[i]<-x$projects$longitude[i]<-x$projects$type[i]<-''
    write_tables(x,file.path(root,'data'));review<-review_candidates(root,'SE')
    stopifnot(all(is.na(review$candidates[[1]]$project_scenarios$mw_high)))
    f<-file.path(root,'review.json');atomic_output(review,f);r<-approve_candidates(root,'P099',f)
    stopifnot(project(r,'P099')$bidding_zone=='SE-unassigned',is.na(project(r,'P099')$mw_high),
      nrow(build_tracker(root,result=r)$projects)==2)
  })
})
test('an error replacing site data rolls back register, analysis and all previously installed outputs',function() {
  with_workflow(function(root,work) {
    rebuild_run(root);before<-input_hashes(root)
    analysis<-readBin(file.path(root,'assets/datacenters.json'),'raw',n=file.info(file.path(root,'assets/datacenters.json'))$size)
    prepare_run(root,work);x<-read_inputs(root,work);x$capacity$mw<-'999';write_tables(x,work)
    # Force a later output replacement to fail, after the register and analysis were installed.
    target<-file.path(root,'assets/data/datacenters/scenario_zone.json');unlink(target);dir.create(target)
    failures<-suppressWarnings(tryCatch(apply_run(root,work),error=function(e)e))
    stopifnot(inherits(failures,'error'),identical(before,input_hashes(root)),
      identical(analysis,readBin(file.path(root,'assets/datacenters.json'),'raw',n=length(analysis))),!dir.exists(file.path(root,'.locks/pipeline')))
  })
})
test('local site installation replaces its calculation with the shared presentation and compatibility entry point',function() {
  with_workflow(function(root,work) {
    rebuild_run(root);site<-file.path(root,'site');dir.create(site);writeLines('title: Synthetic site',file.path(site,'_config.yml'))
    install_site(root,site)
    stopifnot(file.exists(file.path(site,'assets/data/datacenters/results.json')),
      identical(readLines(file.path(site,'_projects/datacenter-tracker.md')),readLines('web/datacenter-tracker.md')),
      any(grepl('pipeline.R',readLines(file.path(site,'scripts/build_datacenter_data.R')),fixed=TRUE)))
  })
})
test('preview commands cannot replace active results, inputs or the work packet',function() {
  with_workflow(function(root,work) {
    previous<-getwd();setwd(root);on.exit(setwd(previous))
    rebuild_run();prepare_run(path=work,country='SE')
    x<-read_inputs('.',work);x$capacity$mw<-'999';write_tables(x,work)
    files<-c('assets/datacenters.json',list.files('assets/data/datacenters',full.names=TRUE))
    before<-vapply(files,file_hash,'')
    fails(function()pipeline_main(c('build',paste0('--data=',work))),'requires --output')
    fails(function()pipeline_main(c('tracker',paste0('--data=',work))),'requires --output-dir')
    for(cmd in c('build','packet','review'))
      fails(function()pipeline_main(c(cmd,'--output=assets/datacenters.json')),'Preview cannot overwrite')
    fails(function()pipeline_main(c('tracker','--output-dir=assets/data/datacenters')),'Preview cannot overwrite')
    fails(function()pipeline_main(c('build',paste0('--data=',work),paste0('--output=',work,'/packet.json'))),'work packet')
    fails(function()pipeline_main(c('apply',paste0('--data=',work),'--output=assets/data/datacenters/results.json')),'Preview cannot overwrite')
    stopifnot(file.symlink(normalizePath('assets/data/datacenters'),'alias'))
    fails(function()pipeline_main(c('tracker','--output-dir=alias')),'Preview cannot overwrite')
    dir.create('preview');stopifnot(file.symlink(normalizePath('assets/datacenters.json'),'preview/results.json'))
    fails(function()pipeline_main(c('tracker','--output-dir=preview')),'Preview cannot overwrite')
    fails(function()pipeline_main(c('build','--output=assets/new/../datacenters.json')),'Preview cannot overwrite')
    invisible(capture.output(pipeline_main(c('build',paste0('--data=',work),'--output=preview/analysis.json'))))
    invisible(capture.output(pipeline_main(c('tracker',paste0('--data=',work),'--output-dir=preview/tracker'))))
    stopifnot(identical(before,vapply(files,file_hash,'')))
    check_outputs()
  })
})
test('check rejects stale or altered saved outputs even when the register is valid',function() {
  with_workflow(function(root,work) {
    rebuild_run(root);check_outputs(root)
    f<-file.path(root,'assets/datacenters.json');r<-json_read(f);r$project_scenarios[[1]]$mw_high<-999
    atomic_output(r,f);fails(function()check_outputs(root),'Saved outputs are missing or stale')
    rebuild_run(root);f<-file.path(root,'assets/data/datacenters/scenario_zone.json');writeLines('[]',f)
    fails(function()check_outputs(root),'Saved outputs are missing or stale')
    rebuild_run(root);unlink(file.path(root,'assets/data/datacenters/capacity.json'))
    fails(function()check_outputs(root),'Saved outputs are missing or stale')
    rebuild_run(root);x<-read_inputs(root);x$capacity$mw<-'120';write_tables(x,file.path(root,'data'))
    fails(function()check_outputs(root),'Saved outputs are missing or stale')
  })
})
test('an optional apply export cannot leave the canonical analysis behind',function() {
  with_workflow(function(root,work) {
    rebuild_run(root);prepare_run(root,work);x<-read_inputs(root,work);x$capacity$mw<-'120';write_tables(x,work)
    extra<-file.path(root,'extra.json');apply_run(root,work,output=extra)
    stopifnot(file_hash(extra)==file_hash(file.path(root,'assets/datacenters.json')))
    check_outputs(root)
  })
})
test('the standard CLI keeps inventory, manual approval and the sibling site together',function() {
  with_workflow(function(root,work) {
    site<-file.path(dirname(root),'dfornis.github.io');dir.create(site);writeLines('title: Synthetic site',file.path(site,'_config.yml'))
    x<-read_inputs(root);x$capacity<-rbind(x$capacity,claim('C048','P099',50));write_tables(x,file.path(root,'data'))
    previous<-getwd();setwd(root);on.exit(setwd(previous))
    run<-function(args)invisible(capture.output(pipeline_main(args)))
    run('build');run(c('prepare','--country=SE',paste0('--output=',work)))
    x<-read_inputs('.',work);x$capacity$mw[x$capacity$claim_id=='C001']<-'120';write_tables(x,work)
    run(c('check',paste0('--data=',work)));run(c('apply',paste0('--data=',work),'--output=extra.json'))
    run(c('review','--country=SE','--output=review.json'))
    stopifnot(read_inputs()$projects$record_type[2]=='candidate')
    run(c('approve','--ids=P099','--review=review.json'));run('check')
    result<-build_result();same(result_totals(result,'SE')$mw_high,rep(170,4))
    stopifnot(file_hash('assets/data/datacenters/results.json')==file_hash(file.path(site,'assets/data/datacenters/results.json')))
    writeLines('[]',file.path(site,'assets/data/datacenters/results.json'))
    fails(function()pipeline_main('check'),'Saved outputs are missing or stale')
    run('tracker');run('check')
  })
})
test('a failed sibling site update restores register, analysis and site outputs together',function() {
  with_workflow(function(root,work) {
    site<-file.path(dirname(root),'dfornis.github.io');dir.create(site);writeLines('title: Synthetic site',file.path(site,'_config.yml'))
    rebuild_run(root);prepare_run(root,work);x<-read_inputs(root,work);x$capacity$mw<-'999';write_tables(x,work)
    target<-file.path(site,'assets/data/datacenters/scenario_zone.json')
    files<-c(file.path(root,'data',table_files(x$config)),file.path(root,'assets/datacenters.json'),
      list.files(file.path(root,'assets/data/datacenters'),full.names=TRUE),list.files(file.path(site,'assets/data/datacenters'),full.names=TRUE))
    before<-vapply(files,file_hash,'')
    # Fail after the new register, analysis and earlier site files have actually been installed.
    original_install<-install_file;failed<-FALSE
    assign('install_file',function(from,to) {
      if(!failed && path_id(to)==path_id(target)) {failed<<-TRUE;stop('Synthetic site write failure')}
      original_install(from,to)
    },envir=.GlobalEnv)
    on.exit(assign('install_file',original_install,envir=.GlobalEnv))
    fails(function()apply_run(root,work),'Synthetic site write failure')
    stopifnot(failed,identical(before,vapply(files,file_hash,'')),!dir.exists(file.path(root,'.locks/pipeline')))
  })
})
cat(count,' meaningful method and workflow checks passed.\n')
