# Audit prompt: existing Swedish data centre projects

You are auditing a Swedish data centre tracker used for academic research.

## Input files

Use the following files:

- `data/master/projects_master.csv`
- `data/master/capacity_master.csv`
- `data/master/sources_master.csv`
- `docs/status_rules.md`
- `docs/schema.md`

Use `docs/schema.md` as the authoritative definition of master files, audit output files, column names, and allowed audit structure. Preserve the established audit-column naming, including `audit_id`, `field`, `current_value`, `suggested_value`, and `claim_id`. Do not invent alternative filenames or column names.

## Scope

This task audits existing tracker records. It is conservative by design.

Do not modify master files. Do not directly edit generated tracker files. Write only to the audit output files defined in `docs/schema.md`.

Do not add new projects or phases directly to master files.

Do not run discovery inside this audit. Do not write to `data/audit/new_project_candidates.csv` unless the user explicitly asks for discovery in the same task. If a source found during audit appears to describe a different project, only mention it in the final report or record an identity/duplication issue in `source_conflicts.csv` when it affects an existing master row.

Do not treat GPU purchases, customer deployments, cloud launches, or equipment orders inside an existing data centre as new projects. They are relevant only if the source identifies a new site, phase, expansion, or capacity claim with site-specific evidence.

## Main task

For each existing project and capacity row:

1. First validate current values against registered sources in `sources_master.csv`.
2. Then search for newer public sources only to identify updates, corrections, cancellations, changed timelines, changed developer ownership, changed capacity claims, changed status, or stronger/weaker evidence for investment decisions.
3. Check whether current values are still supported for:
   - `developer`
   - `municipality`
   - `bidding_zone`
   - `project_status`
   - project-level `investment_decision`
   - `reported_capacity_mw`
   - `interpreted_it_load_mw`
   - `capacity_type`
   - `capacity_status`
   - capacity-level `investment_decision`
   - `start_year`
   - `construction_start_year`
   - `reported_capacity_basis`
   - `scenario_tag`, using `docs/status_rules.md` rather than preserving old tags by default
4. Cross-check project-level values against capacity-level values using the project-to-capacity consistency rules in `docs/status_rules.md`.
5. Check that each project is one physical site in one bidding zone. If a row or candidate source spans multiple bidding zones, do not preserve or create it as one project.
6. Write proposed field-level changes only when the proposed value differs from the current master value.
7. Record unresolved contradictions in `data/audit/source_conflicts.csv`.
8. Record inaccessible, redirected, blocked, paywalled, or otherwise problematic registered URLs in `data/audit/dead_links.csv`.

## Evidence hierarchy

When sources disagree, prefer primary or near-primary sources in this order:

1. Official company statements, annual reports, investor releases, or project pages.
2. Planning, permitting, environmental review, or court documents.
3. Grid connection, electricity network, or energy authority documents.
4. Municipal or regional documents.
5. Reputable trade press.
6. Local news.
7. Secondary summaries, databases, or reposted material.

Do not automatically prefer a newer source if it is weaker, derivative, vague, or merely repeats an older claim. Use `source_conflicts.csv` when the best interpretation remains uncertain.

## Investment-decision sanity check

Treat `investment_decision = yes` as a strong claim.

Use `yes` only when there is public evidence of a committed build, final investment decision, signed customer agreement or lease tied to the capacity, financed construction plan, construction start, or operational facility.

Do not use `yes` only because a project has:

- an announced MW value
- an expected operation year
- a permit
- site selection
- land allocation
- grid discussion
- MoU
- marketing page
- political support
- general expansion ambition

Capacity-level `investment_decision` must be supported for that specific phase or capacity claim. Do not copy commitment from an initial phase to a full-campus potential row.

Project-level `investment_decision = yes` is allowed when at least one material phase is committed, under construction, or operational, even if later phases remain `no` or `unclear`.

## Capacity interpretation rules

Do not infer data centre capacity from backup generation, reactor capacity, land area, investment value, number of GPUs, number of racks, number of servers, or employment numbers unless the source explicitly links the value to data centre load, IT capacity, or grid-side data centre capacity.

Preserve the distinction between:

- reported capacity
- reported capacity basis
- interpreted IT load
- grid-side capacity
- backup power
- reactor or generation capacity
- rack density
- cumulative full-site potential
- incremental expansion
- initial phase capacity

Classify `reported_capacity_basis` from the exact source wording that supports the MW number. Do not infer basis from the project name, data centre type, or surrounding narrative.

Use these controlled values:

