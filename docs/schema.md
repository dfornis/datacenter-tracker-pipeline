# Data contract

Generated from `config/schema.json`, version 2.0.0. Regenerate with `Rscript scripts/render_schema_doc.R`; CI uses `--check`.

Read [methodology](methodology.md) for interpretation, [status rules](status_rules.md) for lifecycle/decision evidence, and [consumer migration](consumer-migration-v2.md) for output changes. This is a typed CSV contract, not a JSON Schema. The separate `config/run_response.schema.json` is a standard JSON Schema for extraction responses.

CSV values are UTF-8 strings with exact headers; blank means unknown unless the field is required. Numeric values use a decimal point, never thousands separators. Boolean values are `TRUE`/`FALSE`. IDs and administrative codes remain strings, preserving leading zeroes. Multi-value references use semicolons. JSON export casts typed numeric/boolean fields and uses `null` for unknowns.

Project IDs describe a recorded project identity, while `physical_site_id` groups co-located campus/customer records. `phase_id` identifies scoped capacity. Source quotes and interpretation are separate; source confidence is not a completion probability. `field_reviews` binds each checked value hash to same-entity evidence. A record is fully verified only after its required fields are reviewed; a partial review remains `needs_review`.

Legacy compatibility fields `type`, `start_year`, `scenario_tag`, `interpreted_it_load_mw` and project `max_reported_capacity_mw` are not independent scenario drivers. `start_year`, if retained, must equal the commissioning interval lower endpoint. Broad maximum MW summaries are not comparable across different power bases. Use explicit business/workload, interval, unit, denominator and physical relationship fields.

Blank organisation roles, aliases, site PUE and exact coordinates are not inferred. Approximate municipality points must retain their accuracy/source caveats. All cross-table identities, scoped evidence, dates, units, phase relationships and comparable baselines are validated by `scripts/lib/validation.R` in addition to the column constraints below.

## Tables

### projects_master

Release path: `master/projects_master.csv`. Key: `project_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `project_id` | string | yes | pattern: ^P[0-9]{3,}$ |
| `country` | string | yes |  |
| `project_name` | string | yes |  |
| `developer` | string | yes |  |
| `bidding_zone` | string | yes |  |
| `county` | string | yes |  |
| `municipality` | string | yes |  |
| `type` | tags | no | enum: type_tags |
| `project_status` | enum | yes | enum: lifecycle |
| `investment_decision` | enum | yes | enum: decision |
| `construction_start_years` | string | no |  |
| `expected_operational_years` | string | no |  |
| `max_reported_capacity_mw` | number | no | min: 0 |
| `notes` | string | no |  |
| `physical_site_id` | string | yes |  |
| `municipality_code` | string | yes |  |
| `region_code` | string | yes |  |
| `business_model` | enum | yes | enum: business_model |
| `workload` | enum | yes | enum: workload |
| `decision_basis` | enum | yes | enum: decision_basis |
| `aliases` | string | no |  |
| `review_state` | enum | yes | enum: source_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |

### capacity_master

Release path: `master/capacity_master.csv`. Key: `claim_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `claim_id` | string | yes | pattern: ^C[0-9]{3,}$ |
| `project_id` | string | yes |  |
| `country` | string | yes |  |
| `project_name` | string | yes |  |
| `phase` | string | yes |  |
| `capacity_type` | enum | yes | enum: capacity_type |
| `capacity_status` | enum | yes | enum: lifecycle |
| `investment_decision` | enum | yes | enum: decision |
| `reported_capacity_mw` | number | yes | min: 0 |
| `reported_capacity_basis` | enum | yes | enum: capacity_basis |
| `interpreted_it_load_mw` | number | no | min: 0 |
| `start_year` | year | no |  |
| `construction_start_year` | year | no |  |
| `scenario_tag` | string | no |  |
| `type` | tags | no | enum: type_tags |
| `notes` | string | no |  |
| `physical_site_id` | string | yes |  |
| `phase_id` | string | yes |  |
| `accounting_group_id` | string | yes |  |
| `capacity_unit` | choice | yes | MW_electric, MW_thermal, MW_per_rack |
| `capacity_qualifier` | enum | yes | enum: capacity_qualifier |
| `capacity_max_mw` | number | no | min: 0 |
| `business_model` | enum | yes | enum: business_model |
| `workload` | enum | yes | enum: workload |
| `decision_basis` | enum | yes | enum: decision_basis |
| `timing_scope` | enum | yes | enum: timing_scope |
| `operation_year_min` | year | no |  |
| `operation_year_max` | year | no |  |
| `construction_observed_date` | date | no |  |
| `connection_status` | enum | yes | enum: connection_status |
| `relation` | enum | yes | enum: relationship |
| `parent_claim_id` | string | no |  |
| `baseline_claim_id` | string | no |  |
| `baseline_comparable` | boolean | yes |  |
| `superseded_by_claim_id` | string | no |  |
| `review_state` | enum | yes | enum: source_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |
| `source_ids` | ids | no |  |
| `timing_source_ids` | ids | no |  |
| `decision_source_ids` | ids | no |  |
| `site_pue` | number | no | min: 1; max: 3 |
| `site_pue_kind` | choice | no | design, measured |
| `pue_source_ids` | ids | no |  |
| `overlap_source_ids` | ids | no |  |
| `interpretation_notes` | string | no |  |
| `baseline_scope` | choice | yes | new_capacity, existing_known, existing_unknown |
| `measurement_kind` | enum | yes | enum: measurement_kind |
| `site_pue_qualifier` | choice | no | exact, up_to, approximate, unknown |

