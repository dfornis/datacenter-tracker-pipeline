# Implementation of the review

Baseline: `e3b85cc` on `codex/validated-country-pipeline`. This commit preserves the complete reviewed working tree before implementation. The review is the acceptance specification; this checklist is not evidence of completion on its own.

## Acceptance matrix

| Review requirement | Required evidence | State |
| --- | --- | --- |
| 1 Source links and identities | FI source/archive reconciliation; identity ledger includes retired IDs; regression test | Implemented, tested and migrated; 13 wrong links retired with mapping |
| 2 Reviewed promotion | Same dry-run/apply validation; explicit approval and evidence; source updates; atomic state pointer; replay/concurrency/failure tests | Implemented and end-to-end regression-tested |
| 3 Scenario meaning | Versioned definitions distinguish pipeline, commissioned capacity, incremental baseline and annual energy | Implemented and regression-tested; country evidence refresh pending |
| 4 Timing | Separate observations and events; first-capacity/full-buildout scope; intervals; no construction-as-operation fallback | Implemented and regression-tested; country evidence refresh pending |
| 5 Operational campuses | Future phases remain eligible; comparable baseline subtraction; Hamar/Lefdal fixtures | Implemented and regression-tested; country evidence refresh pending |
| 6 Identity and overlap | Explicit site/phase/claim relationships; Mistral case; supersession; exported inclusion/exclusion ledger | Implemented and regression-tested; factual overlap review pending |
| 7 Capacity and energy | Typed measures/units/qualifiers; connection maturity; defined parameter denominators; ranges and trajectories; source-backed assumption register | Core implemented; literature-based sensitivity documented; factual review pending |
| 8 Types and workloads | Canonical business/workload dimensions; AI/HPC migration; no silent default; site PUE provenance | Implemented and regression-tested; source-specific PUE refresh pending |
| 9 Decisions and evidence | Decision basis separate from absence of evidence; field-specific source support; independence/confidence rules | Core implemented; country review and workflow acceptance pending |
| 10 LLM workflow | Frozen country/run inputs, searches, original quotes, locators, coverage, deterministic IDs and validation; multilingual pilot against reviewed gold cases | Workflow implemented and tested; real-source pilot in progress |
| 11 Validation and releases | Shared typed schema, referential/date/value checks, locked runtime, CI, full build including maps, manifest and reproducibility tests | Implemented; locked environment restored; 36 local tests pass; remote CI not run |
| Folder/instruction inventory | Address every row of the review's folder table, including admin refresh, geometry provenance, legacy assets and repository instructions | Pending |
| Country work | Resolve listed SE/NO/FI review issues, update source routes, perform pilot and then country audit/discovery with explicit coverage and unresolved cases | Pending |
| Delivery | Tests, reproducible release, change attribution, consumer schema migration notes and final requirement-by-requirement audit | Pending |

## Implementation decisions

- Keep CSV and R. Use shared modules for validation, release management, promotion, accounting and export.
- Store immutable complete data states under `data/releases/`; a single `data/current` symlink selects the active state. `data/master` and `data/audit` remain stable convenience paths. Updates acquire a lock, stage and validate a full state, then atomically replace the pointer. Archived evidence is never silently removed.
- Make schema and method definitions machine-readable and versioned. Documentation and rendered prompts must use those same definitions.
- Preserve source-reported facts, including unknowns and partial dates. Corrections based on this review are distinct from fresh web verification. Do not mark a source checked in October merely because its stored metadata was migrated.
- Distinguish undated portfolio potential from capacity commissioned by a target year. Annual energy requires its own explicit assumptions; mature annual equivalents are labelled separately from a target-year forecast.
- Use native GeoJSON assembly for unchanged WGS84 polygons, with required-zone, geometry, coordinate and ring validation. No coordinate reprojection is required for the current task, so the build need not depend on an incompatible spatial binary library. Geographic provenance and precision remain explicit limitations.
- Add run-scoped, auditable extraction and review outputs. Retain an independent human-readable queue for unresolved factual issues instead of filling missing facts with invented values.

## Progress log

- 2026-10-11: Created branch and committed the pre-change baseline. Verified that the active state still matches the review, including stale suggestions and mismatched FI source links.
- 2026-10-11: Added schema, methodology, stable identity registry, migration reconciliation, field-level evidence reviews, and complete-state transactions. The migration has been tested in temporary directories; it has not yet replaced the active legacy tables.
- 2026-10-11: Added typed capacity accounting and a 184-row scenario ledger for the 46 baseline claims. The full temporary export includes all 10 zones. The 27 integration/domain tests pass, including stale values, evidence confirmations of unchanged facts, source corrections, candidate IDs, concurrent writer rejection, interrupted publication, ambiguous overlap, baseline subtraction, first-capacity dates, energy denominators, leap-year schedules and reproducible exports.
- 2026-10-11: Generated `renv.lock` (R 4.6.0; jsonlite 2.0.0; digest 0.6.39; renv 1.3.1) and restored the packages in the isolated project library. The old spatial binary dependency is no longer required by the new build. Input geometries were copied byte-for-byte into a dedicated reference directory, with explicit unresolved origin/licensing metadata.

- 2026-10-11: Implemented frozen responses, explicit second-pass decisions, review import, scope-aware pilot packets, complete no-change coverage and partial-review status. Source-specific timing/decision/PUE/overlap evidence links are derived from reviewed fields. All 36 regression tests pass.
- 2026-10-11: Applied initial validated release `r2-e6b6b27245af3290f523`; original tables preserved in `data/legacy-v1/`. Retired 13 incorrect FI bindings, reconciled 26 already-applied proposals, reserved historical IDs and removed Norway’s statistical placeholder 9999. The historical count 358 included that placeholder; the official municipality count is 357.
- 2026-10-11: Retrieved and hash-registered official 2026 references: SE 290, FI 308, NO 357. The prepared refresh changes only provenance URLs/version labels (1,022 cells), with no municipality/region code or name change.
- 2026-10-11: Replaced root instructions and generated the schema reference from its contract; added consumer migration notes. Archived old prompts/scripts/standalone output and isolated all 442 inherited world geometries. File moves are checksum-recorded. Finder metadata is no longer tracked; local files are preserved. Geometry rights/origin and five missing approximate NO display points remain explicit limitations.
- 2026-10-11: Fresh pilot source screening found Hamar’s 90/150 MW measures are IT capacity, not facility power as labelled in the legacy data. This belongs in the factual review, separately from baseline migration.
