# Data centre tracker schema

This document defines the working data model for the Swedish data centre tracker.

## Core principles

- Master files are the reviewed source of truth.
- Audit files are work products. They should not be imported directly into the public tracker until manually reviewed.
- Generated tracker files are produced by scripts and should not be edited by hand.
- Project-level and capacity-level evidence must be kept separate.
- A project-level status or investment decision must not automatically be copied to all capacity rows.
- A capacity-level status or investment decision must be supported for the specific phase, claim, or capacity item.
- Scenario tags are classification labels for display and filtering. Scenario totals must be calculated from generated scenario files after de-duplication, not by summing tagged rows directly.
- A project is a single physical site in one bidding zone. A national, regional, or multi-site investment is not one project row.
- Operational, dormant, and cancelled rows may remain in master files for audit history, but they are not part of the forward-looking public tracker table or deployment scenarios.

## Master files

### `data/master/projects_master.csv`

One row per project or site.

| column | meaning |
| --- | --- |
| `project_id` | Stable project identifier, for example `P001`. Do not reuse deleted IDs. |
| `project_name` | Short public-facing project/site name. |
| `developer` | Company or organisations publicly associated with the project. Use `;` for multiple names. |
| `bidding_zone` | Swedish electricity bidding zone: exactly one of `SE1`, `SE2`, `SE3`, or `SE4`. Do not use multiple bidding zones in one row. Split separate sites into separate project rows; leave broad multi-site programmes out of master data until site-specific evidence exists. |
| `county` | Swedish county. |
| `municipality` | Municipality, with locality in parentheses if helpful. |
| `type` | Project type tags, separated by `;`, for example `hyperscale; AI`. |
| `project_status` | Lifecycle status for the project/site. See `docs/status_rules.md`. |
| `investment_decision` | Whether the project/site has a public committed-build signal: `yes`, `no`, `unclear`, or `not_applicable`. |
| `construction_start_years` | Publicly stated construction start year or years. Use `;` for multiple values. Leave blank if not public. |
| `expected_operational_years` | Publicly stated operation year or years. Use `;` for multiple values. Leave blank if not public. |
| `max_reported_capacity_mw` | Highest public capacity claim for the project/site, preserving the source concept in notes. |
| `notes` | Short explanation of the interpretation and caveats. |

### `data/master/capacity_master.csv`

One row per capacity claim, phase, or scenario-relevant capacity item.

| column | meaning |
| --- | --- |
| `claim_id` | Stable claim identifier, for example `C001`. Do not reuse deleted IDs. |
| `project_id` | Matching project ID from `projects_master.csv`. |
| `project_name` | Project name copied from `projects_master.csv` for readability. |
| `phase` | Phase name or description. |
| `capacity_type` | Capacity interpretation category. See below. |
| `capacity_status` | Lifecycle status for this specific capacity claim or phase. See `docs/status_rules.md`. |
| `investment_decision` | Whether this specific capacity claim or phase has a public committed-build signal. |
| `reported_capacity_mw` | Capacity number as reported or implied by the source. |
| `reported_capacity_basis` | How the source describes the reported MW figure. See below. This field is used by the build script to derive IT load. |
| `interpreted_it_load_mw` | Optional manual override for interpreted IT load. Normally leave blank and let the build script derive IT load from `reported_capacity_mw`, `reported_capacity_basis`, and PUE. If populated, the build script uses it and warns when it differs from the derived value. |
| `start_year` | Year the capacity is expected to become operational or relevant. Leave blank if unknown. |
| `construction_start_year` | Year construction starts for this specific capacity claim or phase. Leave blank if unknown or only known at broader project level. |
| `scenario_tag` | Scenario relevance tags separated by `;`. Used for display and filtering; scenario totals are de-duplicated in generated scenario files. |
| `type` | Project type tags, separated by `;`. |
| `notes` | Short explanation of phase interpretation and non-additivity caveats. |

Common `capacity_type` values:

| value | use |
| --- | --- |
| `facility_capacity` | A named facility or named data-centre capacity row that is not clearly an initial phase, incremental expansion, cumulative site total, or full-campus potential. Prefer this over `it_load` when the field describes the row shape rather than the MW basis. |
| `it_load` | Legacy/general value for a capacity row where the source explicitly reports IT load or data centre capacity. Avoid using this for new rows when a more descriptive row-shape value such as `facility_capacity`, `initial_phase_capacity`, or `full_campus_potential` fits. |
| `initial_phase_capacity` | First phase capacity where later phases may supersede or add to it. |
| `incremental_expansion` | Incremental added capacity to an existing facility. |
| `cumulative_site_capacity` | Cumulative total site capacity at a given point. Not additive with earlier phases. |
| `full_campus_potential` | Full build-out or maximum campus/site potential. |
| `reactor_capacity` | Power generation capacity linked to a concept, not IT load. |
| `permit_backup_power` | Backup power or permit capacity. Not IT load. |
| `unknown` | Capacity concept is unclear from the available source. Use only when the row is retained for transparency and notes explain the ambiguity. |

Common `reported_capacity_basis` values:

| value | use |
| --- | --- |
| `it_load` | The source explicitly says IT load, IT capacity, critical IT load, critical load, critical power, compute capacity, IT-effekt, or separates `X MW IT` from `Y MW power`. |
| `facility_total` | The source describes total facility power, total power, power capacity, power supply, site power, or similar facility-level power without an IT-specific qualifier. |
| `grid_connection` | The source describes contracted, requested, secured, or available electrical connection/power access for the site: grid connection capacity, anslutningseffekt, contracted power, power feed, access to MW, or a MW figure from a grid, permit, or connection-process document. The source can be a company release if the wording is clearly about site power access rather than a general headline capacity. |
| `unspecified_headline` | The source only says `X MW data centre`, `X MW campus`, `X MW site`, `up to X MW`, `gigawatt-scale`, or similar headline wording without a clear IT, facility, or grid qualifier. |
| `backup_generation` | The source describes backup generation, diesel reserve capacity, or permitted backup power only. |
| `reactor` | The source describes reactor, SMR, or other generation capacity rather than data centre load. |
| `rack_density` | The source gives MW per rack, rack row, or similar density. This is not campus capacity. |

Quick guide for borderline capacity wording:

| source wording | usual basis | why |
| --- | --- | --- |
| `X MW IT load`, `X MW IT capacity`, `critical IT load`, `compute capacity`, or separate `X MW IT` and `Y MW power` | `it_load` | The source identifies the number as IT-side capacity. |
| `access to X MW`, `secured X MW`, `X MW power feed`, `contracted power`, `anslutningseffekt`, or grid/permit power capacity | `grid_connection` | The number is about available or requested electrical supply to the site. |
| `X MW power supply`, `total power`, `site power`, `facility power`, or total facility capacity without connection wording | `facility_total` | The number is facility-side power, but not necessarily a formal grid connection claim. |
| `X MW data center`, `X MW campus`, `up to X MW`, `gigawatt-scale` | `unspecified_headline` | The number is a headline capacity claim without enough wording to identify IT, facility, or grid basis. |

Build-script interpretation:

| basis | derived IT-load rule |
| --- | --- |
| `it_load` | `interpreted_it_load_mw = reported_capacity_mw` |
| `facility_total` | `interpreted_it_load_mw = reported_capacity_mw / PUE` |
| `grid_connection` | `interpreted_it_load_mw = reported_capacity_mw / PUE` |
| `unspecified_headline` | `interpreted_it_load_mw = reported_capacity_mw / PUE`, with an audit flag in generated data |
| `backup_generation` | no IT-load derivation |
| `reactor` | no IT-load derivation |
| `rack_density` | no IT-load derivation |

Keep `reported_capacity_mw` exactly as the source reports it. The build script derives `interpreted_it_load_mw`, `estimated_grid_side_mw`, and annual electricity estimates from the reported value, the basis classification, and the relevant assumptions. If a manual `interpreted_it_load_mw` remains in master data, it is treated as an override and should be cleared once the basis-derived interpretation is accepted.