### sources_master

Release path: `master/sources_master.csv`. Key: `source_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `source_id` | string | yes | pattern: ^S[0-9]{3,}$ |
| `project_id` | string | no |  |
| `claim_id` | string | no |  |
| `source_type` | enum | yes | enum: source_type |
| `source_url` | url | yes |  |
| `source_title` | string | yes |  |
| `source_date` | date | no |  |
| `access_date` | date | yes |  |
| `evidence_excerpt` | string | no |  |
| `supports_fields` | string | no |  |
| `confidence` | enum | yes | enum: confidence |
| `notes` | string | no |  |
| `source_date_raw` | string | no |  |
| `source_date_precision` | enum | yes | enum: date_precision |
| `evidence_kind` | enum | yes | enum: evidence_kind |
| `original_excerpt` | string | no |  |
| `original_language` | string | no |  |
| `translation` | string | no |  |
| `locator` | string | no |  |
| `content_sha256` | string | no |  |
| `independence_group` | string | yes |  |
| `review_state` | enum | yes | enum: source_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |

### assumptions

Release path: `master/assumptions.csv`. Key: `assumption_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `assumption_id` | string | yes |  |
| `assumption_type` | string | no |  |
| `value` | number | no |  |
| `unit` | string | no |  |
| `description` | string | no |  |
| `source` | string | no |  |
| `low` | number | no |  |
| `high` | number | no |  |
| `source_url` | url | no |  |
| `source_locator` | string | no |  |
| `denominator` | string | yes |  |
| `parameter_status` | choice | yes | observed_reference, illustrative_sensitivity, design_assumption, not_calibrated |
| `population` | string | yes |  |
| `version` | string | yes |  |
| `valid_from` | date | yes |  |
| `denominator_kind` | choice | yes | annual_IT_energy, nameplate_capacity, peak_demand, incremental_capacity, unknown |

### admin_units

Release path: `master/admin_units.csv`. Key: `country + municipality_code`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `country` | string | yes |  |
| `country_name` | string | no |  |
| `municipality_code` | string | yes |  |
| `municipality_name` | string | no |  |
| `municipality_name_local` | string | no |  |
| `municipality_name_en` | string | no |  |
| `municipality_name_sv` | string | no |  |
| `municipality_name_fi` | string | no |  |
| `municipality_name_nb` | string | no |  |
| `municipality_name_nn` | string | no |  |
| `region_code` | string | no |  |
| `region_name` | string | no |  |
| `region_name_local` | string | no |  |
| `region_name_en` | string | no |  |
| `region_name_sv` | string | no |  |
| `region_name_fi` | string | no |  |
| `region_name_nb` | string | no |  |
| `region_name_nn` | string | no |  |
| `municipality_term_local` | string | no |  |
| `region_term_local` | string | no |  |
| `valid_from` | date | yes |  |
| `source_authority` | string | no |  |
| `source_url` | string | no |  |
| `source_version` | string | no |  |

### country_config

Release path: `master/country_config.csv`. Key: `country`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `country` | string | yes |  |
| `country_name` | string | no |  |
| `active` | boolean | yes |  |
| `canonical_name_language` | string | no |  |
| `search_languages` | string | no |  |
| `municipality_field` | string | no |  |
| `municipality_term_local` | string | no |  |
| `municipality_term_en` | string | no |  |
| `region_field` | string | no |  |
| `region_term_local` | string | no |  |
| `region_term_en` | string | no |  |
| `source_authority` | string | no |  |
| `source_url` | string | no |  |
| `valid_from` | date | yes |  |

