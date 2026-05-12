library(readr)
library(dplyr)
library(jsonlite)
library(sf)
library(purrr)
library(stringr)
library(tibble)
library(tidyr)

script_path <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE))
  }

  frames <- sys.frames()
  frame_files <- vapply(frames, function(frame) {
    if (!is.null(frame$ofile)) frame$ofile else NA_character_
  }, character(1))
  frame_files <- frame_files[!is.na(frame_files)]
  if (length(frame_files) > 0) {
    return(normalizePath(frame_files[[length(frame_files)]], mustWork = TRUE))
  }

  NA_character_
}

find_repo_root <- function(start_dir) {
  current <- normalizePath(start_dir, mustWork = TRUE)

  repeat {
    if (
      dir.exists(file.path(current, "data", "master")) &&
        file.exists(file.path(current, "scripts", "build_datacenter_data.R"))
    ) {
      return(current)
    }

    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not find repository root from ", start_dir, call. = FALSE)
    }
    current <- parent
  }
}

arg_value <- function(name) {
  prefix <- paste0("--", name, "=")
  match <- grep(paste0("^", prefix), commandArgs(trailingOnly = TRUE), value = TRUE)
  if (length(match) == 0) {
    return(NA_character_)
  }
  sub(paste0("^", prefix), "", match[[1]])
}

resolve_path <- function(path, base_dir) {
  if (is.na(path) || path == "") {
    return(NA_character_)
  }

  if (grepl("^(/|[A-Za-z]:)", path) || startsWith(path, "~")) {
    return(normalizePath(path, mustWork = FALSE))
  }

  normalizePath(file.path(base_dir, path), mustWork = FALSE)
}

detected_script_path <- script_path()
repo_root <- if (!is.na(detected_script_path)) {
  find_repo_root(dirname(detected_script_path))
} else {
  find_repo_root(getwd())
}

# Paths
csv_dir <- file.path(repo_root, "data")
master_dir <- file.path(csv_dir, "master")
default_json_dir <- file.path(repo_root, "assets", "data", "datacenters")
json_dir_arg <- arg_value("output-dir")
json_dir_env <- Sys.getenv("DATACENTER_TRACKER_OUTPUT_DIR", unset = NA_character_)
json_dir <- resolve_path(
  dplyr::coalesce(json_dir_arg, json_dir_env, default_json_dir),
  repo_root
)

dir.create(json_dir, recursive = TRUE, showWarnings = FALSE)

master_path <- function(master_name, legacy_name) {
  path <- file.path(master_dir, master_name)
  if (file.exists(path)) {
    return(path)
  }
  file.path(csv_dir, legacy_name)
}

# Read CSV master files
projects_path <- master_path("projects_master.csv", "projects.csv")
capacity_path <- master_path("capacity_master.csv", "capacity.csv")
assumptions_path <- master_path("assumptions.csv", "assumptions.csv")
sources_path <- master_path("sources_master.csv", "sources_master.csv")
municipality_locations_path <- master_path("municipality_locations.csv", "municipality_locations.csv")

projects <- read_csv(projects_path, show_col_types = FALSE)
capacity <- read_csv(capacity_path, show_col_types = FALSE)
assumptions <- read_csv(assumptions_path, show_col_types = FALSE)
municipality_locations <- read_csv(municipality_locations_path, show_col_types = FALSE)
sources <- if (file.exists(sources_path)) {
  read_csv(sources_path, show_col_types = FALSE)
} else {
  tibble(
    source_id = character(),
    project_id = character(),
    claim_id = character(),
    source_date = character(),
    access_date = character()
  )
}

# Basic validation
required_project_cols <- c(
  "project_id", "project_name", "developer",
  "bidding_zone", "county", "municipality",
  "type", "project_status", "investment_decision", "notes"
)

missing_project_cols <- setdiff(required_project_cols, names(projects))

if (length(missing_project_cols) > 0) {
  stop("Missing columns in ", projects_path, ": ",
       paste(missing_project_cols, collapse = ", "))
}

required_capacity_cols <- c(
  "claim_id", "project_id", "capacity_type",
  "capacity_status", "investment_decision",
  "reported_capacity_mw", "reported_capacity_basis", "interpreted_it_load_mw",
  "start_year", "construction_start_year", "scenario_tag"
)

missing_capacity_cols <- setdiff(required_capacity_cols, names(capacity))

