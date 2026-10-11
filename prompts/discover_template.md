# Discovery Prompt Template

Search for new or missing data centre projects in one configured country.

Use this template together with exactly one country overlay from `prompts/country_overlays/`. The run must be scoped to one country only.

## Parameters

- `country`: required country code from `data/master/geography_config.csv`
- `country_overlay`: required overlay for the same country

## Scope

Filter comparisons against `data/master/projects_master.csv` and `data/master/capacity_master.csv` to the selected `country`, but still check the full master data for cross-country duplicate risk when a developer uses regional project names.

Use `data/master/admin_units.csv` as the authority for `municipality` and `county` values. `municipality` may include a locality suffix in parentheses, but the base municipality before the suffix should match `municipality_name`. `county` should match `region_name`. Use `data/master/country_config.csv` and the language-specific name columns in `admin_units.csv` for country-aware searching.

One candidate must be one physical site in one configured bidding zone. Do not create one candidate for a national, regional, or multi-site investment spanning several bidding zones or countries.

Include hyperscale, AI/HPC, colocation, cloud, enterprise, and large edge projects. Exclude ordinary server rooms unless reported as a data centre project.

Exclude GPU purchases, customer deployments, cloud launches, and equipment orders inside existing data centres unless the source identifies a new site, phase, expansion, or capacity claim.

Include only projects with public evidence.

## Search for

- company announcements
- municipal planning material
- environmental permits
- grid connection information
- construction starts
- investment decisions
- operational openings
- cancellations or dormancy
- new phases or capacity claims for projects already in the master files

Use the country overlay for source languages, search terms, authorities, grid actors, municipal terminology, and local trade press.

## Output

Write project-level candidates to `data/audit/new_project_candidates.csv`.

Write capacity-claim and phase-level candidates to `data/audit/new_capacity_claim_candidates.csv`.

Before writing a project candidate, compare it with `data/master/projects_master.csv` and `data/master/capacity_master.csv`. If it appears to be a customer deployment or hardware purchase inside an existing project, do not write a project candidate. If the evidence is only a new phase, expansion, or capacity claim for an existing site, write only a capacity-claim candidate and explain the overlap in `notes`.

Include `country` on every candidate row in both files.

Use one `project_candidate_id` per physical site. Use one `capacity_candidate_id` per distinct MW claim, phase, expansion, cumulative site total, or full-campus potential. This mirrors the master model: project candidates promote to `projects_master.csv`, while capacity-claim candidates promote to `capacity_master.csv` and receive permanent `claim_id` values during manual review.

Do not collapse multiple capacity claims into one project row. If a source gives both an initial phase and a later full-campus potential, write one project candidate and two capacity-claim candidates linked by `project_candidate_id`. If a project has no public MW claim, write a project candidate and no capacity-claim candidate.

Keep source metadata on the row whose value it supports. Project-identification, location, and status evidence belongs on the project candidate. MW, capacity-basis, phase timing, and phase investment-decision evidence belongs on the capacity-claim candidate. When the same source supports both levels, repeat the source metadata in both files.

Use `docs/status_rules.md` when judging whether a capacity claim could later be scenario-relevant. Scenario tags are public relevance tags, not additive accounting instructions. If a new phase sits inside a dated full-site or cumulative capacity path, explain that relationship in the capacity candidate `notes`.

Write candidates so manual promotion is straightforward: project candidates should map to `projects_master.csv`, capacity-claim candidates should map to `capacity_master.csv`, and source metadata on either candidate row should be enough to create or update the matching `sources_master.csv` row. Scenario calculations will use promoted capacity rows, not the project candidate row.

## Capacity interpretation

For every MW figure, classify `reported_capacity_basis` from the exact source wording that supports the number. Do not infer basis from the project name, data centre type, or surrounding narrative.

Use these values:

- `it_load`: the source explicitly says IT load, IT capacity, critical IT load, critical load, critical power, compute capacity, or separates `X MW IT` from `Y MW power`.
- `facility_total`: the source explicitly describes total facility power, total power, power capacity, power supply, site power, nameplate facility capacity, electrical connection/power serving the facility, or equivalent wording without an IT-specific qualifier. Use only when the wording makes clear the number is on the facility/grid side rather than IT load.
- `grid_connection`: the source describes contracted, requested, secured, or available electrical connection or power access for the site, or a MW figure from a permit, grid, or connection-process document. A company release can support `grid_connection` if the wording is clearly about site power access rather than a general headline capacity.
- `unspecified_headline`: the source gives a MW headline or capacity claim but does not clearly identify whether it is IT load, total/nameplate facility power, grid connection/access, backup generation, or another basis. Use this for ambiguous MW claims such as `X MW capacity`, `X MW data centre`, `X MW campus`, `up to X MW`, unusually round headline figures, or AI-factory capacity claims without power/IT wording. The build script treats this conservatively as facility/grid-side and derives IT load using PUE, while flagging the row for audit.
- `backup_generation`: the source describes only backup generation, diesel reserve, or permitted backup power.
- `reactor`: the source describes reactor, SMR, or other generation capacity rather than load.
- `rack_density`: the source gives MW per rack, rack row, or similar density rather than campus capacity.