### geography_config

Release path: `master/geography_config.csv`. Key: `bidding_zone`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `country` | string | no |  |
| `country_name` | string | no |  |
| `bidding_zone` | string | yes |  |
| `zone_name` | string | no |  |
| `active` | boolean | yes |  |
| `geojson_file` | string | no |  |

### municipality_locations

Release path: `master/municipality_locations.csv`. Key: `country + municipality`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `country` | string | yes |  |
| `municipality` | string | yes |  |
| `latitude` | number | yes | min: -90; max: 90 |
| `longitude` | number | yes | min: -180; max: 180 |
| `coordinate_note` | string | no |  |
| `source_url` | url | no |  |
| `accuracy` | choice | yes | municipality_seat, locality, site, legacy_approximate |
| `review_state` | enum | yes | enum: source_state |

### suggested_project_updates

Release path: `audit/suggested_project_updates.csv`. Key: `audit_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `audit_id` | string | yes |  |
| `country` | string | no |  |
| `project_id` | string | no |  |
| `project_name` | string | no |  |
| `field` | string | no |  |
| `current_value` | string | no |  |
| `suggested_value` | string | no |  |
| `source_url` | string | no |  |
| `source_title` | string | no |  |
| `source_date` | string | no |  |
| `access_date` | date | no |  |
| `evidence_excerpt` | string | no |  |
| `confidence` | enum | yes | enum: confidence |
| `rationale` | string | no |  |
| `run_id` | string | yes |  |
| `review_state` | enum | yes | enum: review_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |
| `resolution` | string | no |  |
| `evidence_source_id` | string | no |  |
| `source_type` | enum | no | enum: source_type |
| `original_excerpt` | string | no |  |
| `original_language` | string | no |  |
| `translation` | string | no |  |
| `locator` | string | no |  |
| `evidence_kind` | enum | no | enum: evidence_kind |
| `supports_fields` | string | no |  |
| `change_kind` | choice | no | correction, confirmation |
| `review_kind` | choice | no | source, interpretation |
| `additional_evidence` | string | no |  |
| `independence_group` | string | no |  |

### suggested_capacity_updates

Release path: `audit/suggested_capacity_updates.csv`. Key: `audit_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `audit_id` | string | yes |  |
| `country` | string | no |  |
| `claim_id` | string | no |  |
| `project_id` | string | no |  |
| `project_name` | string | no |  |
| `phase` | string | no |  |
| `field` | string | no |  |
| `current_value` | string | no |  |
| `suggested_value` | string | no |  |
| `source_url` | string | no |  |
| `source_title` | string | no |  |
| `source_date` | string | no |  |
| `access_date` | date | no |  |
| `evidence_excerpt` | string | no |  |
| `confidence` | enum | yes | enum: confidence |
| `rationale` | string | no |  |
| `run_id` | string | yes |  |
| `review_state` | enum | yes | enum: review_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |
| `resolution` | string | no |  |
| `evidence_source_id` | string | no |  |
| `source_type` | enum | no | enum: source_type |
| `original_excerpt` | string | no |  |
| `original_language` | string | no |  |
| `translation` | string | no |  |
| `locator` | string | no |  |
| `evidence_kind` | enum | no | enum: evidence_kind |
| `supports_fields` | string | no |  |
| `change_kind` | choice | no | correction, confirmation |
| `review_kind` | choice | no | source, interpretation |
| `additional_evidence` | string | no |  |
| `independence_group` | string | no |  |

### suggested_source_updates

