#!/usr/bin/env Rscript
source('scripts/lib/common.R');source('scripts/lib/validation.R');source('scripts/lib/releases.R');source('scripts/lib/accounting.R');source('scripts/lib/runtime.R')
root<-pipeline_root();check_runtime(root);schema<-read_json(file.path(root,'config/schema.json'));method<-read_json(file.path(root,'config/methodology.json'))
before<-file.path(root,'data/releases/r2-e6b6b27245af3290f523');after<-current_state(root);verify_release(before);verify_release(after)
a<-load_state(before,schema);b<-load_state(after,schema);out<-file.path(root,'docs/reviews/2026-10-11/results');dir.create(out,recursive=TRUE,showWarnings=FALSE)
changes<-list()
for(name in c('projects_master','capacity_master')) {
 key<-schema$tables[[name]]$key[[1]]; old<-a[[name]];new<-b[[name]]
 for(i in seq_len(nrow(new))) {
  j<-match(new[[key]][i],old[[key]]);if(is.na(j))next
  for(field in names(new))if(old[[field]][j]!=new[[field]][i]) {
   review<-b$field_reviews[b$field_reviews$entity_id==new[[key]][i] & b$field_reviews$field==field,,drop=FALSE]
   category<-if(nrow(review))paste0('reviewed_',review$review_kind[1]) else if(field=='start_year')'derived_compatibility_alias' else 'derived_review_metadata'
   changes[[length(changes)+1]]<-data.frame(table=name,entity_id=new[[key]][i],country=new$country[i],field=field,before=old[[field]][j],after=new[[field]][i],attribution=category,run_id=if(nrow(review))review$run_id[1] else '',source_ids=if(nrow(review))review$source_ids[1] else '',stringsAsFactors=FALSE)
  }
 }
}
write_table(do.call(rbind,changes),file.path(out,'field-changes.csv'))
calc_a<-account_all(a,method);calc_b<-account_all(b,method)
write_table(calc_a$ledger,file.path(out,'ledger-before.csv'));write_table(calc_b$ledger,file.path(out,'ledger-after.csv'))
keys<-c('scenario_id','claim_id'); fields<-c('counted','reason','it_load_mw','facility_power_mw','grid_connection_mw','conditional_mature_annual_twh_low','conditional_mature_annual_twh_high')
m<-merge(calc_a$ledger[,c(keys,fields)],calc_b$ledger[,c(keys,fields)],by=keys,suffixes=c('_before','_after'),all=TRUE)
changed<-rep(FALSE,nrow(m));for(field in fields){x<-m[[paste0(field,'_before')]];y<-m[[paste0(field,'_after')]];different<-(is.na(x)!=is.na(y))|(!is.na(x)&!is.na(y)&x!=y);changed<-changed|different}
write_table(m[changed,,drop=FALSE],file.path(out,'ledger-changes.csv'))
summary_rows<-list()
for(stage in c('before','after')) {
 l<-if(stage=='before')calc_a$ledger else calc_b$ledger
 for(country in unlist(method$countries))for(scenario in vapply(method$scenarios,function(s)s$scenario_id,character(1))) {
  all<-l[l$country==country & l$scenario_id==scenario,,drop=FALSE];d<-all[all$counted,,drop=FALSE]
  partial<-function(f) if(!nrow(d))0 else if(all(is.na(d[[f]])))NA_real_ else sum(d[[f]],na.rm=TRUE)
  summary_rows[[length(summary_rows)+1]]<-data.frame(stage=stage,country=country,scenario_id=scenario,counted_claims=nrow(d),known_it_mw=partial('it_load_mw'),known_facility_mw=partial('facility_power_mw'),known_grid_mw=partial('grid_connection_mw'),conditional_mature_twh_low=partial('conditional_mature_annual_twh_low'),conditional_mature_twh_high=partial('conditional_mature_annual_twh_high'),excluded_claims=nrow(all)-nrow(d),scope='partial non-additive measure views, not a national forecast',stringsAsFactors=FALSE)
 }
}
write_table(do.call(rbind,summary_rows),file.path(out,'country-comparison.csv'))
runstats<-list()
for(kind in c('pilot','audit','discover'))for(country in tolower(unlist(method$countries))) {
 id<-paste0('2026-10-11-',country,'-',kind);d<-read_json(file.path(root,'data/runs',id,'work/response.json'))
 outcomes<-unlist(lapply(d$coverage,function(c)vapply(c$field_outcomes,function(f)f$outcome,character(1))))
 runstats[[id]]<-list(proposals=length(d$proposals),evidence_items=length(d$evidence),coverage_rows=length(d$coverage),field_outcomes=as.list(table(outcomes)))
}
write_json(list(baseline_release=basename(before),current_release=basename(after),comparison='Same version-2 method applied to both states; differences reflect reviewed factual changes. The original v1 figures are methodologically non-comparable and preserved in utvardering.md.',changed_fields=length(changes),changed_ledger_rows=sum(changed),runs=runstats),file.path(out,'summary.json'))
cat(basename(after),length(changes),'changed cells;',sum(changed),'changed ledger rows\n')
