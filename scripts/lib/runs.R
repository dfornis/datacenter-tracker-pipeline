validate_json_contract <- function(value,schema,path='$') {
  errors <- character(); add <- function(msg) errors <<- c(errors,paste(path,msg))
  type <- schema$type
  valid <- switch(type,object=is.list(value) && (length(value)==0 || !is.null(names(value))),
    array=is.list(value) && is.null(names(value)),string=is.character(value) && length(value)==1,
    number=is.numeric(value) && length(value)==1 && is.finite(value),boolean=is.logical(value) && length(value)==1,FALSE)
  if (!valid) return(paste(path,'expected',type))
  if (type=='object') {
    missing <- setdiff(unlist(schema$required),names(value)); if(length(missing)) add(paste('missing',paste(missing,collapse=', ')))
    extra <- setdiff(names(value),names(schema$properties))
    if (identical(schema$additionalProperties,FALSE) && length(extra)) add(paste('unknown keys',paste(extra,collapse=', ')))
    for (key in names(value)) {
      rule <- schema$properties[[key]]
      if (is.null(rule) && is.list(schema$additionalProperties)) rule <- schema$additionalProperties
      if (!is.null(rule)) errors <- c(errors,validate_json_contract(value[[key]],rule,paste0(path,'.',key)))
    }
  }
  if (type=='array') {
    if (!is.null(schema$minItems) && length(value)<schema$minItems) add('array too short')
    for (i in seq_along(value)) errors <- c(errors,validate_json_contract(value[[i]],schema$items,paste0(path,'[',i,']')))
  }
  if (type=='string') {
    if (!is.null(schema$enum) && !value %in% unlist(schema$enum)) add('value outside enum')
    if (!is.null(schema$pattern) && !grepl(schema$pattern,value)) add('pattern mismatch')
    if (identical(schema$format,'uri') && !grepl('^https?://[^/[:space:]]+[^[:space:]]*$',value)) add('invalid HTTP URL')
    if (identical(schema$format,'date') && !valid_date(value)) add('invalid date')
    if (identical(schema$format,'date-time') && (!grepl('^[0-9-]{10}T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]Z$',value) || !valid_date(substr(value,1,10)))) add('invalid UTC datetime')
  }
  errors
}
run_inventory <- function(path) {
  files <- c(file_inventory(file.path(path,'input')),file_inventory(file.path(path,'instructions')))
  names(files) <- c(paste0('input/',names(file_inventory(file.path(path,'input')))),paste0('instructions/',names(file_inventory(file.path(path,'instructions')))))
  files
}
verify_run <- function(path) {
  manifest <- read_json(file.path(path,'manifest.json'))
  if (!identical(manifest$frozen_files,run_inventory(path))) stop('Frozen run input or instructions were modified')
  manifest
}
create_country_run <- function(root,state,country,task,run_id,engine,model,project_ids=character()) {
  if (!grepl('^[A-Za-z0-9][A-Za-z0-9._-]{2,100}$',run_id)) stop('Run ID must be a safe unique directory name')
  if (!task %in% c('audit','discover') || !nzchar(engine) || !nzchar(model)) stop('Task, engine and model identity are required; use not_exposed when exact model ID is unavailable')
  final_path <- file.path(root,'data/runs',run_id)
  if (dir.exists(final_path)) stop('Run already exists; frozen inputs cannot be replaced')
  staging <- file.path(root,'data/runs/.staging'); dir.create(staging,recursive=TRUE,showWarnings=FALSE)
  path <- tempfile('run-',staging); on.exit(unlink(path,recursive=TRUE),add=TRUE)
  release <- verify_release(state); schema <- read_json(file.path(root,'config/schema.json')); validate_state(state,root,schema)
  tables <- load_state(state,schema); active <- tables$country_config$country[tables$country_config$active=='TRUE']
  if (!country %in% active) stop('Country is not configured and active')
  country_projects <- tables$projects_master$project_id[tables$projects_master$country==country]
  if(length(project_ids) && (task!='audit' || any(!project_ids %in% country_projects)))stop('Scoped pilot requires known same-country project IDs and audit task')
  selected_ids <- if(length(project_ids))project_ids else country_projects
  workflow <- read_json(file.path(root,'config/run_workflow.json'))
  dir.create(file.path(path,'input'),recursive=TRUE); dir.create(file.path(path,'instructions')); dir.create(file.path(path,'work'))
  for (name in names(tables)) {
    if (!startsWith(schema$tables[[name]]$path,'master/')) next
    data <- tables[[name]]
    if ('country' %in% names(data)) data <- data[data$country==country,,drop=FALSE]
    if (name %in% c('projects_master','capacity_master','sources_master')) data <- data[data$project_id %in% selected_ids,,drop=FALSE]
    if (name %in% c('capacity_observations','deployment_schedule')) data <- data[data$claim_id %in% tables$capacity_master$claim_id[tables$capacity_master$project_id %in% selected_ids],,drop=FALSE]
    if (name=='field_reviews') data <- data[data$entity_id %in% c(selected_ids,tables$capacity_master$claim_id[tables$capacity_master$project_id %in% selected_ids]),,drop=FALSE]
    if (name=='identity_registry') next # Models do not allocate permanent identities.
    write_table(data,file.path(path,'input',paste0(name,'.csv')))
  }
  write_table(tables$projects_master[,c('project_id','country','project_name','developer','physical_site_id','municipality','aliases')],file.path(path,'input','global_identity_index.csv'))
  for (name in c('schema.json','methodology.json','run_workflow.json','run_response.schema.json')) if (!file.copy(file.path(root,'config',name),file.path(path,'input',name))) stop('Failed to freeze run contract')
  for (name in c('methodology.md','energy-assumptions.md','status_rules.md')) if (!file.copy(file.path(root,'docs',name),file.path(path,'instructions',name))) stop('Failed to freeze run instructions')
  template <- file.path(root,'prompts',paste0(task,'_template.md'))
  overlay <- file.path(root,'prompts/country_overlays',paste0(tolower(country),'.md'))
  if (!file.exists(template) || !file.exists(overlay)) stop('Missing country prompt')
  writeLines(c(paste0('# Frozen country run ',run_id),paste0('Country: ',country,'; task: ',task,'; input release: ',release$release_id),
    paste0('Engine: ',engine,'; exact model: ',model),
    'Read only this run\'s input/ and instructions/. Process one numbered packet at a time. Write work/response.json; never edit masters, shared review queues or frozen files.',
    '',readLines(template,warn=FALSE),'',readLines(overlay,warn=FALSE)),file.path(path,'instructions','prompt.md'),useBytes=TRUE)
  projects <- tables$projects_master[tables$projects_master$project_id %in% selected_ids,,drop=FALSE]
  groups <- split(projects$project_id,ceiling(seq_len(nrow(projects))/workflow$packet_projects))
  for (i in seq_along(groups)) {
    ids <- groups[[i]]
    packet <- list(projects=projects[projects$project_id %in% ids,,drop=FALSE],
      capacities=tables$capacity_master[tables$capacity_master$project_id %in% ids,,drop=FALSE],
      evidence=tables$sources_master[tables$sources_master$project_id %in% ids,,drop=FALSE])
    write_json(packet,file.path(path,'input',sprintf('packet-%03d.json',i)))
  }
  manifest <- list(run_id=run_id,task=task,country=country,scope=if(length(project_ids))'selected_project_pilot' else 'country',project_ids=as.list(selected_ids),created_at=utc_now(),as_of_date=read_json(file.path(root,'config/methodology.json'))$as_of_date,
    engine=engine,model=model,temperature='not_exposed',tool_settings='record actual search engine in each search row',
    input_release=release$release_id,input_release_manifest_sha256=sha_file(file.path(state,'manifest.json')),
    input_master_hashes=file_inventory(file.path(state,'master')),frozen_files=run_inventory(path))
  write_json(manifest,file.path(path,'manifest.json'))
  write_json(list(run_id=run_id,searches=list(),evidence=list(),coverage=list(),proposals=list(),conflicts=list(),summary='',limitations=list()),file.path(path,'work','response.json'))
  verify_run(path)
  if (!file.rename(path,final_path)) stop('Cannot install frozen run')
  list(run_id=run_id,path=final_path,input_release=release$release_id,packet_count=length(groups),project_count=nrow(projects),task=task,country=country)
}
validate_run_response <- function(path,response_path=file.path(path,'work','response.json'),stop_on_error=TRUE) {
  manifest <- verify_run(path); response <- read_json(response_path)
  errors <- validate_json_contract(response,read_json(file.path(path,'input','run_response.schema.json')))
  fail <- function(message) errors <<- c(errors,message)
  if (!length(errors)) {
    schema <- read_json(file.path(path,'input','schema.json')); workflow <- read_json(file.path(path,'input','run_workflow.json'))
    projects <- read_table(file.path(path,'input/projects_master.csv')); claims <- read_table(file.path(path,'input/capacity_master.csv'))
    if (response$run_id!=manifest$run_id) fail('Response belongs to another run')
    ids <- function(rows,key) vapply(rows,function(row)row[[key]],character(1))
    search_ids <- ids(response$searches,'search_id'); evidence_ids <- ids(response$evidence,'evidence_id'); proposal_ids <- ids(response$proposals,'proposal_id')
    for (set in list(search_ids,evidence_ids,proposal_ids)) if(any(!grepl('^[A-Za-z][A-Za-z0-9_-]{0,79}$',set)) || anyDuplicated(set)) fail('Run-local IDs must be safe, nonempty and unique')
    candidate_projects <- vapply(Filter(function(p)p$table=='new_project_candidates',response$proposals),function(p)p$proposal_id,character(1))
    candidate_claims <- vapply(Filter(function(p)p$table=='new_capacity_claim_candidates',response$proposals),function(p)p$proposal_id,character(1))
    allowed_fields <- unique(unlist(lapply(schema$tables[c('projects_master','capacity_master','sources_master')],function(t)names(t$columns))))
    language <- ids(response$searches,'language')
    if (any(!unlist(workflow$minimum_search_languages[[manifest$country]]) %in% language)) fail('Required country search languages are not covered')
    for (s in response$searches) {
      if (!nzchar(s$query) || !nzchar(s$outcome) || !nzchar(s$engine)) fail('Every search/open needs query, engine and outcome')
      if (!s$scope_id %in% c(manifest$country,projects$project_id,claims$claim_id,candidate_projects,candidate_claims,unlist(workflow$discovery_routes))) fail('Search has unknown scope')
    }
    for (e in response$evidence) {
      if (!e$project_id %in% c(projects$project_id,candidate_projects)) fail(paste('Evidence has unknown project',e$evidence_id))
      if (nzchar(e$claim_id) && !e$claim_id %in% c(claims$claim_id,candidate_claims)) fail(paste('Evidence has unknown claim',e$evidence_id))
      if (e$claim_id %in% claims$claim_id && claims$project_id[match(e$claim_id,claims$claim_id)]!=e$project_id) fail('Evidence claim/project mismatch')
      if (any(!unlist(e$supports_fields) %in% allowed_fields)) fail('Evidence lists unsupported field names')
      if (e$retrieval_status=='accessible' && (!nzchar(e$original_excerpt) || !nzchar(e$original_language) || !nzchar(e$locator) || !nzchar(e$independence_group))) fail('Accessible evidence lacks exact original text, language, locator or independence group')
      if (nzchar(e$publication_date) && !grepl('^([0-9]{4}|[0-9]{4}-(0[1-9]|1[0-2])|[0-9]{4}-(0[1-9]|1[0-2])-[0-9]{2})$',e$publication_date)) fail('Invalid publication date precision')
      if (nzchar(e$publication_date) && (e$publication_date>substr(manifest$as_of_date,1,nchar(e$publication_date)) || e$publication_date>substr(e$access_date,1,nchar(e$publication_date)))) fail('Evidence publication date is after as-of date/access at its stated precision')
      if (nchar(e$publication_date)==10 && (!valid_date(e$publication_date) || e$publication_date>manifest$as_of_date || e$publication_date>e$access_date)) fail('Evidence publication date is invalid or after as-of date/access')
    }
    evidence_supported <- function(ids,field,project_id,claim_id='') {
      if (!length(ids) || any(!ids %in% evidence_ids)) return(FALSE)
      selected <- response$evidence[match(ids,evidence_ids)]
      all(vapply(selected,function(e)e$retrieval_status=='accessible' && e$project_id==project_id && e$claim_id==claim_id && field %in% unlist(e$supports_fields),logical(1)))
    }
    covered <- character()
    for (coverage in response$coverage) {
      key <- paste(coverage$entity_type,coverage$entity_id,sep=':'); if(key %in% covered) fail('Duplicate coverage row'); covered <- c(covered,key)
      if (any(!unlist(coverage$search_ids) %in% search_ids) || !length(coverage$search_ids)) fail('Coverage needs valid search IDs, including no-change results')
      if (coverage$entity_type=='discovery_route') {
        if (!coverage$entity_id %in% unlist(workflow$discovery_routes)) fail('Unknown discovery route')
        next
      }
      allowed <- if(coverage$entity_type=='project') projects$project_id else claims$claim_id
      if (!coverage$entity_id %in% allowed) {fail('Coverage targets an unknown country entity'); next}
      fields <- ids(coverage$field_outcomes,'field')
      if (anyDuplicated(fields) || any(!unlist(workflow$audit_required_fields[[coverage$entity_type]]) %in% fields)) fail(paste('Coverage is missing required fields:',key))
      pid <- if(coverage$entity_type=='project') coverage$entity_id else claims$project_id[match(coverage$entity_id,claims$claim_id)]
      cid <- if(coverage$entity_type=='claim') coverage$entity_id else ''
      scoped <- Filter(function(s)s$scope_id %in% c(pid,cid) && s$action=='search',response$searches)
      if (!length(scoped)) fail(paste('No targeted update search:',key))
      for (f in coverage$field_outcomes) {
        entity_fields <- names(if(coverage$entity_type=='project') projects else claims)
        if (!f$field %in% entity_fields || any(!unlist(f$search_ids) %in% search_ids)) fail('Invalid field coverage reference')
        if (f$outcome=='confirmed' && !evidence_supported(unlist(f$evidence_ids),f$field,pid,cid)) fail(paste('Confirmed field lacks accessible same-entity evidence:',key,f$field))
        if (f$outcome=='correction_proposed') {
          target_table <- if(coverage$entity_type=='project') 'suggested_project_updates' else 'suggested_capacity_updates'
          target_key <- if(coverage$entity_type=='project') 'project_id' else 'claim_id'
          matching <- Filter(function(p)p$table==target_table && identical(p$values[[target_key]],coverage$entity_id) && identical(p$values$field,f$field),response$proposals)
          if(length(matching)!=1)fail('Correction coverage must reference exactly one matching proposal')
        }
        if (f$outcome %in% c('unknown','conflict','not_applicable') && !nzchar(f$notes)) fail('Unknown/conflicting/not-applicable fields require an explanation')
      }
    }
    expected <- if(manifest$task=='audit') c(paste0('project:',projects$project_id),paste0('claim:',claims$claim_id)) else paste0('discovery_route:',unlist(workflow$discovery_routes))
    if (any(!expected %in% covered)) fail(paste('Coverage missing:',paste(setdiff(expected,covered),collapse=', ')))
    for (p in response$proposals) {
      spec <- schema$tables[[p$table]]; fields <- names(p$values)
      protected <- c('audit_id','run_id','review_state','reviewed_by','reviewed_at','resolution','source_url','original_excerpt','supports_fields')
      if (any(!fields %in% names(spec$columns)) || any(fields %in% protected)) fail('Proposal supplies unknown or workflow-owned fields')
      if (!nzchar(p$rationale)) fail('Proposal needs an interpretation rationale')
      if (!length(p$evidence_ids) || any(!unlist(p$evidence_ids) %in% evidence_ids)) fail('Proposal evidence is missing')
      if (manifest$task=='audit' && startsWith(p$table,'new_')) fail('Audit cannot silently become discovery; record the lead for a discovery run')
      if (startsWith(p$table,'suggested_')) {
        target <- switch(p$table,suggested_project_updates=projects,suggested_capacity_updates=claims,suggested_source_updates=read_table(file.path(path,'input/sources_master.csv')))
        key <- switch(p$table,suggested_project_updates='project_id',suggested_capacity_updates='claim_id',suggested_source_updates='source_id')
        if (any(!c(key,'field','current_value','suggested_value') %in% names(p$values))) {fail('Update proposal is missing its entity, field or explicit before/after values'); next}
        id <- p$values[[key]] %||% ''; i <- match(id,target[[key]]); field <- p$values$field %||% ''
        if (is.na(i) || !field %in% names(target)) {fail('Proposal targets unknown entity/field'); next}
        if ((p$values$current_value %||% '') != target[[field]][i]) fail('Proposal current_value differs from frozen input')
        if (p$table!='suggested_source_updates' && !evidence_supported(unlist(p$evidence_ids),field,target$project_id[i],if(key=='claim_id')id else '')) fail('Proposal evidence does not support the target field and entity')
      }
    }
    for (conflict in response$conflicts) if (length(conflict$evidence_ids)<2 || any(!unlist(conflict$evidence_ids) %in% evidence_ids) || !nzchar(conflict$description)) fail('Conflict needs two registered evidence items and an explanation')
  }
  result <- list(valid=!length(errors),errors=unique(errors),run_id=manifest$run_id,response_sha256=sha_file(response_path))
  if (stop_on_error && length(errors)) stop(paste(c('Run response failed validation:',paste0('- ',unique(errors))),collapse='\n'),call.=FALSE)
  result
}
