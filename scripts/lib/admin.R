regex_groups <- function(pattern,text) {
  matches <- regmatches(text,gregexpr(pattern,text,perl=TRUE))[[1]]
  lapply(matches,function(x)regmatches(x,regexec(pattern,x,perl=TRUE))[[1]][-1])
}
html_plain <- function(value) {
  replacements <- c('&amp;'='&','&nbsp;'=' ','&aring;'='å','&auml;'='ä','&ouml;'='ö','&Aring;'='Å','&Auml;'='Ä','&Ouml;'='Ö')
  for (key in names(replacements)) value <- gsub(key,replacements[[key]],value,fixed=TRUE)
  trimws(value)
}
admin_source_files <- function(country,spec) {
  languages <- unlist(spec$languages)
  setNames(lapply(languages,function(lang)list(file=paste0(tolower(country),'-',lang,if(spec$provider=='scb_html')'.html' else '.json'),
     url=gsub('{language}',lang,spec$url,fixed=TRUE))),languages)
}
fetch_admin_inputs <- function(config,path) {
  dir.create(path,recursive=TRUE,showWarnings=FALSE); records <- list()
  old <- options(timeout=45); on.exit(options(old),add=TRUE)
  for (country in names(config$countries)) for (source in admin_source_files(country,config$countries[[country]])) {
    destination <- file.path(path,source$file)
    if (file.exists(destination)) stop('Refusing to overwrite cached source: ',destination)
    status <- utils::download.file(source$url,destination,mode='wb',quiet=TRUE,method='libcurl')
    if (status!=0 || !file.exists(destination) || file.info(destination)$size==0) stop('Reference source download failed')
    records[[source$file]] <- list(url=source$url,retrieved_at=utc_now(),sha256=sha_file(destination),bytes=unname(file.info(destination)$size))
  }
  write_json(records,file.path(path,'source-manifest.json'))
  invisible(records)
}
parse_admin_country <- function(country,spec,config,country_row,columns,path) {
  base <- list(country=country,country_name=country_row$country_name,municipality_term_local=country_row$municipality_term_local,
    region_term_local=country_row$region_term_local,valid_from=config$valid_from,source_authority=spec$source_authority,
    source_url=gsub('{language}',unlist(spec$languages)[1],spec$url,fixed=TRUE),source_version=spec$source_version)
  files <- admin_source_files(country,spec); rows <- list()
  if (spec$provider=='scb_html') {
    page <- paste(readLines(file.path(path,files[[1]]$file),warn=FALSE,encoding='UTF-8'),collapse='\n')
    years <- unique(unlist(lapply(regex_groups('Counties and municipalities ([0-9]{4}) in numerical order',page),`[[`,1)))
    if (!identical(years,substr(config$valid_from,1,4))) stop('SCB page is not unambiguously the requested reference year')
    blocks <- regex_groups('(?s)<h2><a id="[^"]+"></a>([0-9]{2})\\s+([^<]+)</h2>\\s*<p>(.*?)</p>',page)
    for (block in blocks) for (entry in regex_groups('([0-9]{4})\\s+([^<]+)(?:<br\\s*/?>|$)',block[3])) {
      values <- c(base,list(municipality_code=entry[1],municipality_name=html_plain(entry[2]),municipality_name_local=html_plain(entry[2]),municipality_name_sv=html_plain(entry[2]),
        region_code=block[1],region_name=html_plain(block[2]),region_name_local=html_plain(block[2]),region_name_sv=html_plain(block[2])))
      rows[[length(rows)+1]] <- row_frame(values,columns)
    }
  } else {
    by_code <- list(); code_sets <- list()
    for (language in names(files)) {
      doc <- read_json(file.path(path,files[[language]]$file))
      if (spec$provider=='ssb_correspondence') {
        if (!grepl(substr(config$valid_from,1,4),doc$source,fixed=TRUE) || !grepl(substr(config$valid_from,1,4),doc$target,fixed=TRUE)) stop('SSB correspondence version does not match reference year')
        if (language=='nb' && doc$name!=spec$version_marker) stop('SSB correspondence table differs from reviewed configuration')
        entries <- doc$correspondenceMaps
      } else entries <- doc
      codes <- character()
      for (entry in entries) {
        if (spec$provider=='statfi_correspondence') {
          if (entry$correspondenceTable$localId!=spec$classification) stop('Statistics Finland classification differs from requested version')
          name <- function(item) {
            found <- Filter(function(n)n$lang==language,item$classificationItemNames)
            if (length(found)!=1) stop('Missing or ambiguous official translation')
            found[[1]]$name
          }
          code <- entry$sourceItem$code; region <- entry$targetItem$code
          names <- list(municipality=name(entry$sourceItem),region=name(entry$targetItem))
        } else {
          code <- entry$targetCode; region <- entry$sourceCode
          names <- list(municipality=entry$targetName,region=entry$sourceName)
        }
        if (code %in% unlist(spec$exclude_codes)) next
        if (code %in% codes) stop('Duplicate municipality code in official source')
        codes <- c(codes,code)
        if (is.null(by_code[[code]])) by_code[[code]] <- list(region_code=region)
        if (by_code[[code]]$region_code!=region) stop('Language versions disagree on region mapping')
        by_code[[code]][[language]] <- names
      }
      code_sets[[language]] <- sort(codes)
    }
    if (!all(vapply(code_sets,function(c)identical(c,code_sets[[1]]),logical(1)))) stop('Language versions have different municipality coverage')
    canonical <- country_row$canonical_name_language
    for (code in sort(names(by_code))) {
      entry <- by_code[[code]]; local <- entry[[canonical]]
      if (is.null(local)) stop('Canonical naming language is missing')
      values <- c(base,list(municipality_code=code,municipality_name=local$municipality,municipality_name_local=local$municipality,
        region_code=entry$region_code,region_name=local$region,region_name_local=local$region))
      for (language in names(files)) {
        values[[paste0('municipality_name_',language)]] <- entry[[language]]$municipality
        values[[paste0('region_name_',language)]] <- entry[[language]]$region
      }
      rows[[length(rows)+1]] <- row_frame(values,columns)
    }
  }
  result <- if(length(rows))do.call(rbind,rows) else empty_table(columns)
  if (nrow(result)!=spec$expected_count || anyDuplicated(result$municipality_code) || any(!nzchar(result$municipality_name))) stop('Official reference count/code checks failed for ',country,': expected ',spec$expected_count,', got ',nrow(result))
  result[order(result$municipality_code),,drop=FALSE]
}
table_changes <- function(before,after,keys) {
  key <- function(d)do.call(paste,c(d[keys],sep=':'))
  old_key <- key(before); new_key <- key(after); changes <- list()
  for (id in union(old_key,new_key)) {
    bi <- match(id,old_key); ai <- match(id,new_key)
    if (is.na(bi) || is.na(ai)) {
      changes[[length(changes)+1]] <- data.frame(key=id,field='record',before=if(is.na(bi))'' else 'present',after=if(is.na(ai))'' else 'present',stringsAsFactors=FALSE)
      next
    }
    for(field in setdiff(intersect(names(before),names(after)),keys)) if(before[[field]][bi]!=after[[field]][ai]) changes[[length(changes)+1]] <- data.frame(key=id,field=field,before=before[[field]][bi],after=after[[field]][ai],stringsAsFactors=FALSE)
  }
  if(length(changes))do.call(rbind,changes) else empty_table(c('key','field','before','after'))
}
prepare_admin_reference <- function(root,state,year,raw_path,output) {
  if (dir.exists(output)) stop('Reference proposal already exists; choose a new output directory')
  config <- read_json(file.path(root,'config/admin_sources.json'))[[as.character(year)]]
  if(is.null(config))stop('Reference year is not configured; review source versions and expected counts first')
  schema <- read_json(file.path(root,'config/schema.json')); tables <- load_state(state,schema); release <- verify_release(state)
  active <- tables$country_config$country[tables$country_config$active=='TRUE']
  if(!setequal(active,names(config$countries)))stop('Reference source configuration must cover exactly the active countries')
  sources <- read_json(file.path(raw_path,'source-manifest.json'))
  for(country in active) for(source in admin_source_files(country,config$countries[[country]])) {
    record <- sources[[source$file]]
    if(is.null(record) || record$url!=source$url || record$sha256!=sha_file(file.path(raw_path,source$file)))stop('Raw reference source differs from its retrieval manifest')
  }
  parsed <- lapply(sort(active),function(country)parse_admin_country(country,config$countries[[country]],config,tables$country_config[tables$country_config$country==country,,drop=FALSE],names(tables$admin_units),raw_path))
  replacement <- do.call(rbind,parsed); rownames(replacement)<-NULL
  changes <- table_changes(tables$admin_units,replacement,c('country','municipality_code'))
  dir.create(output,recursive=TRUE)
  write_table(replacement,file.path(output,'admin_units.csv')); write_table(changes,file.path(output,'changes.csv'))
  write_json(list(year=year,input_release=release$release_id,original_admin_sha256=sha_file(file.path(state,'master/admin_units.csv')),
    country_config_sha256=sha_file(file.path(state,'master/country_config.csv')),source_config_sha256=sha_file(file.path(root,'config/admin_sources.json')),
    raw_sources=sources,counts=as.list(table(replacement$country)),files=file_inventory(output)),file.path(output,'manifest.json'))
  list(path=output,counts=as.list(table(replacement$country)),changed_cells=nrow(changes),semantic_changes=sum(changes$field %in% c('record','municipality_name','region_code','region_name')))
}
apply_admin_reference <- function(root,proposal,expected_release,reviewer,apply=FALSE) {
  if(!nzchar(reviewer))stop('Reference replacement needs review attribution')
  manifest <- read_json(file.path(proposal,'manifest.json'))
  if(!identical(manifest$files,release_inventory(proposal)))stop('Reference proposal has changed since preparation')
  if(manifest$source_config_sha256!=sha_file(file.path(root,'config/admin_sources.json')))stop('Reference source configuration has changed')
  state_transaction(root,function(tables,stage,schema) {
    if(manifest$original_admin_sha256!=sha_file(file.path(stage,'master/admin_units.csv')) || manifest$country_config_sha256!=sha_file(file.path(stage,'master/country_config.csv')))stop('Administrative or country configuration changed since preparation')
    tables$admin_units <- read_table(file.path(proposal,'admin_units.csv'))
    archive <- file.path(stage,'audit/archive/admin',paste0(manifest$year,'-',substr(sha_file(file.path(proposal,'manifest.json')),1,16)))
    copy_directory(proposal,archive)
    write_json(list(reviewer=reviewer,reviewed_at=utc_now()),file.path(archive,'review.json'))
    # Shared validation rejects orphaned codes or uncoordinated name changes before publication.
    list(tables=tables,details=list(year=manifest$year,reviewer=reviewer,changed_cells=nrow(read_table(file.path(proposal,'changes.csv')))))
  },expected_release,apply,metadata=list(action='admin_reference',year=manifest$year,reviewer=reviewer))
}
