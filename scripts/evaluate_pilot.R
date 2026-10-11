#!/usr/bin/env Rscript
# Recheck the frozen real-source acceptance cases, not a blind model benchmark.
source('scripts/lib/common.R'); source('scripts/lib/validation.R'); source('scripts/lib/releases.R'); source('scripts/lib/accounting.R'); source('scripts/lib/runtime.R')
root <- pipeline_root(); check_runtime(root)
state <- file.path(root,'data/releases/r2-7f9486d6fc7ee1536aa0'); verify_release(state)
schema <- read_json(file.path(root,'config/schema.json')); t <- load_state(state,schema)
ledger <- account_all(t,read_json(file.path(root,'config/methodology.json')))$ledger
results <- list()
check <- function(id,description,condition) results[[length(results)+1]] <<- list(case=id,description=description,passed=isTRUE(condition))
field <- function(id,name) t$capacity_master[[name]][match(id,t$capacity_master$claim_id)]
rows <- function(id) ledger[ledger$claim_id==id,,drop=FALSE]
check('FI-source-identity','Incorrect legacy FI source IDs stay retired and replacement links remain scoped.',!any(sprintf('S%03d',44:56) %in% t$sources_master$source_id) && all(t$sources_master$project_id[match(sprintf('S%03d',58:70),t$sources_master$source_id)]==sprintf('P%03d',26:38)))
check('Mistral-basis','23 MW is not upgraded to IT load without an explicit denominator.',field('C014','reported_capacity_basis')=='unspecified_headline' && field('C014','interpreted_it_load_mw')=='')
check('Mistral-overlap','Unresolved customer/campus overlap blocks their combined potential.',rows('C014')$reason[rows('C014')$scenario_id=='pipeline_potential']=='unresolved_overlap')
check('Google-thermal','468 MW thermal backup power never enters electric-load scenarios.',all(rows('C022')$reason=='not_datacenter_electric_load'))
check('Hamar-operational-basis','90 MW baseline is source-reported IT capacity.',field('C025','reported_capacity_basis')=='it_load')
check('Hamar-first-capacity','2023 is first-capacity timing, not proof all 90 MW opened then.',field('C025','timing_scope')=='first_capacity')
check('Hamar-expansion','An operational campus retains an undated 60 MW IT increment.',rows('C026')$it_load_mw[rows('C026')$scenario_id=='pipeline_potential']==60)
check('Hamar-undated','150 MW expansion ceiling does not acquire a full commissioning year.',field('C026','timing_scope')=='unknown' && all(!rows('C026')$counted[rows('C026')$scenario_id!='pipeline_potential']))
check('Lefdal-grid','Available connection remains distinct from installed IT.',field('C030','reported_capacity_basis')=='grid_connection' && field('C030','measurement_kind')=='available_power')
check('Lefdal-baseline','200 MW potential cannot subtract an 80 MW available connection as installed capacity.',all(rows('C031')$reason=='installed_baseline_unknown'))
check('FIN04-basis','430 MW headline is not converted with a PUE assumption.',field('C038','reported_capacity_basis')=='unspecified_headline' && all(is.na(rows('C038')$conditional_mature_annual_twh_high)))
check('FIN04-PUE','The 1.2 PUE limit is explicitly design and up-to.',field('C038','site_pue')=='1.2' && field('C038','site_pue_kind')=='design' && field('C038','site_pue_qualifier')=='up_to')
check('XTX-timing','2027 first capacity does not date the full 310 MW campus.',field('C040','timing_scope')=='first_capacity' && field('C040','operation_year_min')=='2027' && all(!rows('C040')$counted[rows('C040')$scenario_id!='pipeline_potential']))
check('No-target-energy','No target-year electricity is invented without a deployment schedule.',all(is.na(ledger$target_year_energy_twh_high)))
verified <- t$sources_master[t$sources_master$review_state=='verified',,drop=FALSE]
check('Exact-evidence','Verified sources retain original excerpts, languages, locators and attribution.',nrow(verified)>0 && all(nzchar(verified$original_excerpt)) && all(nzchar(verified$locator)) && all(nzchar(verified$original_language)) && all(nzchar(verified$reviewed_by)))
report <- list(pilot_release=basename(state),passed=sum(vapply(results,function(x)x$passed,logical(1))),cases=results,interpretation='Same-agent reviewed real-source acceptance suite. Not blind, independent, representative or a model accuracy/recall estimate. Model identifier was not exposed. Failed source retrievals remain unknown.',countries=3,projects=7,claims=10)
write_json(report,file.path(root,'docs/reviews/2026-10-11/pilot/acceptance-results.json'))
cat(report$passed,'/',length(results),'real-source acceptance cases passed\n')
if(report$passed!=length(results))stop('Pilot acceptance case failed')
