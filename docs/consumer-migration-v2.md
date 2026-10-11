# Consumer migration to version 2

This is a breaking output change. Check `manifest.json.schema_version`. Consume one complete release with its manifest, never a mixture of builds. JSON unknown numbers are `null`, not zero; CSV blanks remain unknown.

| Previous behaviour | Version 2 |
| --- | --- |
| Operational/dormant/cancelled projects hidden | All history exported; `has_counted_forward_capacity` and ledger show scenario participation. |
| Highest eligible claim per project | Physical site, phase, explicit containment, supersession and baseline relationships control accounting. |
| `high_2035` treated as dated | `pipeline_potential` has no target year. |
| Construction/first-capacity date used for campus | Only full scoped timing or an explicit deployment schedule dates full capacity. |
| Unknown/grid MW converted to IT | Separate non-additive IT, facility and grid measures; unmatched basis stays unknown. |
| One annual TWh estimate | Conditional mature annual equivalents use labelled sensitivities; target-year electricity needs an average-year deployment schedule. |
| Summaries treated as checked evidence | Legacy summaries remain visible; exact evidence and field reviews identify checked facts. |

`projects.json` describes projects and approximate display coordinates. `capacity.json` contains reported claims and interpreted scope. `capacity_observations.json` contains alternate measures of the same phase; do not count it as additional projects. `sources.json` and `field_reviews.json` link interpretations to original passages. `assumptions.json` distinguishes legacy uncalibrated values from active illustrative parameters.

Use `scenario_zone.json` with its completeness flags and the accounting ledger. Zero in an evidence-qualified scenario means no qualifying records in this inventory, not zero actual future construction or electricity demand. This inventory does not claim exhaustive Nordic coverage.

Missing coordinates should give a list entry without a map marker. Municipality points do not establish the site, network connection or bidding zone. Geometry provenance limitations are in `quality.json`.

Method migration can reduce totals without any cancellation. Attribute changes separately to source/identity repair, basis correction, timing rules, baseline subtraction, overlap treatment, scenario definitions, energy assumptions and new factual evidence. The original comparison remains in the October review. A percentage change between old inferred IT totals and new explicitly separated measures is not meaningful.
