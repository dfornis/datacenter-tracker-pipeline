validate_state <- function(path, root, schema = read_json(file.path(root, 'config/schema.json')), stop_on_error = TRUE) {
  errors <- character(); warnings <- character()
  fail <- function(message) errors <<- c(errors, message)
  warn <- function(message) warnings <<- c(warnings, message)
  tables <- list()
  for (name in names(schema$tables)) {
    spec <- schema$tables[[name]]; p <- file.path(path, spec$path)
    data <- tryCatch(read_table(p), error = function(e) { fail(conditionMessage(e)); NULL })
    if (is.null(data)) next
    tables[[name]] <- data
    absent <- setdiff(names(spec$columns), names(data)); extra <- setdiff(names(data), names(spec$columns))
    if (length(absent)) fail(paste(name, 'missing columns', paste(absent, collapse = ', ')))
    if (length(extra)) fail(paste(name, 'unknown columns', paste(extra, collapse = ', ')))
    keys <- unlist(spec$key)
    if (all(keys %in% names(data))) {
      joined <- do.call(paste, c(data[keys], sep = '\r'))
      if (anyDuplicated(joined)) fail(paste(name, 'duplicate primary key', paste(unique(joined[duplicated(joined)]), collapse = ', ')))
    }
    for (field in intersect(names(spec$columns), names(data))) {
      rule <- spec$columns[[field]]; values <- data[[field]]; present <- nzchar(values)
      bad <- rep(FALSE, length(values))
      if (isTRUE(rule$required)) bad <- bad | !present
      if (!is.null(rule$pattern)) bad <- bad | (present & !grepl(rule$pattern, values))
      type <- rule$type
      if (type %in% c('number', 'year')) {
        valid <- grepl('^[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)([eE][+-]?[0-9]+)?$', values)
        converted <- num(values)
        valid <- valid & is.finite(converted)
        if (!is.null(rule$min)) valid <- valid & converted >= rule$min
        if (!is.null(rule$max)) valid <- valid & converted <= rule$max
        if (type == 'year') valid <- valid & grepl('^[0-9]{4}$', values) & converted >= 1900 & converted <= 2200
        bad <- bad | (present & !valid)
      }
      if (type == 'date') bad <- bad | (present & !valid_date(values))
      if (type == 'datetime') {
        valid <- grepl('^[0-9]{4}-[0-9]{2}-[0-9]{2}T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]Z$', values) & valid_date(substr(values, 1, 10))
        bad <- bad | (present & !valid)
      }
      if (type == 'enum') bad <- bad | (present & !values %in% unlist(schema$enums[[rule$enum]]))
      if (type == 'choice') bad <- bad | (present & !values %in% unlist(rule$values))
      if (type == 'boolean') bad <- bad | (present & !values %in% c('TRUE', 'FALSE'))
      if (type == 'url') bad <- bad | (present & !grepl('^https?://[^/[:space:]]+[^[:space:]]*$', values))
      if (type == 'tags') bad <- bad | vapply(values, function(v) any(!split_values(v) %in% unlist(schema$enums[[rule$enum]])), logical(1))
      if (any(bad)) fail(paste(name, field, 'invalid row(s)', paste(which(bad), collapse = ',')))
    }
  }
  # Relational checks run only after structural checks, so diagnostics never hide malformed input.
  if (!length(errors)) {
    p <- tables$projects_master; c <- tables$capacity_master; s <- tables$sources_master
    g <- tables$geography_config; countries <- tables$country_config; admin <- tables$admin_units
    registry <- tables$identity_registry
    if (any(admin$municipality_code=='9999' & admin$country=='NO')) fail('Norway Uoppgitt is a statistical placeholder, not a project municipality')
    refs <- function(values, allowed, label, allow_blank = TRUE) {
      bad <- setdiff(unique(values), c(allowed, if (allow_blank) '' else character()))
      if (length(bad)) fail(paste(label, 'unknown reference(s)', paste(bad, collapse = ', ')))
    }
    refs(p$country, countries$country[countries$active == 'TRUE'], 'project country', FALSE)
    refs(p$bidding_zone, g$bidding_zone[g$active == 'TRUE'], 'project zone', FALSE)
    if (any(p$country != g$country[match(p$bidding_zone, g$bidding_zone)], na.rm = TRUE)) fail('Project country/zone mismatch')
    if (!setequal(countries$country[countries$active == 'TRUE'], unique(g$country[g$active == 'TRUE']))) fail('Country and zone active flags disagree')
    refs(c$project_id, p$project_id, 'capacity project_id', FALSE)
    pi <- match(c$project_id, p$project_id)
    if (any(c$country != p$country[pi], na.rm = TRUE)) fail('Capacity country differs from project')
    if (any(c$project_name != p$project_name[pi], na.rm = TRUE)) fail('Capacity project_name differs from project')
    if (any(c$physical_site_id != p$physical_site_id[pi], na.rm = TRUE)) fail('Capacity physical_site_id differs from project')
    if (anyDuplicated(c$phase_id[!nzchar(c$superseded_by_claim_id)])) fail('Multiple current interpretations of one phase_id')
    refs(s$project_id, p$project_id, 'source project_id')
    refs(s$claim_id, c$claim_id, 'source claim_id')
    linked <- nzchar(s$claim_id)
    if (any(s$project_id[linked] != c$project_id[match(s$claim_id[linked], c$claim_id)], na.rm = TRUE)) fail('Source claim/project mismatch')
    if (any(!nzchar(s$project_id) & !nzchar(s$claim_id))) fail('Source must identify an entity')
    if (any(nzchar(s$source_date) & s$source_date > s$access_date)) fail('Source publication date after access date')
    for (i in seq_len(nrow(s))) {
      precision <- s$source_date_precision[i]; raw <- s$source_date_raw[i]
      valid <- switch(precision, day = valid_date(raw), month = grepl('^[0-9]{4}-(0[1-9]|1[0-2])$', raw),
                      year = grepl('^[0-9]{4}$', raw), unknown = !nzchar(raw), FALSE)
      if (!valid || (precision == 'day' && s$source_date[i] != raw) || (precision != 'day' && nzchar(s$source_date[i]))) fail(paste('Inconsistent source date precision', s$source_id[i]))
      if (nzchar(raw) && raw > substr(s$access_date[i],1,nchar(raw))) fail(paste('Source publication is after access at its stated precision',s$source_id[i]))
      entity_cols <- names(schema$tables[[if (nzchar(s$claim_id[i])) 'capacity_master' else 'projects_master']]$columns)
      # Legacy sources sometimes support both site and claim; a verified field still needs explicit support.
      allowed <- if (s$review_state[i] == 'verified') entity_cols else union(names(schema$tables$capacity_master$columns), names(schema$tables$projects_master$columns))
      allowed <- union(allowed, c('confidence'))
      refs(split_values(s$supports_fields[i]), allowed, paste('supports_fields', s$source_id[i]), FALSE)
      if (s$review_state[i] == 'verified') {
        if (!nzchar(s$original_excerpt[i]) || !nzchar(s$original_language[i]) || !nzchar(s$locator[i]) || !nzchar(s$reviewed_by[i]) || !nzchar(s$reviewed_at[i])) fail(paste('Verified source lacks original evidence/review', s$source_id[i]))
        if (!s$evidence_kind[i] %in% c('verbatim','translation')) fail(paste('Verified source is not verbatim evidence', s$source_id[i]))
      }
    }
    for (entity in c('project','claim','source','observation')) {
      ids <- switch(entity, project = p$project_id, claim = c$claim_id, source = s$source_id, observation = tables$capacity_observations$observation_id)
      active <- registry$entity_id[registry$entity_type == entity & registry$state == 'active']
      if (!setequal(ids, active)) fail(paste(entity, 'identity ledger differs from active master IDs'))
    }
    refs(p$physical_site_id, registry$entity_id[registry$entity_type == 'site' & registry$state == 'active'], 'physical site', FALSE)
    refs(c$phase_id, registry$entity_id[registry$entity_type == 'phase' & registry$state == 'active'], 'phase', FALSE)
    for (data in list(p,c)) {
      basis <- data$decision_basis; decision <- data$investment_decision
      if (any(basis=='no_public_evidence' & decision!='unclear') || any(basis=='explicit_nondecision' & decision!='no') ||
          any(basis %in% c('explicit_decision','execution_evidence') & decision!='yes') || any(basis=='not_applicable' & decision!='not_applicable') ||
          any(basis=='conditional_commitment' & decision!='unclear')) fail('Decision value contradicts its evidence basis')
      if (any(data$review_state=='verified' & basis=='legacy_unverified')) fail('A verified record cannot retain an unverified decision basis')
    }
    for (entity in c('project','claim','source','site','phase','observation')) {
      prefix <- switch(entity, project='P',claim='C',source='S',site='SITE',phase='PH',observation='OBS')
      if (any(!grepl(paste0('^',prefix,'[0-9]{3,}$'), registry$entity_id[registry$entity_type == entity]))) fail(paste('Malformed identity',entity))
    }
    if (any(registry$state == 'retired' & !nzchar(registry$retired_in))) fail('Retired identity lacks retirement provenance')
    if (any(num(c$reported_capacity_mw) == 0)) warn('Zero-capacity observations are retained but not counted')
    if (any(nzchar(c$capacity_max_mw) & num(c$capacity_max_mw) < num(c$reported_capacity_mw))) fail('Capacity range is reversed')
    if (any(c$capacity_qualifier == 'range' & !nzchar(c$capacity_max_mw))) fail('Range qualifier requires upper capacity')
    if (any(nzchar(c$operation_year_min) != nzchar(c$operation_year_max))) fail('Commissioning interval needs both endpoints')
    if (any(num(c$operation_year_min) > num(c$operation_year_max), na.rm = TRUE)) fail('Commissioning interval reversed')
    if (any(nzchar(c$start_year) & c$start_year != c$operation_year_min)) fail('Legacy start_year must equal interval lower endpoint')
    if (any(nzchar(c$construction_start_year) & nzchar(c$operation_year_max) & num(c$construction_start_year) > num(c$operation_year_max))) fail('Construction starts after commissioning interval')
    if (any(c$capacity_unit == 'MW_thermal' & !c$reported_capacity_basis %in% c('backup_generation','reactor'))) fail('Thermal capacity cannot represent electrical load')
    if (any(c$capacity_unit == 'MW_per_rack' & c$reported_capacity_basis != 'rack_density')) fail('Density unit/basis mismatch')
    if (any(c$reported_capacity_basis == 'rack_density' & c$capacity_unit != 'MW_per_rack')) fail('Rack density requires density unit')
    if (any(nzchar(c$interpreted_it_load_mw) & c$reported_capacity_basis != 'it_load')) fail('Manual IT conversion requires separate source-supported IT observation')
    if (any(c$reported_capacity_basis == 'it_load' & nzchar(c$interpreted_it_load_mw) & num(c$interpreted_it_load_mw) != num(c$reported_capacity_mw))) fail('IT override contradicts observed IT measure')
    for (field in c('source_ids','timing_source_ids','decision_source_ids','pue_source_ids','overlap_source_ids')) {
      refs(unlist(lapply(c[[field]], split_values)), s$source_id, paste('capacity', field), FALSE)
    }
    refs(c$parent_claim_id, c$claim_id, 'parent claim')
    refs(c$baseline_claim_id, c$claim_id, 'baseline claim')
    refs(c$superseded_by_claim_id, c$claim_id, 'superseding claim')
    if (any(c$relation != 'independent' & !nzchar(c$parent_claim_id))) fail('Non-independent claim needs an explicit parent')
    if (any(c$relation == 'independent' & nzchar(c$parent_claim_id))) fail('Independent claim cannot have a parent')
    if (any(c$relation == 'incremental_to' & c$capacity_type != 'incremental_expansion')) fail('Incremental relationship requires an incremental capacity observation')
    if (any(c$capacity_type == 'incremental_expansion' & c$baseline_scope != 'new_capacity')) fail('An already incremental observation must not subtract its baseline again')
    if (any(c$baseline_comparable == 'TRUE' & !nzchar(c$baseline_claim_id))) fail('Comparable baseline requires baseline_claim_id')
    if (any(c$baseline_scope == 'existing_known' & c$baseline_comparable != 'TRUE')) fail('Known baseline must be comparable')
    if (any(c$baseline_scope != 'existing_known' & c$baseline_comparable == 'TRUE')) fail('Comparable baseline has wrong scope')
    if (any(c$accounting_group_id != c$physical_site_id)) fail('Accounting groups must identify physical sites')
    for (i in seq_len(nrow(c))) {
      id <- c$claim_id[i]
      # Follow both containment and supersession independently to detect cycles.
      for (field in c('parent_claim_id','superseded_by_claim_id','baseline_claim_id')) {
        seen <- id; next_id <- c[[field]][i]
        while (nzchar(next_id) && next_id %in% c$claim_id) {
          if (next_id %in% seen) { fail(paste('Cyclic', field, id)); break }
          seen <- c(seen, next_id); next_id <- c[[field]][match(next_id, c$claim_id)]
        }
      }
      for (field in c('parent_claim_id','baseline_claim_id')) {
        other <- c[[field]][i]
        if (nzchar(other) && other %in% c$claim_id && c$physical_site_id[i] != c$physical_site_id[match(other,c$claim_id)]) fail(paste(field, 'crosses physical sites', id))
      }
      if (c$baseline_comparable[i] == 'TRUE' && c$baseline_claim_id[i] %in% c$claim_id) {
        bi <- match(c$baseline_claim_id[i], c$claim_id)
        if (c$reported_capacity_basis[i] != c$reported_capacity_basis[bi] || c$capacity_unit[i] != c$capacity_unit[bi] || c$capacity_status[bi] != 'Operational' || c$measurement_kind[i] != c$measurement_kind[bi] || !c$measurement_kind[bi] %in% c('nameplate_capacity','peak_demand')) fail(paste('Incomparable baseline', id))
        if (num(c$reported_capacity_mw[i]) < num(c$reported_capacity_mw[bi])) fail(paste('Capacity below baseline', id))
      }
      linked_sources <- split_values(c$source_ids[i])
      if (!length(linked_sources)) fail(paste('Capacity has no evidence link', id))
      allowed_sources <- s$source_id[s$project_id == c$project_id[i] & (!nzchar(s$claim_id) | s$claim_id == id)]
      if (any(!linked_sources %in% allowed_sources)) fail(paste('Capacity evidence supports a different entity', id))
      if (c$review_state[i] == 'verified' && (!nzchar(c$reviewed_by[i]) || !nzchar(c$reviewed_at[i]))) fail(paste('Verified capacity lacks reviewer', id))
      if (nzchar(c$site_pue[i]) && (!nzchar(c$site_pue_kind[i]) || !nzchar(c$site_pue_qualifier[i]) || !nzchar(c$pue_source_ids[i]))) fail(paste('PUE lacks evidence/kind/qualifier', id))
      for (field in c('timing_source_ids','decision_source_ids','pue_source_ids','overlap_source_ids')) {
        ids <- split_values(c[[field]][i])
        # Project-level evidence may describe execution, but may not silently support another site.
        if (any(!ids %in% allowed_sources)) fail(paste(field,'supports another entity',id))
      }
    }
    o <- tables$capacity_observations
    refs(o$claim_id,c$claim_id,'observation claim',FALSE)
    for (i in seq_len(nrow(o))) {
      ci <- match(o$claim_id[i],c$claim_id)
      if (is.na(ci)) next
      ids <- split_values(o$source_ids[i]); refs(ids,s$source_id,'observation evidence',FALSE)
      if (any(!ids %in% s$source_id[s$claim_id == o$claim_id[i]])) fail(paste('Observation evidence lacks exact claim scope',o$observation_id[i]))
      if (o$basis[i] == c$reported_capacity_basis[ci]) fail(paste('Observation duplicates primary measure; revise the claim instead',o$observation_id[i]))
      if (o$unit[i] != c$capacity_unit[ci]) fail(paste('Alternate observation has incompatible unit',o$observation_id[i]))
      if (o$review_state[i] == 'verified' && (anyNA(match(ids,s$source_id)) || any(s$review_state[match(ids,s$source_id)] != 'verified'))) fail('Verified observation needs verified evidence')
    }
    if (anyDuplicated(paste(o$claim_id,o$basis))) fail('Conflicting alternate observations need explicit resolution')
    if (any(o$qualifier == 'range' & !nzchar(o$value_max))) fail('Observation range needs upper bound')
    if (any(num(o$value_max) < num(o$value),na.rm=TRUE)) fail('Observation range reversed')
    f <- tables$field_reviews
    for (i in seq_len(nrow(f))) {
      entity <- switch(f$entity_type[i],project=p,claim=c,source=s)
      key <- switch(f$entity_type[i],project='project_id',claim='claim_id',source='source_id')
      ei <- match(f$entity_id[i],entity[[key]])
      if (is.na(ei) || !f$field[i] %in% names(entity)) { fail('Field review refers to unknown entity/field'); next }
      if (sha_value(entity[[f$field[i]]][ei]) != f$value_sha256[i]) fail(paste('Stale field review',f$entity_id[i],f$field[i]))
      ids <- split_values(f$source_ids[i]); refs(ids,s$source_id,'field review evidence',FALSE)
      if (!length(ids) || anyNA(match(ids,s$source_id)) || any(s$review_state[match(ids,s$source_id)] != 'verified')) fail('Field review requires verified source evidence')
      if (f$entity_type[i] != 'source') {
        allowed <- if (f$entity_type[i] == 'claim') s$source_id[s$claim_id == f$entity_id[i]] else s$source_id[s$project_id == f$entity_id[i] & !nzchar(s$claim_id)]
        if (any(!ids %in% allowed)) fail('Field review evidence targets another entity')
        supported <- any(vapply(s$supports_fields[match(ids,s$source_id)],function(v) f$field[i] %in% split_values(v),logical(1)))
        if (!supported) fail(paste('Field is not supported by cited evidence',f$field[i]))
      }
    }
    for (entity in c('project','claim')) {
      records <- if(entity=='project') p else c; key <- if(entity=='project') 'project_id' else 'claim_id'
      for(i in which(records$review_state=='verified')) {
        fields <- f$field[f$entity_type==entity & f$entity_id==records[[key]][i]]
        if(any(!unlist(schema$verification_fields[[entity]]) %in% fields))fail(paste('Verified record lacks complete field reviews',records[[key]][i]))
      }
    }
    admin_key <- paste(admin$country, admin$municipality_code, sep = ':')
    loc <- tables$municipality_locations
    for (i in seq_len(nrow(p))) {
      ai <- match(paste(p$country[i], p$municipality_code[i], sep = ':'), admin_key)
      if (is.na(ai)) { fail(paste('Unknown municipality code', p$project_id[i])); next }
      base_name <- trimws(sub('\\s*\\([^)]*\\)\\s*$', '', p$municipality[i]))
      if (base_name != admin$municipality_name[ai] || p$county[i] != admin$region_name[ai] || p$region_code[i] != admin$region_code[ai]) fail(paste('Administrative name/code mismatch', p$project_id[i]))
      if (!p$project_status[i] %in% c('Cancelled','Dormant') && !paste(p$country[i],p$municipality[i]) %in% paste(loc$country,loc$municipality)) warn(paste('Missing approximate display location', p$project_id[i]))
    }
    a <- tables$assumptions
    if (any(num(a$low) > num(a$high), na.rm = TRUE)) fail('Assumption range reversed')
    if (any(nzchar(a$value) & nzchar(a$low) & num(a$value) < num(a$low), na.rm = TRUE) || any(nzchar(a$value) & nzchar(a$high) & num(a$value) > num(a$high), na.rm = TRUE)) fail('Assumption central value outside sensitivity range')
    pue <- a$assumption_type == 'PUE'; lf <- a$assumption_type == 'Annual load factor'
    for (field in c('value','low','high')) {
      if (any(num(a[[field]][pue]) < 1, na.rm = TRUE)) fail('PUE below one')
      if (any(num(a[[field]][lf]) < 0 | num(a[[field]][lf]) > 1, na.rm = TRUE)) fail('Load factor outside [0,1]')
    }
    d <- tables$deployment_schedule
    refs(d$claim_id,c$claim_id,'deployment claim',FALSE)
    refs(d$assumption_id,a$assumption_id,'deployment assumption')
    refs(unlist(lapply(d$source_ids,split_values)),s$source_id,'deployment evidence',FALSE)
    if (any(num(d$average_year_fraction) > num(d$year_end_fraction))) fail('Average deployment exceeds end-year fraction')
    if (any(d$basis=='source' & !nzchar(d$source_ids)) || any(d$basis=='model_assumption' & !nzchar(d$assumption_id))) fail('Deployment schedule lacks basis')
    for (id in unique(d$claim_id)) {
      schedule <- d[d$claim_id==id,,drop=FALSE]; schedule <- schedule[order(num(schedule$year)),,drop=FALSE]
      if (any(diff(num(schedule$year_end_fraction)) < 0)) fail('Cumulative deployment cannot decrease')
      if (nrow(schedule)>1 && any(num(schedule$average_year_fraction[-1]) < num(head(schedule$year_end_fraction,-1)))) fail('Average deployment below previous end-year fraction')
    }
    for (i in seq_len(nrow(d))) {
      ids <- split_values(d$source_ids[i])
      if (d$review_state[i] == 'verified' && d$basis[i]=='source' && (anyNA(match(ids,s$source_id)) || any(s$review_state[match(ids,s$source_id)]!='verified') || any(!ids %in% s$source_id[s$claim_id==d$claim_id[i]]))) fail('Verified deployment needs verified same-claim source')
      if (d$basis[i]=='model_assumption' && !d$assumption_id[i] %in% a$assumption_id[a$denominator_kind=='incremental_capacity']) fail('Deployment assumption has incompatible denominator')
    }
    # Review rows can be incomplete while pending. Approval creates a binding contract.
    for (name in names(tables)[grepl('^(suggested_|new_)', names(tables))]) {
      r <- tables[[name]]; approved <- r$review_state == 'approved'
      if (any(approved & (!nzchar(r$reviewed_by) | !nzchar(r$reviewed_at)))) fail(paste('Approved rows lack reviewer', name))
      if (any(approved & !nzchar(r$source_url))) fail(paste('Approved rows lack source URL', name))
    }
    if (any(s$review_state != 'verified')) warn(paste(sum(s$review_state != 'verified'), 'source links await field-level verification'))
  }
  result <- list(valid = !length(errors), errors = unique(errors), warnings = unique(warnings))
  if (stop_on_error && length(errors)) stop(paste(c('Data validation failed:', paste0('- ', unique(errors))), collapse = '\n'), call. = FALSE)
  result
}