if (length(missing_capacity_cols) > 0) {
  stop("Missing columns in ", capacity_path, ": ",
       paste(missing_capacity_cols, collapse = ", "))
}

required_municipality_location_cols <- c(
  "municipality", "latitude", "longitude", "coordinate_note"
)

missing_municipality_location_cols <- setdiff(
  required_municipality_location_cols,
  names(municipality_locations)
)

if (length(missing_municipality_location_cols) > 0) {
  stop("Missing columns in ", municipality_locations_path, ": ",
       paste(missing_municipality_location_cols, collapse = ", "))
}

# Check controlled values
allowed_status <- c(
  "Concept study", "Planned", "Permitted", "Under construction",
  "Operational", "Dormant", "Cancelled", "Unclear"
)

public_excluded_statuses <- c("Operational", "Dormant", "Cancelled")

allowed_bidding_zones <- c("SE1", "SE2", "SE3", "SE4")

allowed_investment_decision <- c("yes", "no", "unclear", "not_applicable")

allowed_reported_capacity_basis <- c(
  "it_load",
  "facility_total",
  "grid_connection",
  "unspecified_headline",
  "backup_generation",
  "reactor",
  "rack_density"
)

non_load_capacity_basis <- c("backup_generation", "reactor", "rack_density")

bad_project_status <- setdiff(unique(projects$project_status), allowed_status)

if (length(bad_project_status) > 0) {
  stop("Unexpected project_status values: ", paste(bad_project_status, collapse = ", "))
}

bad_project_zones <- projects %>%
  filter(is.na(bidding_zone) | !(bidding_zone %in% allowed_bidding_zones)) %>%
  pull(project_id)

if (length(bad_project_zones) > 0) {
  stop(
    "Project rows must use exactly one bidding_zone value from SE1, SE2, SE3, SE4. ",
    "Invalid project_id values: ",
    paste(bad_project_zones, collapse = ", ")
  )
}

bad_capacity_status <- setdiff(unique(capacity$capacity_status), allowed_status)

if (length(bad_capacity_status) > 0) {
  stop("Unexpected capacity_status values: ", paste(bad_capacity_status, collapse = ", "))
}

bad_project_decision <- setdiff(unique(projects$investment_decision), allowed_investment_decision)

if (length(bad_project_decision) > 0) {
  stop("Unexpected project investment_decision values: ",
       paste(bad_project_decision, collapse = ", "))
}

bad_capacity_decision <- setdiff(unique(capacity$investment_decision), allowed_investment_decision)

if (length(bad_capacity_decision) > 0) {
  stop("Unexpected capacity investment_decision values: ",
       paste(bad_capacity_decision, collapse = ", "))
}

bad_reported_capacity_basis <- setdiff(
  unique(capacity$reported_capacity_basis[!is.na(capacity$reported_capacity_basis)]),
  allowed_reported_capacity_basis
)

if (length(bad_reported_capacity_basis) > 0) {
  stop("Unexpected reported_capacity_basis values: ",
       paste(bad_reported_capacity_basis, collapse = ", "))
}

# Check project_id consistency
missing_project_ids <- setdiff(capacity$project_id, projects$project_id)

if (length(missing_project_ids) > 0) {
  stop(capacity_path, " contains project_id values not found in ", projects_path, ": ",
       paste(missing_project_ids, collapse = ", "))
}

normalize_type_tags <- function(value) {
  if (is.na(value) || value == "") {
    return(character())
  }

  str_split(value, ";", simplify = FALSE)[[1]] |>
    str_trim() |>
    str_to_lower()
}

assumption_category <- function(type_value) {
  tags <- normalize_type_tags(type_value)

  has_hyperscale <- "hyperscale" %in% tags
  has_ai <- "ai" %in% tags
  has_hpc <- "hpc" %in% tags
  has_colocation <- "colocation" %in% tags
  has_research <- any(c("research", "smr-linked") %in% tags)

  if (has_research) return("Research_SMR")
  if (has_colocation && has_ai) return("Colocation_AI")
  if (has_colocation) return("Colocation")
  if (has_ai && has_hpc) return("AI_HPC")
  if (has_hyperscale && has_ai) return("Hyperscale_AI")
  if (has_hyperscale) return("Hyperscale")
  if (has_ai || has_hpc) return("AI_HPC")

  "Hyperscale"
}

assumption_values <- assumptions %>%
  mutate(value = as.numeric(value)) %>%
  select(assumption_id, value) %>%
  deframe()

