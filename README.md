# Datacenter Tracker Pipeline

This repository hosts the data pipeline for the Nordic data centre tracker. It is intentionally separate from the public tracker site: reviewed source data, audit files, prompt templates, R scripts, and generated tracker-ready files live here, while the public app consumes only the generated outputs.

## Repository Shape

- `data/master/` contains reviewed source-of-truth CSV files.
- `data/audit/` contains proposed changes, discovery candidates, conflicts, and review work products.
- `docs/` defines schemas, status rules, and capacity-interpretation rules.
- `prompts/` contains country-scoped audit and discovery prompt templates.
- `scripts/` contains the R scripts used to render prompts, promote reviewed rows, refresh administrative units, and build public tracker data.
- `assets/data/datacenters/` contains generated tracker-ready files. Do not edit these by hand.

Generated public outputs:

- `projects.json`
- `capacity.json`
- `scenario_zone.json`
- `bidding_zones.geojson`

## Pipeline Workflow

1. **Maintain shared reference data.**
   Countries, bidding zones, administrative units, assumptions, source records, and map coordinates are kept in `data/master/`. These files define the allowed geography and schema used by every later step.

2. **Refresh administrative units when needed.**
   This step updates official municipality-to-region mappings from SCB, Statistics Finland, and SSB.

   ```sh
   Rscript scripts/build_admin_units.R
   ```

   Manual review point: check that changed municipality or region names are expected before using the result in audit, discovery, or master edits.

3. **Render a country-scoped audit or discovery prompt.**
   The same base prompt is combined with one country overlay, so runs are scoped to one country without duplicating the whole instruction set.

   ```sh
   Rscript scripts/render_country_prompt.R --task=audit --country=FI
   Rscript scripts/render_country_prompt.R --task=discover --country=NO
   ```

   Agent iteration point: paste or run the rendered prompt with the agent, then iterate on ambiguous evidence, source quality, project identity, capacity basis, investment-decision status, and timing assumptions.

4. **Write proposed changes to review files, not master files.**
   Audit runs write field-level suggestions to `data/audit/suggested_*_updates.csv`.
   Discovery runs write new project candidates to `data/audit/new_project_candidates.csv` and capacity-claim candidates to `data/audit/new_capacity_claim_candidates.csv`.

   Manual review point: candidates and audit rows are deliberately not public data. Review evidence excerpts, source URLs, municipality/region names, bidding zone, investment-decision status, capacity basis, and whether capacity rows are additive or overlapping.

5. **Promote only reviewed rows.**
   Promotion is dry-run by default. Add `--apply` only after reviewing the selected rows.

   ```sh
   Rscript scripts/promote_review_rows.R --source=candidates --country=FI
   Rscript scripts/promote_review_rows.R --source=candidates --country=FI --exclude-projects=NP004 --exclude-capacities=NC002 --apply
   Rscript scripts/promote_review_rows.R --source=audit --level=project --country=SE --apply
   Rscript scripts/promote_review_rows.R --source=audit --level=capacity --country=SE --apply
   ```

   Manual review point: promotion is where reviewed audit/candidate rows become master data. Candidate promotion handles project and capacity rows together so temporary candidate IDs are replaced by permanent `project_id`, `claim_id`, and source IDs consistently.

6. **Build tracker-ready outputs from master data.**
   The build script reads only reviewed master files, validates geography and schema consistency, derives capacity metrics, assembles bidding-zone GeoJSON, and writes the public runtime files.

   ```sh
   Rscript scripts/build_datacenter_data.R
   ```

   To export directly into another project:

   ```sh
   Rscript scripts/build_datacenter_data.R --output-dir=/path/to/public-tracker/assets/data/datacenters
   ```

   Manual review point: inspect warnings and spot-check generated outputs after material data changes. If something is wrong, fix the CSV master data and rebuild; do not hand-edit generated JSON.

7. **Publish from generated outputs.**
   The public tracker should consume the generated files from `assets/data/datacenters/` or an exported copy. Working audit files, prompt files, and intermediate review files stay in this pipeline repository.

## Core Review Principles

- Master data is reviewed data; audit and candidate files are work-in-progress.
- Discovery finds possible new sites and capacity claims; it does not directly change the public tracker.
- Capacity rows are the scenario-relevant evidence units. Project rows describe sites; capacity rows describe MW claims, phases, timing, and scenario tags.
- Ambiguous MW headlines can remain included but flagged: the build applies conservative PUE-based interpretation while preserving the original reported basis.
- Operational, dormant, and cancelled records may remain in master files for audit history, but they are excluded from the forward-looking public tracker outputs.

## Requirements

Use R with these packages installed:

```r
install.packages(c(
  "readr",
  "dplyr",
  "jsonlite",
  "sf",
  "purrr",
  "stringr",
  "tibble",
  "tidyr"
))
```

The `sf` package may require GDAL, GEOS, and PROJ on the machine.
