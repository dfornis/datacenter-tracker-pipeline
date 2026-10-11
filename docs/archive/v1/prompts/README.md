# Prompt Assembly

Audit and discovery use one geography-agnostic template plus one country overlay.

Render a prompt with:

```sh
Rscript scripts/render_country_prompt.R --task=audit --country=FI
Rscript scripts/render_country_prompt.R --task=discover --country=NO
```

The rendered prompt tells the agent to filter master data to the selected `country` and to include `country` on shared audit-output rows.

Discovery writes project-level candidates to `data/audit/new_project_candidates.csv` and capacity-claim or phase-level candidates to `data/audit/new_capacity_claim_candidates.csv`. This mirrors the reviewed master structure: project candidates can promote to `projects_master.csv`, while capacity-claim candidates can promote to `capacity_master.csv` with permanent `claim_id` values.
