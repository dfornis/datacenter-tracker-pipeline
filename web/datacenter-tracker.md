---
layout: page
title: Nordic datacenter tracker
description: Public project evidence and phased capacity scenarios for Nordic datacenters.
hide_description: true
img: /assets/images/project-sketches/datacenter-tracker.png
permalink: /projects/datacenter-tracker/
---

This tracker shows manually reviewed datacenter projects in Sweden, Norway and Finland. Sources describe capacity, phases, timing and construction status. New candidates are reviewed with their MW impact and approved manually before entering these results. Corrections and source suggestions are welcome at <fornborg@kth.se>.

**Capacity envelope (MW)** is the additional facility capacity before phasing, after accounting for existing operation and overlaps. It remains visible when dates are unknown. **Deployed MW** is the share modelled by the selected year, including cooling and other facility electricity use. **TWh/year** is a year-equivalent at that deployment level, not consumption during the commissioning year. Unknown MW remains unknown; quantified totals do not establish complete market coverage.

<div id="dc-tracker" data-results="{{ '/assets/data/datacenters/results.json' | relative_url }}?v=3.3">
  <div class="dc-controls" aria-label="Filter approved projects">
    <label>Country <select id="dc-country"></select></label>
    <label>Bidding zone <select id="dc-zone"></select></label>
    <label>Status <select id="dc-status-filter"></select></label>
    <label>Type <select id="dc-type"></select></label>
    <label>Scenario <select id="dc-scenario"></select></label>
  </div>
  <p id="dc-status" role="status" aria-live="polite">Loading approved scenario results…</p>
  <p id="dc-envelope"></p>
  <div class="dc-table-wrap">
    <table class="dc-table">
      <thead><tr><th>Project and sources</th><th>Location</th><th>Construction status</th><th>Capacity envelope (MW)</th><th>Deployed MW</th><th>TWh/year</th></tr></thead>
      <tbody id="dc-rows"></tbody>
    </table>
  </div>
  <h2>Scenario map</h2>
  <p>The map follows the same filters and precomputed project results as the table. Labels show the full MW range; colour represents its upper bound. Grey indicates an unknown upper bound. Projects without a known bidding zone remain in the table totals.</p>
  <div id="dc-scenario-map"></div>
</div>

## Scenarios and deployment

| Scenario | Included capacity |
| --- | --- |
| Low 2030 | Capacity with a scoped implementation decision and timing anchor, phased to 2030. |
| Stated 2030 | Capacity with a timing anchor, phased to 2030. |
| Stated 2035 | The same selection, phased to 2035. |
| High 2035 | Active capacity, including undated plans; timing uncertainty remains a range. |

The default deployment ramp is 20, 40, 60, 80 and 100 percent from first operation. Construction-only evidence uses a 2–3 year construction period before that ramp. Explicit full-capacity dates apply to their documented scope; a first phase does not commit the whole campus. Undated capacity remains in the envelope and High. These are conditional scenarios, not probability forecasts or connection guarantees.

The same model supplies this page and the project review. Original source MW and construction status are preserved in the expandable project evidence. IT capacity is converted to facility capacity with a PUE sensitivity; ambiguous headline MW retains both facility and IT interpretations. Backup generation and electricity production do not become datacenter load. Tenant/campus overlaps are counted once and comparable existing operation is deducted before conversion.

Deployment follows the modelling assumption in [EPRI (2026)](https://powering-intelligence.epri.com/annual-peak-use.html), with the construction sensitivity informed by [IEA (2025)](https://www.iea.org/reports/energy-and-ai/energy-demand-from-ai). Annual use uses type-specific factors from the same model configuration. The assumptions and their limits are documented with the register; they are not measurements of individual Nordic facilities.

<style>
.dc-controls { display:flex; flex-wrap:wrap; gap:1rem; margin:1.5rem 0; }
.dc-controls label { display:flex; flex-direction:column; gap:.3rem; font-size:.85rem; }
.dc-controls select { max-width:250px; padding:.35rem; color:var(--global-text-color); background:var(--global-bg-color); border:1px solid #888; border-radius:4px; }
.dc-table-wrap { overflow-x:auto; }
.dc-table { width:100%; border-collapse:collapse; font-size:.85rem; }
.dc-table th,.dc-table td { padding:.65rem; vertical-align:top; border-bottom:1px solid #8886; }
.dc-table th:nth-child(n+4),.dc-table td:nth-child(n+4) { text-align:right; white-space:nowrap; }
.dc-table summary { cursor:pointer; min-width:200px; font-weight:600; }
.dc-table details[open] { min-width:300px; max-width:520px; }
.dc-table details p,.dc-table details ul { margin:.7rem 0; font-size:.8rem; }
#dc-scenario-map svg { max-width:100%; width:760px; height:auto; }
</style>
<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
<script src="{{ '/assets/js/datacenter-tracker.js' | relative_url }}?v=3.3" defer></script>
