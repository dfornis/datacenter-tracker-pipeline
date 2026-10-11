#!/usr/bin/env Rscript
source('scripts/lib/common.R'); source('scripts/lib/runtime.R')
root <- pipeline_root(); check_runtime(root); args <- cli_args(); check_args(args,c('check'))
schema <- read_json(file.path(root,'config/schema.json'))
lines <- c('# Data contract', '', paste0('Generated from `config/schema.json`, version ',schema$schema_version,'. Regenerate with `Rscript scripts/render_schema_doc.R`; CI uses `--check`.'), '',
  'Read [methodology](methodology.md) for interpretation, [status rules](status_rules.md) for lifecycle/decision evidence, and [consumer migration](consumer-migration-v2.md) for output changes. This is a typed CSV contract, not a JSON Schema. The separate `config/run_response.schema.json` is a standard JSON Schema for extraction responses.', '',
  'CSV values are UTF-8 strings with exact headers; blank means unknown unless the field is required. Numeric values use a decimal point, never thousands separators. Boolean values are `TRUE`/`FALSE`. IDs and administrative codes remain strings, preserving leading zeroes. Multi-value references use semicolons. JSON export casts typed numeric/boolean fields and uses `null` for unknowns.', '',
  'Project IDs describe a recorded project identity, while `physical_site_id` groups co-located campus/customer records. `phase_id` identifies scoped capacity. Source quotes and interpretation are separate; source confidence is not a completion probability. `field_reviews` binds each checked value hash to same-entity evidence. A record is fully verified only after its required fields are reviewed; a partial review remains `needs_review`.', '',
  'Legacy compatibility fields `type`, `start_year`, `scenario_tag`, `interpreted_it_load_mw` and project `max_reported_capacity_mw` are not independent scenario drivers. `start_year`, if retained, must equal the commissioning interval lower endpoint. Broad maximum MW summaries are not comparable across different power bases. Use explicit business/workload, interval, unit, denominator and physical relationship fields.', '',
  'Blank organisation roles, aliases, site PUE and exact coordinates are not inferred. Approximate municipality points must retain their accuracy/source caveats. All cross-table identities, scoped evidence, dates, units, phase relationships and comparable baselines are validated by `scripts/lib/validation.R` in addition to the column constraints below.', '',
  '## Tables','')
for(name in names(schema$tables)) {
  table <- schema$tables[[name]]
  lines <- c(lines,paste0('### ',name),'',paste0('Release path: `',table$path,'`. Key: `',paste(unlist(table$key),collapse=' + '),'`.'),'',
    '| Field | Type | Required | Constraints |','| --- | --- | --- | --- |')
  for(field in names(table$columns)) {
    spec <- table$columns[[field]]; details <- character()
    if(!is.null(spec$values))details<-c(details,paste(unlist(spec$values),collapse=', '))
    if(!is.null(spec$enum))details<-c(details,paste0('enum: ',spec$enum))
    for(k in c('min','max','pattern'))if(!is.null(spec[[k]]))details<-c(details,paste0(k,': ',gsub('|','\\|',as.character(spec[[k]]),fixed=TRUE)))
    lines<-c(lines,paste0('| `',field,'` | ',spec$type,' | ',if(isTRUE(spec$required))'yes' else 'no',' | ',paste(details,collapse='; '),' |'))
  }
  lines<-c(lines,'')
}
lines<-c(lines,'## Enumerations','')
for(name in names(schema$enums))lines<-c(lines,paste0('### ',name),'',paste(paste0('`',unlist(schema$enums[[name]]),'`'),collapse=', '),'')
lines<-c(lines,'## Complete-review fields','')
for(entity in names(schema$verification_fields))lines<-c(lines,paste0('- ',entity,': ',paste(paste0('`',unlist(schema$verification_fields[[entity]]),'`'),collapse=', ')))
path <- file.path(root,'docs/schema.md')
if(isTRUE(arg(args,'check',FALSE))) {
  if(!identical(readLines(path,warn=FALSE,encoding='UTF-8'),lines))stop('Schema documentation is stale; regenerate it')
  cat('Schema documentation matches contract.\n')
} else writeLines(lines,path,useBytes=TRUE)
