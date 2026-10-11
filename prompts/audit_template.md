# Audit Prompt Template

You are auditing an academic data centre tracker for one configured country.

Use this template together with exactly one country overlay from `prompts/country_overlays/`. The run must be scoped to one country only.

## Parameters

- `country`: required country code from `data/master/geography_config.csv`
- `country_overlay`: required overlay for the same country

## Input files

Use the following files:

- `data/master/geography_config.csv`
- `data/master/admin_units.csv`
- `data/master/country_config.csv`
- `data/master/projects_master.csv`
- `data/master/capacity_master.csv`
- `data/master/sources_master.csv`
- `docs/status_rules.md`
- `docs/schema.md`

Use `docs/schema.md` as the authoritative definition of master files, audit output files, column names, and allowed audit structure. Preserve established audit-column naming, including `country`, `audit_id`, `field`, `current_value`, `suggested_value`, and `claim_id`. Do not invent alternative filenames or column names.

Use `data/master/admin_units.csv` as the authority for `municipality` and `county` values. `municipality` may include a locality suffix in parentheses, but the base municipality before the suffix should match `municipality_name`. `county` should match `region_name`. Use `data/master/country_config.csv` and the language-specific name columns for searches and source interpretation.

## Scope

Filter `projects_master.csv` and `capacity_master.csv` to `country = <country>` before auditing. Do not audit other countries in the same run.

This task audits existing tracker records. It is conservative by design.

Do not modify master files. Do not directly edit generated tracker files. Write only to the audit output files defined in `docs/schema.md`.

Do not add new projects or phases directly to master files.

Do not run discovery inside this audit. Do not write to `data/audit/new_project_candidates.csv` unless the user explicitly asks for discovery in the same task. If a source found during audit appears to describe a different project, only mention it in the final report or record an identity/duplication issue in `source_conflicts.csv` when it affects an existing master row.

Do not treat GPU purchases, customer deployments, cloud launches, or equipment orders inside an existing data centre as new projects. They are relevant only if the source identifies a new site, phase, expansion, or capacity claim with site-specific evidence.

## Main task

For each existing project and capacity row in the selected country:

1. First validate current values against registered sources in `sources_master.csv`.
2. Then search for newer public sources only to identify updates, corrections, cancellations, changed timelines, changed developer ownership, changed capacity claims, changed status, or stronger/weaker evidence for investment decisions.
3. Check whether current values are still supported for `country`, `developer`, `municipality`, `county`, `bidding_zone`, `project_status`, project-level `investment_decision`, `reported_capacity_mw`, `interpreted_it_load_mw`, `capacity_type`, `capacity_status`, capacity-level `investment_decision`, `start_year`, `construction_start_year`, `reported_capacity_basis`, and `scenario_tag`.
4. Cross-check project-level values against capacity-level values using `docs/status_rules.md`.
5. Check that each project is one physical site in one configured bidding zone. If a row or source spans multiple bidding zones or countries, do not preserve or create it as one project.
6. Write proposed field-level changes only when the proposed value differs from the current master value.
7. Include `country` on every audit output row.
8. Record unresolved contradictions in `data/audit/source_conflicts.csv`.
9. Record inaccessible, redirected, blocked, paywalled, or otherwise problematic registered URLs in `data/audit/dead_links.csv`.

## Evidence hierarchy

When sources disagree, prefer primary or near-primary sources in this order:

1. Official company statements, annual reports, investor releases, or project pages.
2. Planning, permitting, environmental review, or court documents.
3. Grid connection, electricity network, or energy authority documents.
4. Municipal or regional documents.
5. Reputable trade press.
6. Local news.
7. Secondary summaries, databases, or reposted material.

Apply the country overlay when deciding which agencies, grid actors, document types, local terminology, and languages to prioritize.

Do not automatically prefer a newer source if it is weaker, derivative, vague, or merely repeats an older claim. Use `source_conflicts.csv` when the best interpretation remains uncertain.

## Investment-decision sanity check

Treat `investment_decision = yes` as a strong claim.

An investment decision means a real decision to proceed with material capital deployment for the project, phase, or capacity item. It may be explicit, or it may be inferred from strong execution evidence.

Use `yes` when public evidence directly shows a decision point, such as final investment decision, board approval, financial close, committed investment, decided to build, construction start, operational facility, awarded main construction contract, signed lease or anchor-customer agreement tied to the site/phase, public procurement award, or financed construction plan.

You may infer `yes` without the exact words "investment decision" only when the evidence is strong. Require a named site plus at least two execution signals such as committed capex, appointed contractor, construction schedule, anchor customer, procurement award, building permit being acted on, or secured grid connection for the specific phase.

Use `no` when sources describe a future possibility, marketing plan, site selection, permit, land allocation, grid discussion, MoU, target year, or long-term expansion option without evidence that the decision to execute has been taken.

Use `unclear` when the wording sounds committed but the source does not expose the actual decision point.

Do not use `yes` only because a project has an announced MW value, expected operation year, permit, site selection, land allocation, grid discussion, MoU, marketing page, political support, or general expansion ambition.