### `data/master/sources_master.csv`

One row per source-to-project or source-to-claim link. Multiple rows may point to the same URL if the source supports several claims.

| column | meaning |
| --- | --- |
| `source_id` | Stable source identifier, for example `S001`. |
| `project_id` | Matching project ID, if known. |
| `claim_id` | Matching capacity claim ID, if the source supports a specific phase or capacity claim. |
| `source_type` | Source category, for example `company`, `municipal`, `permit`, `grid`, `media`, `registry`, `other`. |
| `source_url` | Public URL. |
| `source_title` | Source title. |
| `source_date` | Publication, decision, or document date in `YYYY-MM-DD` when available. Leave blank if no reliable date is available. |
| `access_date` | Date the source was checked in `YYYY-MM-DD`. |
| `evidence_excerpt` | Short excerpt supporting the linked field or claim. |
| `supports_fields` | Fields supported by this source, separated by `;`. Use `project_status`, `capacity_status`, and `investment_decision` instead of the older generic `status`. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |
| `notes` | Caveats, translation notes, or interpretation comments. |

### `data/master/municipality_locations.csv`

One row per municipality/locality label used by `projects_master.csv`. These points are approximate display coordinates for the project-dot map, not exact site coordinates.

| column | meaning |
| --- | --- |
| `municipality` | Exact municipality/locality label as written in `projects_master.csv`, for example `Stockholm (Kista)`. |
| `latitude` | Approximate latitude in WGS84 decimal degrees. |
| `longitude` | Approximate longitude in WGS84 decimal degrees. |
| `coordinate_note` | Short note describing whether the point is a municipality seat, locality, or other approximate display point. |

## Audit output files

Audit files record proposed changes, unresolved source problems, and new candidates. They are review files, not tracker inputs.

General audit rules:

- Use one row per field-level issue, proposed change, conflict, dead link, or candidate.
- Preserve the established audit-column naming: `audit_id`, `field`, `current_value`, `suggested_value`, and `claim_id`.
- Only write a row to `suggested_project_updates.csv` or `suggested_capacity_updates.csv` when the proposed value differs from the current master value.
- Do not rewrite already-supported values merely to confirm them.
- Do not invent publication dates. If `source_date` is unavailable, leave it blank and explain the limitation in `rationale` or `notes`.
- `evidence_excerpt` should be short and directly tied to the proposed change or issue.
- `confidence` must be one of `high`, `medium`, `low`, or `unclear`.
- Use `unclear` when evidence is ambiguous, contradictory, or too indirect.
- Use semicolons within fields when multiple tags, names, or values are needed.

### `data/audit/suggested_project_updates.csv`

One row per proposed project-level field change. Use this file only for fields in `projects_master.csv`. Use `project_status` and project-level `investment_decision` for status-related changes.

Project-level changes should be checked against the underlying capacity rows using `docs/status_rules.md`.

| column | meaning |
| --- | --- |
| `audit_id` | Stable audit-row identifier, for example `AP001`. Use `AP` for project-level audit rows. |
| `project_id` | Matching project ID from `projects_master.csv`. |
| `project_name` | Project name from the master file. |
| `field` | Project-level field proposed for change. |
| `current_value` | Current value in `projects_master.csv`. |
| `suggested_value` | Suggested replacement value. Leave blank when the recommendation is to clear the current value. |
| `source_url` | URL supporting the proposed change. |
| `source_title` | Source title. |
| `source_date` | Publication, decision, or document date in `YYYY-MM-DD` when available. Leave blank if unavailable. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `evidence_excerpt` | Short excerpt supporting the proposed change. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |
| `rationale` | Short explanation of why the field should change and how the source supports the proposed value. |

### `data/audit/suggested_capacity_updates.csv`

One row per proposed capacity-claim field change. Use this file only for fields in `capacity_master.csv`. Use `capacity_status` and capacity-level `investment_decision` for status-related changes. Use `construction_start_year` where a source supports phase-specific construction timing.

Capacity-level changes should preserve phase-specific evidence and should not automatically inherit project-level status or timing.

