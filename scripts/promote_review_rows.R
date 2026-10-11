suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
  library(tibble)
})

arg_value <- function(name, default = NA_character_) {
  prefix <- paste0("--", name, "=")
  match <- grep(paste0("^", prefix), commandArgs(trailingOnly = TRUE), value = TRUE)
  if (length(match) == 0) {
    return(default)
  }
  sub(paste0("^", prefix), "", match[[1]])
}

has_flag <- function(name) {
  paste0("--", name) %in% commandArgs(trailingOnly = TRUE)
}

discard_empty <- function(x) {
  x[!is.na(x) & x != ""]
}

split_ids <- function(value) {
  if (is.na(value) || value == "") {
    return(character())
  }
  str_split(value, ",|;", simplify = FALSE)[[1]] %>%
    str_trim() %>%
    discard_empty()
}

script_path <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[[1]]), mustWork = TRUE))
  }
  normalizePath(getwd(), mustWork = TRUE)
}

find_repo_root <- function(start_dir) {
  current <- normalizePath(start_dir, mustWork = TRUE)
  repeat {
    if (file.exists(file.path(current, "data", "master", "projects_master.csv"))) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not find repository root", call. = FALSE)
    }
    current <- parent
  }
}

drop_empty_columns <- function(data) {
  empty_name <- is.na(names(data)) | names(data) == "" | str_detect(names(data), "^\\.\\.\\.[0-9]+$")
  empty_value <- vapply(data, function(x) all(is.na(x) | x == ""), logical(1))
  data[, !(empty_name & empty_value), drop = FALSE]
}

read_csv_chr <- function(path) {
  header <- readLines(path, n = 1, warn = FALSE)
  if (length(header) == 0) {
    return(tibble())
  }
  delim <- if (str_count(header, ";") > str_count(header, ",")) ";" else ","
  data <- read_delim(
    path,
    delim = delim,
    col_types = cols(.default = col_character()),
    show_col_types = FALSE
  )
  drop_empty_columns(data)
}

write_csv_chr <- function(x, path) {
  write_csv(x, path, na = "")
}

normalize_value <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x
}

next_ids <- function(existing, prefix, n) {
  if (n == 0) {
    return(character())
  }
  nums <- str_match(existing, paste0("^", prefix, "([0-9]+)$"))[, 2]
  width <- max(3, suppressWarnings(max(nchar(discard_empty(nums)), na.rm = TRUE)))
  if (!is.finite(width)) {
    width <- 3
  }
  start <- suppressWarnings(max(as.integer(nums), na.rm = TRUE))
  if (!is.finite(start)) {
    start <- 0
  }
  paste0(prefix, str_pad(seq.int(start + 1, length.out = n), width = width, pad = "0"))
}

select_by_country_and_ids <- function(data, id_col, country, include_ids, exclude_ids) {
  selected <- data
  if (!is.na(country) && country != "" && "country" %in% names(selected)) {
    selected <- selected %>% filter(.data$country == country)
  }
  if (length(include_ids) > 0) {
    selected <- selected %>% filter(.data[[id_col]] %in% include_ids)
  }
  if (length(exclude_ids) > 0) {
    selected <- selected %>% filter(!(.data[[id_col]] %in% exclude_ids))
  }
  selected
}

