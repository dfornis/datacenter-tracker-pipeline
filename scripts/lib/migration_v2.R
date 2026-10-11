# One-time migration of baseline e3b85cc. No web access or fresh verification.
migrate_v1_tables <- function(input, output, root) {
  reviewed <- read_json(file.path(root,'docs/reviews/2026-10-11/granskningsunderlag.json'))$original_file_inventory
  for (file in reviewed) {
    if (grepl('^data/(master|audit)/.*[.]csv$',file$path)) {
      path <- file.path(input,sub('^data/','',file$path))
      if (!file.exists(path) || sha_file(path)!=file$sha256) stop('Legacy input differs from the reviewed baseline: ',file$path)
    }
  }
  schema <- read_json(file.path(root, 'config/schema.json'))
  tables <- list(); originals <- list()
  for (name in names(schema$tables)) {
    spec <- schema$tables[[name]]; path <- file.path(input, spec$path)
    d <- if (file.exists(path)) read_table(path) else empty_table(names(spec$columns))
    originals[[name]] <- d
    for (field in setdiff(names(spec$columns), names(d))) d[[field]] <- rep('', nrow(d))
    tables[[name]] <- d[, names(spec$columns), drop = FALSE]
  }
  migration_id <- '2026-10-11-v2-migration'
  p <- tables$projects_master; c <- tables$capacity_master; s <- tables$sources_master
  p$type <- gsub('AI/HPC', 'AI; HPC', p$type, fixed = TRUE)
  c$type <- gsub('AI/HPC', 'AI; HPC', c$type, fixed = TRUE)
  classify <- function(tags, dimension) {
    t <- split_values(tags)
    if (dimension == 'business') {
      if ('public research' %in% t || 'research' %in% t) return('public_research')
      for (v in c('colocation','hyperscale','enterprise')) if (v %in% t) return(v)
    } else {
      if ('research' %in% t || 'public research' %in% t) return('research')
      if ('AI' %in% t) return('ai_unspecified')
      if ('HPC' %in% t) return('hpc')
      if ('cloud' %in% t) return('cloud')
    }
    'unknown'
  }
  p$business_model <- vapply(p$type, classify, character(1), dimension = 'business')
  p$workload <- vapply(p$type, classify, character(1), dimension = 'workload')
  c$business_model <- p$business_model[match(c$project_id,p$project_id)]
  c$workload <- vapply(c$type, classify, character(1), dimension = 'workload')
  p$physical_site_id <- sub('^P', 'SITE', p$project_id)
  p$physical_site_id[p$project_id == 'P010'] <- 'SITE003'
  c$physical_site_id <- p$physical_site_id[match(c$project_id,p$project_id)]
  c$phase_id <- sub('^C', 'PH', c$claim_id); c$accounting_group_id <- c$physical_site_id
  admin <- tables$admin_units
  # SSB's statistical placeholder is not a municipality and cannot locate a project.
  admin <- admin[!(admin$country=='NO' & admin$municipality_code=='9999'),,drop=FALSE]
  tables$admin_units <- admin
  for (i in seq_len(nrow(p))) {
    name <- trimws(sub('\\s*\\([^)]*\\)\\s*$', '', p$municipality[i]))
    a <- which(admin$country == p$country[i] & admin$municipality_name == name)
    if (length(a) != 1L) stop('Migration cannot resolve municipality: ', p$project_id[i])
    p$municipality_code[i] <- admin$municipality_code[a]; p$region_code[i] <- admin$region_code[a]
  }
  p$decision_basis <- c$decision_basis <- 'legacy_unverified'
  p$review_state <- c$review_state <- 'legacy_unverified'
  c$capacity_unit <- 'MW_electric'; c$capacity_unit[c$claim_id == 'C022'] <- 'MW_thermal'
  c$measurement_kind <- ifelse(c$reported_capacity_basis %in% c('it_load','facility_total'),'nameplate_capacity','unspecified_capacity')
  c$measurement_kind[c$claim_id %in% c('C008','C030')] <- 'available_power'
  c$measurement_kind[c$claim_id == 'C047'] <- 'peak_demand'
  c$measurement_kind[c$claim_id == 'C022'] <- 'thermal_input'
  c$capacity_qualifier <- 'unknown'
  c$capacity_qualifier[c$claim_id %in% c('C001','C005','C038','C039','C040')] <- 'up_to'
  c$capacity_qualifier[c$claim_id %in% c('C003','C004','C042','C045','C046','C047')] <- 'approximate'
  c$operation_year_min <- c$start_year; c$operation_year_max <- c$start_year
  c$timing_scope <- ifelse(nzchar(c$start_year), 'full_capacity', 'unknown')
  c$timing_scope[c$claim_id %in% c('C005','C036','C038','C040')] <- 'first_capacity'
  c$timing_scope[c$claim_id %in% c('C008','C024')] <- 'grid_availability'
  c$operation_year_max[c$claim_id == 'C003'] <- '2040'
  c$interpretation_notes[c$claim_id == 'C003'] <- '2035–2040 is a relative 10–15-year window from the 2025 announcement, not a firm commissioning commitment; recheck original scope.'
  c$connection_status <- 'unknown'
  c$relation <- 'independent'; c$baseline_comparable <- 'FALSE'; c$baseline_scope <- 'new_capacity'
  parents <- c(C006 = 'C003', C008 = 'C004', C010 = 'C007', C016 = 'C010', C015 = 'C009',
               C018 = 'C013', C020 = 'C023', C032 = 'C033', C035 = 'C036')
  for (id in names(parents)) {
    i <- match(id, c$claim_id); c$relation[i] <- 'included_in'; c$parent_claim_id[i] <- parents[[id]]
  }
  c$relation[c$claim_id == 'C014'] <- 'possibly_included_in'
  c$parent_claim_id[c$claim_id == 'C014'] <- 'C004'
  c$overlap_source_ids[c$claim_id == 'C014'] <- 'S020'
  c$interpretation_notes[c$claim_id == 'C014'] <- 'Same Borlänge physical site is supported. Whether the reported 23 MW is contained in the operator envelope remains unresolved; do not add automatically.'
  c$baseline_claim_id[c$claim_id == 'C026'] <- 'C025'
  c$baseline_comparable[c$claim_id == 'C026'] <- 'TRUE'
  c$baseline_scope[c$claim_id == 'C026'] <- 'existing_known'
  c$interpretation_notes[c$claim_id == 'C026'] <- 'Legacy evidence describes 90 MW completed and 150 MW same-campus potential in facility power. Conditional additional envelope is 60 MW; requires fresh baseline review.'
  c$baseline_claim_id[c$claim_id == 'C031'] <- 'C030'
  c$baseline_scope[c$claim_id %in% c('C031','C033')] <- 'existing_unknown'
  c$interpretation_notes[c$claim_id == 'C031'] <- '80 MW is available power, not demonstrated installed capacity; do not subtract it from 200 MW as an installed baseline.'
  c$interpretation_notes[c$claim_id == 'C033'] <- 'Existing campus includes capacity outside the 42 MW new building. Installed same-scope baseline is not established.'
  # Preserve all original records; retire only the duplicated bindings known to be wrong.
  retired_ids <- sprintf('S%03d', 44:56)
  retired <- s[s$source_id %in% retired_ids, , drop = FALSE]
  correction <- data.frame(retired_source_id = retired_ids, replacement_source_id = sprintf('S%03d',58:70),
                           original_project_id = sprintf('P%03d',25:37), correct_project_id = sprintf('P%03d',26:38),
                           reason = 'Earlier promotion shifted project identities; later source record has correct binding', stringsAsFactors = FALSE)
  for (i in seq_len(nrow(correction))) {
    a <- originals$sources_master[match(correction$retired_source_id[i], originals$sources_master$source_id),]
    b <- originals$sources_master[match(correction$replacement_source_id[i], originals$sources_master$source_id),]
    if (a$source_url != b$source_url || a$source_title != b$source_title) stop('Source reconciliation differs from reviewed baseline')
  }
  s <- s[!s$source_id %in% retired_ids, , drop = FALSE]
  s$source_date_raw <- s$source_date
  s$source_date_precision <- ifelse(nchar(s$source_date) == 10, 'day', ifelse(nchar(s$source_date) == 7, 'month', ifelse(nchar(s$source_date) == 4, 'year', 'unknown')))
  s$source_date[s$source_date_precision != 'day'] <- ''
  s$evidence_kind <- 'summary'; s$review_state <- 'legacy_unverified'
  # Same URL always belongs to the same independence group. Cross-URL syndication requires review.
  s$independence_group <- paste0('legacy-url-', vapply(s$source_url, function(u) substr(sha_value(u),1,16), character(1)))
  for (i in seq_len(nrow(c))) {
    eligible <- s$project_id == c$project_id[i] & (!nzchar(s$claim_id) | s$claim_id == c$claim_id[i])
    c$source_ids[i] <- paste(s$source_id[eligible], collapse = ';')
    # Legacy broad support labels are retained in sources but not promoted to verified field links.
  }
  tables$projects_master <- p; tables$capacity_master <- c; tables$sources_master <- s
  g <- tables$geography_config
  g$geojson_file <- ifelse(g$country=='SE','data/reference/bidding-zones/SE.geojson',paste0('data/reference/bidding-zones/',basename(g$geojson_file)))
  tables$geography_config <- g
  a <- tables$assumptions
  a$denominator <- ifelse(a$assumption_type == 'PUE', 'annual facility energy / annual IT energy', 'annual average facility electrical load / compatible available facility nameplate MW')
  a$denominator_kind <- ifelse(a$assumption_type == 'PUE','annual_IT_energy','nameplate_capacity')
  a$parameter_status <- 'not_calibrated'; a$population <- 'Legacy Nordic modelling assumption; cited foreign evidence is not a Nordic calibration'
  a$version <- 'legacy-v1-retained'; a$valid_from <- '2026-10-11'
  a$description <- paste(a$description, 'Retained for traceability; not validated for target-year forecasting.')
  a$description[a$assumption_id == 'LF_AI_HPC'] <- 'Legacy 0.80 value retained only for traceability. Server operational time does not establish facility load factor. Not eligible as an empirical default.'
  # These are explicit methodological sensitivity cases, not a country data refresh.
  a <- rbind(a,row_frame(list(assumption_id='PUE_SENSITIVITY',assumption_type='PUE',low='1.1',high='1.5',unit='ratio',
    description='Analyst-selected PUE sensitivity bracket; endpoints are scenarios, not observed Nordic bounds. No central value.',
    source='EPRI Powering Intelligence 2026 gives efficiency context across facility types; selection of the bracket is an analyst assumption.',
    source_url='https://powering-intelligence.epri.com/annual-peak-use.html',source_locator='Section Annual and Peak Electricity Use; paragraph on capacity-weighted PUE',
    denominator='Annual facility energy / annual IT energy; applied to capacity only as a labelled model approximation',denominator_kind='annual_IT_energy',
    parameter_status='illustrative_sensitivity',population='Illustrative Nordic application of foreign technology context; not a fitted population estimate',version='2.0.0',valid_from='2026-10-11'),names(a)))
  a <- rbind(a,row_frame(list(assumption_id='LF_NAMEPLATE_SENSITIVITY',assumption_type='Annual load factor',low='0.57',high='0.75',unit='ratio',
    description='Two reference utilisation cases. Not a confidence interval, Nordic calibration or AI workload prediction. Applies to available operational nameplate, not grid connection or realised peak.',
    source='EPRI Powering Intelligence 2026 reports 0.57 for smaller multi-tenant facilities and 0.75 for one large single-tenant facility; transfer to this portfolio is illustrative.',
    source_url='https://powering-intelligence.epri.com/annual-peak-use.html',source_locator='Figure 3 and paragraph beginning Finally, we must estimate annual and hourly utilization',
    denominator='Average facility electrical load / available operational facility nameplate; deployment separately represents incremental capacity available during the year',denominator_kind='nameplate_capacity',
    parameter_status='illustrative_sensitivity',population='Small anonymous EPRI facility sample, used only as reference cases',version='2.0.0',valid_from='2026-10-11'),names(a)))
  tables$assumptions <- a
  tables$municipality_locations$accuracy <- rep('legacy_approximate', nrow(tables$municipality_locations))
  tables$municipality_locations$review_state <- rep('legacy_unverified', nrow(tables$municipality_locations))
  # Historical suggestions remain searchable but cannot be silently re-applied.
  for (name in names(tables)[grepl('^(suggested_|new_|source_conflicts$|dead_links$)', names(tables))]) {
    d <- tables[[name]]; d$run_id <- rep('legacy-2026-05-14', nrow(d)); d$review_state <- rep('pending', nrow(d))
    if ('evidence_kind' %in% names(d)) d$evidence_kind <- rep('summary', nrow(d))
    if (name == 'source_conflicts') d$conflict_id <- sprintf('LEGACY-CF%03d',seq_len(nrow(d)))
    if (name == 'dead_links' && nrow(d)) d$link_issue_id <- sprintf('LEGACY-DL%03d',seq_len(nrow(d)))
    if (grepl('^suggested_', name)) {
      target_name <- switch(name, suggested_project_updates = 'projects_master', suggested_capacity_updates = 'capacity_master', suggested_source_updates = 'sources_master')
      target <- originals[[target_name]]; key <- schema$tables[[target_name]]$key[[1]]
      for (i in seq_len(nrow(d))) {
        j <- match(d[[key]][i], target[[key]])
        if (!is.na(j) && d$field[i] %in% names(target) && target[[d$field[i]]][j] == d$suggested_value[i]) {
          d$review_state[i] <- 'already_applied'; d$resolution[i] <- paste('Baseline', 'e3b85cc', 'already contains suggested value; reconciled without reapplying')
        }
      }
    }
    tables[[name]] <- d
  }
  obs <- row_frame(list(observation_id = 'OBS001', claim_id = 'C042', basis = 'facility_total', value = '130', unit = 'MW_electric', measurement_kind='nameplate_capacity', qualifier = 'approximate', source_ids = 'S078', review_state = 'legacy_unverified', notes = 'Same VE1 option as the 100 MW IT claim. Alternate measurement, never an additive phase; original source must be rechecked.'), names(schema$tables$capacity_observations$columns))
  tables$capacity_observations <- obs
  registry <- empty_table(names(schema$tables$identity_registry$columns))
  add_ids <- function(type, ids, state = 'active', notes = '') {
    for (id in unique(ids)) registry <<- rbind(registry, row_frame(list(entity_type = type, entity_id = id, state = state, created_in = migration_id,
       retired_in = if (state == 'retired') migration_id else '', notes = notes), names(registry)))
  }
  add_ids('project', p$project_id); add_ids('claim', c$claim_id); add_ids('source', s$source_id)
  add_ids('site', p$physical_site_id); add_ids('phase', c$phase_id); add_ids('observation', obs$observation_id)
  add_ids('source', retired_ids, 'retired', 'Wrong historical project binding; see migration source reconciliation')
  add_ids('claim', 'C002', 'retired', 'Absent from active baseline; reserve historical ID permanently')
  tables$identity_registry <- registry
  archive <- file.path(output, 'audit', 'archive', migration_id)
  dir.create(archive, recursive = TRUE, showWarnings = FALSE)
  for (name in names(originals)) if (nrow(originals[[name]])) write_table(originals[[name]], file.path(archive, paste0('original_',name,'.csv')))
  write_table(correction, file.path(archive, 'source_reconciliation.csv'))
  legacy_archive <- file.path(input,'audit','archive')
  if (dir.exists(legacy_archive)) copy_directory(legacy_archive, file.path(archive, 'legacy_promotions'))
  project_history <- read_table(file.path(legacy_archive, 'promoted_new_project_candidates.csv'))
  project_history$reconciliation_state <- ifelse(project_history$project_name == p$project_name[match(project_history$promoted_project_id,p$project_id)], 'matches_current_identity', 'superseded_mapping')
  project_history$current_project_id <- p$project_id[match(project_history$project_name,p$project_name)]
  project_history$current_project_id[is.na(project_history$current_project_id)] <- ''
  write_table(project_history, file.path(archive, 'project_promotion_reconciliation.csv'))
  write_json(list(migration_id = migration_id, original_input_hashes = file_inventory(input),
    fresh_web_verification = FALSE, retired_sources = retired_ids,
    already_applied_suggestions = tables$suggested_capacity_updates$audit_id[tables$suggested_capacity_updates$review_state == 'already_applied']), file.path(archive, 'migration.json'))
  write_state_tables(tables, output, schema)
  invisible(tables)
}
