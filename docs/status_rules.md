# Status and investment decision rules

Use the most conservative value supported by public evidence. Keep lifecycle status separate from investment decision.

## Where fields live

| field | file | meaning |
| --- | --- | --- |
| `project_status` | `data/master/projects_master.csv` | Lifecycle status for the project/site as a whole. |
| `capacity_status` | `data/master/capacity_master.csv` | Lifecycle status for the specific capacity claim or phase. |
| `investment_decision` | Both master files | Whether a real project or phase investment decision has been taken, explicitly or by strong implication from public evidence. |

`project_status` and `capacity_status` should not contain investment-decision wording. Use `investment_decision` for that.

## What counts as a project

A project is one physical site in one configured bidding zone. Do not create one project row for a national, regional, or multi-site investment spanning several bidding zones or countries.

If a source describes a broad investment across several existing data centres, record nothing as a new project until there is site-specific evidence for a new site, phase, expansion, or capacity claim. If several specific sites are named, they should be separate project rows.

## Lifecycle status values

| status | rule |
| --- | --- |
| `Concept study` | MoU, feasibility study, early concept, or strategic option without a committed project. |
| `Planned` | Public plan, site announcement, land allocation, customer marketing, early permitting, or decided future project not yet under construction. |
| `Permitted` | Material permits exist, but construction has not started. |
| `Under construction` | Construction has visibly or officially started, or the developer reports construction is underway. |
| `Operational` | The project, facility, or phase is publicly reported as opened, live, or in operation. |
| `Dormant` | Older public project with no recent progress and no clear cancellation. |
| `Cancelled` | A source states that the project has been cancelled, abandoned, or replaced by a materially different project. |
| `Unclear` | Sources are too ambiguous or conflicting for a more specific status. |

`Operational`, `Dormant`, and `Cancelled` rows can remain in the master files as audit history, but they are not part of the forward-looking public tracker table or deployment scenarios.

## Investment decision values

| value | rule |
| --- | --- |
| `yes` | Public evidence shows that the developer, owner, customer, or public procurer has decided to execute the project or the specific phase/capacity claim. |
| `no` | Public evidence shows a plan, concept, permit, marketing effort, site selection, grid connection request, MoU, target year, or long-term expansion option, but no investment decision has been identified. |
| `unclear` | Sources imply possible commitment but do not clearly show whether an investment decision has been taken, or sources conflict. |
| `not_applicable` | The row is not a data centre capacity commitment, for example a purely contextual reference. Avoid using this in master rows unless needed. |

An investment decision is a decision to proceed with material capital deployment for a site, phase, or capacity item. It is not the same as public interest, a permit, a grid enquiry, a capacity ambition, or a strategic market announcement.

Direct evidence for `yes` includes one or more of:

- Explicit wording such as final investment decision, board approval, financial close, committed investment, decided to build, or equivalent local-language wording.
- Construction has started, ground has been broken, enabling works are clearly part of the decided project execution, or the facility/phase is operational.
- A construction, EPC, design-build, or main-contractor contract has been awarded for the site/phase with a concrete delivery scope.
- A signed customer agreement, lease, anchor-tenant commitment, or public procurement award is tied to the named site/phase and implies build execution.
- A financed construction plan is public, for example named capex with financing and a concrete build schedule.

Implicit evidence for `yes` is allowed, but only when the evidence is strong enough that a reasonable reviewer would treat the investment decision as taken. As a rule of thumb, require a named site plus at least two independent execution signals, for example committed capex, appointed contractor, construction schedule, anchor customer, procurement award, building permit being acted on, or grid connection secured for the specific phase.

Use `no` when sources describe a future possibility but not an executed decision. Use `unclear` when the source language sounds committed but the underlying decision point is not visible.

- Do not mark `investment_decision = yes` only because a project has an announced capacity number, expected operation year, permit, land allocation, grid connection discussion, or marketing page.
- Capacity-level `yes` must be supported for that specific phase or capacity claim. Do not copy an initial phase commitment onto a later full-campus or long-term potential row.
- Project-level `yes` means at least one material phase of the project/site has a public investment decision, is under construction, or is operational. A project can be `yes` at project level while later capacity rows remain `no` or `unclear`.
- If a source says "investment" in a broad strategic sense, check whether it is actually a project investment decision. If not, use `no` or `unclear`.
- When changing a value to `yes`, cite the exact public evidence for the commitment in the audit rationale.

## Evidence hierarchy

Prefer primary sources over secondary sources:

1. Company announcements, annual reports, permit applications, environmental court decisions, municipal planning records, grid connection documents.
2. Trade press or local media with named sources or document references.
3. General media summaries.

If sources conflict, record the conflict in `data/audit/source_conflicts.csv` rather than forcing a single interpretation.

## Project-to-capacity consistency

Project-level fields are summaries of the evidence across one or more capacity rows. Capacity rows are the more granular evidence units. During audit, compare the two levels for internal consistency before proposing changes.

Use these general principles:

- A project-level value should be supportable from the set of capacity rows and registered sources, not only from a loose reading of the project name or notes.
- A capacity row should not automatically inherit the project-level status, investment decision, or timing. Each row should reflect what is supported for that specific phase or claim.
- If project-level and capacity-level values imply different maturity, identify which level is better supported by sources and propose the least inferential correction.
- If a project has mixed phases, use project-level fields as a concise summary of the most relevant current project/site state, and use capacity rows to preserve phase-specific differences.
- If consistency cannot be resolved from public evidence, leave the uncertain value conservative and write the issue to `data/audit/source_conflicts.csv`.

Examples of consistency issues to flag include project maturity that is not supported by any phase, phase timing copied from a broader project announcement without phase-specific support, or a full-campus potential row treated as `investment_decision = yes` only because an initial phase is `yes`.

## Capacity interpretation rules

- Do not infer IT load from backup generation capacity.
- Do not infer IT load from reactor capacity.
- Do not infer campus capacity from rack density, land area, investment value, number of GPUs, or employment unless the source explicitly links it to data centre load, facility power, grid connection, or IT capacity.
- Do not treat a GPU purchase, customer deployment, cloud launch, or equipment order inside an existing data centre as a new project unless the source identifies a new site, phase, expansion, or capacity claim.
- Mark cumulative site capacities as non-additive with earlier phase rows.
- Keep `reported_capacity_mw` exactly as the source reports it.
- Classify the source wording in `reported_capacity_basis`. Do this from the specific source text that supports the MW number, not from the project name, data centre type, or general narrative.
- Do not set `interpreted_it_load_mw = reported_capacity_mw` unless `reported_capacity_basis = it_load`.
- Normally leave `interpreted_it_load_mw` blank in master data and let the build script derive IT load from `reported_capacity_mw`, `reported_capacity_basis`, and PUE. Use manual `interpreted_it_load_mw` only as a temporary override when needed; the build script warns when it differs from the derived value.
- Treat full-campus potential separately from phase capacity with its own investment decision. A project can have `investment_decision = yes` while a later full-buildout capacity row has `investment_decision = no` or `unclear`.
- Keep `capacity_type` and `reported_capacity_basis` conceptually separate:
  - `capacity_type` says what kind of row this is: phase, expansion, cumulative total, full-campus potential, and so on.
  - `reported_capacity_basis` says what the MW number means in the source: IT load, facility power, grid connection, headline capacity, backup generation, and so on.
  - Avoid using `capacity_type = it_load` for new or audited rows when a row-shape value such as `facility_capacity`, `initial_phase_capacity`, or `full_campus_potential` is clearer.

Use these `reported_capacity_basis` rules:

| basis | rule |
| --- | --- |
| `it_load` | Use only when the source explicitly says IT load, IT capacity, critical IT load, critical load, critical power, compute capacity, IT-effekt, or separates `X MW IT` from `Y MW power`. |
| `facility_total` | Use when the source explicitly describes total facility power, power capacity, power supply, site power, nameplate facility capacity, electrical connection/power serving the facility, or equivalent local-language wording without an IT-specific qualifier. Use this only when the wording makes clear the number is on the facility/grid side rather than IT load. |
| `grid_connection` | Use when the source describes contracted, requested, secured, or available electrical connection/power access for the site: grid connection capacity, anslutningseffekt, contracted power, power feed, access to MW, or a MW figure from a permit, grid, or connection-process document. The source can be a company release if the wording is clearly about site power access rather than a general headline capacity. |
| `unspecified_headline` | Use when the source gives a MW headline or capacity claim but does not clearly identify whether it is IT load, total/nameplate facility power, grid connection/access, backup generation, or another basis. Treat this as facility/grid-side for conservative derived calculations: IT load is derived as `reported_capacity_mw / PUE`, but the generated row is flagged for audit. |
| `backup_generation` | Use when the MW figure is only backup generation, diesel reserve, or permitted backup power. Do not derive IT load. |
| `reactor` | Use when the MW figure is reactor, SMR, or other generation capacity. Do not derive IT load. |
| `rack_density` | Use when the MW figure is per rack, per row, or another density. Do not derive campus IT load. |

