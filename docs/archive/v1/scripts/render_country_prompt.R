suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(stringr)
})

arg_value <- function(name) {
  prefix <- paste0("--", name, "=")
  match <- grep(paste0("^", prefix), commandArgs(trailingOnly = TRUE), value = TRUE)
  if (length(match) == 0) {
    return(NA_character_)
  }
  sub(paste0("^", prefix), "", match[[1]])
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
    if (file.exists(file.path(current, "data", "master", "geography_config.csv"))) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("Could not find repository root", call. = FALSE)
    }
    current <- parent
  }
}

task <- str_to_lower(arg_value("task"))
country_arg <- str_to_upper(arg_value("country"))

if (is.na(task) || !(task %in% c("audit", "discover"))) {
  stop("Use --task=audit or --task=discover", call. = FALSE)
}

if (is.na(country_arg) || country_arg == "") {
  stop("Use --country=<country code>", call. = FALSE)
}

repo_root <- find_repo_root(dirname(script_path()))
geography_config <- read_csv(file.path(repo_root, "data", "master", "geography_config.csv"), show_col_types = FALSE) %>%
  mutate(country = str_to_upper(country), active = as.logical(active)) %>%
  filter(active)

if (!(country_arg %in% geography_config$country)) {
  stop("Country is not active in data/master/geography_config.csv: ", country_arg, call. = FALSE)
}

template_path <- file.path(repo_root, "prompts", paste0(task, "_template.md"))
overlay_path <- file.path(repo_root, "prompts", "country_overlays", paste0(str_to_lower(country_arg), ".md"))

if (!file.exists(template_path)) {
  stop("Missing template: ", template_path, call. = FALSE)
}

if (!file.exists(overlay_path)) {
  stop("Missing country overlay: ", overlay_path, call. = FALSE)
}

country_rows <- geography_config %>%
  filter(.data$country == country_arg) %>%
  arrange(bidding_zone)

header <- paste0(
  "# Rendered ", str_to_title(task), " Prompt: ", country_arg, "\n\n",
  "- country: `", country_arg, "`\n",
  "- country_name: `", unique(country_rows$country_name)[[1]], "`\n",
  "- bidding_zones: `", paste(country_rows$bidding_zone, collapse = "`, `"), "`\n\n"
)

cat(header)
cat(paste(readLines(template_path, warn = FALSE), collapse = "\n"))
cat("\n\n---\n\n")
cat(paste(readLines(overlay_path, warn = FALSE), collapse = "\n"))
cat("\n")
