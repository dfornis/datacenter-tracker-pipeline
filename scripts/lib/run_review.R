freeze_run_review <- function(path,decisions_path,reviewer) {
  validation <- validate_run_response(path)
  if (!nzchar(reviewer)) stop('An explicit reviewing identity is required')
  decisions <- read_table(decisions_path)
  fields <- c('proposal_id','decision','reviewer','reviewed_at','reason')
  if (!setequal(names(decisions),fields)) stop('Review decisions need proposal_id, decision, reviewer, reviewed_at, reason')
  response <- read_json(file.path(path,'work/response.json'))
  ids <- vapply(response$proposals,function(p)p$proposal_id,character(1))
  if (anyDuplicated(decisions$proposal_id) || any(!decisions$proposal_id %in% ids)) stop('Review decisions target duplicate or unknown proposals')
  if (any(!decisions$decision %in% c('approved','rejected','needs_review')) || any(decisions$reviewer!=reviewer) || any(!nzchar(decisions$reason))) stop('Invalid review decision or missing rationale')
  for (date in decisions$reviewed_at) if(length(validate_json_contract(date,list(type='string',format='date-time')))) stop('Review timestamps must be exact UTC datetimes')
  signature <- list(response_sha256=validation$response_sha256,decisions_sha256=sha_file(decisions_path),run_manifest_sha256=sha_file(file.path(path,'manifest.json')),reviewer=reviewer)
  id <- paste0('review-',substr(sha_value(signature),1,20)); target <- file.path(path,'reviews',id)
  if (dir.exists(target)) { verify_review(path,id); return(list(review_id=id,replay=TRUE)) }
  stage <- tempfile('review-',file.path(path,'work')); dir.create(stage); on.exit(unlink(stage,recursive=TRUE),add=TRUE)
  if (!file.copy(file.path(path,'work/response.json'),file.path(stage,'response.json')) || !file.copy(decisions_path,file.path(stage,'decisions.csv'))) stop('Cannot freeze review inputs')
  write_json(c(list(review_id=id),signature,list(files=file_inventory(stage))),file.path(stage,'manifest.json'))
  dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
  if (!file.rename(stage,target)) stop('Cannot publish frozen review')
  verify_review(path,id)
  list(review_id=id,replay=FALSE,approved=sum(decisions$decision=='approved'),rejected=sum(decisions$decision=='rejected'),unselected=length(setdiff(ids,decisions$proposal_id)))
}
verify_review <- function(path,review_id) {
  if (!grepl('^review-[a-f0-9]{20}$',review_id)) stop('Invalid review ID')
  verify_run(path); review <- file.path(path,'reviews',review_id)
  manifest <- read_json(file.path(review,'manifest.json'))
  if (manifest$review_id!=review_id || manifest$run_manifest_sha256!=sha_file(file.path(path,'manifest.json')) || !identical(manifest$files,release_inventory(review))) stop('Reviewed response or decision record was modified')
  validate_run_response(path,file.path(review,'response.json'))
  manifest
}
assert_run_still_current <- function(path,tables,schema,root) {
  manifest <- verify_run(path); country <- manifest$country
  for (name in c('schema.json','methodology.json','run_workflow.json','run_response.schema.json')) {
    if (sha_file(file.path(path,'input',name))!=sha_file(file.path(root,'config',name))) stop('Run contract is stale; render and review a new run')
  }
  for (name in names(tables)) {
    frozen <- file.path(path,'input',paste0(name,'.csv'))
    if (!file.exists(frozen)) next
    data <- tables[[name]]
    if ('country' %in% names(data)) data <- data[data$country==country,,drop=FALSE]
    pids <- unlist(manifest$project_ids)
    if(is.null(manifest$project_ids))pids <- tables$projects_master$project_id[tables$projects_master$country==country]
    cids <- tables$capacity_master$claim_id[tables$capacity_master$project_id %in% pids]
    if (name %in% c('projects_master','capacity_master','sources_master')) data <- data[data$project_id %in% pids,,drop=FALSE]
    if (name %in% c('capacity_observations','deployment_schedule')) data <- data[data$claim_id %in% cids,,drop=FALSE]
    if (name=='field_reviews') data <- data[data$entity_id %in% c(pids,cids),,drop=FALSE]
    rownames(data) <- NULL; original <- read_table(frozen); rownames(original) <- NULL
    if (!identical(data,original)) stop('Country input changed since extraction: ',name,'; review against a fresh packet')
  }
  if (manifest$task=='discover') {
    current <- tables$projects_master[,c('project_id','country','project_name','developer','physical_site_id','municipality','aliases')]
    rownames(current) <- NULL
    if (!identical(current,read_table(file.path(path,'input/global_identity_index.csv')))) stop('Global identity index changed; repeat duplicate screening')
  }
  invisible(TRUE)
}
evidence_to_columns <- function(evidence) {
  list(source_type=evidence$source_type,source_url=evidence$url,source_title=evidence$title,source_date=evidence$publication_date,
       access_date=evidence$access_date,original_excerpt=evidence$original_excerpt,original_language=evidence$original_language,
       translation=evidence$translation,locator=evidence$locator,evidence_kind=if(nzchar(evidence$translation))'translation' else 'verbatim',
       supports_fields=paste(unlist(evidence$supports_fields),collapse=';'),confidence=evidence$confidence,independence_group=evidence$independence_group,evidence_excerpt='')
}
import_run_review <- function(root,run_id,review_id,expected_release,apply=FALSE) {
  if (!grepl('^[A-Za-z0-9][A-Za-z0-9._-]{2,100}$',run_id)) stop('Invalid run ID')
  path <- file.path(root,'data/runs',run_id); manifest <- verify_run(path); review <- verify_review(path,review_id)
  review_path <- file.path(path,'reviews',review_id)
  replay_check <- function(tables) {
    receipts <- tables$run_imports; i <- match(run_id,receipts$run_id)
    if (is.na(i)) return(NULL)
    if (receipts$review_id[i]!=review_id) stop('Run already imported from a different review; use a new run for revised evidence')
    list(run_id=run_id,review_id=review_id)
  }
  mutate <- function(tables,stage,schema) {
    assert_run_still_current(path,tables,schema,root)
    response <- read_json(file.path(review_path,'response.json')); decisions <- read_table(file.path(review_path,'decisions.csv'))
    eids <- vapply(response$evidence,function(e)e$evidence_id,character(1))
    prefix <- function(id) paste(run_id,id,sep='--')
    p_candidates <- vapply(Filter(function(p)p$table=='new_project_candidates',response$proposals),function(p)p$proposal_id,character(1))
    c_candidates <- vapply(Filter(function(p)p$table=='new_capacity_claim_candidates',response$proposals),function(p)p$proposal_id,character(1))
    imported <- list()
    for (proposal in response$proposals) {
      name <- proposal$table; values <- proposal$values
      decision <- decisions[decisions$proposal_id==proposal$proposal_id,,drop=FALSE]
      state <- if(nrow(decision)) decision$decision else 'pending'
      evidence <- response$evidence[match(unlist(proposal$evidence_ids),eids)]
      if (state=='approved' && any(vapply(evidence,function(e)e$retrieval_status!='accessible',logical(1)))) stop('Approved proposal cites inaccessible or snippet-only evidence')
      values$country <- manifest$country; values$run_id <- run_id; values$review_state <- state; values$review_kind <- proposal$review_kind
      if (nrow(decision)) { values$reviewed_by <- decision$reviewer; values$reviewed_at <- decision$reviewed_at; values$resolution <- decision$reason }
      if (startsWith(name,'suggested_')) {
        values$audit_id <- prefix(proposal$proposal_id); values$rationale <- proposal$rationale
        target_name <- switch(name,suggested_project_updates='projects_master',suggested_capacity_updates='capacity_master',suggested_source_updates='sources_master')
        target <- tables[[target_name]]; key <- schema$tables[[target_name]]$key[[1]]
        i <- match(values[[key]],target[[key]])
        values$project_id <- target$project_id[i]
        if (name=='suggested_capacity_updates') values$phase <- target$phase[i]
        if (name=='suggested_source_updates') values$claim_id <- target$claim_id[i]
        values$project_name <- tables$projects_master$project_name[match(values$project_id,tables$projects_master$project_id)]
        values$change_kind <- if(values$current_value==values$suggested_value)'confirmation' else 'correction'
        pid <- values$project_id; cid <- if(name=='suggested_capacity_updates') values$claim_id else if(name=='suggested_source_updates') values$claim_id else ''
      } else if (name=='new_project_candidates') {
        values$project_candidate_id <- prefix(proposal$proposal_id); values$notes <- proposal$rationale
        pid <- proposal$proposal_id; cid <- ''
      } else {
        values$capacity_candidate_id <- prefix(proposal$proposal_id); values$notes <- proposal$rationale
        pid <- values$project_candidate_id %||% values$project_id %||% ''; cid <- proposal$proposal_id
        if (!nzchar(pid)) pid <- values$project_id %||% ''
        if (nzchar(values$project_candidate_id %||% '')) values$project_candidate_id <- prefix(values$project_candidate_id)
        for(field in c('parent_claim_id','baseline_claim_id','superseded_by_claim_id')) if((values[[field]] %||% '') %in% c_candidates) values[[field]] <- prefix(values[[field]])
      }
      if (any(vapply(evidence,function(e)e$project_id!=pid || e$claim_id!=cid,logical(1)))) stop('Proposal evidence has a different entity scope')
      primary <- evidence_to_columns(evidence[[1]])
      for (field in names(primary)) values[[field]] <- primary[[field]]
      if (length(evidence)>1) values$additional_evidence <- as.character(jsonlite::toJSON(lapply(evidence[-1],evidence_to_columns),auto_unbox=TRUE,null='null'))
      row <- row_frame(values,names(tables[[name]])); key <- schema$tables[[name]]$key[[1]]
      if (row[[key]] %in% tables[[name]][[key]]) stop('Run-scoped proposal ID collision')
      tables[[name]] <- rbind(tables[[name]],row); imported[[length(imported)+1]] <- list(table=name,id=row[[key]],review_state=state)
    }
    for (conflict in response$conflicts) {
      evidence <- response$evidence[match(unlist(conflict$evidence_ids),eids)]
      value <- list(conflict_id=prefix(conflict$conflict_id),run_id=run_id,review_state='needs_review',country=manifest$country,
        project_id=conflict$project_id,claim_id=conflict$claim_id,field=conflict$field,conflict_summary=conflict$description,recommended_resolution=conflict$resolution,
        source_url_1=evidence[[1]]$url,source_title_1=evidence[[1]]$title,source_date_1=if(nchar(evidence[[1]]$publication_date)==10)evidence[[1]]$publication_date else '',
        source_url_2=evidence[[2]]$url,source_title_2=evidence[[2]]$title,source_date_2=if(nchar(evidence[[2]]$publication_date)==10)evidence[[2]]$publication_date else '',
        access_date=evidence[[1]]$access_date,confidence='unclear')
      tables$source_conflicts <- rbind(tables$source_conflicts,row_frame(value,names(tables$source_conflicts)))
    }
    archive <- file.path(stage,'audit/archive/runs',run_id)
    copy_directory(review_path,archive)
    if (!file.copy(file.path(path,'manifest.json'),file.path(archive,'run-manifest.json'))) stop('Cannot preserve run provenance')
    receipt <- row_frame(list(run_id=run_id,review_id=review_id,response_sha256=review$response_sha256,review_manifest_sha256=sha_file(file.path(review_path,'manifest.json')),
      imported_at=utc_now(),input_release=manifest$input_release,parent_release=expected_release),names(tables$run_imports))
    tables$run_imports <- rbind(tables$run_imports,receipt)
    list(tables=tables,details=list(run_id=run_id,review_id=review_id,imported=imported))
  }
  state_transaction(root,mutate,expected_release,apply,metadata=list(action='import_run_review',run_id=run_id,review_id=review_id),replay_check=replay_check)
}
