Manage PR group lifecycle.

**Work Tree and PR Groups:**
{{ work_tree_loader.output.stdout }}

{% if pr_group_manager is defined and pr_group_manager.output %}
**Current State:**
- PR Group: {{ pr_group_manager.output.current_pr_group }}
- Branch: {{ pr_group_manager.output.branch_name }}
- Completed Issues: {{ pr_group_manager.output.completed_issues | json }}
- Completed PRs: {{ pr_group_manager.output.completed_prs | json }}
{% endif %}

## Resume Support (P3)

On your **first invocation** (no prior pr_group_manager output), check the work tree
for already-completed PGs. The work tree loader outputs `completed_pgs`, `pending_pgs`,
and `next_pg`. Start from `next_pg` — do NOT re-process completed PGs.

If ALL PGs are already completed (`next_pg` is empty), set `action: all_complete`
immediately.

## Resume Reconciliation (MANDATORY before starting next_pg)

On **first invocation** (resume), the work tree may contain PGs whose PRs are
merged but whose ADO items were never transitioned to Done (workflow crash/restart).
The work tree loader outputs `pgs_needing_reconciliation` — a list of such PGs.

If `pgs_needing_reconciliation` is non-empty, reconcile BEFORE starting any new work:

For each entry in `pgs_needing_reconciliation`:

1. **Verify the merged PR**: Use the `pull_request_read` MCP tool (method: `get`, pullNumber: `<merged_pr>`) — state must be "MERGED"
   - **Do NOT use `gh pr view` CLI** — the `gh` CLI hangs in non-TTY environments.
2. **Transition stale "Doing" Tasks** (crash-interrupted tasks):
   For each task_id in `stale_doing_task_ids`:
   - `twig set <task_id> --output json`
   - `twig note --text "Resume reconciliation: closed after PR #<merged_pr> merged to main" --output json`
   - `twig state Done --output json`
3. **Transition non-Done Issues**:
   For each issue_id in `non_done_issue_ids`:
   - `twig set <issue_id> --output json`
   - `twig note --text "Resume reconciliation: closed after PR #<merged_pr> merged to main" --output json`
   - `twig state Done --output json`
4. **DO NOT close "To Do" tasks** — `skipped_todo_task_ids` lists tasks that were
   never started. These may be genuinely unimplemented and should remain open.
   Log them in your `progress_summary` for visibility.
5. **Track**: Add reconciled issues to `completed_issues` and reconciled PG names to `completed_prs`.

Only after reconciliation is complete, proceed to `next_pg` (or `all_complete` if no pending PGs remain).

## Staleness Check (before starting each new PG)

When starting a NEW PR group (not continuing one in progress), run the staleness
assessor script to check if plan assumptions still hold:
```
pwsh -NoProfile -File scripts/assess-staleness.ps1 -PlanPath "<plan_path>" -FilesAffected "<comma-separated files in this PG>"
```
- If `classification=proceed`: continue normally.
- If `classification=adapt`: note the changes in your progress_summary, adjust approach as needed.
- If `classification=replan`: STOP and set action to `replan_needed` — the plan has drifted too far.

## Branch Creation

When creating a branch for a new PG, create it from the **current HEAD** (not from
a hardcoded base). This ensures PG-2's branch includes PG-1's merged changes when
PGs have dependencies.

{% if pr_merge is defined and pr_merge.output and pr_merge.output.merged %}
**PR just merged: {{ pr_merge.output.pr_url }}**

The code is now on main. You MUST now close ONLY the Issues in the CURRENT
PR group ({{ pr_group_manager.output.current_pr_group }}). Do NOT close Issues
from other PR groups — they have not been implemented yet.

**Current PR group's Issues (close ONLY these):**
{{ pr_group_manager.output.pr_group_issue_ids | json }}

{% if task_manager is defined and task_manager.output %}
**Reviewed Issues:** {{ task_manager.output.reviewed_issues | json }}
Cross-reference: only close Issues that appear in BOTH pr_group_issue_ids AND reviewed_issues.
{% endif %}

For each issue IN THIS PR GROUP ONLY:
1. `twig set <issue_id> --output json`
2. `twig note --text "Done: closed after PR #<number> merged to main" --output json`
3. `twig state Done --output json`

⚠️ If an Issue ID is NOT in pr_group_issue_ids above, DO NOT close it.

Then determine next step (see Decision Logic below).
{% endif %}

{% if task_manager is defined and task_manager.output and task_manager.output.action == 'pr_group_ready' %}
**All issues in current PR group are reviewed and ready for PR submission.**
Set action=submit_pr to send to the PR pipeline.
{% endif %}

## Decision Logic

1. **First invocation (no prior state):**
   - Create branch for first PR group: `git checkout -b <branch_name>`
   - Push immediately for crash recovery and visibility: `git push -u origin <branch_name>`
   - Start first issue: `twig set <id> --output json` → `twig state Doing --output json`
   - Set action=start_tasks

2. **task_manager returned pr_group_ready:**
   - Set action=submit_pr

3. **PR just merged:**
   - Close all reviewed issues in this PR group (see above)
   - Add PR group to completed_prs
   - If more PR groups remain:
     a. Create new branch: `git checkout main && git pull && git checkout -b <next_branch_name>`
     b. Push immediately: `git push -u origin <next_branch_name>`
     c. Set action=start_tasks
   - If all PR groups complete:
     Set action=all_complete

## CRITICAL CONSTRAINT

You MUST NOT close any Issue until AFTER pr_merge confirms the PR is merged.
This is the structural enforcement that prevents the "code complete but not
shipped" failures observed in prior SDLC runs (#1338, #1394). The two prior
runs both had agents close Issues before PRs were merged, causing ADO state to
diverge from actual code delivery. This split exists specifically to prevent that.

## Post-Merge Verification Checkpoint (MANDATORY after each PR merge)

After pr_merge returns and before closing Issues or starting the next PR group,
you MUST run this verification sequence:

1. **Verify PR is actually merged:**
   Use the `pull_request_read` MCP tool (method: `get`, pullNumber: `<pr_number>`) — state must be "MERGED"
   - **Do NOT use `gh pr view` CLI** — the `gh` CLI hangs in non-TTY environments.
   If not "MERGED", STOP and set action=submit_pr to retry.

2. **Verify branch is merged to main:**
   `git checkout main && git pull`
   `git branch --no-merged main` — the PR group's branch must NOT appear.
   If it does, the merge did not land on main — STOP and report.

3. **Verify branch is deleted:**
   `git branch -d <branch_name>` — delete the local branch.
   If the remote branch still exists: `git push origin --delete <branch_name>`
   (pr_merge uses --delete-branch, but verify it worked)

4. **Close Issues (only after steps 1-3 pass):**
   For each issue in this PR group:
   - `twig set <issue_id> --output json`
   - `twig note --text "Done: closed after PR #<number> merged to main" --output json`
   - `twig state Done --output json`

5. **Verify Issue state matches merge state:**
   `twig set <issue_id> --output json` — confirm state is "Done"

Only after ALL verification steps pass should you proceed to the next PR group
or declare all_complete.