Use the country overlay for local-language equivalents.

Do not set `interpreted_it_load_mw` equal to `reported_capacity_mw` unless `reported_capacity_basis = it_load`. For `facility_total`, `grid_connection`, and `unspecified_headline`, leave `interpreted_it_load_mw` blank unless there is a specific reason to propose a manual override. The build script derives IT load from `reported_capacity_mw / PUE`.

`facility_total`, `grid_connection`, and `unspecified_headline` are evidentiary basis labels, not additive capacity types. They all receive the same conservative PUE-based derivation in the build. Do not create multiple capacity rows for the same MW claim just because sources describe it as nameplate/facility capacity, grid connection, or headline capacity. Choose the best-supported basis and document ambiguity in `notes`.

Keep `capacity_type` and `reported_capacity_basis` separate. `capacity_type` describes the row shape, such as `facility_capacity`, `initial_phase_capacity`, `incremental_expansion`, `cumulative_site_capacity`, or `full_campus_potential`. `reported_capacity_basis` describes what the MW number means.

## Investment decision

Treat `investment_decision = yes` as a strong claim. Do not default candidate rows to `yes`.

An investment decision means a real decision to proceed with material capital deployment for the project, phase, or capacity item. It may be explicit, or it may be inferred from strong execution evidence.

Use `yes` when public evidence directly shows a decision point, such as final investment decision, board approval, financial close, committed investment, decided to build, construction start, operational facility, awarded main construction contract, signed lease or anchor-customer agreement tied to the site/phase, public procurement award, or financed construction plan.

You may infer `yes` without the exact words "investment decision" only when the evidence is strong. Require a named site plus at least two execution signals such as committed capex, appointed contractor, construction schedule, anchor customer, procurement award, building permit being acted on, or secured grid connection for the specific phase.

Use `no` when sources describe a future possibility, marketing plan, site selection, permit, land allocation, grid discussion, MoU, target year, or long-term expansion option without evidence that the decision to execute has been taken.

Use `unclear` when the wording sounds committed but the source does not expose the actual decision point.

Capacity-level `investment_decision` must be supported for that specific phase or capacity claim. Do not copy commitment from an initial phase to a full-campus potential row.

Project-level `investment_decision = yes` is allowed when at least one material phase has a public investment decision, is under construction, or is operational, even if later phases remain `no` or `unclear`.

## Timing and scenario hints

If a source explicitly says a project or phase is under construction, set `construction_start_year` for the matching capacity-claim candidate. Prefer the exact construction-start year when the source gives one. If the source says construction is underway but gives no exact start year, use the `source_date` year; if the source is undated, use the `access_date` year and explain this in `notes`.

Do not use the access-date year for merely planned, permitted, marketed, preparatory, or grid-connection-only projects. Leave timing blank unless the source supports it.

An under-construction capacity claim with `investment_decision = yes` should normally be tagged `low_2030; stated_2030; stated_2035; high_2035`, unless there is specific evidence that the capacity will not be relevant before 2030.

## Required project candidate fields

- `project_candidate_id`
- `country`
- `developer`
- `project_name`
- `bidding_zone`
- `county`
- `municipality`
- `type`
- `project_status`
- `investment_decision`
- `construction_start_years`
- `expected_operational_years`
- `max_reported_capacity_mw`
- `source_url`
- `source_title`
- `source_date`
- `access_date`
- `evidence_excerpt`
- `confidence`
- `notes`

## Required capacity-claim candidate fields

- `capacity_candidate_id`
- `project_candidate_id`
- `project_id`
- `country`
- `project_name`
- `phase`
- `capacity_type`
- `capacity_status`
- `investment_decision`
- `reported_capacity_mw`
- `reported_capacity_basis`
- `interpreted_it_load_mw`
- `start_year`
- `construction_start_year`
- `scenario_tag`
- `type`
- `source_url`
- `source_title`
- `source_date`
- `access_date`
- `evidence_excerpt`
- `confidence`
- `notes`

Do not add candidates to master data.
