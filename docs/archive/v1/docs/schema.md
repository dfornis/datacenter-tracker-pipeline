# Data centre tracker schema

This document defines the working data model for the Nordic data centre tracker.

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
- Countries and bidding zones are controlled by `data/master/geography_config.csv`. Add new geographies there before using them in master or audit data.

## Master files

### `data/master/projects_master.csv`

One row per project or site.

| column | meaning |
| --- | --- |
| `project_id` | Stable project identifier, for example `P001`. Do not reuse deleted IDs. |
| `country` | ISO-style country code from `data/master/geography_config.csv`, for example `SE`, `FI`, or `NO`. Existing rows can be deterministically derived from `bidding_zone`, but the stored value makes filtering and QA explicit. |
| `project_name` | Short public-facing project/site name. |
| `developer` | Company or organisations publicly associated with the project. Use `;` for multiple names. |
| `bidding_zone` | Nordic electricity bidding zone from `data/master/geography_config.csv`. Do not use multiple bidding zones in one row. Split separate sites into separate project rows; leave broad multi-site programmes out of master data until site-specific evidence exists. |
| `county` | Canonical region label from `data/master/admin_units.csv`: Swedish `län`, Finnish `maakunta`, or Norwegian `fylke`. |
| `municipality` | Canonical municipality label from `data/master/admin_units.csv`, with locality in parentheses if helpful for display, for example `Stockholm (Kista)`. The build validates the base municipality before the parenthetical suffix. |
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
| `country` | Country code inherited from the linked project. The build script validates that this matches `projects_master.csv`. |
| `project_name` | Project name copied from `projects_master.csv` for readability. |
| `phase` | Phase name or description. |
| `capacity_type` | Capacity interpretation category. See below. |
| `capacity_status` | Lifecycle status for this specific capacity claim or phase. See `docs/status_rules.md`. |
| `investment_decision` | Whether this specific capacity claim or phase has a public or strongly implied investment decision. |
| `reported_capacity_mw` | Capacity number as reported or implied by the source. |
| `reported_capacity_basis` | How the source describes the reported MW figure. See below. This field is used by the build script to derive IT load. |
| `interpreted_it_load_mw` | Optional manual override for interpreted IT load. Normally leave blank and let the build script derive IT load from `reported_capacity_mw`, `reported_capacity_basis`, and PUE. If populated, the build script uses it and warns when it differs from the derived value. |
| `start_year` | Year the capacity is expected to become operational or relevant. Leave blank if unknown. |
| `construction_start_year` | Year construction starts for this specific capacity claim or phase. Leave blank if unknown or only known at broader project level. If a source explicitly reports the phase as under construction but gives no exact start year, use the source-date year, or access-date year for an undated source, and explain this in `notes`. |
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
| `facility_total` | The source explicitly describes total facility power, total power, power capacity, power supply, site power, nameplate facility capacity, electrical connection/power serving the facility, or equivalent wording without an IT-specific qualifier. Use only when the wording makes clear the number is on the facility/grid side rather than IT load. |
| `grid_connection` | The source describes contracted, requested, secured, or available electrical connection/power access for the site: grid connection capacity, anslutningseffekt, contracted power, power feed, access to MW, or a MW figure from a grid, permit, or connection-process document. The source can be a company release if the wording is clearly about site power access rather than a general headline capacity. |
| `unspecified_headline` | The source gives a MW headline or capacity claim but does not clearly identify whether it is IT load, total/nameplate facility power, grid connection/access, backup generation, or another basis. |
| `backup_generation` | The source describes backup generation, diesel reserve capacity, or permitted backup power only. |
| `reactor` | The source describes reactor, SMR, or other generation capacity rather than data centre load. |
| `rack_density` | The source gives MW per rack, rack row, or similar density. This is not campus capacity. |

Quick guide for borderline capacity wording:

| source wording | usual basis | why |
| --- | --- | --- |
| `X MW IT load`, `X MW IT capacity`, `critical IT load`, `compute capacity`, or separate `X MW IT` and `Y MW power` | `it_load` | The source identifies the number as IT-side capacity. |
| `access to X MW`, `secured X MW`, `X MW power feed`, `contracted power`, `anslutningseffekt`, or grid/permit power capacity | `grid_connection` | The number is about available or requested electrical supply to the site. |
| `X MW power supply`, `total power`, `site power`, `facility power`, `nameplate capacity`, `connected load`, or total electrical facility capacity without IT wording | `facility_total` | The number is facility/grid-side power, but not necessarily a formal grid connection claim. |
| `X MW capacity`, `X MW data center`, `X MW campus`, `up to X MW`, `gigawatt-scale`, or oddly rounded figures with no facility, grid, or IT context | `unspecified_headline` | The number is a capacity claim that should be used conservatively but still flagged for audit. |

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

