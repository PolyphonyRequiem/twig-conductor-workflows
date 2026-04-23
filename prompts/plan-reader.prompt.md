Read the approved plan and extract its metadata.
**Plan file:** {{ intake.output.existing_plan_path }}

## Steps

### If the work item is an Epic with multiple child Issue plans:
If `{{ intake.output.existing_plan_path }}` is empty or the item type is "Epic",
check `docs/projects/*.plan.md` for plans matching child Issue IDs.

1. Run: `twig set {{ intake.output.epic_id }} --output json` then `twig tree --depth 1 --output json`
2. Get child Issue IDs from the tree
3. For each `.plan.md` in `docs/projects/`, parse YAML frontmatter for `work_item_id`
4. Match plans to child Issues
5. Read ALL matched plans and produce a combined summary
6. Set `plan_path` to the first matched plan (the load-work-tree script will auto-discover all of them via `-PlanDir`)
7. Count Issues and PR groups across ALL plans
8. Sum estimated LoC across ALL plans

### If a single plan file exists:
1. Read the plan file
2. Count the number of Issues and PR groups
3. Extract the executive summary
4. Estimate total LoC from the plan's estimates
5. Return the metadata

Do NOT modify any plan. Just read and summarize.
