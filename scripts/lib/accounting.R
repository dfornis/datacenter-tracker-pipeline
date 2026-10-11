field_is_verified <- function(tables, entity, id, field) {
  r <- tables$field_reviews
  any(r$entity_type == entity & r$entity_id == id & r$field == field)
}
parameter_range <- function(tables, id) {
  a <- tables$assumptions; i <- match(id %||% '',a$assumption_id)
  if (is.na(i) || a$parameter_status[i] == 'not_calibrated') return(NULL)
  if (!nzchar(a$low[i]) || !nzchar(a$high[i])) return(NULL)
  list(id=id,low=num(a$low[i]),high=num(a$high[i]),value=num(a$value[i]),status=a$parameter_status[i],denominator=a$denominator[i],denominator_kind=a$denominator_kind[i])
}
claim_measure <- function(tables, index, basis, bound='low') {
  c <- tables$capacity_master
  if (c$reported_capacity_basis[index] == basis) {
    if (bound == 'high' && c$capacity_qualifier[index] == 'range') return(num(c$capacity_max_mw[index]))
    return(num(c$reported_capacity_mw[index]))
  }
  o <- tables$capacity_observations
  i <- which(o$claim_id == c$claim_id[index] & o$basis == basis)
  if (length(i) != 1L) return(NA_real_)
  num(if (bound == 'high' && o$qualifier[i] == 'range') o$value_max[i] else o$value[i])
}
measure_kind <- function(tables,index,basis) {
  c <- tables$capacity_master
  if (c$reported_capacity_basis[index] == basis) return(c$measurement_kind[index])
  o <- tables$capacity_observations
  i <- which(o$claim_id == c$claim_id[index] & o$basis == basis)
  if (length(i) == 1L) o$measurement_kind[i] else 'unspecified_capacity'
}
net_measure <- function(tables,index,basis,bound='low') {
  c <- tables$capacity_master; value <- claim_measure(tables,index,basis,bound)
  if (c$baseline_scope[index] == 'existing_unknown') return(NA_real_)
  if (c$baseline_scope[index] == 'existing_known') {
    baseline <- match(c$baseline_claim_id[index],c$claim_id)
    if (is.na(baseline)) return(NA_real_)
    value <- value - claim_measure(tables,baseline,basis,if (bound=='low') 'high' else 'low')
  }
  value
}
claim_ancestors <- function(c,index) {
  result <- character(); i <- index
  while (c$relation[i] %in% c('included_in','possibly_included_in')) {
    id <- c$parent_claim_id[i]
    if (!nzchar(id)) break
    if (id %in% result) stop('Containment cycle escaped validation')
    result <- c(result,id); i <- match(id,c$claim_id)
    if (is.na(i)) stop('Missing parent escaped validation')
  }
  result
}
account_scenario <- function(tables, method, scenario) {
  c <- tables$capacity_master; p <- tables$projects_master
  n <- nrow(c); reason <- rep('eligible',n); eligible <- rep(TRUE,n)
  end_fraction <- rep(1,n); average_fraction <- rep(NA_real_,n)
  timing_basis <- rep('full_scoped_capacity',n)
  quality <- rep('',n)
  exclude <- function(i,why) {
    selected <- which(eligible & i)
    eligible[selected] <<- FALSE; reason[selected] <<- why
  }
  exclude(nzchar(c$superseded_by_claim_id),'superseded')
  exclude(c$capacity_unit != 'MW_electric' | c$reported_capacity_basis %in% unlist(method$non_load_bases),'not_datacenter_electric_load')
  exclude(c$capacity_status %in% unlist(method$scenario_excluded_statuses), 'phase_status_excluded')
  exclude(c$baseline_scope == 'existing_unknown','installed_baseline_unknown')
  net <- vapply(seq_len(n),function(i) net_measure(tables,i,c$reported_capacity_basis[i]),numeric(1))
  net_high <- vapply(seq_len(n),function(i) net_measure(tables,i,c$reported_capacity_basis[i],'high'),numeric(1))
  exclude(!is.na(net_high) & net_high <= 0,'no_positive_increment')
  year <- scenario$year
  if (!is.null(year)) {
    timed <- c$timing_scope == 'full_capacity' & nzchar(c$operation_year_max) & num(c$operation_year_max) <= year
    timed[is.na(timed)] <- FALSE
    d <- tables$deployment_schedule
    for (i in seq_len(n)) {
      schedule <- which(d$claim_id == c$claim_id[i] & num(d$year) == year & d$review_state == 'verified' & d$basis == 'source')
      if (length(schedule) == 1L) {
        timed[i] <- num(d$year_end_fraction[schedule]) > 0
        end_fraction[i] <- num(d$year_end_fraction[schedule]); average_fraction[i] <- num(d$average_year_fraction[schedule])
        timing_basis[i] <- 'source_deployment_schedule'
      }
    }
    exclude(!timed,'full_capacity_not_dated_by_target')
    overdue <- nzchar(c$operation_year_max) & num(c$operation_year_max) < as.integer(substr(method$as_of_date,1,4))
    overdue[is.na(overdue)] <- FALSE
    current_status <- vapply(c$claim_id,function(id) field_is_verified(tables,'claim',id,'capacity_status'),logical(1))
    exclude(overdue & !current_status,'past_target_requires_status_refresh')
  } else timing_basis[] <- 'undated_potential'
  if (isTRUE(scenario$require_decision)) {
    supported <- vapply(c$claim_id,function(id) field_is_verified(tables,'claim',id,'investment_decision') && field_is_verified(tables,'claim',id,'decision_basis'),logical(1))
    exclude(c$investment_decision != 'yes' | !c$decision_basis %in% unlist(method$eligible_decision_bases) | !supported,'scoped_commitment_not_verified')
    critical <- vapply(c$claim_id,function(id)all(vapply(unlist(method$committed_required_verified_fields),function(field)field_is_verified(tables,'claim',id,field),logical(1))),logical(1))
    exclude(!critical,'scoped_capacity_not_verified')
  }
  # Select envelopes only by explicit containment; never take max() by project name/ID.
  eligible_before_overlap <- eligible
  for (i in which(eligible_before_overlap & c$relation == 'included_in')) {
    ancestors <- claim_ancestors(c,i)
    covered <- ancestors[ancestors %in% c$claim_id[eligible_before_overlap]]
    if (length(covered)) { eligible[i] <- FALSE; reason[i] <- paste0('contained_in:',tail(covered,1)) }
  }
  for (i in which(eligible_before_overlap & c$relation == 'possibly_included_in')) {
    ancestors <- claim_ancestors(c,i)
    # Also consider descendants of the uncertain envelope (e.g. tenant vs first campus phase).
    same_scope <- vapply(seq_len(n),function(j) c$claim_id[j] %in% ancestors || any(claim_ancestors(c,j) %in% ancestors),logical(1))
    peers <- which(eligible & same_scope & seq_len(n) != i)
    if (length(peers)) {
      affected <- unique(c(i,peers)); eligible[affected] <- FALSE; reason[affected] <- 'unresolved_overlap'
    }
  }
  it <- facility <- grid <- rep(NA_real_,n)
  energy_low <- energy_high <- target_low <- target_high <- rep(NA_real_,n)
  model_facility_low <- model_facility_high <- rep(NA_real_,n)
  pue_id <- lf_id <- rep('',n); pue_kind <- rep('',n)
  energy_status <- rep('not_counted',n)
  pue_assumption <- parameter_range(tables,method$energy_assumptions$pue_id)
  lf_assumption <- parameter_range(tables,method$energy_assumptions$load_factor_id)
  for (i in seq_len(n)) {
    flags <- character()
    ids <- split_values(c$source_ids[i]); source_states <- tables$sources_master$review_state[match(ids,tables$sources_master$source_id)]
    if (c$review_state[i] != 'verified') flags <- c(flags,'legacy_or_incomplete_field_review')
    if (c$capacity_qualifier[i] != 'exact') flags <- c(flags,paste0('qualifier:',c$capacity_qualifier[i]))
    if (c$reported_capacity_basis[i] == 'unspecified_headline') flags <- c(flags,'capacity_basis_unknown')
    if (c$reported_capacity_basis[i] == 'grid_connection') flags <- c(flags,paste0('connection:',c$connection_status[i]))
    quality[i] <- paste(flags,collapse=';')
    if (!eligible[i]) next
    it[i] <- net_measure(tables,i,'it_load') * end_fraction[i]
    facility[i] <- net_measure(tables,i,'facility_total') * end_fraction[i]
    grid[i] <- net_measure(tables,i,'grid_connection') * end_fraction[i]
    if (!is.na(facility[i])) {
      kind <- measure_kind(tables,i,'facility_total')
      if (kind %in% c('nameplate_capacity','peak_demand')) {
        model_facility_low[i] <- facility[i]
        model_facility_high[i] <- net_measure(tables,i,'facility_total','high') * end_fraction[i]
      }
      pue_kind[i] <- 'same_scope_facility_observation'
    } else if (!is.na(it[i])) {
      kind <- 'nameplate_capacity'
      it_high <- net_measure(tables,i,'it_load','high') * end_fraction[i]
      if (nzchar(c$site_pue[i])) {
        # A design upper bound is not automatically an exact peak conversion or measured annual PUE.
        pue_id[i] <- paste0('site:',c$claim_id[i]); pue_kind[i] <- c$site_pue_kind[i]
        if (c$site_pue_qualifier[i] %in% c('exact','up_to')) {
          model_facility_low[i] <- it[i] * if (c$site_pue_qualifier[i]=='up_to') 1 else num(c$site_pue[i])
          model_facility_high[i] <- it_high * num(c$site_pue[i])
          if (c$site_pue_qualifier[i]=='up_to') quality[i] <- paste(c(quality[i],'PUE_low_is_physical_bound_not_forecast'),collapse=';')
        }
        quality[i] <- paste(c(quality[i],'PUE_capacity_conversion_is_modelled'),collapse=';')
      } else if (!is.null(pue_assumption)) {
        pue_id[i] <- pue_assumption$id; pue_kind[i] <- pue_assumption$status
        model_facility_low[i] <- it[i] * pue_assumption$low; model_facility_high[i] <- it_high * pue_assumption$high
      }
    }
    if (is.na(model_facility_low[i])) {
      energy_status[i] <- if (c$reported_capacity_basis[i] == 'grid_connection') 'connection_is_not_facility_demand' else if (c$reported_capacity_basis[i] == 'unspecified_headline') 'basis_unknown' else 'PUE_assumption_missing'
    } else if (is.null(lf_assumption)) energy_status[i] <- 'load_factor_assumption_missing' else if (kind != lf_assumption$denominator_kind) energy_status[i] <- 'load_factor_denominator_mismatch' else {
      lf_id[i] <- lf_assumption$id; energy_status[i] <- 'conditional_mature_annual_equivalent'
      energy_low[i] <- model_facility_low[i] * lf_assumption$low * 8760 / 1e6
      energy_high[i] <- model_facility_high[i] * lf_assumption$high * 8760 / 1e6
      if (!is.na(average_fraction[i])) {
        days <- as.numeric(as.Date(sprintf('%d-01-01',year+1)) - as.Date(sprintf('%d-01-01',year)))
        target_low[i] <- model_facility_low[i] / end_fraction[i] * average_fraction[i] * lf_assumption$low * days * 24 / 1e6
        target_high[i] <- model_facility_high[i] / end_fraction[i] * average_fraction[i] * lf_assumption$high * days * 24 / 1e6
      }
    }
  }
  pi <- match(c$project_id,p$project_id)
  data.frame(scenario_id=scenario$scenario_id,target_year=if (is.null(year)) NA_integer_ else year,
    claim_id=c$claim_id,project_id=c$project_id,physical_site_id=c$physical_site_id,phase_id=c$phase_id,
    country=c$country,bidding_zone=p$bidding_zone[pi],counted=eligible,reason=reason,quality_flags=quality,
    reported_capacity_mw=num(c$reported_capacity_mw),reported_capacity_basis=c$reported_capacity_basis,
    capacity_unit=c$capacity_unit,measurement_kind=c$measurement_kind,capacity_qualifier=c$capacity_qualifier,
    incremental_reported_mw=ifelse(eligible,net*end_fraction,NA_real_),incremental_reported_mw_high=ifelse(eligible,net_high*end_fraction,NA_real_),
    it_load_mw=it,facility_power_mw=facility,grid_connection_mw=grid,year_end_fraction=end_fraction,average_year_fraction=average_fraction,
    timing_basis=timing_basis,pue_assumption_id=pue_id,pue_kind=pue_kind,load_factor_assumption_id=lf_id,
    modelled_facility_equivalent_mw_low=model_facility_low,modelled_facility_equivalent_mw_high=model_facility_high,
    conditional_mature_annual_twh_low=energy_low,conditional_mature_annual_twh_high=energy_high,
    target_year_energy_twh_low=target_low,target_year_energy_twh_high=target_high,energy_status=energy_status,
    source_ids=c$source_ids,stringsAsFactors=FALSE)
}
account_all <- function(tables,method) {
  ledger <- do.call(rbind,lapply(method$scenarios,function(s) account_scenario(tables,method,s)))
  g <- tables$geography_config[tables$geography_config$active=='TRUE',,drop=FALSE]
  rows <- list()
  for (scenario in method$scenarios) for (i in seq_len(nrow(g))) {
    all <- ledger[ledger$scenario_id==scenario$scenario_id & ledger$bidding_zone==g$bidding_zone[i],,drop=FALSE]
    counted <- all[all$counted,,drop=FALSE]
    uncertain <- all$reason %in% c('unresolved_overlap','installed_baseline_unknown','past_target_requires_status_refresh')
    sum_or_na <- function(field) if (nrow(counted)==0) 0 else if (all(is.na(counted[[field]]))) NA_real_ else sum(counted[[field]],na.rm=TRUE)
    known <- sum(!is.na(counted$modelled_facility_equivalent_mw_low))
    energy_known <- sum(!is.na(counted$conditional_mature_annual_twh_low))
    target_known <- sum(!is.na(counted$target_year_energy_twh_low))
    rows[[length(rows)+1]] <- data.frame(scenario_id=scenario$scenario_id,target_year=if (is.null(scenario$year)) NA_integer_ else scenario$year,
      country=g$country[i],bidding_zone=g$bidding_zone[i],baseline_date=method$baseline_date,
      inventory_claims=nrow(all),counted_claims=nrow(counted),unresolved_claims=sum(uncertain),
      evidence_gap_claims=sum(all$reason %in% c('scoped_commitment_not_verified','scoped_capacity_not_verified','past_target_requires_status_refresh')),
      timing_excluded_claims=sum(all$reason=='full_capacity_not_dated_by_target'),
      totals_scope='qualifying_inventory_subset_only',
      # These are separate, non-additive measures. No total sums IT MW and facility MW.
      known_it_load_mw=sum_or_na('it_load_mw'),known_facility_power_mw=sum_or_na('facility_power_mw'),known_grid_connection_mw=sum_or_na('grid_connection_mw'),
      modelled_facility_equivalent_mw_low=sum_or_na('modelled_facility_equivalent_mw_low'),modelled_facility_equivalent_mw_high=sum_or_na('modelled_facility_equivalent_mw_high'),
      capacity_estimate_complete=known==nrow(counted) && !any(uncertain),
      conditional_mature_annual_twh_low=sum_or_na('conditional_mature_annual_twh_low'),conditional_mature_annual_twh_high=sum_or_na('conditional_mature_annual_twh_high'),
      annual_equivalent_complete=energy_known==nrow(counted) && !any(uncertain),
      target_year_energy_twh_low=if (is.null(scenario$year)) NA_real_ else sum_or_na('target_year_energy_twh_low'),
      target_year_energy_twh_high=if (is.null(scenario$year)) NA_real_ else sum_or_na('target_year_energy_twh_high'),
      target_year_energy_complete=!is.null(scenario$year) && target_known==nrow(counted) && !any(uncertain),
      quality_flagged_claims=sum(nzchar(counted$quality_flags)),stringsAsFactors=FALSE)
  }
  list(ledger=ledger,scenario_zone=do.call(rbind,rows))
}
