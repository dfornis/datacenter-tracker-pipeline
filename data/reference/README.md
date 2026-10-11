# Reference inputs

`bidding-zones/` holds the seven input files for all ten configured SE/FI/NO zones. These copies are byte-identical to the reviewed baseline; `config/geography_sources.json` records hashes, inherited paths and unresolved origin/licensing. Validation checks zone identity, WGS84 bounds, ring closure, dimensions and nonzero area. It does not prove boundary accuracy or all polygon topology properties (such as self-intersections). No municipality point establishes a network connection or boundary assignment.

`admin/2026/raw/` stores the official SCB, Statistics Finland and SSB responses fetched for the reference refresh. `source-manifest.json` identifies URL, retrieval timestamp, byte count and hash. `config/admin_sources.json` binds the expected classification versions, languages and counts. Parsing and review proposals are separate from application to the selected release. SSB's `9999 Uoppgitt` is excluded from the allowed municipality list.

Source data remains subject to the issuing authority's applicable terms. The repository does not grant new rights over third-party material.