Release path: `audit/suggested_source_updates.csv`. Key: `audit_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `audit_id` | string | yes |  |
| `country` | string | no |  |
| `source_id` | string | no |  |
| `project_id` | string | no |  |
| `claim_id` | string | no |  |
| `project_name` | string | no |  |
| `field` | string | no |  |
| `current_value` | string | no |  |
| `suggested_value` | string | no |  |
| `source_url` | string | no |  |
| `source_title` | string | no |  |
| `source_date` | string | no |  |
| `access_date` | date | no |  |
| `evidence_excerpt` | string | no |  |
| `confidence` | enum | yes | enum: confidence |
| `rationale` | string | no |  |
| `run_id` | string | yes |  |
| `review_state` | enum | yes | enum: review_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |
| `resolution` | string | no |  |
| `evidence_source_id` | string | no |  |
| `source_type` | enum | no | enum: source_type |
| `original_excerpt` | string | no |  |
| `original_language` | string | no |  |
| `translation` | string | no |  |
| `locator` | string | no |  |
| `evidence_kind` | enum | no | enum: evidence_kind |
| `supports_fields` | string | no |  |
| `change_kind` | choice | no | correction, confirmation |
| `review_kind` | choice | no | source, interpretation |
| `additional_evidence` | string | no |  |
| `independence_group` | string | no |  |

### new_project_candidates

Release path: `audit/new_project_candidates.csv`. Key: `project_candidate_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `project_candidate_id` | string | yes |  |
| `country` | string | no |  |
| `developer` | string | no |  |
| `project_name` | string | no |  |
| `bidding_zone` | string | no |  |
| `county` | string | no |  |
| `municipality` | string | no |  |
| `type` | string | no |  |
| `project_status` | string | no |  |
| `investment_decision` | string | no |  |
| `construction_start_years` | string | no |  |
| `expected_operational_years` | string | no |  |
| `max_reported_capacity_mw` | string | no |  |
| `source_url` | string | no |  |
| `source_title` | string | no |  |
| `source_date` | string | no |  |
| `access_date` | date | no |  |
| `evidence_excerpt` | string | no |  |
| `confidence` | enum | yes | enum: confidence |
| `notes` | string | no |  |
| `run_id` | string | yes |  |
| `review_state` | enum | yes | enum: review_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |
| `resolution` | string | no |  |
| `physical_site_id` | string | no |  |
| `municipality_code` | string | no |  |
| `region_code` | string | no |  |
| `business_model` | enum | no | enum: business_model |
| `workload` | enum | no | enum: workload |
| `decision_basis` | enum | no | enum: decision_basis |
| `aliases` | string | no |  |
| `source_type` | enum | no | enum: source_type |
| `original_excerpt` | string | no |  |
| `original_language` | string | no |  |
| `translation` | string | no |  |
| `locator` | string | no |  |
| `evidence_kind` | enum | no | enum: evidence_kind |
| `supports_fields` | string | no |  |
| `review_kind` | choice | no | source, interpretation |
| `additional_evidence` | string | no |  |
| `independence_group` | string | no |  |

### new_capacity_claim_candidates

