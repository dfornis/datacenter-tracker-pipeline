# Implementation of the review

Baseline: `e3b85cc` on `codex/validated-country-pipeline`. This commit preserves the complete reviewed working tree before implementation. The review is the acceptance specification; this checklist is not evidence of completion on its own.

## Acceptance matrix

| Review requirement | Delivered evidence | Final state |
| --- | --- | --- |
| 1 Source links and identities | Retired-ID registry, 13 repaired FI bindings, reconciliation and regression checks | Implemented; newly found C042 neighbour-site conflict blocks all scenario use |
| 2 Reviewed promotion | Frozen response/review, explicit selection, identical dry-run/apply validation, stale-parent guard, atomic pointer, replay and failure tests | Implemented; exercised by nine real-source runs |
| 3 Scenario meaning | Versioned low/stated/undated definitions, per-claim ledger and non-additive measures | Implemented; no relabelled 2035 high forecast |
| 4 Timing | Full/first capacity, construction and connection distinctions; reviewed interval/legacy-alias synchronisation | Implemented; unsupported dates cleared or held unknown |
| 5 Operational campuses | Phase eligibility and comparable installed baselines; Hamar/Lefdal cases | Implemented; unknown baselines remain excluded |
| 6 Identity and overlap | Physical-site identities, explicit containment, unresolved-overlap and identity exclusions | Implemented; Mistral, C042 and Kalberg/Undheim retain explicit factual holds |
| 7 Capacity and energy | Typed measures, intervals, PUE provenance, compatible load-factor denominator, deployment/leap-year checks | Implemented; illustrative sensitivity, no calibrated Nordic forecast |
| 8 Types and workloads | Separate canonical dimensions, unknown values, design/observed PUE | Implemented; partial factual reviews remain partial |
| 9 Decisions and evidence | Scoped decisions, execution versus absence, field reviews, short original excerpts, source groups | Implemented; 52 pilot and 117 audit proposals applied |
| 10 LLM workflow | Frozen packets, multilingual queries, complete field coverage, explicit abstention and separate second-pass review | Implemented; 15/15 real-source acceptance cases; same-agent, not independent benchmark |
| 11 Validation and releases | Locked runtime, shared contract, immutable states, complete ten-zone output, CI configuration, regression checks | Implemented; final verification recorded in `results/verification.json`; remote CI not run |
| Folder/instruction inventory | `folder-acceptance.md`, rewritten guidance, verified admin refresh, hashed archive relocation | Addressed; inherited geometry provenance/rights and five display points remain documented limits |
| Country work | Three pilots, three whole-inventory audits, three bounded discovery runs | Completed within stated scope: 38 projects searched, 46 claims covered, 15 candidates held for review; not a fully verified national census |
| Delivery | Reproducible export, source/field/ledger comparison, consumer migration guide, final Swedish report | Delivered locally on the implementation branch; no external publication |

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
- 2026-10-11: Added schema, methodology, stable identity registry, migration reconciliation, field-level evidence reviews, and complete-state transactions. At that checkpoint the migration had only been tested in temporary directories; the subsequent applied migration is recorded below.
- 2026-10-11: Added typed capacity accounting and a 184-row scenario ledger for the 46 baseline claims. The full temporary export includes all 10 zones. The 27 integration/domain tests pass, including stale values, evidence confirmations of unchanged facts, source corrections, candidate IDs, concurrent writer rejection, interrupted publication, ambiguous overlap, baseline subtraction, first-capacity dates, energy denominators, leap-year schedules and reproducible exports.
- 2026-10-11: Generated `renv.lock` (R 4.6.0; jsonlite 2.0.0; digest 0.6.39; renv 1.3.1) and restored the packages in the isolated project library. The old spatial binary dependency is no longer required by the new build. Input geometries were copied byte-for-byte into a dedicated reference directory, with explicit unresolved origin/licensing metadata.

- 2026-10-11: Implemented frozen responses, explicit second-pass decisions, review import, scope-aware pilot packets, complete no-change coverage and partial-review status. Source-specific timing/decision/PUE/overlap evidence links are derived from reviewed fields. All 36 regression tests pass.
- 2026-10-11: Applied initial validated release `r2-e6b6b27245af3290f523`; original tables preserved in `data/legacy-v1/`. Retired 13 incorrect FI bindings, reconciled 26 already-applied proposals, reserved historical IDs and removed Norway’s statistical placeholder 9999. The historical count 358 included that placeholder; the official municipality count is 357.
- 2026-10-11: Retrieved and hash-registered official 2026 references: SE 290, FI 308, NO 357. The prepared refresh changes only provenance URLs/version labels (1,022 cells), with no municipality/region code or name change.
- 2026-10-11: Replaced root instructions and generated the schema reference from its contract; added consumer migration notes. Archived old prompts/scripts/standalone output and isolated all 442 inherited world geometries. File moves are checksum-recorded. Finder metadata is no longer tracked; local files are preserved. Geometry rights/origin and five missing approximate NO display points remain explicit limitations.
- 2026-10-11: Fresh pilot source screening found Hamar’s 90/150 MW measures are IT capacity, not facility power as labelled in the legacy data. This belongs in the factual review, separately from baseline migration.

- 2026-10-11: Completed the SE/NO/FI pilots and applied 52 reviewed proposals, followed by a targeted search for all 38 existing projects and 117 reviewed audit proposals. Logged 1,308 unresolved required field checks rather than claiming full verification. Three discovery runs placed 15 project candidates in `needs_review`; no candidate was silently added to the master inventory.
- 2026-10-11: Added a hard accounting exclusion for unresolved source/site identity, exposed conflicts and candidate counts in quality output, kept empty committed subsets incomplete where evidence is missing, and prevented IT peak/unspecified measures from inheriting a nameplate load factor. The real-source acceptance suite passes 15/15 cases.
- 2026-10-11: An audit dry run caught a stale legacy `start_year` alias when commissioning intervals changed. Promotion now synchronises that compatibility field and removes any obsolete alias review. Regression checks exercise revisions and clearing.