`facility_total`, `grid_connection`, and `unspecified_headline` are all treated as facility/grid-side inputs for conservative derived calculations: `interpreted_it_load_mw = reported_capacity_mw / PUE`. The distinction is evidentiary, not additive. Do not create separate capacity rows for the same MW claim just because one source calls it power capacity and another calls it grid connection or headline capacity. Choose the best-supported basis and record ambiguity in `notes` or `source_conflicts.csv`.

Quick guide for borderline wording:

| source wording | usual basis |
| --- | --- |
| `X MW IT load`, `X MW IT capacity`, `critical IT load`, `compute capacity`, or separate `X MW IT` and `Y MW power` | `it_load` |
| `access to X MW`, `secured X MW`, `X MW power feed`, `contracted power`, `anslutningseffekt`, or grid/permit power capacity | `grid_connection` |
| `X MW power supply`, `total power`, `site power`, `facility power`, `nameplate capacity`, `connected load`, or total electrical facility capacity without IT wording | `facility_total` |
| `X MW capacity`, `X MW data center`, `X MW campus`, `up to X MW`, `gigawatt-scale`, or oddly rounded figures with no facility, grid, or IT context | `unspecified_headline` |

If two sources linked to the same claim support different `reported_capacity_basis` values, record the issue in `data/audit/source_conflicts.csv` with `field = reported_capacity_basis`.

## Scenario tag and scenario accounting rules

Scenario tags are applied to rows in `data/master/capacity_master.csv`. They say where a row is relevant in the public table and filters. They do not mean that every tagged row is added to the scenario total.

Before a row can receive a scenario tag, the capacity row must be scenario-eligible:

- `interpreted_it_load_mw` must be populated.
- `capacity_type` must not be `permit_backup_power` or `reactor_capacity`.
- `reported_capacity_basis` must not be `backup_generation`, `reactor`, or `rack_density`.
- The project and capacity row must not be `Operational`, `Dormant`, or `Cancelled`.
- The source must support interpreting the value as data centre IT load, grid connection capacity, or site/campus capacity that can reasonably be mapped to grid demand.

Do not tag rows where the only public number is backup generation, reactor capacity, land area, investment value, or GPUs.

Use scenario tags generously enough that the public table makes sense. If a source gives a dated full-site or cumulative build-out, earlier phase rows inside that same site can share the dated scenario tag even when the earlier phase row does not have its own separate year. This keeps rows like "Phase 1" visually connected to the stated project path.

Scenario totals must avoid double counting within the same project. For each project and scenario:

- If a dated or scenario-eligible row is a site total, count that total once and do not add smaller phase rows from the same project.
- If there is no site total, count clearly additive expansion rows together with the best supported baseline row.
- If rows look like alternative ways of describing the same project capacity, count the largest supported grid-side capacity for that project and scenario.
- Keep smaller phase rows tagged when they help explain what is inside the project, even if the scenario total uses a larger row.
- If additivity is unclear, assume the rows are not additive and flag the issue during audit.

| tag | intended use |
| --- | --- |
| `low_2030` | Capacity with a public investment decision and stated operation or construction timing in or before 2030. |
| `stated_2030` | Capacity with stated operation or construction timing in or before 2030, regardless of investment decision. |
| `stated_2035` | Capacity with stated operation or construction timing in or before 2035, regardless of investment decision. Earlier phases covered by a stated full-site or cumulative 2035 path may also carry this tag. |
| `high_2035` | Broad pipeline scenario: known capacity that can reasonably be translated into data-centre grid-side capacity, even when timing is not announced. |

Leave `scenario_tag` blank where the claim is not suitable for scenario inclusion. This should normally exclude backup-power-only rows such as permit backup generation and concept rows where no IT load or grid-load interpretation is supported.

`construction_start_year` belongs in `capacity_master` because scenario tagging is phase-specific. Use it only where the source links the construction timing to that capacity row or phase. Do not copy a project-level construction year onto every full-buildout row unless the source clearly supports that interpretation.

If a source explicitly says a project or phase is `Under construction` but does not give an exact construction-start year, use the year of the dated source as `construction_start_year`. If the source is undated, use the access-date year as the public observation year and explain that limitation in `notes` or `rationale`. Do not use this rule for merely planned, permitted, marketed, or preparatory projects.