| column | meaning |
| --- | --- |
| `audit_id` | Stable audit-row identifier, for example `AC001`. Use `AC` for capacity-level audit rows. |
| `claim_id` | Matching claim ID from `capacity_master.csv`. |
| `project_id` | Matching project ID from `capacity_master.csv`. |
| `project_name` | Project name from the master file. |
| `phase` | Phase or claim description from the master file. |
| `field` | Capacity-level field proposed for change. |
| `current_value` | Current value in `capacity_master.csv`. |
| `suggested_value` | Suggested replacement value. Leave blank when the recommendation is to clear the current value. |
| `source_url` | URL supporting the proposed change. |
| `source_title` | Source title. |
| `source_date` | Publication, decision, or document date in `YYYY-MM-DD` when available. Leave blank if unavailable. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `evidence_excerpt` | Short excerpt supporting the proposed change. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |
| `rationale` | Short explanation of why the field should change and how the source supports the proposed value. |

### `data/audit/suggested_source_updates.csv`

One row per proposed source-level field change. Use this file only for fields in `sources_master.csv`, for example when `supports_fields`, `confidence`, `evidence_excerpt`, or `notes` should be corrected after an audit.

| column | meaning |
| --- | --- |
| `audit_id` | Stable audit-row identifier, for example `AS001`. Use `AS` for source-level audit rows. |
| `source_id` | Matching source ID from `sources_master.csv`. |
| `project_id` | Matching project ID, if available. |
| `claim_id` | Matching claim ID, if available. |
| `project_name` | Project name from the master file, if available. |
| `field` | Source-level field proposed for change. |
| `current_value` | Current value in `sources_master.csv`. |
| `suggested_value` | Suggested replacement value. Leave blank when the recommendation is to clear the current value. |
| `source_url` | URL for the source row being updated. |
| `source_title` | Source title. |
| `source_date` | Publication, decision, or document date in `YYYY-MM-DD` when available. Leave blank if unavailable. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `evidence_excerpt` | Short excerpt supporting the source-row update. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |
| `rationale` | Short explanation of why the source metadata should change. |

### `data/audit/source_conflicts.csv`

One row per unresolved conflict between sources, or between a source and a current master value. Use this file when the evidence is not strong enough to make a clean proposed update.

| column | meaning |
| --- | --- |
| `project_id` | Matching project ID, if known. |
| `claim_id` | Matching claim ID, if the conflict concerns a specific capacity row. Leave blank for project-level conflicts. |
| `project_name` | Project name, if known. |
| `field` | Field affected by the conflict. |
| `current_value` | Current master value, if relevant. |
| `source_url_1` | First source URL. |
| `source_title_1` | First source title. |
| `source_date_1` | First source date in `YYYY-MM-DD` when available. |
| `value_supported_1` | Value or interpretation supported by source 1. |
| `source_url_2` | Second source URL. |
| `source_title_2` | Second source title. |
| `source_date_2` | Second source date in `YYYY-MM-DD` when available. |
| `value_supported_2` | Value or interpretation supported by source 2. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `conflict_summary` | Short explanation of the disagreement. |
| `recommended_resolution` | Suggested manual resolution, or `manual_review_needed`. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |

### `data/audit/dead_links.csv`

One row per inaccessible, redirected, paywalled, or otherwise problematic registered URL that needs manual checking.

| column | meaning |
| --- | --- |
| `source_id` | Matching source ID from `sources_master.csv`, if registered. |
| `project_id` | Matching project ID, if known. |
| `claim_id` | Matching claim ID, if known. Leave blank for project-level sources. |
| `project_name` | Project name, if known. |
| `source_url` | Problematic URL. |
| `source_title` | Registered or visible source title, if available. |
| `error_type` | For example `404`, `redirect`, `paywall`, `timeout`, `blocked`, `not_found`, or `other`. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `notes` | Short explanation of the access problem and any replacement source found. |

### `data/audit/new_project_candidates.csv`

One row per new or missing candidate project or phase found during a discovery run. Candidates are not master data.

