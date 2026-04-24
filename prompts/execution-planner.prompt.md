Define PR groups for the approved plan.

**Work Item:** #{{ intake.output.work_item_id }} — {{ intake.output.title }}
**Plan:** {{ architect.output.plan_path }}

{% if execution_planner is defined and execution_planner.output.needs_revision %}
**Previous attempt failed** — architect has revised the plan. Re-evaluate PG grouping.
{% endif %}

## Steps

### 1. Read the approved plan
Read `{{ architect.output.plan_path }}` and understand:
- What Issues/deliverables are defined
- What Tasks exist under each Issue
- Dependencies between components

### 2. Define PR groups
Group Tasks into PGs optimizing for:
- **Self-containment**: each PG builds and tests independently
- **Review coherence**: related changes together
- **Size**: ≤2,000 LoC, ≤50 files per PG
- **Ordering**: respect dependencies between groups

Name each PG as `PG-N-descriptive-slug` (e.g., `PG-1-domain-model`, `PG-2-cli-commands`).

### 3. Check self-containment
For each PG, verify:
- Can a developer implement just this PG and have a building, passing codebase?
- Are there imports/references to code that only exists in a later PG?
- If not self-contained, set `needs_revision: true`

### 4. Append Execution Plan to plan document
Append a `## Execution Plan` section to `{{ architect.output.plan_path }}` with:
- PR group table: | Group | Name | Issues/Tasks | Dependencies | Type (deep/wide) |
- Execution order narrative
- Validation strategy per PG

## Output

```json
{
  "pr_groups": [
    {
      "name": "PG-1-descriptive-slug",
      "task_ids": [],
      "issue_ids": [],
      "depends_on": [],
      "type": "deep|wide",
      "estimated_loc": 500
    }
  ],
  "pr_group_count": 2,
  "needs_revision": false,
  "revision_requests": "",
  "execution_plan_summary": "2 PR groups, sequential, all self-contained"
}
```