require_columns <- function(data, columns, label) {
  missing <- setdiff(columns, names(data))
  if (length(missing) > 0) {
    stop(label, " is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
  }
}

require_values <- function(data, columns, label, id_col) {
  for (column in columns) {
    bad <- data %>%
      filter(is.na(.data[[column]]) | .data[[column]] == "") %>%
      pull(.data[[id_col]])
    if (length(bad) > 0) {
      stop(
        label, " rows have blank ", column, ": ",
        paste(bad, collapse = ", "),
        call. = FALSE
      )
    }
  }
}

append_archive <- function(rows, archive_path) {
  dir.create(dirname(archive_path), recursive = TRUE, showWarnings = FALSE)
  if (file.exists(archive_path)) {
    archive <- read_csv_chr(archive_path)
    rows <- bind_rows(archive, rows)
  }
  write_csv_chr(rows, archive_path)
}

supports_fields <- function(fields) {
  paste(discard_empty(fields), collapse = ";")
}

infer_source_type <- function(url) {
  url <- str_to_lower(coalesce(url, ""))
  case_when(
    str_detect(url, "datacenterdynamics|powermag|reuters|datacentermap") ~ "media",
    str_detect(url, "ymparisto\\.fi|energiavirasto|nve\\.no|dsb\\.no") ~ "registry",
    str_detect(url, "lahti\\.fi|kajaani\\.fi|hamina\\.fi|kirkkonummi|kommune|municipal") ~ "municipal",
    TRUE ~ "company"
  )
}

resolve_source_type <- function(url, override) {
  if (!is.na(override) && override != "" && override != "infer") {
    return(rep(override, length(url)))
  }
  infer_source_type(url)
}

apply_audit_updates <- function(master, updates, id_col, force = FALSE) {
  for (i in seq_len(nrow(updates))) {
    id <- updates[[id_col]][[i]]
    field <- updates$field[[i]]
    current_value <- normalize_value(updates$current_value[[i]])
    suggested_value <- normalize_value(updates$suggested_value[[i]])

    if (!(field %in% names(master))) {
      stop("Field does not exist in master file: ", field, call. = FALSE)
    }

    idx <- which(master[[id_col]] == id)
    if (length(idx) != 1) {
      stop("Expected exactly one master row for ", id_col, "=", id, call. = FALSE)
    }

    actual_value <- normalize_value(master[[field]][[idx]])
    if (!force && !identical(actual_value, current_value)) {
      stop(
        "Current value mismatch for ", id, " field ", field,
        ". Master has `", actual_value, "`, audit row expected `", current_value, "`.",
        " Re-run with --force to override.",
        call. = FALSE
      )
    }

    master[[field]][[idx]] <- if (suggested_value == "") NA_character_ else suggested_value
  }
  master
}

apply_audit <- function(repo_root, level, country, include_ids, exclude_ids, apply, force) {
  if (!(level %in% c("project", "capacity"))) {
    stop("For --source=audit, use --level=project or --level=capacity", call. = FALSE)
  }

  master_path <- if (level == "project") {
    file.path(repo_root, "data", "master", "projects_master.csv")
  } else {
    file.path(repo_root, "data", "master", "capacity_master.csv")
  }
  audit_path <- if (level == "project") {
    file.path(repo_root, "data", "audit", "suggested_project_updates.csv")
  } else {
    file.path(repo_root, "data", "audit", "suggested_capacity_updates.csv")
  }
  master_id_col <- if (level == "project") "project_id" else "claim_id"

  master <- read_csv_chr(master_path)
  audit <- read_csv_chr(audit_path)
  selected <- select_by_country_and_ids(audit, "audit_id", country, include_ids, exclude_ids)

  if (nrow(selected) == 0) {
    message("No audit rows selected.")
    return(invisible(NULL))
  }

  message("Selected ", nrow(selected), " audit update rows from ", basename(audit_path), ".")
  print(selected %>% select(any_of(c("audit_id", "country", master_id_col, "field", "current_value", "suggested_value"))))

  if (!apply) {
    message("Dry run only. Re-run with --apply to update master and archive selected audit rows.")
    return(invisible(NULL))
  }

  updated_master <- apply_audit_updates(master, selected, master_id_col, force)
  write_csv_chr(updated_master, master_path)

  archive_rows <- selected %>% mutate(applied_at = as.character(Sys.time()))
  archive_path <- file.path(
    repo_root, "data", "audit", "archive",
    paste0("applied_", tools::file_path_sans_ext(basename(audit_path)), ".csv")
  )
  append_archive(archive_rows, archive_path)

  remaining <- anti_join(audit, selected %>% select(audit_id), by = "audit_id")
  write_csv_chr(remaining, audit_path)
  message("Applied and archived ", nrow(selected), " audit rows.")
}

promote_candidates <- function(
  repo_root,
  country,
  project_ids,
  exclude_projects,
  capacity_ids,
  exclude_capacities,
  apply,
  project_source_type,
  capacity_source_type
) {
  project_candidate_path <- file.path(repo_root, "data", "audit", "new_project_candidates.csv")
  capacity_candidate_path <- file.path(repo_root, "data", "audit", "new_capacity_claim_candidates.csv")
  master_project_path <- file.path(repo_root, "data", "master", "projects_master.csv")
  master_capacity_path <- file.path(repo_root, "data", "master", "capacity_master.csv")
  master_source_path <- file.path(repo_root, "data", "master", "sources_master.csv")

  project_candidates <- read_csv_chr(project_candidate_path)
  capacity_candidates <- read_csv_chr(capacity_candidate_path)
  projects <- read_csv_chr(master_project_path)
  capacity <- read_csv_chr(master_capacity_path)
  sources <- read_csv_chr(master_source_path)

  require_columns(project_candidates, c(
    "project_candidate_id", "country", "developer", "project_name", "bidding_zone",
    "county", "municipality", "type", "project_status", "investment_decision",
    "construction_start_years", "expected_operational_years", "max_reported_capacity_mw",
    "source_url", "source_title", "source_date", "access_date",
    "evidence_excerpt", "confidence", "notes"
  ), "new_project_candidates.csv")
  require_columns(capacity_candidates, c(
    "capacity_candidate_id", "project_candidate_id", "project_id", "country",
    "project_name", "phase", "capacity_type", "capacity_status", "investment_decision",
    "reported_capacity_mw", "reported_capacity_basis", "interpreted_it_load_mw",
    "start_year", "construction_start_year", "scenario_tag", "type",
    "source_url", "source_title", "source_date", "access_date",
    "evidence_excerpt", "confidence", "notes"
  ), "new_capacity_claim_candidates.csv")

  selected_projects <- select_by_country_and_ids(
    project_candidates,
    "project_candidate_id",
    country,
    project_ids,
    exclude_projects
  )

  selected_capacities <- select_by_country_and_ids(
    capacity_candidates,
    "capacity_candidate_id",
    country,
    capacity_ids,
    exclude_capacities
  )

  selected_project_ids <- selected_projects$project_candidate_id
  selected_capacities <- selected_capacities %>%
    filter(
      (!is.na(project_id) & project_id != "") |
        (!is.na(project_candidate_id) & project_candidate_id %in% selected_project_ids)
    )

  if (nrow(selected_projects) == 0 && nrow(selected_capacities) == 0) {
    message("No candidate rows selected.")
    return(invisible(NULL))
  }

  duplicate_projects <- selected_projects %>%
    inner_join(
      projects %>% select(existing_project_id = project_id, country, project_name),
      by = c("country", "project_name")
    )
  if (nrow(duplicate_projects) > 0) {
    print(duplicate_projects %>% select(project_candidate_id, country, project_name, existing_project_id))
    stop(
      "Selected project candidates already exist in projects_master.csv. ",
      "Rollback those master rows or remove/archive the candidate rows before running atomic candidate promotion.",
      call. = FALSE
    )
  }

  require_values(selected_projects, c(
    "country", "developer", "project_name", "bidding_zone", "county",
    "municipality", "project_status", "investment_decision", "source_url"
  ), "Project candidate", "project_candidate_id")
  require_values(selected_capacities, c(
    "country", "project_name", "phase", "capacity_type", "capacity_status",
    "investment_decision", "reported_capacity_mw", "reported_capacity_basis", "source_url"
  ), "Capacity candidate", "capacity_candidate_id")

  new_project_ids <- next_ids(projects$project_id, "P", nrow(selected_projects))
  selected_projects <- selected_projects %>%
    mutate(promoted_project_id = new_project_ids, .before = 1)
  project_map <- selected_projects %>%
    select(project_candidate_id, promoted_project_id)

  selected_capacities <- selected_capacities %>%
    left_join(project_map, by = "project_candidate_id") %>%
    mutate(resolved_project_id = coalesce(na_if(project_id, ""), promoted_project_id))

  missing_project_links <- selected_capacities %>%
    filter(is.na(resolved_project_id) | resolved_project_id == "") %>%
    pull(capacity_candidate_id)
  if (length(missing_project_links) > 0) {
    stop(
      "Capacity candidates have no selected project_candidate_id and no existing project_id: ",
      paste(missing_project_links, collapse = ", "),
      call. = FALSE
    )
  }

  future_project_ids <- c(projects$project_id, selected_projects$promoted_project_id)
  missing_master_projects <- setdiff(selected_capacities$resolved_project_id, future_project_ids)
  if (length(missing_master_projects) > 0) {
    stop(
      "Capacity candidates resolve to project_id values not present in master or this promotion: ",
      paste(missing_master_projects, collapse = ", "),
      call. = FALSE
    )
  }

  new_claim_ids <- next_ids(capacity$claim_id, "C", nrow(selected_capacities))
  selected_capacities <- selected_capacities %>%
    mutate(promoted_claim_id = new_claim_ids, .before = 1)

  next_source_ids <- next_ids(sources$source_id, "S", nrow(selected_projects) + nrow(selected_capacities))
  project_source_ids <- head(next_source_ids, nrow(selected_projects))
  capacity_source_ids <- tail(next_source_ids, nrow(selected_capacities))

  message("Selected ", nrow(selected_projects), " project candidates and ", nrow(selected_capacities), " capacity candidates.")
  if (nrow(selected_projects) > 0) {
    print(selected_projects %>%
      select(promoted_project_id, project_candidate_id, country, developer, project_name, municipality, bidding_zone, investment_decision))
  }
  if (nrow(selected_capacities) > 0) {
    print(selected_capacities %>%
      select(promoted_claim_id, capacity_candidate_id, project_candidate_id, resolved_project_id, project_name, phase, reported_capacity_mw, reported_capacity_basis))
  }

  skipped_capacities <- select_by_country_and_ids(
    capacity_candidates,
    "capacity_candidate_id",
    country,
    capacity_ids,
    exclude_capacities
  ) %>%
    filter(!capacity_candidate_id %in% selected_capacities$capacity_candidate_id)
  if (nrow(skipped_capacities) > 0) {
    message("Skipped ", nrow(skipped_capacities), " capacity candidates because their project was not selected or they were excluded.")
    print(skipped_capacities %>% select(capacity_candidate_id, project_candidate_id, project_id, project_name, phase))
  }

  if (!apply) {
    message("Dry run only. Re-run with --apply to promote selected candidates atomically.")
    return(invisible(NULL))
  }

  project_rows <- selected_projects %>%
    transmute(
      project_id = promoted_project_id,
      country,
      project_name,
      developer,
      bidding_zone,
      county,
      municipality,
      type,
      project_status,
      investment_decision,
      construction_start_years,
      expected_operational_years,
      max_reported_capacity_mw,
      notes
    )

  capacity_rows <- selected_capacities %>%
    transmute(
      claim_id = promoted_claim_id,
      project_id = resolved_project_id,
      country,
      project_name,
      phase,
      capacity_type,
      capacity_status,
      investment_decision,
      reported_capacity_mw,
      reported_capacity_basis,
      interpreted_it_load_mw,
      start_year,
      construction_start_year,
      scenario_tag,
      type,
      notes
    )

  project_source_rows <- selected_projects %>%
    mutate(promoted_source_id = project_source_ids) %>%
    transmute(
      source_id = promoted_source_id,
      project_id = promoted_project_id,
      claim_id = NA_character_,
      source_type = resolve_source_type(source_url, project_source_type),
      source_url,
      source_title,
      source_date,
      access_date,
      evidence_excerpt,
      supports_fields = supports_fields(c(
        "project_status", "investment_decision", "municipality", "county",
        "bidding_zone", "construction_start_years",
        "expected_operational_years", "max_reported_capacity_mw"
      )),
      confidence,
      notes
    )

  capacity_source_rows <- selected_capacities %>%
    mutate(promoted_source_id = capacity_source_ids) %>%
    transmute(
      source_id = promoted_source_id,
      project_id = resolved_project_id,
      claim_id = promoted_claim_id,
      source_type = resolve_source_type(source_url, capacity_source_type),
      source_url,
      source_title,
      source_date,
      access_date,
      evidence_excerpt,
      supports_fields = supports_fields(c(
        "capacity_status", "investment_decision", "reported_capacity_mw",
        "reported_capacity_basis", "capacity_type", "start_year",
        "construction_start_year", "scenario_tag"
      )),
      confidence,
      notes
    )

  write_csv_chr(bind_rows(projects, project_rows), master_project_path)
  write_csv_chr(bind_rows(capacity, capacity_rows), master_capacity_path)
  write_csv_chr(bind_rows(sources, project_source_rows, capacity_source_rows), master_source_path)

  run_id <- format(Sys.time(), "%Y%m%d%H%M%S")
  archive_dir <- file.path(repo_root, "data", "audit", "archive")
  promoted_at <- as.character(Sys.time())
  if (nrow(selected_projects) > 0) {
    append_archive(
      selected_projects %>% mutate(promotion_run_id = run_id, promoted_at = promoted_at),
      file.path(archive_dir, "promoted_new_project_candidates.csv")
    )
  }
  if (nrow(selected_capacities) > 0) {
    append_archive(
      selected_capacities %>% mutate(promotion_run_id = run_id, promoted_at = promoted_at),
      file.path(archive_dir, "promoted_new_capacity_claim_candidates.csv")
    )
  }

  remaining_projects <- anti_join(
    project_candidates,
    selected_projects %>% select(project_candidate_id),
    by = "project_candidate_id"
  )
  remaining_capacities <- anti_join(
    capacity_candidates,
    selected_capacities %>% select(capacity_candidate_id),
    by = "capacity_candidate_id"
  )
  write_csv_chr(remaining_projects, project_candidate_path)
  write_csv_chr(remaining_capacities, capacity_candidate_path)

  message("Promoted candidates in one run: ", nrow(selected_projects), " projects, ", nrow(selected_capacities), " capacity claims.")
}

main <- function() {
  source <- str_to_lower(arg_value("source"))
  level <- str_to_lower(arg_value("level", ""))
  country <- str_to_upper(arg_value("country", ""))
  apply <- has_flag("apply")
  force <- has_flag("force")

  repo_root <- find_repo_root(dirname(script_path()))

  if (source == "audit") {
    apply_audit(
      repo_root = repo_root,
      level = level,
      country = country,
      include_ids = split_ids(arg_value("ids", "")),
      exclude_ids = split_ids(arg_value("exclude", "")),
      apply = apply,
      force = force
    )
    return(invisible(NULL))
  }

  if (source == "candidates") {
    if (!is.na(level) && level != "" && level != "both") {
      stop("Candidate promotion is atomic. Use --source=candidates with no --level, or --level=both.", call. = FALSE)
    }
    promote_candidates(
      repo_root = repo_root,
      country = country,
      project_ids = split_ids(arg_value("project-ids", "")),
      exclude_projects = split_ids(arg_value("exclude-projects", "")),
      capacity_ids = split_ids(arg_value("capacity-ids", "")),
      exclude_capacities = split_ids(arg_value("exclude-capacities", "")),
      apply = apply,
      project_source_type = arg_value("project-source-type", "infer"),
      capacity_source_type = arg_value("capacity-source-type", "infer")
    )
    return(invisible(NULL))
  }

  stop("Use --source=audit or --source=candidates", call. = FALSE)
}

main()
