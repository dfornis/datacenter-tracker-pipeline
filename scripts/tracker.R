# Public tracker export for dfornis.github.io (/projects/datacenter-tracker/).
#
# Writes exactly the files and fields the tracker page reads:
#   projects.json, capacity.json, scenario_zone.json, bidding_zones.geojson
# with the same scenario rules as the page's own JavaScript, so the table and
# the map agree. Values are point estimates with type-based PUE/load factor
# (config$tracker). The range/phasing model in model.R is the research output
# and is not changed by this export.

tracker_point_estimate <- function(row, cfg, category) {
  tr <- cfg$tracker
  a <- cfg$type_assumptions$categories[[category]]
  pue <- if (nzchar(row$pue)) number(row$pue) else a$pue
  lf <- a$load_factor
  mw <- number(row$mw)
  na <- list(it = NA_real_, grid = NA_real_, pue = NA_real_, lf = NA_real_)
  if (!is.finite(mw) || row$issue == 'identity_conflict' || row$basis %in% c('backup', 'generation', 'density')) return(na)
  if (startsWith(row$basis, 'it_') || (row$basis == 'unspecified' && tr$unspecified_headline_as == 'it')) {
    it <- mw; grid <- mw * pue
  } else {
    # Facility, grid, unspecified and declared facility peak: the stated MW is the grid-side figure.
    # A permit's declared peak demand is not inflated by an inverse peak/nameplate ratio here.
    grid <- mw; it <- mw / pue
  }
  list(it = it, grid = grid, pue = pue, lf = lf)
}

tracker_category <- function(type) {
  category <- type_category(type)
  if (is.na(category)) 'Hyperscale' else category
}

tracker_text <- function(x) {
  # The site uses "datacenter" throughout (site commit 04566735). Registry text keeps source wording.
  x <- gsub('([Dd])ata[ -][Cc]ent(re|er)', '\\1atacenter', x, perl = TRUE)
  x
}

tracker_basis <- function(basis) {
  map <- c(unspecified = 'unspecified_headline', grid = 'grid_connection', backup = 'backup_generation',
           generation = 'reactor', density = 'rack_density')
  if (basis %in% names(map)) return(unname(map[basis]))
  if (startsWith(basis, 'it_')) return('it_load')
  'facility_total'
}

tracker_capacity_type <- function(i, c) {
  # The register stores relations, not the old capacity_type labels. Rebuild the labels the
  # page uses for de-duplication; within-project relations decide, the phase text only labels.
  r <- c[i, ]
  if (r$basis == 'backup') return('permit_backup_power')
  if (r$basis == 'generation') return('reactor_capacity')
  same_project <- c$project_id == r$project_id
  contained <- c$relation %in% c('included_in', 'possibly_included_in')
  parent_here <- r$relation %in% c('included_in', 'possibly_included_in') &&
    isTRUE(c$project_id[match(r$parent_id, c$claim_id)] == r$project_id)
  has_children <- any(c$parent_id == r$claim_id & contained & same_project)
  if (parent_here) return(if (has_children) 'cumulative_site_capacity' else 'initial_phase_capacity')
  if (r$relation == 'incremental_to') return('incremental_expansion')
  tops <- c$claim_id[same_project & !c$basis %in% c('backup', 'generation', 'density') &
    !(contained & c$project_id[match(c$parent_id, c$claim_id)] %in% r$project_id)]
  if (length(tops) > 1) return('incremental_expansion') # explicitly independent rows are additive in the model
  if (has_children) return('full_campus_potential')
  ph <- tolower(r$phase)
  if (grepl('expansion|incremental', ph)) return('incremental_expansion')
  if (grepl('phase|first|initial', ph)) return('initial_phase_capacity')
  if (r$qualifier == 'up_to' || grepl('full|campus|potential|build-out|site', ph)) return('full_campus_potential')
  'facility_capacity'
}

