/* Display precomputed approved results. No capacity, timing, PUE or scenario model lives here. */
(function (global) {
  'use strict';
  const numeric = value => value === null || value === undefined || value === '' ? null : Number.isFinite(Number(value)) ? Number(value) : null;
  const format = (value, digits = 1) => numeric(value) === null ? 'Unknown' : Number(value).toLocaleString('en-US', { maximumFractionDigits: digits });
  function range(low, high, digits = 1) {
    low = numeric(low); high = numeric(high);
    if (low === null && high === null) return 'Unknown';
    if (high === null) return '≥ ' + format(low, digits);
    if (low === null) return '≤ ' + format(high, digits);
    return low === high ? format(low, digits) : format(low, digits) + '–' + format(high, digits);
  }
  function sumBounds(rows, low, high) {
    const total = key => rows.some(row => numeric(row[key]) === null && row.capacity_known) ? null : rows.reduce((sum, row) => sum + (numeric(row[key]) ?? 0), 0);
    const unknown = rows.filter(row => !row.capacity_known && !['operational', 'cancelled', 'dormant'].includes(row.indicator)).length;
    const known = rows.some(row => numeric(row[low]) !== null && (row.capacity_known || ['operational', 'cancelled', 'dormant'].includes(row.indicator)));
    return { low: !known && unknown ? null : total(low), high: !known && unknown ? null : total(high), unknown };
  }
  function assertContract(data) {
    if (data.scope !== 'manually_approved_projects' || !Array.isArray(data.project_scenarios) || !Array.isArray(data.projects)) throw new Error('Shared scenario result required. Rebuild the tracker data.');
    if (data.projects.some(project => project.record_type !== 'existing') || data.project_scenarios.some(row => !row.included_in_result)) throw new Error('Unapproved project in public result.');
    const keys = data.project_scenarios.map(row => row.project_id + ':' + row.scenario);
    if (new Set(keys).size !== keys.length || keys.length !== data.projects.length * data.method.scenarios.length) throw new Error('Incomplete or duplicate project scenarios.');
    return data;
  }
  const escape = value => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
  const tags = value => String(value || '').split(';').map(tag => tag.trim()).filter(Boolean);
  async function mount(document) {
    const root = document.getElementById('dc-tracker');
    if (!root) return;
    const status = document.getElementById('dc-status');
    try {
      const response = await fetch(root.dataset.results);
      if (!response.ok) throw new Error('Could not load scenario results.');
      const data = assertContract(await response.json());
      const projects = new Map(data.projects.map(project => [project.project_id, project]));
      const sources = new Map(data.sources.map(source => [source.source_id, source]));
      const controls = ['country', 'zone', 'status', 'type', 'scenario'].map(id => document.getElementById(id === 'status' ? 'dc-status-filter' : 'dc-' + id));
      const [country, zone, state, type, scenario] = controls;
      const option = (select, value, text) => { const node = document.createElement('option'); node.value = value; node.textContent = text; select.append(node); };
      function choices(select, values, label) {
        option(select, '', label);
        [...new Set(values.filter(Boolean))].sort().forEach(value => option(select, value, value));
      }
      choices(country, data.projects.map(project => project.country), 'All countries');
      choices(zone, data.project_scenarios.map(row => row.bidding_zone), 'All zones');
      choices(state, data.projects.map(project => project.status), 'All statuses');
      choices(type, data.projects.flatMap(project => tags(project.type)), 'All types');
      data.method.scenarios.forEach(item => option(scenario, item.id, item.label + ' ' + item.year));
      scenario.value = 'stated_2030';
      function filtered() {
        return data.project_scenarios.filter(row => {
          const project = projects.get(row.project_id);
          return row.scenario === scenario.value && (!country.value || project.country === country.value) && (!zone.value || row.bidding_zone === zone.value) && (!state.value || project.status === state.value) && (!type.value || tags(project.type).includes(type.value));
        });
      }
      function evidence(project) {
        const claims = data.capacity.filter(row => row.project_id === project.project_id);
        const refs = new Set([...tags(project.source_ids), ...claims.flatMap(row => tags(row.source_ids))]);
        const list = claims.map(row => '<li><strong>' + escape(row.phase) + '</strong>: ' + escape(row.mw ? row.mw + (row.mw_max ? '–' + row.mw_max : '') + ' MW' : 'MW unknown') + ' (' + escape(row.basis) + '); ' + escape(row.status) + '; scope decision: ' + escape(row.decision) + '. ' + escape(row.notes) + '</li>').join('');
        const links = [...refs].map(id => sources.get(id)).filter(Boolean).map(source => '<li><a href="' + escape(source.url) + '" target="_blank" rel="noopener noreferrer">' + escape(source.title) + '</a></li>').join('');
        return '<p>' + escape(project.notes) + '</p><ul>' + list + '</ul><ul>' + links + '</ul>';
      }
      function render() {
        const rows = filtered();
        const mw = sumBounds(rows, 'mw_low', 'mw_high');
        const energy = sumBounds(rows, 'annual_twh_low', 'annual_twh_high');
        const ram = sumBounds(rows, 'nameplate_mw_low', 'nameplate_mw_high');
        status.textContent = rows.length + ' approved projects · ' + range(mw.low, mw.high) + ' MW deployed · ' + range(energy.low, energy.high, 3) + ' TWh/year · ' + mw.unknown + ' active projects with unknown MW. Totals cover the quantified part.';
        document.getElementById('dc-envelope').textContent = 'Capacity envelope: ' + range(ram.low, ram.high) + ' MW before phasing. Missing dates do not remove this envelope.';
        const tbody = document.getElementById('dc-rows');
        tbody.innerHTML = rows.map(row => {
          const project = projects.get(row.project_id);
          return '<tr data-project="' + escape(project.project_id) + '"><td><details><summary>' + escape(project.project_name) + '</summary>' + evidence(project) + '</details></td><td>' + escape(project.country + ' / ' + row.bidding_zone) + '<br>' + escape(project.municipality) + '</td><td>' + escape(project.status) + '</td><td>' + range(row.nameplate_mw_low, row.nameplate_mw_high) + '</td><td>' + range(row.mw_low, row.mw_high) + '</td><td>' + range(row.annual_twh_low, row.annual_twh_high, 3) + '</td></tr>';
        }).join('');
        renderMap(rows);
      }
      function renderMap(rows) {
        const container = document.getElementById('dc-scenario-map');
        container.replaceChildren();
        const d3 = global.d3;
        if (!d3) { container.textContent = 'Map unavailable. All scenario values remain available in the table.'; return; }
        const width = 760, height = 660;
        const svg = d3.select(container).append('svg').attr('viewBox', '0 0 ' + width + ' ' + height).attr('role', 'img').attr('aria-label', 'Deployed additional datacenter capacity by bidding zone');
        const projection = d3.geoMercator().fitExtent([[30, 25], [width - 30, height - 25]], data.bidding_zones);
        const path = d3.geoPath(projection);
        const color = d3.scaleThreshold().domain([1, 500, 1000, 1500, 2500]).range(['#eef3ff', '#c6dbef', '#9ecae1', '#6baed6', '#3182bd', '#08519c']);
        data.bidding_zones.features.forEach(feature => {
          const selected = rows.filter(row => row.bidding_zone === feature.id);
          const mw = sumBounds(selected, 'mw_low', 'mw_high');
          const shape = svg.append('path').datum(feature).attr('d', path).attr('stroke', '#789').attr('stroke-width', 0.7).attr('fill', mw.high === null ? '#ddd' : color(mw.high));
          shape.append('title').text(feature.id + ': ' + range(mw.low, mw.high) + ' MW; ' + mw.unknown + ' active projects with unknown MW');
          const point = path.centroid(feature);
          if (point.every(Number.isFinite)) svg.append('text').attr('x', point[0]).attr('y', point[1]).attr('text-anchor', 'middle').attr('font-size', 11).attr('paint-order', 'stroke').attr('stroke', 'white').attr('stroke-width', 3).attr('fill', '#172d45').text(feature.id + ' · ' + range(mw.low, mw.high));
        });
        const unassigned = rows.filter(row => row.bidding_zone.endsWith('-unassigned'));
        if (unassigned.length) { const note = document.createElement('p'); const mw = sumBounds(unassigned, 'mw_low', 'mw_high'); note.textContent = 'Unassigned bidding zone: ' + unassigned.length + ' projects, ' + range(mw.low, mw.high) + ' MW; included in table totals.'; container.append(note); }
      }
      controls.forEach(control => control.addEventListener('change', render));
      render();
    } catch (error) { status.textContent = 'Tracker unavailable: ' + error.message; status.setAttribute('role', 'alert'); }
  }
  const api = { numeric, range, sumBounds, assertContract, mount };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (global.document) {
    if (global.document.readyState === 'loading') global.document.addEventListener('DOMContentLoaded', () => mount(global.document));
    else mount(global.document);
  }
})(typeof window === 'undefined' ? globalThis : window);