assumption_value <- function(id) {
  value <- assumption_values[[id]]
  if (is.null(value)) {
    return(NA_real_)
  }
  value
}

derive_it_load_mw <- function(reported_capacity_mw, reported_capacity_basis, pue) {
  if (is.na(reported_capacity_mw) || is.na(reported_capacity_basis)) {
    return(NA_real_)
  }

  if (reported_capacity_basis == "it_load") {
    return(reported_capacity_mw)
  }

  if (reported_capacity_basis %in% c("facility_total", "grid_connection", "unspecified_headline")) {
    if (is.na(pue)) {
      return(NA_real_)
    }

    return(reported_capacity_mw / pue)
  }

  if (reported_capacity_basis %in% non_load_capacity_basis) {
    return(NA_real_)
  }

  NA_real_
}

capacity <- capacity %>%
  rowwise() %>%
  mutate(
    assumption_category = assumption_category(type),
    pue = if_else(
      reported_capacity_basis %in% non_load_capacity_basis &
        is.na(interpreted_it_load_mw),
      NA_real_,
      assumption_value(paste0("PUE_", assumption_category))
    ),
    annual_load_factor = if_else(
      reported_capacity_basis %in% non_load_capacity_basis &
        is.na(interpreted_it_load_mw),
      NA_real_,
      assumption_value(paste0("LF_", assumption_category))
    ),
    manual_interpreted_it_load_mw = interpreted_it_load_mw,
    derived_interpreted_it_load_mw = derive_it_load_mw(
      reported_capacity_mw,
      reported_capacity_basis,
      pue
    ),
    interpreted_it_load_mw = coalesce(
      manual_interpreted_it_load_mw,
      derived_interpreted_it_load_mw
    ),
    it_load_derivation_method = case_when(
      !is.na(manual_interpreted_it_load_mw) ~ "manual_override",
      !is.na(derived_interpreted_it_load_mw) ~ "derived_from_reported_capacity_basis",
      TRUE ~ "not_derived"
    ),
    reported_capacity_basis_needs_audit = reported_capacity_basis == "unspecified_headline",
    estimated_grid_side_mw = if_else(
      is.na(interpreted_it_load_mw) | is.na(pue),
      NA_real_,
      interpreted_it_load_mw * pue
    ),
    estimated_twh_year = if_else(
      is.na(estimated_grid_side_mw) | is.na(annual_load_factor),
      NA_real_,
      estimated_grid_side_mw * annual_load_factor * 8760 / 1000000
    )
  ) %>%
  ungroup()

manual_it_load_differences <- capacity %>%
  filter(
    !is.na(manual_interpreted_it_load_mw),
    !is.na(derived_interpreted_it_load_mw),
    abs(manual_interpreted_it_load_mw - derived_interpreted_it_load_mw) > 0.1
  ) %>%
  mutate(
    warning_text = paste0(
      claim_id,
      " manual=", round(manual_interpreted_it_load_mw, 2),
      " derived=", round(derived_interpreted_it_load_mw, 2),
      " basis=", reported_capacity_basis
    )
  ) %>%
  pull(warning_text)

if (length(manual_it_load_differences) > 0) {
  warning(
    "Manual interpreted_it_load_mw differs from basis-derived IT load for: ",
    paste(manual_it_load_differences, collapse = "; "),
    call. = FALSE
  )
}

latest_source_date <- function(source_date, access_date) {
  published_dates <- source_date[!is.na(source_date)]

  if (length(published_dates) > 0) {
    return(max(published_dates))
  }

  checked_dates <- access_date[!is.na(access_date)]

  if (length(checked_dates) > 0) {
    return(max(checked_dates))
  }

  as.Date(NA)
}

source_dates <- sources %>%
  mutate(
    source_date = as.Date(source_date),
    access_date = as.Date(access_date)
  )

claim_updates <- source_dates %>%
  filter(!is.na(claim_id), claim_id != "") %>%
  group_by(claim_id) %>%
  summarise(last_updated = latest_source_date(source_date, access_date), .groups = "drop")

project_updates <- source_dates %>%
  filter(!is.na(project_id), project_id != "") %>%
  group_by(project_id) %>%
  summarise(project_last_updated = latest_source_date(source_date, access_date), .groups = "drop")

