const assert = require('node:assert/strict');
const fs = require('node:fs');
const view = require('../assets/js/datacenter-tracker.js');
assert.equal(view.numeric(null), null);
assert.equal(view.numeric(''), null);
assert.equal(view.range(null, null), 'Unknown');
assert.equal(view.range(30, 90), '30–90');
assert.equal(view.range(10, null), '≥ 10');
assert.deepEqual(view.sumBounds([{mw_low:null,mw_high:null,capacity_known:false,indicator:'unquantified'}], 'mw_low','mw_high'), {low:null,high:null,unknown:1});
assert.deepEqual(view.sumBounds([{mw_low:null,mw_high:null,capacity_known:false,indicator:'unquantified'},{mw_low:5,mw_high:20,capacity_known:true,indicator:'pipeline'}], 'mw_low','mw_high'), {low:5,high:20,unknown:1});
assert.equal(view.totalRange({low:1234,high:5678,unknown:0}), '1,230–5,680');
assert.equal(view.totalRange({low:0,high:0,unknown:1}), 'Unknown');
assert.equal(view.totalRange({low:5,high:20,unknown:1}), '5–20*');
const data = view.assertContract(JSON.parse(fs.readFileSync(process.env.TRACKER_RESULTS || 'assets/data/datacenters/results.json', 'utf8')));
for (const zone of data.scenarios) {
  const rows = data.project_scenarios.filter(row => row.scenario === zone.scenario && row.bidding_zone === zone.bidding_zone);
  const mw = view.sumBounds(rows, 'mw_low', 'mw_high');
  const twh = view.sumBounds(rows, 'annual_twh_low', 'annual_twh_high');
  const near = (a,b) => a === null || b === null ? assert.equal(a,b) : assert.ok(Math.abs(a-b) < 1e-8, `${a} != ${b}`);
  near(mw.low, zone.mw_low); near(mw.high, zone.mw_high);
  near(twh.low, zone.annual_twh_low); near(twh.high, zone.annual_twh_high);
  assert.equal(mw.unknown, zone.projects_without_mw + zone.projects_with_unknown_phases);
}
const contaminated = {...data, projects: [...data.projects, {record_type:'candidate'}]};
assert.throws(() => view.assertContract(contaminated), /Unapproved/);
assert.throws(() => view.assertContract({...data,project_scenarios:data.project_scenarios.slice(1)}), /Incomplete/);
assert.throws(() => view.assertContract({...data,actors:[...data.actors,{...data.actors[0],project_id:'P999999'}]}), /Orphaned/);
for (const scenario of data.method.scenarios) {
  const select = filters => view.makeView(data, scenario.id, filters);
  const ids = filters => select(filters).rows.map(row => row.project_id);
  assert.ok(ids({hqCountries:['country:FR'],actorTypes:['ai_compute_provider']}).includes('P010'));
  assert.ok(!ids({hqCountries:['country:FR'],actorTypes:['datacenter_developer_operator']}).includes('P010'), 'Country and type must match the same partner');
  assert.ok(ids({hqCountries:['region:eu_eea'],actorTypes:['datacenter_developer_operator']}).includes('P004'), 'Iceland belongs to EEA');
  assert.equal(ids({hqCountries:['country:US']}).filter(id => id === 'P005').length,1, 'Two matching actors cannot duplicate a project');
  assert.ok(ids({hqOrigins:['unknown']}).includes('P054'), 'Anonymous operator must keep the whole HQ origin incomplete');
  assert.ok(!ids({hqOrigins:['foreign']}).includes('P054'));
  assert.ok(ids({hqCountries:['country:US'],actorTypes:['investment_manager']}).includes('P054'), 'A known landlord HQ remains independently searchable');
  assert.ok(ids({hqOrigins:['mixed']}).includes('P010'));
  const unreviewed = select({countries:['NO'],hqOrigins:['unknown']});
  const incompleteNo = data.projects.filter(project => project.country === 'NO' && project.actor_hq_origin === 'unknown');
  assert.deepEqual(unreviewed.rows.map(row => row.project_id).sort(), incompleteNo.map(row => row.project_id).sort());
  assert.ok(unreviewed.rows.some(row => row.project_id === 'P183'));
  const filtered = select({hqCountries:['region:eu_eea']});
  assert.deepEqual(filtered.totals.mw,view.sumBounds(filtered.rows,'mw_low','mw_high'));
  assert.deepEqual(filtered.totals.twh,view.sumBounds(filtered.rows,'annual_twh_low','annual_twh_high'));
  const customer = select({hqCountries:['country:FR'],actorTypes:['ai_compute_provider']}).rows.find(row => row.project_id === 'P010');
  assert.equal(customer.mw_high,data.project_scenarios.find(row => row.project_id === 'P010' && row.scenario === scenario.id).mw_high, 'Filtering cannot reassign campus capacity to the tenant');
}
for (const scenario of data.method.scenarios) {
  const all = view.makeView(data, scenario.id);
  const sweden = view.makeView(data, scenario.id, {countries:['SE']});
  assert.equal(sweden.rows.length, data.projects.filter(project => project.country === 'SE').length);
  assert.equal(sweden.zones.FI.excluded, true);
  assert.equal(all.zones.FI.excluded, false);
  assert.equal(sweden.countries.NO.excluded, true);
  const se1 = view.makeView(data, scenario.id, {zones:['SE1']});
  assert.ok(se1.rows.every(row => row.bidding_zone === 'SE1'));
  assert.equal(se1.countries.FI.excluded, true);
  assert.equal(se1.countries.SE.excluded, false);
  assert.deepEqual(se1.totals.mw, view.sumBounds(se1.rows,'mw_low','mw_high'));
  const unknown = all.rows.filter(row => !row.capacity_known && row.indicator === 'unquantified');
  assert.ok(unknown.length, 'Unknown-capacity projects must remain visible');
}
assert.equal(view.operationYears([{timing:'grid_availability',first_year:'2028'}]), 'Grid 2028');
assert.equal(view.operationYears([{timing:'unknown',construction_year:'2026'},{timing:'grid_availability',first_year:'2028'}]), 'Construction 2026');
assert.equal(view.operationYears([{timing:'first_capacity',first_year:'2029'},{timing:'unknown',construction_year:'2026'}]), '2029');
assert.equal(view.operationYears([{timing:'first_capacity',first_year:'2027',last_year:'2029'}]), '2027–2029');
assert.equal(view.operationYears([{status:'Operational',timing:'first_capacity',first_year:'2025'},{status:'Planned',timing:'unknown',first_year:''}]), 'Unknown');
assert.equal(view.projectDecision([{status:'Planned',basis:'facility_nameplate',decision:'unclear'}, {status:'Under construction',basis:'it_nameplate',decision:'yes'}]), 'Confirmed for part');
const page = fs.readFileSync('web/datacenter-tracker.md','utf8');
for (const text of ['filter-country-group','filter-zone-group','filter-status-group','filter-type-group','filter-scenario-group','Developer','Investment decision','Announced dates','Last checked','Full build-out (MW)','Full build-out (TWh/yr)','Other Europe','Outside Europe']) assert.ok(page.includes(text), 'Missing tracker control or field: '+text);
assert.ok(!page.includes('Non-EU'));
assert.ok(!page.includes('with no stated upper limit'));
const mapSource = fs.readFileSync('assets/js/datacenter-tracker/scenario-map-d3.js','utf8');
const map = require('../assets/js/datacenter-tracker/scenario-map-d3.js');
assert.equal(view.makeView(data,'stated_2030',{projectIds:[]}).rows.length,0,'An empty HQ selection cannot fall back to every project');
assert.equal(map.capacityLabel({low:0,high:0,unknown:0}),'0 MW');
assert.equal(map.capacityLabel({low:0,high:0,unknown:1}),'Unknown','Unknown contribution is not a known zero');
assert.equal(map.capacityLabel({low:10,high:20,unknown:1}),'10–20 MW*');
assert.equal(map.capacityLabel({low:0,high:0,unknown:0,hq_unreviewed:true}),'—','Missing HQ research is not zero capacity');
const possibleIds=map.mapRows(view.makeView(data,'high_2035'),data).map(row=>row.project_id).sort();
for(const scenario of data.method.scenarios) {
  const base=view.makeView(data,scenario.id);
  const before=JSON.stringify(base);
  assert.deepEqual(map.mapRows(base,data).map(row=>row.project_id).sort(),possibleIds,'Inactive context and positions remain stable between scenarios');
  assert.equal(map.hqView(base,data,'none'),base);
  for(const mode of ['domestic','other_europe','outside_europe']) {
    const expected=base.rows.filter(row=>map.matchesHq(data.projects.find(project=>project.project_id===row.project_id),mode));
    const selected=map.hqView(base,data,mode);
    assert.deepEqual(selected.rows.map(row=>row.project_id),expected.map(row=>row.project_id));
    assert.equal(new Set(selected.rows.map(row=>row.project_id)).size,selected.rows.length,'Several matching actors still count the project once');
    for(const country of ['SE','NO','FI']) {
      const sum=view.sumBounds(expected.filter(row=>row.country===country),'mw_low','mw_high');
      assert.deepEqual({low:selected.countries[country].low,high:selected.countries[country].high,unknown:selected.countries[country].unknown},sum);
    }
    assert.equal(selected.countries.SE.hq_unreviewed,false);
    assert.equal(selected.countries.NO.hq_unreviewed,false);
    assert.equal(selected.countries.FI.hq_unreviewed,false);
    assert.notEqual(map.capacityLabel(selected.zones.FI),'—');
    const tenant=map.hqView(view.makeView(data,scenario.id,{projectIds:['P010']}),data,'other_europe');
    assert.equal(tenant.rows[0].mw_high,base.rows.find(row=>row.project_id==='P010').mw_high,'HQ selection cannot allocate campus capacity to its customer');
    const se3=map.hqView(view.makeView(data,scenario.id,{countries:['SE'],zones:['SE3']}),data,mode);
    assert.ok(se3.rows.every(row=>row.country==='SE'&&row.bidding_zone==='SE3'));
    assert.equal(se3.countries.NO.excluded,true);
  }
  assert.equal(JSON.stringify(base),before,'Map HQ totals cannot mutate the table view');
}
assert.equal(map.mapState({participates:true,indicator:'pipeline'}),'included');
assert.equal(map.mapState({participates:false,indicator:'pipeline',capacity_known:true}),'excluded');
assert.equal(map.mapState({participates:false,indicator:'pipeline',capacity_known:true,partial_capacity:true}),'unknown','A known campus cannot erase an unquantified dated phase');
assert.equal(map.mapState({participates:false,indicator:'unquantified',capacity_known:false}),'unknown','Unknown contribution must not become zero');
assert.equal(map.mapState({participates:true,indicator:'operational'}),'included','Modelled capacity additions at operating sites must remain on the map');
assert.equal(map.mapState({participates:false,indicator:'operational'}),'excluded');
assert.equal(map.mapState({participates:false,indicator:'cancelled'}),'excluded');
for (const scenario of data.method.scenarios) {
  const all=view.makeView(data,scenario.id);
  const knownExcluded=all.rows.filter(row=>row.capacity_known && !row.partial_capacity && !row.participates);
  assert.ok(knownExcluded.every(row=>map.mapState(row)==='excluded'));
  assert.ok(all.rows.filter(row=>row.indicator==='unquantified').every(row=>map.mapState(row)==='unknown'));
  assert.ok(all.rows.filter(row=>row.participates).every(row=>map.mapState(row)==='included'));
}
const project = id => data.projects.find(row => row.project_id === id);
assert.ok(map.matchesHq(project('P010'),'domestic'), 'A Swedish partner can match domestic HQ');
assert.ok(map.matchesHq(project('P010'),'other_europe'));
assert.ok(!map.matchesHq(project('P010'),'outside_europe'), 'A French HQ in Sweden remains European');
assert.ok(map.matchesHq(project('P004'),'other_europe'));
assert.ok(!map.matchesHq(project('P004'),'outside_europe'), 'Iceland is part of the explicit Europe group');
assert.ok(map.matchesHq(project('P054'),'outside_europe'), 'Known property owner can match while operator remains unknown');
assert.ok(!map.matchesHq(project('P183'),'outside_europe'), 'An unknown HQ cannot be classified as outside Europe');
const cluster = {project_count:2, phases:[project('P010'),project('P054')]};
const clusterBefore = JSON.stringify(cluster);
assert.equal(map.highlightGroups([cluster],'other_europe')[0].hq_match_count,1, 'Mixed clusters must count only matching projects');
assert.equal(map.highlightGroups([cluster],'outside_europe')[0].hq_match_count,1);
assert.ok(map.matchesHq({country:'SE',actor_hq_countries:'FR;US',actor_hq_groups:'foreign;europe;other_europe;outside_europe'},'other_europe'));
assert.ok(map.matchesHq({country:'SE',actor_hq_countries:'FR;US',actor_hq_groups:'foreign;europe;other_europe;outside_europe'},'outside_europe'), 'Partnerships can include actors elsewhere in Europe and outside Europe');
assert.equal(map.highlightGroups([cluster],'none')[0].hq_match_count,0);
assert.equal(JSON.stringify(cluster),clusterBefore,'Highlighting cannot mutate project data or scenario results');
const mixedSelection={project_count:3,phases:[{...project('P004'),participates:true},{...project('P010'),participates:true},{...project('P054'),participates:false}]};
assert.equal(map.highlightGroups([mixedSelection],'none')[0].selected_count,2);
assert.equal(map.highlightGroups([mixedSelection],'other_europe')[0].selected_count,2);
assert.equal(map.highlightGroups([mixedSelection],'outside_europe')[0].selected_count,0,'A known HQ cannot activate a project outside the selected scenario');
for (const scenario of data.method.scenarios) {
  const phases=['P060','P061','P062'].map(id=>({...project(id),...data.project_scenarios.find(row=>row.project_id===id && row.scenario===scenario.id)}));
  assert.ok(phases.every(row=>row.indicator==='unquantified' && row.mw_high===null),'Microsoft sites have verified HQ but no quantified new capacity');
  const unknownSelection={project_count:3,phases};
  const before=JSON.stringify(unknownSelection);
  assert.equal(map.highlightGroups([unknownSelection],'outside_europe')[0].selected_count,3,'Missing MW cannot hide a verified HQ match');
  assert.equal(map.highlightGroups([unknownSelection],'other_europe')[0].selected_count,0,'Unknown MW cannot create a match in another HQ group');
  assert.equal(map.highlightGroups([unknownSelection],'none')[0].selected_count,0,'Without an HQ selection, unknown contributions retain their neutral scenario colour');
  assert.equal(JSON.stringify(unknownSelection),before,'Highlighting unknown capacity cannot assign MW or alter scenario participation');
}
for (const id of ['filter-hq-origin-group','filter-hq-country-group','filter-actor-type-group']) assert.ok(!page.includes(id),'HQ highlight must stay out of the table filters');
for (const state of ['scenario-active','scenario-mixed','scenario-inactive']) assert.ok(mapSource.includes(state), 'Missing scenario marker state: '+state);
for (const text of ['projects have unknown capacity','Totals cover the quantified part','no assigned bidding zone','Project locations are approximate']) assert.ok(!mapSource.includes(text), 'Obsolete map note remains: '+text);
const trackerSource = fs.readFileSync('assets/js/datacenter-tracker.js','utf8');
assert.ok(trackerSource.includes('Selected scenario'));
assert.ok(trackerSource.includes('>In campus</span>'));
assert.ok(trackerSource.includes('without assigned capacity'));
assert.ok(!trackerSource.includes('(not counted)'));
for (const text of ['How the tracker is updated','rules-based search routine','documented codebook','Search for new capacity','Reconcile identity, phases and dates','Record what each source actually measures','Calculate and review the scenarios']) assert.ok(page.includes(text), 'Missing workflow section: '+text);
assert.ok(!page.includes('Capacity envelope'));
assert.ok(!page.includes('Max reported MW'));
assert.ok(!page.includes('Reported IT load MW'));
console.log('PASS website contract, unknowns, and exact table/map MW and TWh parity in every scenario and zone');
