cast_table <- function(data,spec) {
  for (field in names(spec$columns)) {
    type <- spec$columns[[field]]$type
    if (type %in% c('number','year')) data[[field]] <- num(data[[field]])
    if (type=='boolean') data[[field]] <- ifelse(nzchar(data[[field]]),data[[field]]=='TRUE',NA)
  }
  data
}
build_inputs <- function(root,state,geometry) {
  paths <- c(list.files(file.path(root,'scripts'),recursive=TRUE,full.names=TRUE,pattern='[.]R$'),
             list.files(file.path(root,'config'),recursive=TRUE,full.names=TRUE),file.path(root,'renv.lock'))
  paths <- sort(paths[file.exists(paths)])
  code <- setNames(lapply(paths,sha_file),substring(paths,nchar(root)+2))
  list(data_release=read_json(file.path(state,'manifest.json'))$release_id,data_manifest_sha256=sha_file(file.path(state,'manifest.json')),
       code_and_config=code,geometry=geometry$input_hashes,
       runtime=list(R=as.character(getRversion()),jsonlite=as.character(utils::packageVersion('jsonlite')),digest=as.character(utils::packageVersion('digest'))))
}
verify_output <- function(path) {
  manifest <- read_json(file.path(path,'manifest.json'))
  if (!identical(manifest$output_hashes,release_inventory(path))) stop('Generated release checksum mismatch')
  invisible(manifest)
}
publish_output <- function(stage,output,id,initialise=FALSE,failpoint=NULL) {
  output <- file.path(normalizePath(dirname(output),mustWork=TRUE),basename(output))
  releases <- paste0(output,'-releases'); destination <- file.path(releases,id)
  dir.create(releases,recursive=TRUE,showWarnings=FALSE)
  if (dir.exists(destination)) {
    verify_output(destination)
    if (!identical(file_inventory(stage),file_inventory(destination))) stop('Output ID collision')
    unlink(stage,recursive=TRUE)
  } else if (!file.rename(stage,destination)) stop('Cannot install complete output release')
  if (identical(failpoint,'before_pointer')) stop('Injected output interruption before pointer')
  legacy <- NULL; selected <- FALSE
  on.exit({
    if (!selected && !is.null(legacy)) file.rename(legacy,output)
  },add=TRUE)
  if (dir.exists(output) && !is_symlink(output)) {
    if (!initialise) stop('Existing output is a directory. Use --initialise-output once to preserve it and install a release pointer.')
    legacy <- file.path(releases,paste0('legacy-',substr(sha_value(file_inventory(output)),1,20)))
    if (dir.exists(legacy) || !file.rename(output,legacy)) stop('Cannot preserve previous output directory')
  }
  pointer <- tempfile('.tmp-output-',dirname(output)); on.exit(unlink(pointer),add=TRUE)
  if (!file.symlink(file.path(basename(releases),id),pointer)) stop('Cannot stage output pointer')
  if (!file.rename(pointer,output)) stop('Cannot atomically select complete output')
  selected <- TRUE
  invisible(destination)
}
build_export <- function(root,state,output,apply=FALSE,initialise=FALSE,failpoint=NULL) {
  root <- normalizePath(root,mustWork=TRUE); state <- normalizePath(state,mustWork=TRUE)
  parent <- verify_release(state)
  schema <- read_json(file.path(root,'config/schema.json')); method <- read_json(file.path(root,'config/methodology.json'))
  for (name in c('schema.json','methodology.json')) {
    if (sha_file(file.path(state,'contract',name))!=sha_file(file.path(root,'config',name))) stop('Release contract differs from working configuration; create a reviewed contract upgrade first')
  }
  validation <- validate_state(state,root,schema); tables <- load_state(state,schema)
  geometry <- assemble_geometry(tables,root) # All maps must succeed before any publication.
  inputs <- build_inputs(root,state,geometry)
  calculated <- account_all(tables,method)
  dir.create(dirname(output),recursive=TRUE,showWarnings=FALSE)
  releases <- paste0(output,'-releases'); staging <- file.path(releases,'.staging')
  dir.create(staging,recursive=TRUE,showWarnings=FALSE)
  stage <- tempfile('build-',staging); dir.create(stage)
  on.exit(unlink(stage,recursive=TRUE),add=TRUE)
  p <- cast_table(tables$projects_master,schema$tables$projects_master)
  loc <- tables$municipality_locations
  li <- match(paste(p$country,p$municipality),paste(loc$country,loc$municipality))
  p$latitude <- num(loc$latitude[li]); p$longitude <- num(loc$longitude[li]); p$coordinate_note <- loc$coordinate_note[li]
  p$coordinate_accuracy <- loc$accuracy[li]
  forward <- calculated$ledger$project_id[calculated$ledger$counted]
  p$has_counted_forward_capacity <- p$project_id %in% forward
  write_json(p,file.path(stage,'projects.json'))
  write_json(cast_table(tables$capacity_master,schema$tables$capacity_master),file.path(stage,'capacity.json'))
  write_json(cast_table(tables$capacity_observations,schema$tables$capacity_observations),file.path(stage,'capacity_observations.json'))
  write_json(calculated$scenario_zone,file.path(stage,'scenario_zone.json'))
  write_json(calculated$ledger,file.path(stage,'accounting_ledger.json'))
  write_table(calculated$ledger,file.path(stage,'accounting_ledger.csv'))
  write_json(tables$sources_master,file.path(stage,'sources.json'))
  write_json(tables$field_reviews,file.path(stage,'field_reviews.json'))
  write_json(cast_table(tables$assumptions,schema$tables$assumptions),file.path(stage,'assumptions.json'))
  write_json(geometry$geojson,file.path(stage,'bidding_zones.geojson'))
  unresolved <- calculated$ledger[!calculated$ledger$counted,,drop=FALSE]
  write_json(list(schema_version=schema$schema_version,as_of_date=method$as_of_date,validation=validation,
    countries=unlist(method$countries),active_projects=nrow(p),active_claims=nrow(tables$capacity_master),
    verified_sources=sum(tables$sources_master$review_state=='verified'),total_sources=nrow(tables$sources_master),
    source_access_min=min(tables$sources_master$access_date),source_access_max=max(tables$sources_master$access_date),
    verified_fields=nrow(tables$field_reviews),exclusion_counts=as.data.frame(table(unresolved$scenario_id,unresolved$reason)),
    geometry_provenance=geometry$provenance,energy_interpretation=method$annual_energy_label,
    sensitivity_interpretation=method$sensitivity_interpretation),file.path(stage,'quality.json'))
  # Code/config and external map inputs must remain unchanged throughout a build.
  if (!identical(inputs,build_inputs(root,state,geometry))) stop('Build inputs changed during generation')
  for (name in names(geometry$input_hashes)) if (sha_file(file.path(root,name))!=geometry$input_hashes[[name]]) stop('Map changed during generation')
  verify_release(state)
  if (identical(failpoint,'after_json')) stop('Injected output interruption after JSON generation')
  files <- release_inventory(stage)
  id <- paste0('build-',substr(sha_value(list(inputs=inputs,outputs=files)),1,20))
  write_json(list(build_id=id,schema_version=schema$schema_version,method_version=method$method_version,
    as_of_date=method$as_of_date,baseline_date=method$baseline_date,inputs=inputs,output_hashes=files,
    semantics=list(scenarios=method$scenarios,measure=method$measure,energy=method$annual_energy_label,
      separate_measures='IT, facility and grid columns are non-additive views; unknown is null',
      missing='Partial totals are labelled with completeness flags; excluded claims remain in the ledger')),
    file.path(stage,'manifest.json'))
  verify_output(stage)
  if (apply) publish_output(stage,output,id,initialise,failpoint)
  list(applied=apply,build_id=id,data_release=parent$release_id,output=output,validation=validation,
       project_count=nrow(p),claim_count=nrow(tables$capacity_master),ledger_rows=nrow(calculated$ledger),map_zones=length(geometry$geojson$features))
}