Release path: `audit/new_capacity_claim_candidates.csv`. Key: `capacity_candidate_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `capacity_candidate_id` | string | yes |  |
| `project_candidate_id` | string | no |  |
| `project_id` | string | no |  |
| `country` | string | no |  |
| `project_name` | string | no |  |
| `phase` | string | no |  |
| `capacity_type` | string | no |  |
| `capacity_status` | string | no |  |
| `investment_decision` | string | no |  |
| `reported_capacity_mw` | string | no |  |
| `reported_capacity_basis` | string | no |  |
| `interpreted_it_load_mw` | string | no |  |
| `start_year` | string | no |  |
| `construction_start_year` | string | no |  |
| `scenario_tag` | string | no |  |
| `type` | string | no |  |
| `source_url` | string | no |  |
| `source_title` | string | no |  |
| `source_date` | string | no |  |
| `access_date` | date | no |  |
| `evidence_excerpt` | string | no |  |
| `confidence` | enum | yes | enum: confidence |
| `notes` | string | no |  |
| `run_id` | string | yes |  |
| `review_state` | enum | yes | enum: review_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |
| `resolution` | string | no |  |
| `physical_site_id` | string | no |  |
| `phase_id` | string | no |  |
| `accounting_group_id` | string | no |  |
| `capacity_unit` | choice | no | MW_electric, MW_thermal, MW_per_rack |
| `capacity_qualifier` | enum | no | enum: capacity_qualifier |
| `capacity_max_mw` | number | no | min: 0 |
| `business_model` | enum | no | enum: business_model |
| `workload` | enum | no | enum: workload |
| `decision_basis` | enum | no | enum: decision_basis |
| `timing_scope` | enum | no | enum: timing_scope |
| `operation_year_min` | year | no |  |
| `operation_year_max` | year | no |  |
| `construction_observed_date` | date | no |  |
| `connection_status` | enum | no | enum: connection_status |
| `relation` | enum | no | enum: relationship |
| `parent_claim_id` | string | no |  |
| `baseline_claim_id` | string | no |  |
| `baseline_comparable` | boolean | no |  |
| `superseded_by_claim_id` | string | no |  |
| `source_ids` | ids | no |  |
| `timing_source_ids` | ids | no |  |
| `decision_source_ids` | ids | no |  |
| `site_pue` | number | no | min: 1; max: 3 |
| `site_pue_kind` | choice | no | design, measured |
| `pue_source_ids` | ids | no |  |
| `overlap_source_ids` | ids | no |  |
| `interpretation_notes` | string | no |  |
| `source_type` | enum | no | enum: source_type |
| `original_excerpt` | string | no |  |
| `original_language` | string | no |  |
| `translation` | string | no |  |
| `locator` | string | no |  |
| `evidence_kind` | enum | no | enum: evidence_kind |
| `supports_fields` | string | no |  |
| `baseline_scope` | choice | no | new_capacity, existing_known, existing_unknown |
| `measurement_kind` | enum | no | enum: measurement_kind |
| `site_pue_qualifier` | choice | no | exact, up_to, approximate, unknown |
| `review_kind` | choice | no | source, interpretation |
| `additional_evidence` | string | no |  |
| `independence_group` | string | no |  |

### source_conflicts

Release path: `audit/source_conflicts.csv`. Key: `conflict_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `project_id` | string | no |  |
| `country` | string | no |  |
| `claim_id` | string | no |  |
| `project_name` | string | no |  |
| `field` | string | no |  |
| `current_value` | string | no |  |
| `source_url_1` | string | no |  |
| `source_title_1` | string | no |  |
| `source_date_1` | string | no |  |
| `value_supported_1` | string | no |  |
| `source_url_2` | string | no |  |
| `source_title_2` | string | no |  |
| `source_date_2` | string | no |  |
| `value_supported_2` | string | no |  |
| `access_date` | date | no |  |
| `conflict_summary` | string | no |  |
| `recommended_resolution` | string | no |  |
| `confidence` | enum | yes | enum: confidence |
| `conflict_id` | string | yes |  |
| `run_id` | string | yes |  |
| `review_state` | enum | yes | enum: review_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |
| `resolution` | string | no |  |

### dead_links

Release path: `audit/dead_links.csv`. Key: `link_issue_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `source_id` | string | no |  |
| `country` | string | no |  |
| `project_id` | string | no |  |
| `claim_id` | string | no |  |
| `project_name` | string | no |  |
| `source_url` | string | no |  |
| `source_title` | string | no |  |
| `error_type` | string | no |  |
| `access_date` | date | no |  |
| `notes` | string | no |  |
| `link_issue_id` | string | yes |  |
| `run_id` | string | yes |  |
| `review_state` | enum | yes | enum: review_state |
| `reviewed_by` | string | no |  |
| `reviewed_at` | datetime | no |  |
| `resolution` | string | no |  |

### identity_registry

Release path: `master/identity_registry.csv`. Key: `entity_type + entity_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `entity_type` | choice | yes | project, claim, source, phase, site, observation |
| `entity_id` | string | yes |  |
| `state` | choice | yes | active, retired, reserved |
| `created_in` | string | yes |  |
| `retired_in` | string | no |  |
| `notes` | string | no |  |

### deployment_schedule

Release path: `master/deployment_schedule.csv`. Key: `claim_id + year`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `claim_id` | string | yes |  |
| `year` | year | yes |  |
| `year_end_fraction` | number | yes | min: 0; max: 1 |
| `average_year_fraction` | number | yes | min: 0; max: 1 |
| `basis` | choice | yes | source, model_assumption |
| `source_ids` | ids | no |  |
| `assumption_id` | string | no |  |
| `review_state` | enum | yes | enum: source_state |
| `notes` | string | no |  |

### promotion_history

Release path: `audit/promotion_history.csv`. Key: `request_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `request_id` | string | yes |  |
| `run_id` | string | yes |  |
| `source` | string | yes |  |
| `selected_ids` | string | yes |  |
| `reviewer` | string | yes |  |
| `applied_at` | datetime | yes |  |
| `parent_release` | string | yes |  |
| `request_digest` | string | yes |  |

### capacity_observations

Release path: `master/capacity_observations.csv`. Key: `observation_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `observation_id` | string | yes | pattern: ^OBS[0-9]{3,}$ |
| `claim_id` | string | yes |  |
| `basis` | enum | yes | enum: capacity_basis |
| `value` | number | yes | min: 0 |
| `unit` | choice | yes | MW_electric, MW_thermal, MW_per_rack |
| `qualifier` | enum | yes | enum: capacity_qualifier |
| `source_ids` | ids | yes |  |
| `review_state` | enum | yes | enum: source_state |
| `notes` | string | no |  |
| `measurement_kind` | enum | yes | enum: measurement_kind |
| `value_max` | number | no | min: 0 |

