suppressPackageStartupMessages({
  library(dplyr)
  library(jsonlite)
  library(readr)
  library(stringr)
  library(tibble)
})

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

repo_root <- find_repo_root(dirname(script_path()))
admin_units_path <- file.path(repo_root, "data", "master", "admin_units.csv")
country_config_path <- file.path(repo_root, "data", "master", "country_config.csv")

scb_url <- "https://www.scb.se/en/finding-statistics/regional-statistics/regional-divisions/counties-and-municipalities/counties-and-municipalities-in-numerical-order/"
statfi_corr_url <- "https://api.stat.fi/classificationservice/open/api/classifications/v2/correspondenceTables/kunta_1_20260101%23maakunta_1_20260101/maps?content=data&meta=min&format=json&lang=%s"
ssb_corr_url <- "https://data.ssb.no/api/klass/v1/correspondencetables/2800?language=%s"

fieldnames <- c(
  "country",
  "country_name",
  "municipality_code",
  "municipality_name",
  "municipality_name_local",
  "municipality_name_en",
  "municipality_name_sv",
  "municipality_name_fi",
  "municipality_name_nb",
  "municipality_name_nn",
  "region_code",
  "region_name",
  "region_name_local",
  "region_name_en",
  "region_name_sv",
  "region_name_fi",
  "region_name_nb",
  "region_name_nn",
  "municipality_term_local",
  "region_term_local",
  "valid_from",
  "source_authority",
  "source_url",
  "source_version"
)

