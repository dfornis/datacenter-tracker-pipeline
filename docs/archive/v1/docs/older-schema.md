# Data centre tracker schema

This archived document defines an older working data model for the data centre tracker. The current schema in `docs/schema.md` is authoritative.

## Master files

### `data/master/projects_master.csv`

One row per project or site.

| column | meaning |
| --- | --- |
| `project_id` | Stable project identifier, for example `P001`. Do not reuse deleted IDs. |
| `country` | Country code from the configured geography list. |
| `project_name` | Short public-facing project/site name. |
| `developer` | Company or organisations publicly associated with the project. Use `;` for multiple names. |
| `bidding_zone` | Electricity bidding zone from the configured geography list. |
| `county` | County, region, fylke, maakunta, or closest public regional administrative label. |
| `municipality` | Municipality, with locality in parentheses if helpful. |
| `type` | Project type tags, separated by `;`, for example `hyperscale; AI`. |
| `project_status` | Lifecycle status for the project/site. See `docs/status_rules.md`. |
| `investment_decision` | Whether a real investment decision for the project/site is public or strongly implied: `yes`, `no`, `unclear`, or `not_applicable`. |
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
| `investment_decision` | Whether this specific capacity claim or phase has a public or strongly implied investment decision. |
| `reported_capacity_mw` | Capacity number as reported or implied by the source. |
| `interpreted_it_load_mw` | Tracker interpretation of IT load. Leave blank when the source does not support IT load. |
| `start_year` | Year the capacity is expected to become operational or relevant. Leave blank if unknown. |
| `construction_start_year` | Year construction starts for this specific capacity claim or phase. Leave blank if unknown or only known at broader project level. |
| `scenario_tag` | Scenario relevance tags separated by `;`. These are used for display and filtering; scenario totals are de-duplicated in the generated scenario files. |
| `type` | Project type tags, separated by `;`. |
| `notes` | Short explanation of phase interpretation and non-additivity caveats. |

Common `capacity_type` values:

| value | use |
| --- | --- |
| `it_load` | Source explicitly reports IT load or data centre capacity. |
| `initial_phase_capacity` | First phase capacity where later phases may supersede or add to it. |
| `incremental_expansion` | Incremental added capacity to an existing facility. |
| `cumulative_site_capacity` | Cumulative total site capacity at a given point. Not additive with earlier phases. |
| `full_campus_potential` | Full build-out or maximum campus/site potential. |
| `reactor_capacity` | Power generation capacity linked to a concept, not IT load. |
| `permit_backup_power` | Backup power or permit capacity. Not IT load. |

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
| `source_date` | Publication, decision, or document date in `YYYY-MM-DD` when available. |
| `access_date` | Date the source was checked in `YYYY-MM-DD`. |
| `evidence_excerpt` | Short excerpt supporting the linked field or claim. |
| `supports_fields` | Fields supported by this source, separated by `;`. Use `project_status`, `capacity_status`, and `investment_decision` instead of the older generic `status`. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |
| `notes` | Caveats, translation notes, or interpretation comments. |

## Audit output files

Audit files are work products. They should not be imported directly into the public tracker until reviewed.

### `data/audit/suggested_project_updates.csv`

One row per proposed project-level field change. Use `project_status` and project-level `investment_decision` for status-related changes.
Project-level changes should be checked against the underlying capacity rows using `docs/status_rules.md`.

### `data/audit/suggested_capacity_updates.csv`

One row per proposed capacity-claim field change. Use `capacity_status` and capacity-level `investment_decision` for status-related changes. Use `construction_start_year` where a source supports phase-specific construction timing.
Capacity-level changes should preserve phase-specific evidence and should not automatically inherit project-level status or timing.

### `data/audit/source_conflicts.csv`

One row per unresolved conflict between sources or between a source and a current master value.

### `data/audit/dead_links.csv`

One row per inaccessible or redirected URL that needs manual checking.

### `data/audit/new_project_candidates.csv`

One row per new or missing candidate project or phase. Candidates are not master data. Include `start_year` for expected operation and `construction_start_year` for phase-specific construction timing when available.

## Generated tracker files

These files are produced by `scripts/build_datacenter_data.R` and are used by the public tracker. They should not be edited by hand.

### `assets/data/datacenters/capacity.json`

One row per capacity claim or phase, with derived PUE, grid-side MW, annual TWh estimate, scenario relevance tags, and source-based update date. This is the file used for the expandable project table.

`last_updated` is based on the latest available `source_date` for the project or claim. If no source publication date is available, the build falls back to `access_date`.

### `assets/data/datacenters/scenario_zone.json` and `scenario_zone.csv`

One row per bidding zone and scenario. These files are the correct inputs for the scenario map and any zone-level scenario totals.

The R script removes double counting before these files are written. If a project has both a 300 MW phase row and a 750 MW full-buildout row in the same scenario, the 750 MW row is counted once and the 300 MW row remains visible only as a phase row in `capacity.json`.

Use `grid_side_mw` for scenario MW values. The older `mw` field is kept only for compatibility with existing visual code.