Capacity-level `investment_decision` must be supported for that specific phase or capacity claim. Do not copy commitment from an initial phase to a full-campus potential row.

Project-level `investment_decision = yes` is allowed when at least one material phase has a public investment decision, is under construction, or is operational, even if later phases remain `no` or `unclear`.

## Capacity interpretation rules

Classify `reported_capacity_basis` from the exact source wording that supports the MW number. Do not infer basis from the project name, data centre type, or surrounding narrative.

Use these controlled values:

- `it_load`: the source explicitly says IT load, IT capacity, critical IT load, critical load, critical power, compute capacity, or separates `X MW IT` from `Y MW power`.
- `facility_total`: the source explicitly describes total facility power, total power, power capacity, power supply, site power, nameplate facility capacity, electrical connection/power serving the facility, or equivalent wording without an IT-specific qualifier. Use only when the wording makes clear the number is on the facility/grid side rather than IT load.
- `grid_connection`: the source describes contracted, requested, secured, or available electrical connection or power access for the site, or a MW figure from a permit, grid, or connection-process document.
- `unspecified_headline`: the source gives a MW headline or capacity claim but does not clearly identify whether it is IT load, total/nameplate facility power, grid connection/access, backup generation, or another basis. Use this for ambiguous MW claims such as `X MW capacity`, `X MW data centre`, `X MW campus`, `up to X MW`, unusually round headline figures, or AI-factory capacity claims without power/IT wording. The build script treats this conservatively as facility/grid-side and derives IT load using PUE, while flagging the row for audit.
- `backup_generation`: the source describes only backup generation, diesel reserve, or permitted backup power.
- `reactor`: the source describes reactor, SMR, or other generation capacity rather than load.
- `rack_density`: the source gives MW per rack, rack row, or similar density rather than campus capacity.

Use the country overlay for local-language equivalents of IT load, facility power, grid connection power, permits, and municipal terms.

Do not set `interpreted_it_load_mw = reported_capacity_mw` unless `reported_capacity_basis = it_load`.

For `facility_total`, `grid_connection`, and `unspecified_headline`, leave `interpreted_it_load_mw` blank unless there is a specific reason to recommend a manual override. The build script derives IT load as `reported_capacity_mw / PUE`.

`facility_total`, `grid_connection`, and `unspecified_headline` are evidentiary basis labels, not additive capacity types. They all receive the same conservative PUE-based derivation in the build. Do not create or preserve multiple capacity rows for the same MW claim just because sources describe it as nameplate/facility capacity, grid connection, or headline capacity. Choose the best-supported basis and document ambiguity in `notes` or `source_conflicts.csv`.

For `backup_generation`, `reactor`, and `rack_density`, leave `interpreted_it_load_mw` blank and do not scenario-tag the row unless another source provides a separate data centre load figure.

If two sources for the same claim support different `reported_capacity_basis` values, write the disagreement to `data/audit/source_conflicts.csv` with `field = reported_capacity_basis`.

## Timing rules

If a source explicitly says a project or phase is under construction, check whether the matching project and capacity rows have construction timing. Prefer the exact construction-start year when the source gives one. If the source says construction is underway but gives no exact start year, use the `source_date` year for `construction_start_year`; if the source is undated, use the `access_date` year and explain this in `rationale`.

Do not use the access-date year for merely planned, permitted, marketed, preparatory, or grid-connection-only projects. Leave timing blank unless the source supports it.

## Scenario-tag rules

Scenario tags are for public display and filtering. They can mark smaller phase rows as relevant to a scenario when those rows sit inside a dated full-site or cumulative project path.

Do not use tags alone to decide what is added in scenario totals. Scenario totals are based on generated scenario files after de-duplication.

Operational, dormant, and cancelled rows should not carry scenario tags.

## Output rules

Use only the audit output files and column schemas defined in `docs/schema.md`:

- `data/audit/suggested_project_updates.csv`
- `data/audit/suggested_capacity_updates.csv`
- `data/audit/suggested_source_updates.csv`
- `data/audit/source_conflicts.csv`
- `data/audit/dead_links.csv`

Every proposed change must include the established audit columns from `docs/schema.md`, including `country`, source metadata, `evidence_excerpt`, `confidence`, and `rationale`.

If `source_date` is not available, leave it blank and explain this in `rationale` or `notes`. Do not invent dates from access date, copyright year, URL path, page metadata, or file metadata unless clearly tied to the source publication, decision, or document date.

## Audit ID rules

Use stable, sequential audit identifiers within each output file:

- `AP001`, `AP002`, ... for `suggested_project_updates.csv`
- `AC001`, `AC002`, ... for `suggested_capacity_updates.csv`
- `AS001`, `AS002`, ... for `suggested_source_updates.csv`

Do not reuse an existing `audit_id` for a different issue when appending to an existing audit file. A country prefix is not required because every output row has `country`.

## Final report

After writing audit files, provide a short summary with counts by output file and any high-priority manual review items.