capacity <- capacity %>%
  left_join(claim_updates, by = "claim_id") %>%
  left_join(project_updates, by = "project_id") %>%
  mutate(
    last_updated = coalesce(last_updated, project_last_updated),
    last_updated = as.character(last_updated)
  ) %>%
  select(-project_last_updated)

scenario_definitions <- tibble(
  scenario_id = c("low_2030", "stated_2030", "stated_2035", "high_2035"),
  scenario_label = c("Low", "Stated", "Stated", "High"),
  scenario_order = c(1, 2, 3, 4),
  year = c(2030, 2030, 2035, 2035),
  panel = c("Low", "Stated", "Stated", "High")
)

scenario_time_year <- function(start_year, construction_start_year) {
  years <- c(
    suppressWarnings(as.integer(str_extract(as.character(start_year), "^[0-9]{4}"))),
    suppressWarnings(as.integer(str_extract(as.character(construction_start_year), "^[0-9]{4}")))
  )
  years <- years[!is.na(years)]
  if (length(years) == 0) {
    return(NA_integer_)
  }
  min(years)
}

is_scenario_eligible <- function(interpreted_it_load_mw, capacity_type, reported_capacity_basis) {
  !is.na(interpreted_it_load_mw) &&
    !(capacity_type %in% c("permit_backup_power", "reactor_capacity")) &&
    !(reported_capacity_basis %in% non_load_capacity_basis)
}

site_total_capacity_types <- c("full_campus_potential", "cumulative_site_capacity")
additive_capacity_types <- c("incremental_expansion", "incremental_expansion_capacity")

is_site_total_capacity <- function(capacity_type) {
  capacity_type %in% site_total_capacity_types
}

is_additive_capacity <- function(capacity_type) {
  capacity_type %in% additive_capacity_types
}

capacity <- capacity %>%
  rowwise() %>%
  mutate(
    scenario_time_year = scenario_time_year(start_year, construction_start_year),
    scenario_eligible = is_scenario_eligible(
      interpreted_it_load_mw,
      capacity_type,
      reported_capacity_basis
    ),
    scenario_site_total = is_site_total_capacity(capacity_type),
    scenario_additive = is_additive_capacity(capacity_type)
  ) %>%
  ungroup()

scenario_capacity <- capacity %>%
  semi_join(
    projects %>%
      filter(!project_status %in% public_excluded_statuses) %>%
      select(project_id),
    by = "project_id"
  ) %>%
  filter(!capacity_status %in% public_excluded_statuses)

# Direct candidates meet the scenario rule on their own row.
scenario_direct_candidates <- bind_rows(
  scenario_capacity %>%
    filter(scenario_eligible, investment_decision == "yes", !is.na(scenario_time_year), scenario_time_year <= 2030) %>%
    mutate(scenario_id = "low_2030"),
  scenario_capacity %>%
    filter(scenario_eligible, !is.na(scenario_time_year), scenario_time_year <= 2030) %>%
    mutate(scenario_id = "stated_2030"),
  scenario_capacity %>%
    filter(scenario_eligible, !is.na(scenario_time_year), scenario_time_year <= 2035) %>%
    mutate(scenario_id = "stated_2035"),
  scenario_capacity %>%
    filter(scenario_eligible) %>%
    mutate(scenario_id = "high_2035")
) %>%
  left_join(scenario_definitions, by = "scenario_id") %>%
  mutate(scenario_match = "direct")