Use this file when a discovery search reveals a project, phase, or capacity claim not already represented in `projects_master.csv` or `capacity_master.csv`. Do not add the candidate directly to master files.

Do not use this file for ordinary existing-project audit unless the user explicitly asks for discovery. Do not write candidates for GPU purchases, customer deployments, cloud-service launches, or equipment orders inside an existing data centre unless the source also identifies a new site, phase, expansion, or capacity claim. Do not write one candidate for investments spanning multiple bidding zones; each candidate must be one site in one bidding zone.

| column | meaning |
| --- | --- |
| `candidate_id` | Temporary candidate identifier, for example `N001`. |
| `developer` | Company or organisations publicly associated with the candidate. Use `;` for multiple names. |
| `project_name` | Candidate project/site name, if available. |
| `municipality` | Municipality, with locality in parentheses if helpful. |
| `county` | Swedish county, if available. |
| `bidding_zone` | Exactly one of `SE1`, `SE2`, `SE3`, `SE4`, or blank if the single-site zone is not yet determined. Do not use semicolon-separated zones. |
| `project_status` | Candidate lifecycle status using `docs/status_rules.md`, if classifiable. |
| `investment_decision` | `yes`, `no`, `unclear`, or `not_applicable`, based on public committed-build evidence. |
| `reported_capacity_mw` | Reported capacity, if available. |
| `reported_capacity_basis` | How the source describes the reported MW figure, using the same controlled values as `capacity_master.csv`. |
| `capacity_type` | Capacity interpretation category, if classifiable. |
| `interpreted_it_load_mw` | Optional manual IT-load override. Normally leave blank unless the source explicitly gives IT load or the candidate needs a temporary manual value that cannot be derived from basis + PUE. |
| `start_year` | Expected operation or relevance year when available. |
| `construction_start_year` | Phase-specific construction start year when available. |
| `source_url` | URL supporting the candidate. |
| `source_title` | Source title. |
| `source_date` | Publication, decision, or document date in `YYYY-MM-DD` when available. Leave blank if unavailable. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `evidence_excerpt` | Short excerpt supporting the candidate. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |
| `notes` | Caveats, duplicate-risk notes, interpretation issues, or relation to existing projects. |

## Generated tracker files

These files are produced by `scripts/build_datacenter_data.R` and are used by the public tracker. They should not be edited by hand.

### `assets/data/datacenters/capacity.json`

One row per capacity claim or phase, with reported MW basis, derived IT load, derived PUE, grid-side MW, annual TWh estimate, scenario relevance tags, and source-based update date. This is the file used for the expandable project table.

Generated capacity rows include both `derived_interpreted_it_load_mw` and `interpreted_it_load_mw`. When no manual override exists, these are the same. When a manual override remains in `capacity_master.csv`, `interpreted_it_load_mw` uses the manual value and the build script warns if it differs from the basis-derived value.

`last_updated` is based on the latest available `source_date` for the project or claim. If no source publication date is available, the build falls back to `access_date`.

The generated public tracker files exclude projects and capacity rows with `Operational`, `Dormant`, or `Cancelled` status. These rows can stay in master files for audit history, but they are not shown as forward-looking project pipeline.

Project rows in `assets/data/datacenters/projects.json` include approximate coordinates inherited from `municipality_locations.csv`. The project-dot layer on the scenario map uses those coordinates directly.

Coordinates are display coordinates, not exact data-centre site coordinates. When several projects share the same municipality/locality point, the map clusters them rather than offsetting them in a way that implies exact locations.

### `assets/data/datacenters/scenario_zone.json` and `scenario_zone.csv`

One row per bidding zone and scenario. These files are the correct inputs for the scenario map and any zone-level scenario totals.

The R script removes double counting before these files are written. If a project has both a 300 MW phase row and a 750 MW full-buildout row in the same scenario, the 750 MW row is counted once and the 300 MW row remains visible only as a phase row in `capacity.json`.

Use `grid_side_mw` for scenario MW values. The older `mw` field is kept only for compatibility with existing visual code.