latest_date <- function(sources, ids_) {
  s <- sources[sources$source_id %in% ids_, , drop = FALSE]
  pub <- s$published[grepl('^[0-9]{4}-[0-9]{2}-[0-9]{2}$', s$published)]
  acc <- s$accessed[grepl('^[0-9]{4}-[0-9]{2}-[0-9]{2}$', s$accessed)]
  if (length(pub)) return(max(pub))
  if (length(acc)) return(max(acc))
  NA_character_
}

year_list <- function(v) {
  y <- sort(unique(number(v[nzchar(v)])), decreasing = TRUE)
  if (!length(y)) NA_character_ else paste(y, collapse = '; ')
}

as_num <- function(v) { n <- number(v); if (is.finite(n)) n else NA_real_ }

tracker_scenario_year <- function(start, construction) {
  y <- c(start, construction); y <- y[is.finite(y)]
  if (length(y)) min(y) else NA_real_
}

build_tracker <- function(root = '.', data_dir = file.path(root, 'data')) {
  x <- read_inputs(root, data_dir); validate_inputs(x)
  cfg <- x$config; tr <- cfg$tracker
  p <- x$projects; c <- x$capacity; s <- x$sources
  excluded <- unlist(tr$excluded_statuses)
  public_p <- p[!p$status %in% excluded & p$record_type %in% unlist(tr$public_record_types), , drop = FALSE]
  if (any(!nzchar(public_p$type))) stop('Public tracker projects need type: ', paste(public_p$project_id[!nzchar(public_p$type)], collapse = ', '))
  if (any(!nzchar(public_p$latitude))) stop('Public tracker projects need display coordinates: ', paste(public_p$project_id[!nzchar(public_p$latitude)], collapse = ', '))
  if (any(!nzchar(public_p$bidding_zone))) stop('Public tracker projects need a bidding zone: ', paste(public_p$project_id[!nzchar(public_p$bidding_zone)], collapse = ', '))
  public_c_idx <- which(c$project_id %in% public_p$project_id & !c$status %in% excluded)

  # Capacity rows -----------------------------------------------------------
  cap <- lapply(public_c_idx, function(i) {
    r <- c[i, ]; pr <- p[match(r$project_id, p$project_id), ]
    category <- tracker_category(pr$type)
    est <- tracker_point_estimate(r, cfg, category)
    twh <- if (is.finite(est$grid)) est$grid * est$lf * 8760 / 1e6 else NA_real_
    list(claim_id = r$claim_id, project_id = r$project_id, country = pr$country,
      project_name = tracker_text(pr$project_name), phase = tracker_text(r$phase),
      capacity_type = tracker_capacity_type(i, c), capacity_status = r$status,
      investment_decision = r$decision, reported_capacity_mw = as_num(r$mw),
      reported_capacity_basis = tracker_basis(r$basis), interpreted_it_load_mw = est$it,
      derived_interpreted_it_load_mw = est$it, manual_interpreted_it_load_mw = NA_real_,
      it_load_derivation_method = if (is.finite(est$it)) 'derived_from_reported_capacity_basis' else 'not_derived',
      reported_capacity_basis_needs_audit = r$basis == 'unspecified',
      start_year = as_num(r$first_year), construction_start_year = as_num(r$construction_year),
      scenario_tag = '', type = pr$type,
      notes = tracker_text(paste(c(r$notes, if (r$issue == 'identity_conflict') 'Identity conflict: not counted as datacenter load.'), collapse = ' ')),
      assumption_category = category, pue = est$pue, annual_load_factor = est$lf,
      estimated_grid_side_mw = est$grid, estimated_twh_year = twh,
      last_updated = latest_date(s, ids(r$source_ids)),
      municipality = pr$municipality, county = pr$county, bidding_zone = pr$bidding_zone,
      latitude = as_num(pr$latitude), longitude = as_num(pr$longitude),
      coordinate_note = paste0('Approximate display point for ', pr$municipality, '.'))
  })

  # Scenario selection: identical to the page's entryMatchesScenarioDirectly and
  # chooseScenarioAccountingEntries, so table and map use the same rows.
  eligible <- function(e) is.finite(e$interpreted_it_load_mw) && !e$capacity_type %in% c('permit_backup_power', 'reactor_capacity')
  matches <- function(e, sc) {
    if (!eligible(e)) return(FALSE)
    y <- tracker_scenario_year(e$start_year, e$construction_start_year)
    switch(sc$selection,
      decided_dated = e$investment_decision == 'yes' && is.finite(y) && y <= sc$year,
      dated = is.finite(y) && y <= sc$year,
      all = TRUE)
  }
  site_total <- function(e) e$capacity_type %in% c('full_campus_potential', 'cumulative_site_capacity')
  additive <- function(e) e$capacity_type %in% c('incremental_expansion', 'incremental_expansion_capacity')
  pick <- function(es) {
    ord <- function(v) v[order(-vapply(v, function(e) if (is.finite(e$estimated_grid_side_mw)) e$estimated_grid_side_mw else -Inf, 0),
                              vapply(v, function(e) { y <- tracker_scenario_year(e$start_year, e$construction_start_year); if (is.finite(y)) y else 9999 }, 0))]
    totals <- Filter(site_total, es)
    if (length(totals)) return(ord(totals)[1])
    add <- Filter(additive, es); base <- Filter(Negate(additive), es)
    if (length(add)) return(c(if (length(base)) ord(base)[1], add))
    ord(es)[1]
  }

  tags <- setNames(vector('list', length(cap)), vapply(cap, `[[`, '', 'claim_id'))
  counted <- list()
  for (sc in cfg$scenarios) {
    direct <- Filter(function(e) matches(e, sc), cap)
    for (e in direct) tags[[e$claim_id]] <- c(tags[[e$claim_id]], sc$id)
    # Display tag: smaller rows inside a matching project total follow that total (as before).
    for (e in Filter(site_total, direct)) for (k in seq_along(cap)) {
      d <- cap[[k]]
      if (d$project_id == e$project_id && eligible(d) && !site_total(d) && !sc$id %in% tags[[d$claim_id]] &&
          (!is.finite(d$estimated_grid_side_mw) || !is.finite(e$estimated_grid_side_mw) || d$estimated_grid_side_mw <= e$estimated_grid_side_mw))
        tags[[d$claim_id]] <- c(tags[[d$claim_id]], sc$id)
    }
    by_project <- split(direct, vapply(direct, `[[`, '', 'project_id'))
    chosen <- unlist(lapply(by_project, pick), recursive = FALSE)
    # Cross-project containment (e.g. a tenant inside another project's campus) is counted once.
    ids_chosen <- vapply(chosen, `[[`, '', 'claim_id')
    keep <- vapply(chosen, function(e) {
      j <- match(e$claim_id, c$claim_id)
      if (!c$relation[j] %in% c('included_in', 'possibly_included_in')) return(TRUE)
      top <- c$claim_id[top_claim(c, j)]
      !(c$project_id[match(top, c$claim_id)] != e$project_id && top %in% ids_chosen)
    }, TRUE)
    for (e in chosen[keep]) counted[[length(counted) + 1]] <- c(e, scenario_id = sc$id)
  }
  order_ids <- vapply(cfg$scenarios, function(sc) sc$id, '')
  for (k in seq_along(cap)) {
    t <- tags[[cap[[k]]$claim_id]]
    cap[[k]]$scenario_tag <- paste(order_ids[order_ids %in% t], collapse = '; ')
  }

  # Projects ---------------------------------------------------------------
  projects <- lapply(seq_len(nrow(public_p)), function(i) {
    pr <- public_p[i, ]
    rc <- c[c$project_id == pr$project_id & !c$status %in% excluded, , drop = FALSE]
    headline <- number(rc$mw[!rc$basis %in% c('backup', 'density') & rc$issue != 'identity_conflict'])
    headline <- headline[is.finite(headline)]
    # Project-level decision for display: a decided or executing phase means a decision exists for the project.
    decision <- if (any(rc$decision == 'yes') || pr$status %in% c('Under construction', 'Operational')) 'yes' else
      if (!nrow(rc) || any(rc$decision == 'unclear')) 'unclear' else 'no'
    list(project_id = pr$project_id, country = pr$country, project_name = tracker_text(pr$project_name),
      developer = tracker_text(pr$developer), bidding_zone = pr$bidding_zone, county = pr$county,
      municipality = pr$municipality, type = pr$type, project_status = pr$status,
      investment_decision = decision,
      construction_start_years = year_list(rc$construction_year),
      expected_operational_years = year_list(rc$first_year[rc$timing != 'unknown']),
      max_reported_capacity_mw = if (length(headline)) max(headline) else NA_real_,
      notes = tracker_text(pr$notes),
      last_updated = latest_date(s, unique(c(ids(pr$source_ids), unlist(lapply(rc$source_ids, ids))))),
      latitude = as_num(pr$latitude), longitude = as_num(pr$longitude),
      coordinate_note = paste0('Approximate display point for ', pr$municipality, '.'))
  })

  # Scenario x zone totals (all configured zones, zeros included) -----------
  zones <- cfg$zones
  sz <- list()
  for (k in seq_along(cfg$scenarios)) {
    sc <- cfg$scenarios[[k]]
    rows <- Filter(function(e) e$scenario_id == sc$id, counted)
    for (cc in c('FI', 'NO', 'SE')) for (z in Filter(function(z) z$country == cc, zones)) {
      zr <- Filter(function(e) e$bidding_zone == z$id, rows)
      tot <- function(f) sum(vapply(zr, function(e) if (is.finite(e[[f]])) e[[f]] else 0, 0))
      sz[[length(sz) + 1]] <- list(scenario_id = sc$id, scenario_label = sc$label, scenario_order = k, year = sc$year,
        panel = sc$label, country = z$country, bidding_zone = z$id,
        grid_side_mw = tot('estimated_grid_side_mw'), mw = tot('estimated_grid_side_mw'),
        interpreted_it_load_mw = tot('interpreted_it_load_mw'), reported_capacity_mw = tot('reported_capacity_mw'),
        estimated_twh = tot('estimated_twh_year'), n_projects = length(unique(vapply(zr, `[[`, '', 'project_id'))))
    }
  }

  # Map: same feature properties as the published file -----------------------
  names_ <- c(SE = 'Sweden', NO = 'Norway', FI = 'Finland')
  map <- assemble_map(cfg, root)
  order_z <- c(paste0('SE', 1:4), 'FI', paste0('NO', 1:5))
  feats <- map$features[match(order_z, vapply(map$features, function(f) f$id, ''))]
  feats <- lapply(feats, function(f) {
    z <- f$id; cc <- f$properties$country
    zn <- if (cc == 'FI') 'FI' else if (cc == 'NO') paste0('NO-', z) else paste0('SE_', sub('SE', '', z))
    list(type = 'Feature', properties = list(zoneName = zn, bidding_zone = z, country = cc, country_name = unname(names_[cc]),
      zone_name = if (cc == 'FI') 'Finland' else paste(unname(names_[cc]), 'bidding zone', sub('^[A-Z]+', '', z)),
      id = if (cc == 'SE') NULL else if (cc == 'FI') 'FI' else paste0('NO-', z)), geometry = f$geometry)
  })
  geo <- list(type = 'FeatureCollection', name = 'bidding_zones',
    crs = list(type = 'name', properties = list(name = 'urn:ogc:def:crs:OGC:1.3:CRS84')), features = feats)

  list(projects = projects, capacity = cap, scenario_zone = sz, bidding_zones = geo)
}

write_tracker <- function(out, dir) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  w <- function(v, f, digits = 4, pretty = TRUE) {
    tmp <- tempfile('.tracker-', dir)
    jsonlite::write_json(v, tmp, pretty = pretty, auto_unbox = TRUE, na = 'null', null = 'null', digits = digits)
    jsonlite::fromJSON(tmp)
    if (!file.rename(tmp, file.path(dir, f))) stop('Could not write ', f)
  }
  w(out$projects, 'projects.json'); w(out$capacity, 'capacity.json')
  w(out$scenario_zone, 'scenario_zone.json'); w(out$bidding_zones, 'bidding_zones.geojson', digits = NA, pretty = FALSE)
  invisible(dir)
}
