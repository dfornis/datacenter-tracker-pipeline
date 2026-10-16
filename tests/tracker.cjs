const assert = require('node:assert/strict');
const fs = require('node:fs');
const view = require('../assets/js/datacenter-tracker.js');
assert.equal(view.numeric(null), null);
assert.equal(view.numeric(''), null);
assert.equal(view.range(null, null), 'Unknown');
assert.equal(view.range(30, 90), '30–90');
assert.equal(view.range(10, null), '≥ 10');
assert.deepEqual(view.sumBounds([{mw_low:null,mw_high:null,capacity_known:false,indicator:'unquantified'}], 'mw_low','mw_high'), {low:null,high:null,unknown:1});
assert.deepEqual(view.sumBounds([{mw_low:10,mw_high:null,capacity_known:true,indicator:'pipeline'}], 'mw_low','mw_high'), {low:10,high:null,unknown:0});
const data = view.assertContract(JSON.parse(fs.readFileSync('assets/data/datacenters/results.json', 'utf8')));
for (const zone of data.scenarios) {
  const rows = data.project_scenarios.filter(row => row.scenario === zone.scenario && row.bidding_zone === zone.bidding_zone);
  const mw = view.sumBounds(rows, 'mw_low', 'mw_high');
  const twh = view.sumBounds(rows, 'annual_twh_low', 'annual_twh_high');
  const near = (a,b) => a === null || b === null ? assert.equal(a,b) : assert.ok(Math.abs(a-b) < 1e-8, `${a} != ${b}`);
  near(mw.low, zone.mw_low); near(mw.high, zone.mw_high);
  near(twh.low, zone.annual_twh_low); near(twh.high, zone.annual_twh_high);
  assert.equal(mw.unknown, zone.projects_without_mw);
}
const contaminated = {...data, projects: [...data.projects, {record_type:'candidate'}]};
assert.throws(() => view.assertContract(contaminated), /Unapproved/);
assert.throws(() => view.assertContract({...data,project_scenarios:data.project_scenarios.slice(1)}), /Incomplete/);
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
assert.equal(view.operationYears([{timing:'grid_availability',first_year:'2028'}]), 'Unknown');
assert.equal(view.operationYears([{timing:'first_capacity',first_year:'2027',last_year:'2029'}]), '2027–2029');
assert.equal(view.operationYears([{status:'Operational',timing:'first_capacity',first_year:'2025'},{status:'Planned',timing:'unknown',first_year:''}]), 'Unknown');
assert.equal(view.projectDecision([{status:'Planned',basis:'facility_nameplate',decision:'unclear'}, {status:'Under construction',basis:'it_nameplate',decision:'yes'}]), 'Confirmed for part');
const page = fs.readFileSync('web/datacenter-tracker.md','utf8');
for (const text of ['filter-country-group','filter-zone-group','filter-status-group','filter-type-group','filter-scenario-group','Developer','Investment decision','Expected operation','Last checked','Planned capacity (MW)']) assert.ok(page.includes(text), 'Missing original tracker control or field: '+text);
assert.ok(!page.includes('Capacity envelope'));
assert.ok(!page.includes('Max reported MW'));
assert.ok(!page.includes('Reported IT load MW'));
console.log('PASS website contract, unknowns, and exact table/map MW and TWh parity in every scenario and zone');
