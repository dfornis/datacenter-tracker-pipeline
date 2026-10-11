# Energy assumptions

The build emits conditional mature annual equivalents and, only with an explicit deployment schedule, target-year energy. Neither output is a probability-weighted forecast of project realisation. The assumption register preserves the old parameters with `not_calibrated` status; they are excluded from calculation.

The active PUE sensitivity is an analyst-selected 1.1–1.5 bracket. The active nameplate load-factor cases are 0.57 and 0.75. They carry no central estimate. These choices illustrate the effect of the parameters; they are not empirical bounds for Nordic projects or confidence intervals. Project completion, load-factor variation and PUE uncertainty are separate from these illustrative cases.

EPRI's small anonymous sample distinguishes annual load relative to facility nameplate from load relative to realised peak. Its nameplate reference cases inform this sensitivity; its peak-relative factors are different. The source also distinguishes nominal from operational capacity and applies a deployment assumption. That US deployment assumption is **not** automatically assigned to Nordic projects. [EPRI, Powering Intelligence 2026, Figure 3 and annual-use methodology](https://powering-intelligence.epri.com/annual-peak-use.html).

LBNL separately defines IT rated power, facility annual consumption and grid interconnection. Its modelled AI server operational time is not a facility load factor. Its aggregate PUE estimates and interconnection utilisation also have different populations and denominators. They inform these distinctions, rather than supplying a universal multiplier. [LBNL, 2025 Update, published June 2026, pp. 9–10 and 20–24](https://www.energy.gov/documents/united-states-data-center-energy-usage-report-2025-update).

For facility nameplate MW, the conditional calculation is `MW × LF × 8,760 / 1,000,000` TWh. For IT nameplate, use an explicitly modelled PUE conversion or a same-scope observed facility measurement. A design upper PUE bound remains an upper bound; the theoretical lower PUE bound of one is labelled accordingly. This conversion does not turn design/nameplate MW into measured peak demand.

For target-year energy, use average-year availability of the incremental capacity and the actual number of hours in that year, including leap years. A deployment fraction must not repeat occupancy already included in the selected load factor. Keep unavailable schedules as unknown. Grid connections, unspecified MW headlines, unmatched peak-demand denominators and unknown installed baselines do not receive an automatic energy estimate.

Source-specific PUE, load and deployment evidence should replace generic sensitivity cases when its scope, period and denominator are compatible. These assumptions need review whenever the population or intended output changes.
