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
console.log('PASS website contract, unknowns, and exact table/map MW and TWh parity in every scenario and zone');
