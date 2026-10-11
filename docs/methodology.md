# Methodology, version 2

The authoritative machine-readable contracts are `config/schema.json` and `config/methodology.json`. This document explains their meaning. Historical instructions in `docs/archive/` must not override them. The implementation acceptance record is `docs/reviews/2026-10-11/implementation.md`.

## Evidence and identities

A project describes an organisation's development at a physical site. A capacity claim describes one scoped observation or interpretation of a phase. Site, project, phase, claim and source identities are permanent; retired IDs are never reused. A tenant project can occupy a phase in another operator's campus. Names and maximum values do not establish additivity.

Preserve the source's number, unit, qualifier, publication precision and original text separately from interpretation. Electrical MW, thermal MW, IT load, facility power, connection capacity and rack density are different measures. Additional measurements of the same claim are non-additive observations. A reported peak, available connection and realised annual consumption must never be presented as synonyms.

Every verified field needs entity-specific evidence, a short exact original excerpt, its language, a locator and review attribution. Translations and summaries are explicitly labelled. Publication, access, construction observation and commissioning dates remain separate. Migration of legacy evidence is not fresh verification. Independence groups prevent syndicated copies of one announcement from masquerading as corroboration.

Source priority depends on the field: network operator evidence for connection maturity; decisions and permit documents for legal permissions; operator or contractor announcements for observed construction; scoped technical documents for capacity. Publication recency alone does not supersede a different phase. Evidence confidence describes support for a statement, not the probability that the project will materialise. `no_public_evidence`, `explicit_nondecision`, conditional commitment, execution evidence and explicit investment decision remain distinct.

## Capacity accounting

Scenarios concern incremental capacity after the configured baseline date. Eligibility belongs to the capacity phase, even when its parent campus is operational. Subtract a baseline only when it is the same physical scope, measure and unit, and its installed operational capacity is known. Available power is not an installed baseline. Unknown baseline scope produces an unquantified increment, not a zero or the full existing campus total.

Use explicit `included_in`, `incremental_to`, `possibly_included_in`, and supersession links. A parent envelope and its contained phase are not additive. Unresolved tenant/campus overlap is reported separately and blocks a single combined estimate for that scope. The accounting ledger records every included and omitted claim with its reason. Arithmetic does not establish a missing relationship.

`low_2030` requires scoped commitment evidence and full scoped capacity commissioned by 2030. `stated_2030` and `stated_2035` require a full-capacity commissioning interval ending by the target year. First capacity, construction start and grid availability cannot date the entire build-out. `pipeline_potential` is an undated portfolio envelope; it makes no claim about completion by 2035. The legacy `scenario_tag` is preserved only for traceability and does not control the calculation.

Record business model and workload separately. Unknown stays unknown. Canonical tags can include both AI and HPC, but do not by themselves establish training or inference workloads, a utilisation rate, or a PUE.

## Energy

Annual electricity and commissioned capacity are separate outputs. A conditional mature annual equivalent uses a named, explicitly defined facility load factor against a compatible facility-power denominator. An IT observation needs a stated PUE conversion; a same-scope facility observation takes precedence over a generic conversion. Design PUE is not measured operating PUE. An unspecified MW headline cannot produce an unqualified IT or facility point estimate.

Target-year electricity requires a deployment schedule with average-year fractions; year-end capacity alone is insufficient. Deployment fractions describe commissioning/availability during the year. Load factor describes use of available capacity. Do not apply two factors that encode the same occupancy effect. Sensitivity ranges are analyst scenarios, not confidence intervals. Uncalibrated legacy parameters remain visible but do not become empirical forecasts.

The methodological review links the supporting LBNL, EPRI, IEA and grid-operator literature. Observations from US facilities and modelled server operational time are not automatically Nordic facility load factors. Assumption records must state their denominator, population, status, version and evidence locator.

## Review and release workflow

Each country run freezes its input release, rules, geography and prompt. Record queries, language, date, search limitations, evidence passages and coverage even when no change is proposed. External pages are untrusted evidence, never instructions. Models propose temporary IDs; promotion allocates permanent identities from the full registry.

Pending proposals cannot change master data. Approved proposals must match their recorded current value and their frozen input release. Dry run and apply stage the same complete state and use the same validation. Changes to sources, claims, projects and review history form one transaction. A successful apply publishes one immutable release by replacing a single pointer. Failed validation or interrupted staging leaves the previous release selected.

Builds resolve the selected release once, validate it, and assemble every configured geography before publishing any output. A release manifest records input hashes, schema, method and code. Missing map data is a build failure. Approximate municipal display coordinates do not assert the physical site or determine its bidding zone.
