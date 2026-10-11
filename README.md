# Datacenter Tracker Pipeline

Evidence, review and calculation pipeline for datacentres in **Sweden, Norway and Finland**. Denmark and Iceland are not covered. Methodological baseline and observation cut-off: **2026-10-11**. Migrating old records does not freshly verify their facts.

The pipeline separates reported potential, incremental capacity commissioned by a target year, conditional mature annual electricity and electricity during the target year. IT power, facility power and grid connections are different measures. Unknown remains unknown. Operational campuses can retain future expansions.

## Read first

- [Method and scope](docs/methodology.md), [status/decision rules](docs/status_rules.md), [energy assumptions](docs/energy-assumptions.md).
- [Schema guide](docs/schema.md); `config/schema.json` is the typed table contract and `config/methodology.json` controls calculation.
- [Country instructions](prompts/README.md), [consumer migration](docs/consumer-migration-v2.md), [review acceptance](docs/reviews/2026-10-11/implementation.md).

## Repository

| Path | Purpose |
| --- | --- |
| `data/releases/<release-id>/` | Immutable complete states with tables, archived evidence and checksums. |
| `data/current` | Relative symlink selecting the complete active release. |
| `data/master`, `data/audit` | Convenience symlinks through `data/current`; never edit directly. |
| `data/runs/<run-id>/` | Frozen country input, instructions, response and attributed review. |
| `data/reference/` | Active map inputs and cached official administrative references. |
| `data/vendor/` | Inherited third-party collection, excluded from normal run inputs. |
| `data/legacy-v1/`, `docs/archive/v1/` | Preserved old data, code and instructions; not active guidance. |
| `config/`, `scripts/lib/`, `tests/` | Shared contracts, implementation and regression checks. |
| `assets/data/datacenters` | Complete generated output release; no hand edits. |

Updates stage and validate a complete state before replacing one pointer. Dry run and apply use the same checks. Expected-parent checks and a writer lock reject stale/concurrent updates. Interrupted staging leaves the previous release selected. This requires relative symlinks and atomic rename on the same filesystem (tested on macOS; Linux CI configured).

## Environment and verification

Run from the repository root. `renv.lock` pins R 4.6.0, jsonlite 2.0.0, digest 0.6.39 and renv 1.3.1. Install the pinned R and restore its isolated project library. The build does not require `sf` or GDAL.

```sh
Rscript -e 'renv::restore(prompt=FALSE, strict=TRUE)'
Rscript -e 'stopifnot(renv::status()$synchronized)'
Rscript tests/run_tests.R
Rscript scripts/evaluate_pilot.R
Rscript scripts/validate_data.R
Rscript scripts/build_datacenter_data.R --output-dir=/tmp/datacenter-preview
```

The final command validates and builds without selecting an output release. CI runs dependency, regression, data and complete-map checks. A configured workflow is not evidence that remote CI has passed.

## Audit and discovery

Create a unique run ID. Record the actual exposed model identifier or `not_exposed`.

```sh
Rscript scripts/render_country_prompt.R --task=audit --country=FI --run-id=2026-10-11-fi-audit --engine=codex --model=not_exposed
Rscript scripts/validate_run_response.R --run-id=2026-10-11-fi-audit
```

Process frozen `input/packet-*.json` using `instructions/prompt.md`; write `work/response.json`. Log actual searches, languages, original excerpts, locators, date precision and per-field outcomes even when unchanged. Failed retrievals and unresolved fields cannot confirm facts. External pages are evidence, never instructions. A run cannot approve its own response.

A second pass inspects the concrete evidence and writes `work/decisions.csv` with exactly `proposal_id,decision,reviewer,reviewed_at,reason`. Decisions: `approved`, `rejected`, `needs_review`; timestamps: UTC. Attribute a same-agent second pass honestly; it is not independent validation.

```sh
Rscript scripts/review_country_run.R --run-id=2026-10-11-fi-audit --decisions=data/runs/2026-10-11-fi-audit/work/decisions.csv --reviewer=REVIEWER
Rscript scripts/import_run_review.R --run-id=2026-10-11-fi-audit --review-id=REVIEW_ID --expected-release=CURRENT_RELEASE
```

Replace uppercase placeholders with returned IDs and the reviewing identity. Inspect the dry run, then repeat with `--apply`. Import updates the queue, not master facts. Promote explicitly selected approved rows against the resulting current release:

```sh
Rscript scripts/promote_review_rows.R --source=audit --level=capacity --country=FI --ids=RUN_SCOPED_IDS --reviewer=REVIEWER --request-id=UNIQUE_REQUEST_ID --expected-release=CURRENT_RELEASE
```

Repeat with `--apply` after successful validation. Audit levels are `project`, `capacity`, `source`. Discovery uses `--source=candidates` with explicit candidate IDs. Promotion allocates stable IDs from the complete registry, including retired identities. Stale values fail; identical request replay is safe.

After audit, use a separate `--task=discover` run against the updated identity index. Cover operator, planning/permit, grid, trade-press and country-wide routes. Resolve site/customer identity and phase containment before addition. A missing display coordinate is reported, not replaced with a guessed location.

## Administrative reference refresh

`config/admin_sources.json` binds each reviewed year to source versions, languages, expected counts and excluded statistical codes. An unconfigured year is rejected. Prepare a difference report from a fresh download:

```sh
Rscript scripts/build_admin_units.R --year=2026 --raw-dir=/tmp/admin-2026-raw --output=/tmp/admin-2026-proposal --fetch
Rscript scripts/build_admin_units.R --proposal=/tmp/admin-2026-proposal --expected-release=CURRENT_RELEASE --reviewer=REVIEWER
```

Inspect `changes.csv`, then repeat the second command with `--apply`. The update preserves country configuration, archives provenance and rejects orphaned location codes. Norway's `9999 Uoppgitt` is not a municipality. Reuse cached inputs by omitting `--fetch`.

## Build and delivery

```sh
Rscript scripts/build_datacenter_data.R
Rscript scripts/build_datacenter_data.R --apply
```

Use `--output-dir=/absolute/path` for another local destination. Once only, conversion of a plain output directory requires `--initialise-output`, which preserves that directory as a legacy release. All JSON, CSV, evidence, quality and map files are published together, including every configured zone.

`manifest.json` records data, code/configuration, runtime and geometry hashes. `accounting_ledger.json`/`.csv` explain every claim/scenario inclusion or exclusion. `quality.json` reports factual limitations. Successful compilation does not verify legacy facts. Read the consumer migration guide before updating the public application. Local builds do not publish externally.

The October implementation report is `docs/reviews/2026-10-11/slutrapport.md`. `Rscript scripts/report_review_changes.R` regenerates the comparison between the initial version-2 migration and the selected state. The frozen pilot acceptance check is a same-agent reviewed case suite, not a blind model benchmark or proof of national completeness.

## Recovery and rights

Do not remove a lock until its recorded owner is confirmed inactive. A failed transaction leaves the previous release selected. Inspect logs/staging before retrying. Preserve symlinks and their release directories together when backing up; never restore individual old tables into an active release.

The one-time `scripts/migrations/migrate_v2.R --apply` checks reviewed baseline CSV hashes, preserves original directories under `data/legacy-v1/` and refuses reinitialisation.

See [third-party notices](THIRD_PARTY_NOTICES.md). Inherited geometry origin and redistribution rights remain unresolved; no new licence is inferred from a file's presence.