- `it_load` — the source explicitly says IT load, IT capacity, critical IT load, critical load, critical power, compute capacity, IT-effekt, or separates `X MW IT` from `Y MW power`.
- `facility_total` — the source describes total facility power, total power, power capacity, power supply, site power, or similar facility-level power without an IT-specific qualifier.
- `grid_connection` — the source describes contracted, requested, secured, or available electrical connection/power access for the site: grid connection capacity, anslutningseffekt, contracted power, power feed, access to MW, or a MW figure from a permit, grid, or connection-process document. The source can be a company release if the wording is clearly about site power access rather than a general headline capacity.
- `unspecified_headline` — the source only says `X MW data centre`, `X MW campus`, `X MW site`, `up to X MW`, `gigawatt-scale`, or similar headline wording without a clear qualifier.
- `backup_generation` — the source describes only backup generation, diesel reserve, or permitted backup power.
- `reactor` — the source describes reactor, SMR, or other generation capacity rather than load.
- `rack_density` — the source gives MW per rack, rack row, or similar density rather than campus capacity.

Use this quick guide for borderline wording:

| source wording | usual basis |
| --- | --- |
| `X MW IT load`, `X MW IT capacity`, `critical IT load`, `compute capacity`, or separate `X MW IT` and `Y MW power` | `it_load` |
| `access to X MW`, `secured X MW`, `X MW power feed`, `contracted power`, `anslutningseffekt`, or grid/permit power capacity | `grid_connection` |
| `X MW power supply`, `total power`, `site power`, `facility power`, or total facility capacity without connection wording | `facility_total` |
| `X MW data center`, `X MW campus`, `up to X MW`, `gigawatt-scale` | `unspecified_headline` |

Keep `capacity_type` and `reported_capacity_basis` separate. `capacity_type` should describe the row shape, such as initial phase, incremental expansion, cumulative total, full-campus potential, or facility capacity. `reported_capacity_basis` should describe what the MW number means. Avoid proposing `capacity_type = it_load` for new or audited rows when a more descriptive row-shape value fits.

Do not set `interpreted_it_load_mw = reported_capacity_mw` unless `reported_capacity_basis = it_load`.

For `facility_total`, `grid_connection`, and `unspecified_headline`, leave `interpreted_it_load_mw` blank unless there is a specific reason to recommend a manual override. The build script will derive IT load as `reported_capacity_mw / PUE`. For `unspecified_headline`, treat this grid-side/facility-side interpretation as the conservative default for headline MW figures.

For `backup_generation`, `reactor`, and `rack_density`, leave `interpreted_it_load_mw` blank and do not scenario-tag the row unless another source provides a separate data centre load figure.

If two sources for the same claim support different `reported_capacity_basis` values, write the disagreement to `data/audit/source_conflicts.csv` with `field = reported_capacity_basis`.

## Scenario-tag rules

When checking `scenario_tag`, remember that tags are for public display and filtering. They can mark smaller phase rows as relevant to a scenario when those rows sit inside a dated full-site or cumulative project path.

Do not use tags alone to decide what is added in scenario totals. Scenario totals should be based on the generated scenario files after de-duplication.

Treat scenario tags as classification labels, not quantitative inclusion rules. Do not propose `scenario_tag` changes unless source evidence changes timing, commitment status, capacity status, or classification under `docs/status_rules.md`.

Operational, dormant, and cancelled rows should not carry scenario tags. They can remain in master files for audit history, but they should not be included in the forward-looking public tracker table or scenario totals.

## Output rules

Use only the audit output files and column schemas defined in `docs/schema.md`:

- `data/audit/suggested_project_updates.csv`
- `data/audit/suggested_capacity_updates.csv`
- `data/audit/suggested_source_updates.csv`
- `data/audit/source_conflicts.csv`
- `data/audit/dead_links.csv`

Only write a row to `suggested_project_updates.csv`, `suggested_capacity_updates.csv`, or `suggested_source_updates.csv` if the proposed value differs from the current master value. Do not rewrite already-supported values merely to confirm them.

Every proposed change must include the established audit columns from `docs/schema.md`, including:

- `audit_id`
- `project_id`
- `claim_id` where relevant
- `field`
- `current_value`
- `suggested_value`
- `source_url`
- `source_title`
- `source_date` if available
- `access_date`
- `evidence_excerpt`
- `confidence`
- `rationale`

If `source_date` is not available, leave it blank and explain this in `rationale` or `notes`. Do not invent dates from access date, copyright year, URL path, page metadata, or file metadata unless clearly tied to the source publication, decision, or document date.

If evidence is ambiguous, contradictory, or indirect, mark `confidence` as `unclear` and record the issue in `source_conflicts.csv` unless a conservative proposed update is clearly justified.


## Audit ID rules

Use stable, sequential audit identifiers within each output file:

- `AP001`, `AP002`, ... for `suggested_project_updates.csv`
- `AC001`, `AC002`, ... for `suggested_capacity_updates.csv`
- `AS001`, `AS002`, ... for `suggested_source_updates.csv`
- use the ID convention defined in `docs/schema.md` for conflicts and dead links if specified

Do not reuse an existing `audit_id` for a different issue when appending to an existing audit file.

## Final report

After writing the audit files, provide a short summary with:

- number of project-level suggested updates
- number of capacity-level suggested updates
- number of source-level suggested updates
- number of unresolved source conflicts
- number of dead links
- any high-priority manual review items
