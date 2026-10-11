allocate_identity <- function(tables, entity, run_id) {
  prefix <- switch(entity, project='P',claim='C',source='S',site='SITE',phase='PH',observation='OBS',stop('Unsupported identity'))
  registry <- tables$identity_registry
  previous <- registry$entity_id[registry$entity_type == entity]
  n <- if (length(previous)) max(as.integer(sub(paste0('^',prefix),'',previous))) + 1L else 1L
  id <- sprintf('%s%03d',prefix,n)
  if (id %in% registry$entity_id[registry$entity_type == entity]) stop('Identity allocation collision')
  tables$identity_registry <- rbind(registry,row_frame(list(entity_type=entity,entity_id=id,state='active',created_in=run_id),names(registry)))
  list(tables=tables,id=id)
}
assert_evidence <- function(row, fields) {
  required <- c('source_type','source_url','source_title','access_date','original_excerpt','original_language','locator','evidence_kind','reviewed_by','reviewed_at')
  if (any(!nzchar(unlist(row[required])))) stop('Approved row lacks exact source evidence, type, locator or review attribution',call.=FALSE)
  if (!row$evidence_kind %in% c('verbatim','translation')) stop('Promotion requires original verbatim evidence',call.=FALSE)
  if (row$evidence_kind == 'translation' && !nzchar(row$translation)) stop('Translation must be separate from original excerpt')
  if (any(!fields %in% split_values(row$supports_fields))) stop('Evidence does not explicitly support every selected field',call.=FALSE)
  invisible(TRUE)
}
attach_evidence <- function(tables, row, project_id, claim_id, fields, run_id) {
  assert_evidence(row,fields)
  sources <- tables$sources_master
  reusable <- which(sources$project_id==project_id & sources$claim_id==claim_id & sources$review_state=='verified')
  compare <- c('source_type','source_url','source_title','access_date','original_excerpt','original_language','translation','locator')
  reusable <- reusable[vapply(reusable,function(i)all(vapply(compare,function(f)sources[[f]][i]==row[[f]],logical(1))),logical(1))]
  reusable <- reusable[vapply(reusable,function(i)sources$source_date_raw[i]==row$source_date && (!'independence_group' %in% names(row) || !nzchar(row$independence_group) || sources$independence_group[i]==row$independence_group),logical(1))]
  if (length(reusable) && (!'evidence_source_id' %in% names(row) || !nzchar(row$evidence_source_id))) {
    i <- reusable[1]
    sources$supports_fields[i] <- paste(unique(c(split_values(sources$supports_fields[i]),fields)),collapse=';')
    tables$sources_master <- sources
    return(list(tables=tables,id=sources$source_id[i]))
  }
  supplied <- if ('evidence_source_id' %in% names(row)) row$evidence_source_id else ''
  if (nzchar(supplied)) {
    i <- match(supplied,sources$source_id)
    if (is.na(i)) stop('Unknown supplied evidence_source_id')
    compare <- c('source_url','source_title','original_excerpt','original_language','locator','access_date')
    if (sources$project_id[i] != project_id || sources$claim_id[i] != claim_id || sources$review_state[i] != 'verified' ||
        any(vapply(compare,function(f) sources[[f]][i] != row[[f]],logical(1))) ||
        any(!fields %in% split_values(sources$supports_fields[i]))) stop('Supplied source does not match verified evidence and entity scope')
    return(list(tables=tables,id=supplied))
  }
  allocation <- allocate_identity(tables,'source',run_id); tables <- allocation$tables
  raw_date <- row$source_date
  precision <- if (valid_date(raw_date)) 'day' else if (grepl('^[0-9]{4}-(0[1-9]|1[0-2])$',raw_date)) 'month' else if (grepl('^[0-9]{4}$',raw_date)) 'year' else if (!nzchar(raw_date)) 'unknown' else stop('Invalid source date precision')
  same_url <- sources$independence_group[sources$source_url == row$source_url]
  values <- as.list(row[1,intersect(names(row),names(sources)),drop=FALSE])
  values$source_id <- allocation$id; values$project_id <- project_id; values$claim_id <- claim_id
  values$source_date_raw <- raw_date; values$source_date_precision <- precision
  values$source_date <- if (precision == 'day') raw_date else ''
  values$review_state <- 'verified'; values$supports_fields <- paste(fields,collapse=';')
  values$independence_group <- if ('independence_group' %in% names(row) && nzchar(row$independence_group)) row$independence_group else if (length(same_url)) same_url[1] else paste0('source-',allocation$id)
  tables$sources_master <- rbind(sources,row_frame(values,names(sources)))
  list(tables=tables,id=allocation$id)
}
attach_evidence_bundle <- function(tables,row,project_id,claim_id,fields,run_id) {
  records <- list(row)
  if ('additional_evidence' %in% names(row) && nzchar(row$additional_evidence)) {
    extras <- jsonlite::fromJSON(row$additional_evidence,simplifyVector=FALSE)
    if (!is.list(extras) || !is.null(names(extras))) stop('Additional evidence must be an array of evidence records')
    for (extra in extras) {
      allowed <- c('source_type','source_url','source_title','source_date','access_date','original_excerpt','original_language','translation','locator','evidence_kind','supports_fields','confidence','independence_group','evidence_excerpt')
      if (any(!names(extra) %in% allowed)) stop('Unexpected additional-evidence fields')
      record <- row
      for (field in allowed) record[[field]] <- extra[[field]] %||% ''
      record$evidence_source_id <- ''; record$additional_evidence <- ''
      records[[length(records)+1]] <- record
    }
  }
  supported <- unique(unlist(lapply(records,function(r)split_values(r$supports_fields))))
  if (any(!fields %in% supported)) stop('Evidence bundle does not cover required fields')
  ids <- character()
  for (record in records) {
    contributes <- intersect(fields,split_values(record$supports_fields))
    if (!length(contributes)) next
    evidence <- attach_evidence(tables,record,project_id,claim_id,contributes,run_id)
    tables <- evidence$tables; ids <- c(ids,evidence$id)
  }
  list(tables=tables,id=unique(ids))
}
sources_for_field <- function(tables,ids,field) {
  s <- tables$sources_master; ids[vapply(ids,function(id)field %in% split_values(s$supports_fields[match(id,s$source_id)]),logical(1))]
}
record_field_review <- function(tables, entity, id, field, value, sources, row) {
  reviews <- tables$field_reviews
  keep <- !(reviews$entity_type == entity & reviews$entity_id == id & reviews$field == field)
  previous <- reviews[!keep,,drop=FALSE]
  if (nrow(previous)==1 && previous$value_sha256==sha_value(value)) sources <- unique(c(split_values(previous$source_ids),sources))
  review <- row_frame(list(entity_type=entity,entity_id=id,field=field,value_sha256=sha_value(value),source_ids=paste(sources,collapse=';'),
    review_kind=if ('review_kind' %in% names(row) && nzchar(row$review_kind)) row$review_kind else 'source',reviewer=row$reviewed_by,reviewed_at=row$reviewed_at,run_id=row$run_id,notes=row$rationale %||% row$notes %||% ''),names(reviews))
  tables$field_reviews <- rbind(reviews[keep,,drop=FALSE],review)
  tables
}
refresh_review_metadata <- function(tables,schema) {
  groups <- list(timing_source_ids=c('timing_scope','operation_year_min','operation_year_max','construction_start_year'),
    decision_source_ids=c('investment_decision','decision_basis'),pue_source_ids=c('site_pue','site_pue_kind','site_pue_qualifier'),
    overlap_source_ids=c('relation','parent_claim_id','baseline_scope','baseline_claim_id','baseline_comparable','superseded_by_claim_id'))
  f <- tables$field_reviews
  for(entity in c('project','claim')) {
    target <- if(entity=='project')'projects_master' else 'capacity_master'
    key <- if(entity=='project')'project_id' else 'claim_id'
    data <- tables[[target]]
    for(i in seq_len(nrow(data))) {
      reviews <- f[f$entity_type==entity & f$entity_id==data[[key]][i],,drop=FALSE]
      if(!nrow(reviews))next
      required <- unlist(schema$verification_fields[[entity]])
      data$review_state[i] <- if(all(required %in% reviews$field))'verified' else 'needs_review'
      last <- reviews[order(reviews$reviewed_at,decreasing=TRUE)[1],,drop=FALSE]
      data$reviewed_by[i] <- last$reviewer; data$reviewed_at[i] <- last$reviewed_at
      if(entity=='claim')for(field in names(groups)) {
        selected <- reviews[reviews$field %in% groups[[field]],,drop=FALSE]
        if(nrow(selected))data[[field]][i] <- paste(unique(unlist(lapply(selected$source_ids,split_values))),collapse=';')
      }
    }
    tables[[target]] <- data
  }
  tables
}
promotion_selection <- function(tables, source, level, ids, country, reviewer, expected_release) {
  names_selected <- if (source == 'audit') switch(level,project='suggested_project_updates',capacity='suggested_capacity_updates',
    source='suggested_source_updates',stop('Audit level must be project, capacity or source')) else if (source == 'candidates') c('new_project_candidates','new_capacity_claim_candidates') else stop('Source must be audit or candidates')
  selected <- list(); found <- character()
  for (name in names_selected) {
    d <- tables[[name]]; key <- if (source == 'audit') 'audit_id' else if (name == 'new_project_candidates') 'project_candidate_id' else 'capacity_candidate_id'
    rows <- d[d[[key]] %in% ids,,drop=FALSE]; rows <- rows[order(rows[[key]]),,drop=FALSE]
    if (nrow(rows) && any(rows$country != country)) stop('Selection crosses requested country')
    if (nrow(rows) && any(rows$reviewed_by != reviewer)) stop('Reviewer does not match approved rows')
    selected[[name]] <- rows; found <- c(found,rows[[key]])
  }
  if (!length(ids) || !setequal(found,ids) || anyDuplicated(found)) stop('Selection must identify existing, unique review rows explicitly')
  if (length(unique(unlist(lapply(selected,function(r) r$run_id)))) != 1L) stop('A promotion must belong to one frozen run')
  canonical <- lapply(selected,function(r) r[,setdiff(names(r),c('review_state','resolution')),drop=FALSE])
  digest <- sha_value(list(source=source,level=level,ids=sort(ids),country=country,reviewer=reviewer,parent=expected_release,rows=canonical))
  list(rows=selected,digest=digest,run_id=unique(unlist(lapply(selected,function(r) r$run_id))))
}
promote_rows <- function(root, source, level, ids, country, reviewer, request_id, expected_release, apply=FALSE, failpoint=NULL) {
  if (!grepl('^[A-Za-z0-9][A-Za-z0-9._-]{2,100}$',request_id)) stop('Use a stable, explicit request ID')
  if (!nzchar(reviewer) || !nzchar(country)) stop('Country and reviewer are required')
  replay_check <- function(tables) {
    selected <- promotion_selection(tables,source,level,ids,country,reviewer,expected_release)
    h <- tables$promotion_history; i <- match(request_id,h$request_id)
    if (is.na(i)) return(NULL)
    if (h$request_digest[i] != selected$digest) stop('Request ID already used for a different payload')
    list(request_id=request_id,original_applied_at=h$applied_at[i])
  }
  mutate <- function(tables, stage, schema) {
    selected <- promotion_selection(tables,source,level,ids,country,reviewer,expected_release)
    rows <- selected$rows; run_id <- selected$run_id
    if (any(unlist(lapply(rows,function(r) r$review_state)) != 'approved')) stop('Only explicitly approved rows can be promoted')
    assigned <- list(projects=list(),claims=list(),sources=list())
    if (source == 'audit') {
      name <- names(rows)[1]; updates <- rows[[1]]
      target_name <- switch(level,project='projects_master',capacity='capacity_master',source='sources_master')
      key <- schema$tables[[target_name]]$key[[1]]
      # Validate every expected value against the same original state, before any mutation.
      original <- tables[[target_name]]
      if (anyDuplicated(paste(updates[[key]],updates$field))) stop('Multiple proposals target the same field')
      protected <- c(key,'project_id','physical_site_id','phase_id','accounting_group_id','source_ids','timing_source_ids','decision_source_ids','pue_source_ids','overlap_source_ids','reviewed_by','reviewed_at','review_state', if (level == 'capacity') 'project_name')
      for (j in seq_len(nrow(updates))) {
        r <- updates[j,,drop=FALSE]; i <- match(r[[key]],original[[key]])
        if (is.na(i) || !r$field %in% names(original) || r$field %in% protected) stop('Unknown entity or protected field; use a scoped identity migration')
        if (original[[r$field]][i] != r$current_value) stop('Stale current_value for ',r[[key]],' ',r$field,call.=FALSE)
        if (r$current_value == r$suggested_value && r$change_kind != 'confirmation') stop('Unchanged value requires an explicit evidence confirmation')
        if (r$current_value != r$suggested_value && r$change_kind == 'confirmation') stop('A confirmation cannot change the value')
        if (r$project_id != if (level == 'project') r[[key]] else original$project_id[i]) stop('Audit project identity mismatch')
      }
      for (j in seq_len(nrow(updates))) {
        i <- match(updates[[key]][j],tables[[target_name]][[key]])
        tables[[target_name]][[updates$field[j]]][i] <- updates$suggested_value[j]
      }
      for (j in seq_len(nrow(updates))) {
        r <- updates[j,,drop=FALSE]; i <- match(r[[key]],tables[[target_name]][[key]])
        if (level == 'source') {
          # Source edits are evidence about this record, not invented field support for its project.
          assert_evidence(r,r$field)
          sid <- r$source_id
          source_row <- tables$sources_master[i,,drop=FALSE]
          compare <- c('source_url','original_excerpt','original_language','locator','evidence_kind')
          if (any(vapply(compare,function(f) source_row[[f]] != r[[f]],logical(1)))) stop('Source correction must include matching original evidence in the resulting source record')
          tables$sources_master$review_state[i] <- 'verified'
          tables$sources_master$reviewed_by[i] <- r$reviewed_by; tables$sources_master$reviewed_at[i] <- r$reviewed_at
          if (r$field %in% c('source_url','original_excerpt','original_language','translation','supports_fields','evidence_kind','locator')) {
            # Editing evidence invalidates dependent conclusions, rather than silently endorsing them.
            dependents <- vapply(tables$field_reviews$source_ids,function(ids) sid %in% split_values(ids),logical(1))
            tables$field_reviews <- tables$field_reviews[!dependents,,drop=FALSE]
            tables$capacity_master$review_state[tables$capacity_master$claim_id == source_row$claim_id] <- 'needs_review'
          }
        } else {
          evidence <- attach_evidence_bundle(tables,r,r$project_id,if (level == 'capacity') r$claim_id else '',r$field,run_id)
          tables <- evidence$tables; sid <- evidence$id
          if (level == 'capacity') {
            old <- tables$capacity_master$source_ids[i]
            tables$capacity_master$source_ids[i] <- paste(unique(c(split_values(old),sid)),collapse=';')
          }
        }
        tables <- record_field_review(tables,switch(level,capacity='claim',level),r[[key]],r$field,r$suggested_value,sid,r)
        assigned$sources[[r$audit_id]] <- sid
      }
      # Descriptive project names are denormalised only for consumers; maintain consistency.
      tables$capacity_master$project_name <- tables$projects_master$project_name[match(tables$capacity_master$project_id,tables$projects_master$project_id)]
    } else {
      projects <- rows$new_project_candidates; claims <- rows$new_capacity_claim_candidates
      for (j in seq_len(nrow(projects))) {
        r <- projects[j,,drop=FALSE]
        alloc <- allocate_identity(tables,'project',run_id); tables <- alloc$tables; pid <- alloc$id
        site <- r$physical_site_id
        if (!nzchar(site)) { alloc <- allocate_identity(tables,'site',run_id); tables <- alloc$tables; site <- alloc$id }
        r$project_id <- pid; r$physical_site_id <- site
        required_fields <- c('project_name','developer','municipality','county','bidding_zone','project_status','investment_decision','decision_basis')
        e <- attach_evidence_bundle(tables,r,pid,'',required_fields,run_id); tables <- e$tables
        r$review_state <- 'verified'
        tables$projects_master <- rbind(tables$projects_master,row_frame(as.list(r),names(tables$projects_master)))
        for (field in required_fields) tables <- record_field_review(tables,'project',pid,field,r[[field]],sources_for_field(tables,e$id,field),r)
        assigned$projects[[r$project_candidate_id]] <- pid
      }
      # Allocate all candidate claim IDs before resolving temporary relationships.
      for (j in seq_len(nrow(claims))) {
        alloc <- allocate_identity(tables,'claim',run_id); tables <- alloc$tables
        assigned$claims[[claims$capacity_candidate_id[j]]] <- alloc$id
      }
      for (j in seq_len(nrow(claims))) {
        r <- claims[j,,drop=FALSE]; cid <- assigned$claims[[r$capacity_candidate_id]]
        pid <- r$project_id
        if (nzchar(r$project_candidate_id)) {
          proposed_pid <- assigned$projects[[r$project_candidate_id]]
          if (is.null(proposed_pid) || (nzchar(pid) && pid != proposed_pid)) stop('Candidate project dependency must be in this selection')
          pid <- proposed_pid
        }
        pi <- match(pid,tables$projects_master$project_id)
        if (is.na(pi)) stop('Capacity candidate has no valid parent project')
        if (tables$projects_master$country[pi] != country) stop('Candidate project country mismatch')
        r$claim_id <- cid; r$project_id <- pid; r$project_name <- tables$projects_master$project_name[pi]
        r$physical_site_id <- tables$projects_master$physical_site_id[pi]; r$accounting_group_id <- r$physical_site_id
        alloc <- allocate_identity(tables,'phase',run_id); tables <- alloc$tables; r$phase_id <- alloc$id
        for (field in c('parent_claim_id','baseline_claim_id','superseded_by_claim_id')) if (r[[field]] %in% names(assigned$claims)) r[[field]] <- assigned$claims[[r[[field]]]]
        required_fields <- c('reported_capacity_mw','reported_capacity_basis','capacity_unit','measurement_kind','capacity_type','capacity_status','investment_decision','decision_basis','timing_scope','baseline_scope','relation')
        if (nzchar(r$operation_year_min)) required_fields <- c(required_fields,'operation_year_min','operation_year_max')
        e <- attach_evidence_bundle(tables,r,pid,cid,required_fields,run_id); tables <- e$tables
        r$source_ids <- paste(unique(c(split_values(r$source_ids),e$id)),collapse=';'); r$review_state <- 'verified'
        tables$capacity_master <- rbind(tables$capacity_master,row_frame(as.list(r),names(tables$capacity_master)))
        for (field in required_fields) tables <- record_field_review(tables,'claim',cid,field,r[[field]],sources_for_field(tables,e$id,field),r)
      }
    }
    tables <- refresh_review_metadata(tables,schema)
    for (name in names(rows)) {
      key <- schema$tables[[name]]$key[[1]]
      selected_ids <- rows[[name]][[key]]; index <- match(selected_ids,tables[[name]][[key]])
      tables[[name]]$review_state[index] <- 'applied'
      tables[[name]]$resolution[index] <- paste('Applied in request',request_id)
    }
    history <- row_frame(list(request_id=request_id,run_id=run_id,source=paste(source,level,sep=':'),selected_ids=paste(sort(ids),collapse=';'),
      reviewer=reviewer,applied_at=utc_now(),parent_release=expected_release,request_digest=selected$digest),names(tables$promotion_history))
    tables$promotion_history <- rbind(tables$promotion_history,history)
    list(tables=tables,details=list(request_id=request_id,assigned=assigned))
  }
  state_transaction(root,mutate,expected_release,apply,metadata=list(action='promotion',request_id=request_id),failpoint=failpoint,replay_check=replay_check)
}
