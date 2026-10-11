# Frozen country runs

The renderer creates an immutable country packet under `data/runs/<run-id>/`, with numbered project packets, country-filtered data, a small global identity index, exact schema/method copies, instructions and hashes. Models write only the run's `work/response.json`.

```sh
Rscript scripts/render_country_prompt.R --task=audit --country=FI --run-id=2026-10-11-fi-audit --engine=codex --model=not_exposed
Rscript scripts/validate_run_response.R --run-id=2026-10-11-fi-audit
```

Use the exact model identifier when exposed. Otherwise record `not_exposed`; do not guess settings. Every query/open action, original-language excerpt, locator and no-change coverage result belongs in the response. Templates and overlays describe interpretation; `config/schema.json`, `config/run_response.schema.json` and `config/run_workflow.json` control fields and completeness.

For a bounded pilot, pass `--project-ids=P033,P035` to an audit renderer. Its manifest explicitly records `selected_project_pilot`; it must not be described as full-country coverage. A country audit omits this argument.

Audit reviews existing records, including operational campuses. Discovery reviews all required source routes for missing sites and phases. They use separate runs and review queues. The model cannot approve itself or assign permanent IDs. A second review pass must inspect evidence and explicitly select proposals before they can be promoted.

Old prompts are retained only under `docs/archive/v1/prompts/`; they are not active instructions.
