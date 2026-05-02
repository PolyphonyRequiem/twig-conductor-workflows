Verify that all PR groups have been merged before close-out proceeds.

**Completed PGs (from pg_router):**
{{ pg_router.output.completed_pgs | json }}

**Total PGs:** {{ pg_router.output.total_pgs }}

{% if pr_finalizer is defined and pr_finalizer.output %}
**Previous verification attempt #{{ pr_finalizer.output.verification_attempt }}:**
{{ pr_finalizer.output.summary }}
**Previously unmerged:** {{ pr_finalizer.output.unmerged_pr_groups | json }}
{% endif %}

## Verification Steps

### 1. Cross-reference completed PGs against ground truth
For EACH PR group discovered by work_tree_loader, verify it appears in the
completed PGs list from pg_router. If any are missing, investigate.

### 2. Check for unmerged feature branches
```
git checkout main && git pull
git branch --no-merged main
```
Cross-reference any unmerged branches against PG branch names (format: `feature/pg-N`).
If a branch matches a PG that should be complete, that group's work is orphaned.

### 3. Verify merged PRs via GitHub
Use the `list_pull_requests` MCP tool to check merged PRs:
- owner: `{{ workflow.input.pr_owner }}`, repo: `{{ workflow.input.pr_repo_name }}`, state: `closed`
- Cross-reference each PG's branch name against merged PRs. Every PG must have
  a corresponding merged PR.
- **Do NOT use `gh pr list` CLI** — always use the MCP tool.

### 4. Verify Issue states match reality
For each Issue in the work tree:
```
twig set <issue_id> --output json
```
- If the Issue is "Done" but no merged PR exists for its PG → **state integrity violation**
- Record any violations found

### 5. Verify Task states (defense-in-depth)
For each PG that has a verified merged PR, spot-check Tasks:
```
twig set <task_id> --output json
```
- If ANY Task is NOT in state "Done" → **state integrity violation**
- Report any remaining violations so close_out can handle them

## Decision

- If ALL PR groups have merged PRs and no state violations → set `verified: true`
- If ANY PR group is genuinely missing merged code:
  - Set `verified: false`
  - Set `unmerged_pr_groups` to the list of PR group names that lack merged PRs
  - Set `orphaned_branches` to any unmerged branches matching those groups
  - Set `state_violations` to any Issues marked Done without merged code

## Attempt Tracking

{% if pr_finalizer is defined and pr_finalizer.output %}
Set `verification_attempt` to {{ pr_finalizer.output.verification_attempt + 1 }}.
{% else %}
Set `verification_attempt` to 1.
{% endif %}

**IMPORTANT:** Report actual verification results honestly. If verification fails,
set `verified: false` with the specific unmerged PR groups and violations. Do NOT
auto-approve after any number of attempts. The workflow will retry up to 10 times
to allow for merge delays and CI propagation, but the final answer must reflect
reality. (P7: Fail Honestly)

## Output
- `verified` (boolean): True ONLY if every PR group has confirmed merged code
- `unmerged_pr_groups` (array): PR group names that lack merged PRs (empty if verified)
- `orphaned_branches` (array): Feature branches with unmerged work (empty if verified)
- `state_violations` (array): Issues marked Done without merged code (empty if none)
- `summary` (string): Human-readable verification summary
- `verification_attempt` (number): Current attempt count (1-based)