### field_reviews

Release path: `master/field_reviews.csv`. Key: `entity_type + entity_id + field`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `entity_type` | choice | yes | project, claim, source |
| `entity_id` | string | yes |  |
| `field` | string | yes |  |
| `value_sha256` | string | yes |  |
| `source_ids` | ids | yes |  |
| `review_kind` | choice | yes | source, interpretation |
| `reviewer` | string | yes |  |
| `reviewed_at` | datetime | yes |  |
| `run_id` | string | yes |  |
| `notes` | string | no |  |

### run_imports

Release path: `audit/run_imports.csv`. Key: `run_id`.

| Field | Type | Required | Constraints |
| --- | --- | --- | --- |
| `run_id` | string | yes |  |
| `review_id` | string | yes |  |
| `response_sha256` | string | yes |  |
| `review_manifest_sha256` | string | yes |  |
| `imported_at` | datetime | yes |  |
| `input_release` | string | yes |  |
| `parent_release` | string | yes |  |

## Enumerations

### lifecycle

`Concept study`, `Planned`, `Permitted`, `Under construction`, `Operational`, `Dormant`, `Cancelled`, `Unclear`

### decision

`yes`, `no`, `unclear`, `not_applicable`

### decision_basis

`explicit_decision`, `execution_evidence`, `conditional_commitment`, `no_public_evidence`, `explicit_nondecision`, `not_applicable`, `legacy_unverified`

### review_state

`pending`, `approved`, `rejected`, `applied`, `already_applied`, `superseded`, `needs_review`

### confidence

`high`, `medium`, `low`, `unclear`

### capacity_basis

`it_load`, `facility_total`, `grid_connection`, `unspecified_headline`, `backup_generation`, `reactor`, `rack_density`

### capacity_type

`facility_capacity`, `initial_phase_capacity`, `incremental_expansion`, `cumulative_site_capacity`, `full_campus_potential`, `reactor_capacity`, `permit_backup_power`, `unknown`

### business_model

`hyperscale`, `colocation`, `enterprise`, `public_research`, `unknown`

### workload

`ai_training`, `ai_inference`, `ai_unspecified`, `hpc`, `cloud`, `mixed`, `research`, `unknown`

### timing_scope

`full_capacity`, `first_capacity`, `grid_availability`, `unknown`

### date_precision

`day`, `month`, `year`, `unknown`

### evidence_kind

`verbatim`, `summary`, `translation`, `unavailable`

### source_type

`company`, `municipal`, `permit`, `grid`, `media`, `registry`, `research`, `other`

### source_state

`legacy_unverified`, `verified`, `needs_review`

### connection_status

`unknown`, `requested`, `queued`, `reserved`, `contracted`, `available_reported`, `energised`

### capacity_qualifier

`exact`, `approximate`, `up_to`, `at_least`, `range`, `unknown`

### relationship

`independent`, `included_in`, `incremental_to`, `possibly_included_in`

### type_tags

`hyperscale`, `AI`, `HPC`, `cloud`, `colocation`, `enterprise`, `research`, `SMR-linked`, `public research`, `build-to-suit`, `edge`

### measurement_kind

`nameplate_capacity`, `peak_demand`, `available_power`, `contracted_power`, `requested_power`, `normal_operating_range`, `unspecified_capacity`, `thermal_input`

## Complete-review fields

- project: `developer`, `municipality`, `county`, `bidding_zone`, `project_status`, `investment_decision`, `decision_basis`, `business_model`, `workload`
- claim: `reported_capacity_mw`, `reported_capacity_basis`, `capacity_unit`, `measurement_kind`, `capacity_qualifier`, `capacity_type`, `capacity_status`, `investment_decision`, `decision_basis`, `timing_scope`, `operation_year_min`, `operation_year_max`, `construction_start_year`, `relation`, `baseline_scope`, `baseline_claim_id`, `baseline_comparable`, `site_pue`, `capacity_max_mw`, `connection_status`, `site_pue_kind`, `site_pue_qualifier`, `business_model`, `workload`