fetch_text <- function(url) {
  paste(readLines(url, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
}

fetch_json <- function(url) {
  fromJSON(fetch_text(url), simplifyVector = FALSE)
}

html_unescape <- function(x) {
  replacements <- c(
    "&amp;" = "&",
    "&nbsp;" = " ",
    "&aring;" = "å",
    "&auml;" = "ä",
    "&ouml;" = "ö",
    "&Aring;" = "Å",
    "&Auml;" = "Ä",
    "&Ouml;" = "Ö"
  )
  for (entity in names(replacements)) {
    x <- gsub(entity, replacements[[entity]], x, fixed = TRUE)
  }
  x
}

blank_row <- function(country, country_name) {
  row <- as.list(rep("", length(fieldnames)))
  names(row) <- fieldnames
  row$country <- country
  row$country_name <- country_name
  as_tibble(row)
}

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

classification_name <- function(item, lang) {
  names <- item$classificationItemNames
  if (length(names) == 0) {
    return("")
  }
  for (name in names) {
    if (!is.null(name$lang) && identical(name$lang, lang)) {
      return(name$name %||% "")
    }
  }
  names[[1]]$name %||% ""
}

build_sweden <- function() {
  page <- fetch_text(scb_url)
  blocks <- str_match_all(
    page,
    regex('<h2><a id="[^"]+"></a>(\\d{2})\\s+([^<]+)</h2>\\s*<p>(.*?)</p>', dotall = TRUE)
  )[[1]]
  rows <- list()
  for (i in seq_len(nrow(blocks))) {
    region_code <- blocks[i, 2]
    region_name <- str_trim(html_unescape(blocks[i, 3]))
    municipality_html <- blocks[i, 4]
    entries <- str_match_all(municipality_html, "(\\d{4})\\s+([^<]+)(?:<br\\s*/?>|$)")[[1]]
    if (nrow(entries) == 0) {
      next
    }
    for (j in seq_len(nrow(entries))) {
      municipality_code <- entries[j, 2]
      municipality_name <- str_trim(html_unescape(entries[j, 3]))
      rows[[length(rows) + 1]] <- blank_row("SE", "Sweden") %>%
        mutate(
          municipality_code = municipality_code,
          municipality_name = municipality_name,
          municipality_name_local = municipality_name,
          municipality_name_sv = municipality_name,
          region_code = region_code,
          region_name = region_name,
          region_name_local = region_name,
          region_name_sv = region_name,
          municipality_term_local = "kommun",
          region_term_local = "län",
          valid_from = "2026-01-01",
          source_authority = "Statistics Sweden (SCB)",
          source_url = scb_url,
          source_version = "Counties and municipalities 2026"
        )
    }
  }
  bind_rows(rows)
}

build_finland <- function() {
  by_lang <- setNames(
    lapply(c("fi", "sv", "en"), function(lang) fetch_json(sprintf(statfi_corr_url, lang))),
    c("fi", "sv", "en")
  )
  by_code <- list()
  for (lang in names(by_lang)) {
    for (item in by_lang[[lang]]) {
      municipality_code <- item$sourceItem$code
      region_code <- item$targetItem$code
      by_code[[municipality_code]][[lang]] <- list(
        municipality_name = classification_name(item$sourceItem, lang),
        region_code = region_code,
        region_name = classification_name(item$targetItem, lang)
      )
    }
  }

  rows <- lapply(sort(names(by_code)), function(municipality_code) {
    names <- by_code[[municipality_code]]
    fi <- names$fi
    blank_row("FI", "Finland") %>%
      mutate(
        municipality_code = municipality_code,
        municipality_name = fi$municipality_name,
        municipality_name_local = fi$municipality_name,
        municipality_name_en = names$en$municipality_name,
        municipality_name_sv = names$sv$municipality_name,
        municipality_name_fi = fi$municipality_name,
        region_code = fi$region_code,
        region_name = fi$region_name,
        region_name_local = fi$region_name,
        region_name_en = names$en$region_name,
        region_name_sv = names$sv$region_name,
        region_name_fi = fi$region_name,
        municipality_term_local = "kunta/kaupunki",
        region_term_local = "maakunta",
        valid_from = "2026-01-01",
        source_authority = "Statistics Finland",
        source_url = "https://stat.fi/en/luokitukset/corrmaps/kunta_1_20260101%23maakunta_1_20260101",
        source_version = "Municipalities and regions 2026 correspondence table"
      )
  })
  bind_rows(rows)
}

build_norway <- function() {
  by_lang <- setNames(
    lapply(c("nb", "nn", "en"), function(lang) fetch_json(sprintf(ssb_corr_url, lang))),
    c("nb", "nn", "en")
  )
  by_code <- list()
  for (lang in names(by_lang)) {
    for (item in by_lang[[lang]]$correspondenceMaps) {
      municipality_code <- item$targetCode
      by_code[[municipality_code]][[lang]] <- list(
        municipality_name = item$targetName,
        region_code = item$sourceCode,
        region_name = item$sourceName
      )
    }
  }

  rows <- lapply(sort(names(by_code)), function(municipality_code) {
    names <- by_code[[municipality_code]]
    nb <- names$nb
    blank_row("NO", "Norway") %>%
      mutate(
        municipality_code = municipality_code,
        municipality_name = nb$municipality_name,
        municipality_name_local = nb$municipality_name,
        municipality_name_en = names$en$municipality_name,
        municipality_name_nb = nb$municipality_name,
        municipality_name_nn = names$nn$municipality_name,
        region_code = nb$region_code,
        region_name = nb$region_name,
        region_name_local = nb$region_name,
        region_name_en = names$en$region_name,
        region_name_nb = nb$region_name,
        region_name_nn = names$nn$region_name,
        municipality_term_local = "kommune",
        region_term_local = "fylke",
        valid_from = "2026-01-01",
        source_authority = "Statistics Norway (SSB)",
        source_url = "https://data.ssb.no/api/klass/v1/correspondencetables/2800",
        source_version = "Fylkesinndeling 2026 - Kommuneinndeling 2026"
      )
  })
  bind_rows(rows)
}

build_country_config <- function() {
  tribble(
    ~country, ~country_name, ~active, ~canonical_name_language, ~search_languages, ~municipality_field, ~municipality_term_local, ~municipality_term_en, ~region_field, ~region_term_local, ~region_term_en, ~source_authority, ~source_url, ~valid_from,
    "SE", "Sweden", "TRUE", "sv", "sv; en", "municipality", "kommun", "municipality", "county", "län", "county", "Statistics Sweden (SCB)", scb_url, "2026-01-01",
    "FI", "Finland", "TRUE", "fi", "fi; sv; en", "municipality", "kunta/kaupunki", "municipality/city", "county", "maakunta", "region", "Statistics Finland", "https://stat.fi/en/luokitukset/corrmaps/kunta_1_20260101%23maakunta_1_20260101", "2026-01-01",
    "NO", "Norway", "TRUE", "nb", "nb; nn; en", "municipality", "kommune", "municipality", "county", "fylke", "county", "Statistics Norway (SSB)", "https://data.ssb.no/api/klass/v1/correspondencetables/2800", "2026-01-01"
  )
}

rows <- bind_rows(build_sweden(), build_finland(), build_norway()) %>%
  select(all_of(fieldnames)) %>%
  arrange(country, municipality_code)

write_csv(rows, admin_units_path, na = "")

country_config <- build_country_config()
write_csv(country_config, country_config_path, na = "")

counts <- rows %>%
  count(country, name = "n") %>%
  mutate(label = paste0(country, "=", n)) %>%
  pull(label)

message("Wrote ", admin_units_path)
message("Counts: ", paste(counts, collapse = ", "))
message("Wrote ", country_config_path)