# Display tags also follow dated site totals down to smaller rows in the same
# project, so phase rows remain visually connected to the stated project path.
scenario_inherited_candidates <- scenario_direct_candidates %>%
  filter(scenario_site_total) %>%
  group_by(project_id, scenario_id) %>%
  summarise(
    envelope_grid_side_mw = max(estimated_grid_side_mw, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(envelope_grid_side_mw = if_else(is.infinite(envelope_grid_side_mw), NA_real_, envelope_grid_side_mw)) %>%
  inner_join(
    scenario_capacity %>%
      filter(scenario_eligible, !scenario_site_total),
    by = "project_id",
    relationship = "many-to-many"
  ) %>%
  filter(
    is.na(envelope_grid_side_mw) |
      is.na(estimated_grid_side_mw) |
      estimated_grid_side_mw <= envelope_grid_side_mw
  ) %>%
  select(-envelope_grid_side_mw) %>%
  left_join(scenario_definitions, by = "scenario_id") %>%
  mutate(scenario_match = "contained_in_project_total") %>%
  anti_join(
    scenario_direct_candidates %>% select(claim_id, scenario_id),
    by = c("claim_id", "scenario_id")
  )

scenario_candidates <- bind_rows(
  scenario_direct_candidates,
  scenario_inherited_candidates
)

choose_scenario_accounting_rows <- function(rows) {
  site_totals <- rows %>%
    filter(scenario_site_total)

  if (nrow(site_totals) > 0) {
    return(
      site_totals %>%
        arrange(desc(coalesce(estimated_grid_side_mw, -Inf)), scenario_time_year) %>%
        slice(1)
    )
  }

  additive_rows <- rows %>%
    filter(scenario_additive)
  baseline_rows <- rows %>%
    filter(!scenario_additive)

  if (nrow(additive_rows) > 0) {
    if (nrow(baseline_rows) == 0) {
      return(additive_rows)
    }

    baseline_row <- baseline_rows %>%
      arrange(desc(coalesce(estimated_grid_side_mw, -Inf)), scenario_time_year) %>%
      slice(1)

    return(bind_rows(baseline_row, additive_rows))
  }

  rows %>%
    arrange(desc(coalesce(estimated_grid_side_mw, -Inf)), scenario_time_year) %>%
    slice(1)
}

# These are the capacity rows that are actually counted in scenario totals.
# They are based on direct candidates only and collapse non-additive rows within
# the same project before zone totals are calculated.
scenario_counted_rows <- scenario_direct_candidates %>%
  group_by(scenario_id, project_id) %>%
  group_modify(~ choose_scenario_accounting_rows(.x)) %>%
  ungroup() %>%
  left_join(
    projects %>%
      select(
        project_id, developer, bidding_zone, project_status,
        project_investment_decision = investment_decision
      ),
    by = "project_id"
  ) %>%
  mutate(
    entry_id = claim_id,
    status = project_status,
    scenario_it_load_mw = interpreted_it_load_mw,
    scenario_grid_side_mw = estimated_grid_side_mw,
    interpreted_grid_load_mw = scenario_grid_side_mw,
    scenario_mw = scenario_grid_side_mw,
    load_factor = annual_load_factor,
    scenario_estimated_twh_year = estimated_twh_year,
    estimated_twh = scenario_estimated_twh_year
  ) %>%
  select(
    scenario_id, scenario_label, scenario_order, year, panel,
    project_id, entry_id, project_name, developer, bidding_zone,
    type, status, project_status, project_investment_decision,
    phase, capacity_type, capacity_status, investment_decision,
    start_year, construction_start_year,
    reported_capacity_mw, reported_capacity_basis,
    interpreted_it_load_mw, scenario_it_load_mw,
    scenario_grid_side_mw, scenario_estimated_twh_year,
    interpreted_grid_load_mw, scenario_mw,
    pue, load_factor, estimated_twh, notes
  ) %>%
  arrange(scenario_order, bidding_zone, project_id)

scenario_tags <- scenario_candidates %>%
  arrange(scenario_order) %>%
  group_by(claim_id) %>%
  summarise(scenario_tag = paste(unique(scenario_id), collapse = "; "), .groups = "drop")

capacity <- capacity %>%
  select(-scenario_tag) %>%
  left_join(scenario_tags, by = "claim_id") %>%
  mutate(scenario_tag = coalesce(scenario_tag, "")) %>%
  select(
    claim_id, project_id, project_name, phase, capacity_type,
    capacity_status, investment_decision, reported_capacity_mw,
    reported_capacity_basis, interpreted_it_load_mw,
    derived_interpreted_it_load_mw, manual_interpreted_it_load_mw,
    it_load_derivation_method, reported_capacity_basis_needs_audit,
    start_year, construction_start_year,
    scenario_tag, type, notes, assumption_category, pue,
    annual_load_factor, estimated_grid_side_mw, estimated_twh_year,
    last_updated
  )

scenario_zone <- scenario_counted_rows %>%
  group_by(scenario_id, scenario_label, scenario_order, year, bidding_zone, panel) %>%
  summarise(
    grid_side_mw = sum(scenario_grid_side_mw, na.rm = TRUE),
    mw = grid_side_mw,
    interpreted_it_load_mw = sum(scenario_it_load_mw, na.rm = TRUE),
    reported_capacity_mw = sum(reported_capacity_mw, na.rm = TRUE),
    estimated_twh = sum(scenario_estimated_twh_year, na.rm = TRUE),
    n_projects = n_distinct(project_id),
    .groups = "drop"
  ) %>%
  complete(
    nesting(scenario_id, scenario_label, scenario_order, year, panel),
    bidding_zone = c("SE1", "SE2", "SE3", "SE4"),
    fill = list(
      grid_side_mw = 0,
      mw = 0,
      interpreted_it_load_mw = 0,
      reported_capacity_mw = 0,
      estimated_twh = 0,
      n_projects = 0
    )
  ) %>%
  arrange(scenario_order, bidding_zone)

projects <- projects %>%
  left_join(project_updates, by = "project_id") %>%
  mutate(last_updated = as.character(project_last_updated)) %>%
  select(-project_last_updated)

public_projects <- projects %>%
  filter(!project_status %in% public_excluded_statuses)

missing_project_locations <- public_projects %>%
  anti_join(municipality_locations, by = "municipality") %>%
  distinct(municipality) %>%
  pull(municipality)

if (length(missing_project_locations) > 0) {
  stop(
    "Missing municipality coordinates for: ",
    paste(missing_project_locations, collapse = ", ")
  )
}

public_capacity <- capacity %>%
  semi_join(public_projects %>% select(project_id), by = "project_id") %>%
  filter(!capacity_status %in% public_excluded_statuses)

public_projects <- public_projects %>%
  left_join(municipality_locations, by = "municipality")

public_capacity <- public_capacity %>%
  left_join(
    public_projects %>%
      select(project_id, municipality, county, bidding_zone, latitude, longitude, coordinate_note),
    by = "project_id",
    suffix = c("", "_project")
  )

# Optional display table for frontend
project_display <- public_projects %>%
  left_join(
    public_capacity %>%
      filter(capacity_type != "permit_backup_power") %>%
      group_by(project_id) %>%
      summarise(
        max_reported_capacity_mw = ifelse(
          all(is.na(reported_capacity_mw)),
          NA_real_,
          max(reported_capacity_mw, na.rm = TRUE)
        ),
        max_interpreted_it_load_mw = ifelse(
          all(is.na(interpreted_it_load_mw)),
          NA_real_,
          max(interpreted_it_load_mw, na.rm = TRUE)
        ),
        max_estimated_grid_side_mw = ifelse(
          all(is.na(estimated_grid_side_mw)),
          NA_real_,
          max(estimated_grid_side_mw, na.rm = TRUE)
        ),
        max_estimated_twh_year = ifelse(
          all(is.na(estimated_twh_year)),
          NA_real_,
          max(estimated_twh_year, na.rm = TRUE)
        ),
        capacity_types = paste(sort(unique(na.omit(capacity_type))), collapse = "; "),
        .groups = "drop"
      ),
    by = "project_id"
  )

# Export JSON
write_json(public_projects, file.path(json_dir, "projects.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")
write_json(public_capacity, file.path(json_dir, "capacity.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")
write_json(assumptions, file.path(json_dir, "assumptions.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")
write_json(project_display, file.path(json_dir, "project_display.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")
write_json(scenario_zone, file.path(json_dir, "scenario_zone.json"), pretty = TRUE, auto_unbox = TRUE, na = "null")
write_csv(scenario_zone, file.path(json_dir, "scenario_zone.csv"), na = "")

message("Built JSON files in ", json_dir)

# Geo polygons
base_url <- "https://raw.githubusercontent.com/EnergieID/entsoe-py/master/entsoe/geo/geojson"
zones <- c("SE_1", "SE_2", "SE_3", "SE_4")

tryCatch(
  {
    se_zones <- map_dfr(zones, function(z) {
      url <- sprintf("%s/%s.geojson", base_url, z)
      st_read(url, quiet = TRUE) %>%
        mutate(
          bidding_zone = gsub("_", "", z)
        )
    })

    st_write(
      se_zones,
      file.path(json_dir, "bidding_zones.geojson"),
      delete_dsn = TRUE,
      quiet = TRUE
    )
  },
  error = function(e) {
    message("Could not refresh bidding zone GeoJSON: ", conditionMessage(e))
    fallback_geojson <- file.path(repo_root, "assets", "data", "bidding_zones.geojson")
    target_geojson <- file.path(json_dir, "bidding_zones.geojson")

    if (file.exists(fallback_geojson) && !file.exists(target_geojson)) {
      file.copy(fallback_geojson, target_geojson)
      message("Copied existing bidding zone GeoJSON to ", target_geojson)
    }
  }
)