`facility_total`, `grid_connection`, and `unspecified_headline` share the same conservative derived IT-load treatment. They are evidentiary labels, not additive capacity types. If several sources describe the same MW figure with different basis wording, keep one capacity row, choose the best-supported basis, and document the ambiguity.

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

One row per country + municipality/locality label used by `projects_master.csv`. These points are approximate display coordinates for the project-dot map, not exact site coordinates.

| column | meaning |
| --- | --- |
| `country` | Country code from `data/master/geography_config.csv`. |
| `municipality` | Exact municipality/locality label as written in `projects_master.csv`, for example `Stockholm (Kista)`. |
| `latitude` | Approximate latitude in WGS84 decimal degrees. |
| `longitude` | Approximate longitude in WGS84 decimal degrees. |
| `coordinate_note` | Short note describing whether the point is a municipality seat, locality, or other approximate display point. |

### `data/master/admin_units.csv`

One row per official municipality-to-region mapping for active tracker countries. This file defines the standard names and codes that `projects_master.csv` should use for `municipality` and `county`.

The pipeline uses `municipality_name` and `region_name` as canonical values. Language-specific columns support country-aware search and interpretation in prompts.

| column | meaning |
| --- | --- |
| `country` | Country code from `data/master/geography_config.csv`. |
| `country_name` | English country name. |
| `municipality_code` | Official municipality code from the national statistical authority. |
| `municipality_name` | Canonical municipality name to use in `projects_master.csv`, before any optional locality suffix in parentheses. |
| `municipality_name_local` | Municipality name in the country's canonical local language for this tracker. |
| `municipality_name_en` | English name when provided by the source. Leave blank rather than inventing translations. |
| `municipality_name_sv` | Swedish name when provided by the source. |
| `municipality_name_fi` | Finnish name when provided by the source. |
| `municipality_name_nb` | Norwegian Bokmål name when provided by the source. |
| `municipality_name_nn` | Norwegian Nynorsk name when provided by the source. |
| `region_code` | Official region/county code. |
| `region_name` | Canonical region label to use in `projects_master.csv` `county`. |
| `region_name_local` | Region name in the country's canonical local language for this tracker. |
| `region_name_en`, `region_name_sv`, `region_name_fi`, `region_name_nb`, `region_name_nn` | Region-name language variants from the source, where available. |
| `municipality_term_local` | Local term for the municipality-level field, for example `kommun`, `kunta/kaupunki`, or `kommune`. |
| `region_term_local` | Local term for the region-level `county` field, for example `län`, `maakunta`, or `fylke`. |
| `valid_from` | Validity date for the source classification. |
| `source_authority` | Official source authority. |
| `source_url` | Source URL used to build the row. |
| `source_version` | Source classification/version label. |

### `data/master/country_config.csv`

One row per country defining country-level metadata, search languages, and how shared tracker fields map to local administrative terminology.

| column | meaning |
| --- | --- |
| `country` | Country code. |
| `country_name` | English country name. |
| `active` | `TRUE` when the country is active in the pipeline. |
| `canonical_name_language` | Language used for canonical `municipality_name` and `region_name` values. |
| `search_languages` | Languages to use during audit/discovery. |
| `municipality_field` | Shared tracker field name, currently `municipality`. |
| `municipality_term_local` | Local term agents should search for and interpret. |
| `municipality_term_en` | English description of the local term. |
| `region_field` | Shared tracker field name, currently `county`. |
| `region_term_local` | Local term represented by `county`. |
| `region_term_en` | English description of the local term. |
| `source_authority`, `source_url`, `valid_from` | Official source metadata. |

### `data/master/geography_config.csv`

One row per allowed bidding zone. This is the single source of truth for active countries, zone validation, scenario-zone completion, and bidding-zone GeoJSON assembly.

