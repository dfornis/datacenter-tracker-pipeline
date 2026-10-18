# Presentation only. All MW, energy, timing and overlap accounting comes from calculate().
# The website reads results.json; compatibility files contain the same approved result.
public_result <- function(result) {
  keep<-result$projects$record_type=='existing'
  p<-result$projects[keep,,drop=FALSE];ids_<-p$project_id
  out<-result
  out$projects<-p
  out$capacity<-result$capacity[result$capacity$project_id %in% ids_,,drop=FALSE]
  out$project_scenarios<-result$project_scenarios[result$project_scenarios$project_id %in% ids_,,drop=FALSE]
  out$ledger<-result$ledger[result$ledger$project_id %in% ids_,,drop=FALSE]
  out$actors<-result$actors[result$actors$project_id %in% ids_,,drop=FALSE]
  out$timeline$rows<-NULL
  out$timing_diagnostics<-NULL
  out$actor_coverage<-actor_coverage(p,out$actors)
  refs<-unique(c(unlist(lapply(p$source_ids,ids)),unlist(lapply(out$capacity$source_ids,ids)),unlist(lapply(out$actors$source_ids,ids))))
  out$sources<-result$sources[result$sources$source_id %in% refs,,drop=FALSE]
  out$approval<-list(approved_project_ids=as.list(ids_))
  # Pending identifiers/counts belong to the local review, not the public view.
  out$scenarios$pending_projects<-NULL
  out$coverage<-list(projects=nrow(p),claims=nrow(out$capacity),sources=nrow(out$sources),
    scenario_rows=nrow(out$project_scenarios),every_project_represented=TRUE,
    projects_without_mw=as.list(unique(out$project_scenarios$project_id[
      !out$project_scenarios$capacity_known & !out$project_scenarios$indicator %in% c('cancelled','dormant','operational')])))
  out
}
build_tracker <- function(root='.',data_dir=file.path(root,'data'),result=NULL) {
  if(is.null(result))result<-build_result(root,data_dir)
  out<-public_result(result)
  cfg<-list(scenarios=result$method$scenarios)
  # Preserve the filenames while exposing the actual model ranges, never a second estimate.
  sz<-out$scenarios
  sz$scenario_id<-sz$scenario
  sz$country<-substr(sz$bidding_zone,1,2)
  sz$year<-vapply(sz$scenario,function(id)cfg$scenarios[[match(id,vapply(cfg$scenarios,`[[`,'','id'))]]$year,0)
  sz$scenario_label<-vapply(sz$scenario,function(id)cfg$scenarios[[match(id,vapply(cfg$scenarios,`[[`,'','id'))]]$label,'')
  # Explicit lower-bound aliases for older data consumers; the new page displays both bounds.
  sz$grid_side_mw<-sz$mw<-sz$mw_low
  sz$estimated_twh<-sz$annual_twh_low
  sz$n_projects<-sz$participating_projects
  timeline<-result$timeline
  timeline$rows<-timeline$rows[timeline$rows$project_id %in% out$projects$project_id,,drop=FALSE]
  list(results=out,projects=out$projects,capacity=out$capacity,scenario_zone=sz,bidding_zones=out$bidding_zones,timeline=timeline)
}
write_tracker <- function(out,dir) {
  dir.create(dir,recursive=TRUE,showWarnings=FALSE)
  for(n in c('results','projects','capacity','scenario_zone','timeline'))
    jsonlite::write_json(out[[n]],file.path(dir,paste0(n,'.json')),pretty=n!='results',auto_unbox=TRUE,na='null',null='null',digits=NA)
  jsonlite::write_json(out$bidding_zones,file.path(dir,'bidding_zones.geojson'),pretty=FALSE,auto_unbox=TRUE,na='null',null='null',digits=NA)
  invisible(dir)
}
