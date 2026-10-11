source('scripts/model.R')
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
      status='Planned',record_type=if(id=='P099')'candidate' else 'existing',source_ids='S001'))))
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
test('headline MW is preserved; only explicitly IT capacity receives PUE',function() {
  r<-row(calculate(fixture(claim(basis='unspecified'))));same(c(r$nameplate_mw_low,r$nameplate_mw_high),c(100,100))
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
test('energy uses the right denominator and exactly one operational ramp',function() {
  r<-row(calculate(fixture(claim(mw=220,basis='facility_peak'))))
  same(r$counted_mw_low,220/.8);same(r$annual_twh_low,220*.88*8760/1e6)
  r<-row(calculate(fixture(claim(timing='first_capacity',first_year=2027,last_year=2027))),sc='stated_2030')
  same(r$annual_twh_low,100*.8*.57*8760/1e6)
})
test('empty claims and unknown zones retain their project indicators',function() {
  x<-fixture();x$capacity<-x$capacity[FALSE,];x$projects$bidding_zone<-'';r<-calculate(x)
  stopifnot(nrow(r$project_scenarios)==8,all(r$project_scenarios$bidding_zone=='SE-unassigned'),all(is.na(r$project_scenarios$mw_high)))
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
test('complete output is deterministic, includes all projects and leaves source tables intact',function() {
  before<-lapply(c('projects','capacity','sources'),function(n)file_hash(file.path('data',paste0(n,'.csv'))))
  a<-build_result();b<-build_result();stopifnot(identical(a,b),a$coverage$every_project_represented)
  stopifnot(nrow(a$project_scenarios)==nrow(live$projects)*4)
  for(sc in live$config$scenarios)stopifnot(setequal(a$project_scenarios$project_id[a$project_scenarios$scenario==sc$id],live$projects$project_id))
  f<-tempfile(fileext='.json');on.exit(unlink(f));atomic_output(a,f)
  stopifnot(length(json_read(f)$project_scenarios)==nrow(live$projects)*4)
  stopifnot(identical(before,lapply(c('projects','capacity','sources'),function(n)file_hash(file.path('data',paste0(n,'.csv'))))))
})
cat(count,' meaningful method and integration checks passed.\n')