| column | meaning |
| --- | --- |
| `country` | Country code used in master, audit, and generated files. |
| `country_name` | English country name for display and prompt context. |
| `bidding_zone` | Allowed bidding-zone code, for example `SE1`, `FI`, or `NO3`. |
| `zone_name` | Human-readable zone name. |
| `active` | `TRUE` when the zone should be accepted by the build and included in scenario-zone output. |
| `geojson_file` | Repo-relative path to the zone polygon source used by `scripts/build_datacenter_data.R`. |

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
| `country` | Country code for filtering shared audit files. |
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
| `country` | Country code inherited from the linked project/capacity row. |
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
| `country` | Country code for filtering shared audit files, if known. |
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
| `country` | Country code for filtering shared audit files, if known. |
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
| `country` | Country code for filtering shared audit files, if known. |
| `project_id` | Matching project ID, if known. |
| `claim_id` | Matching claim ID, if known. Leave blank for project-level sources. |
| `project_name` | Project name, if known. |
| `source_url` | Problematic URL. |
| `source_title` | Registered or visible source title, if available. |
| `error_type` | For example `404`, `redirect`, `paywall`, `timeout`, `blocked`, `not_found`, or `other`. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `notes` | Short explanation of the access problem and any replacement source found. |

### `data/audit/new_project_candidates.csv`

One row per new or missing candidate project/site found during a discovery run. Candidates are not master data.

Use this file when a discovery search reveals a physical site not already represented in `projects_master.csv`. Do not add the candidate directly to master files. Do not use this file for ordinary existing-project audit unless the user explicitly asks for discovery.

This file is project-level only. Do not place phase-specific MW interpretation here. Capacity claims, phases, expansions, cumulative totals, and full-campus potentials belong in `data/audit/new_capacity_claim_candidates.csv`.

Do not write candidates for GPU purchases, customer deployments, cloud-service launches, or equipment orders inside an existing data centre unless the source also identifies a new site. Do not write one candidate for investments spanning multiple bidding zones; each project candidate must be one site in one bidding zone.

| column | meaning |
| --- | --- |
| `project_candidate_id` | Temporary project candidate identifier, for example `NP001`. Do not reuse within the file. |
| `country` | Country code for the candidate, from `data/master/geography_config.csv`. |
| `developer` | Company or organisations publicly associated with the candidate. Use `;` for multiple names. |
| `project_name` | Candidate project/site name, if available. |
| `bidding_zone` | Exactly one configured bidding zone, or blank if the single-site zone is not yet determined. Do not use semicolon-separated zones. |
| `county` | Canonical region label from `data/master/admin_units.csv`, if available. |
| `municipality` | Municipality, with locality in parentheses if helpful. |
| `type` | Project type tags, separated by `;`, matching the style used in `projects_master.csv`. |
| `project_status` | Candidate lifecycle status using `docs/status_rules.md`, if classifiable. |
| `investment_decision` | Project-level `yes`, `no`, `unclear`, or `not_applicable`, based on public evidence that a real investment decision has been taken or can be strongly inferred for the site. |
| `construction_start_years` | Public project-level construction start year or years. Use `;` for multiple values. Leave blank if timing is only claim-specific. |
| `expected_operational_years` | Public project-level operation year or years. Use `;` for multiple values. Leave blank if timing is only claim-specific. |
| `max_reported_capacity_mw` | Highest public capacity claim for the site. This is a project summary value; the capacity claim itself must also appear in `new_capacity_claim_candidates.csv` when the source gives an MW figure. |
| `source_url` | URL supporting project identity, location, status, or project-level timing. |
| `source_title` | Source title. |
| `source_date` | Publication, decision, or document date in `YYYY-MM-DD` when available. Leave blank if unavailable. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `evidence_excerpt` | Short excerpt supporting the project candidate. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |
| `notes` | Caveats, duplicate-risk notes, relation to existing projects, or instructions for manual promotion. |

### `data/audit/new_capacity_claim_candidates.csv`

One row per new or missing capacity claim, phase, expansion, cumulative site total, or full-campus potential found during a discovery run. Candidates are not master data.

This file mirrors `capacity_master.csv` closely enough that a reviewed row can be promoted to a permanent `claim_id`. It may reference either a new `project_candidate_id` from `new_project_candidates.csv` or an existing `project_id` from `projects_master.csv` when discovery finds a new claim for a known project.

Keep source metadata on the capacity-claim row when the source supports the MW value, capacity basis, phase timing, capacity status, or capacity-level investment decision. Do not create a separate source-candidate file; during manual promotion, this source metadata becomes or updates a row in `sources_master.csv`.

