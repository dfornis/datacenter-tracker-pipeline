# Datacenter Tracker Pipeline

Self-contained data pipeline for the Swedish data centre tracker. The repository keeps reviewed CSV master data, audit notes, build scripts, and generated JSON files separate from the portfolio app that visualises the tracker.

## What This Repo Produces

Running the build script creates tracker-ready files in:

```text
assets/data/datacenters/
```

Generated outputs:

- `projects.json`
- `capacity.json`
- `assumptions.json`
- `project_display.json`
- `scenario_zone.json`
- `scenario_zone.csv`
- `bidding_zones.geojson`

These files can be copied into the portfolio/tracker project. The files under `assets/data/datacenters/` are generated and should not be edited by hand.

## Source Data

Reviewed source-of-truth files live in `data/master/`:

- `projects_master.csv`: one row per project or site
- `capacity_master.csv`: one row per capacity claim, phase, or scenario-relevant capacity item
- `assumptions.csv`: PUE and load-factor assumptions used for derived calculations
- `sources_master.csv`: source links and evidence metadata
- `municipality_locations.csv`: approximate display coordinates for public project dots

Audit work products live in `data/audit/`. They are for review and should not be imported directly into the public tracker.

Schema and interpretation rules are documented in:

- `docs/schema.md`
- `docs/status_rules.md`

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

The `sf` package may require GDAL, GEOS, and PROJ on the machine. On macOS, installing `sf` from CRAN usually handles this, but Homebrew system libraries may be needed on some setups.

## Build The Tracker Data

From the repository root:

```sh
Rscript scripts/build_datacenter_data.R
```

The script detects the repository root from its own location, so it also works when launched from another working directory:

```sh
Rscript /path/to/datacenter-tracker-pipeline/scripts/build_datacenter_data.R
```

By default, output is written to `assets/data/datacenters/`.

## Export Somewhere Else

To write directly into the portfolio/tracker project, pass an output directory:

```sh
Rscript scripts/build_datacenter_data.R --output-dir=/path/to/portfolio/assets/data/datacenters
```

Or set an environment variable:

```sh
DATACENTER_TRACKER_OUTPUT_DIR=/path/to/portfolio/assets/data/datacenters \
  Rscript scripts/build_datacenter_data.R
```

Relative output paths are resolved from this repository root.

## Notes On GeoJSON

The build tries to refresh Swedish bidding-zone polygons from the public ENTSO-E GeoJSON source. If that network refresh fails, the script keeps using the checked-in fallback at `assets/data/bidding_zones.geojson`.

## Typical Workflow

1. Update reviewed CSV files in `data/master/`.
2. Keep proposed or uncertain changes in `data/audit/` until reviewed.
3. Run `Rscript scripts/build_datacenter_data.R`.
4. Copy or export `assets/data/datacenters/` into the portfolio/tracker app.
5. Do not hand-edit generated JSON. Fix the CSV master data and rebuild instead.