| column | meaning |
| --- | --- |
| `capacity_candidate_id` | Temporary capacity candidate identifier, for example `NC001`. Do not reuse within the file. |
| `project_candidate_id` | Temporary project candidate identifier from `new_project_candidates.csv`, if the site is new. Leave blank when `project_id` points to an existing master project. |
| `project_id` | Existing master `project_id` if the claim belongs to a known project. Leave blank for a new project candidate. |
| `country` | Country code inherited from the linked project or project candidate. |
| `project_name` | Project/site name for readability. |
| `phase` | Phase name or claim description. |
| `capacity_type` | Capacity row-shape category, using the same values as `capacity_master.csv`. |
| `capacity_status` | Lifecycle status for this specific capacity claim or phase. |
| `investment_decision` | Capacity-level `yes`, `no`, `unclear`, or `not_applicable`, supported for this specific claim or phase. |
| `reported_capacity_mw` | Capacity number as reported or implied by the source. |
| `reported_capacity_basis` | How the source describes the reported MW figure, using the same controlled values as `capacity_master.csv`. |
| `interpreted_it_load_mw` | Optional manual IT-load override. Normally leave blank unless the source explicitly gives IT load or the candidate needs a temporary manual value that cannot be derived from basis + PUE. |
| `start_year` | Expected operation or relevance year for this specific capacity claim. |
| `construction_start_year` | Construction start year for this specific capacity claim or phase. If the source explicitly reports the claim as under construction but gives no exact start year, use the source-date year, or access-date year for an undated source, and explain this in `notes`. |
| `scenario_tag` | Optional reviewer hint using the normal scenario tags. Leave blank when unsure; scenario tags are recalculated by the build after promotion. |
| `type` | Project type tags, separated by `;`. |
| `source_url` | URL supporting the capacity claim. |
| `source_title` | Source title. |
| `source_date` | Publication, decision, or document date in `YYYY-MM-DD` when available. Leave blank if unavailable. |
| `access_date` | Date checked in `YYYY-MM-DD`. |
| `evidence_excerpt` | Short excerpt supporting this capacity claim. |
| `confidence` | `high`, `medium`, `low`, or `unclear`. |
| `notes` | Non-additivity caveats, relation to other claims, source wording, or manual-review instructions. |

Discovery promotion model:

- Promote a reviewed project candidate by assigning a permanent `project_id` and copying project-level fields into `projects_master.csv`.
- Promote each reviewed capacity-claim candidate by assigning a permanent `claim_id`, replacing `project_candidate_id` with the permanent `project_id`, and copying claim-level fields into `capacity_master.csv`.
- Promote the supporting source metadata from the project or capacity-claim candidate into `sources_master.csv`, linked to the permanent `project_id` and, where relevant, `claim_id`.
- Keep project summary capacity (`max_reported_capacity_mw`) separate from claim accounting. Scenario calculations use promoted capacity rows, not the project candidate row.

## Generated tracker files

These files are produced by `scripts/build_datacenter_data.R` and are used by the public tracker. They should not be edited by hand.

### `assets/data/datacenters/capacity.json`

One row per capacity claim or phase, with country, reported MW basis, derived IT load, derived PUE, grid-side MW, annual TWh estimate, scenario relevance tags, and source-based update date. This is the file used for the expandable project table.

Generated capacity rows include both `derived_interpreted_it_load_mw` and `interpreted_it_load_mw`. When no manual override exists, these are the same. When a manual override remains in `capacity_master.csv`, `interpreted_it_load_mw` uses the manual value and the build script warns if it differs from the basis-derived value.

`last_updated` is based on the latest available `source_date` for the project or claim. If no source publication date is available, the build falls back to `access_date`.

The generated public tracker files exclude projects and capacity rows with `Operational`, `Dormant`, or `Cancelled` status. These rows can stay in master files for audit history, but they are not shown as forward-looking project pipeline.

Project rows in `assets/data/datacenters/projects.json` include approximate coordinates inherited from `municipality_locations.csv`. The project-dot layer on the scenario map uses those coordinates directly.

Coordinates are display coordinates, not exact data-centre site coordinates. When several projects share the same municipality/locality point, the map clusters them rather than offsetting them in a way that implies exact locations.

### `assets/data/datacenters/scenario_zone.json`

One row per country, bidding zone, and scenario. This file is the correct input for the scenario map and any zone-level scenario totals.

The R script removes double counting before these files are written. If a project has both a 300 MW phase row and a 750 MW full-buildout row in the same scenario, the 750 MW row is counted once and the 300 MW row remains visible only as a phase row in `capacity.json`.

Use `grid_side_mw` for scenario MW values. The older `mw` field is kept only for compatibility with existing visual code.
