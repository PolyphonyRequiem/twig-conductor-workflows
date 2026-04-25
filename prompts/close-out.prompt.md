Close out the SDLC workflow.
**Work Item:** #{{ workflow.input.work_item_id }}

**Implementation results:**
{{ implementation.output.summary if implementation is defined and implementation.output is defined else 'No implementation summary available' }}

## Steps

### Step 0: Read current state from ADO
```
twig set {{ workflow.input.work_item_id }} --output json
twig tree --depth 2 --output json
```
Determine: which children are Done, which are still in progress, any state violations.

## Ownership Convention
Implementing agents (coder, task_manager) own Task state transitions.
pr_group_manager owns Issue closure (only after PR merge).
The close_out agent owns the **Epic-level** transition to Done.
Do NOT assume implementing agents have already transitioned the Epic.
## Steps
0. **Sync local cache** (prevents stale-state conflicts from multi-agent workflows):
   - `twig sync --output json` — flush pending changes and pull all remote state into local DB
   - This ensures issues/tasks transitioned by other agents are reflected locally
   - If sync fails with a transient ADO error, retry up to 3 times with 5-second delays
0b. **Fast-path: Already-Done check** (skip redundant verification when re-running):
   - `twig set {{ workflow.input.work_item_id }} --output json` — read the current state
   - If the state is already "Done":
     1. Record the fast-path decision:
        `twig note --text "Fast-path: Epic/Issue is already Done — skipping PR/branch/child verification (Steps 1–4) and proceeding directly to observations."`
     2. Set `epic_completed: false` (the agent did not perform the transition)
     3. **SKIP directly to Step 5** — do NOT execute Steps 1, 1b, 1c, 2, 3, or 4
   - If the state is NOT "Done": continue with Step 1 (normal flow)

   > **Why safe:** Verification was already performed during the original close-out run that transitioned the item to Done.
   > Additionally, the upstream `pr_finalizer` gate already confirmed PR merge state; re-running verification risks false-positive STOP conditions.
   > **When this triggers:** Re-runs, retries, manual workflow restarts, or manual Done transitions.
   > **What is NOT skipped:** Steps 5–8 always execute (observations, git push).
   > Steps 9–10 (close commit, version tag) are guarded by `epic_completed`.
1. **Verify all PRs are merged** (guard against premature close-out):
   - The pr_finalizer agent has already verified PR group completeness upstream.
     Review its `summary` and `state_violations` above.
   - As a defense-in-depth check, also verify directly:
     For each PR in the completed list:
     `gh pr view <pr_number> --json state --jq '.state'` — must be "MERGED"
   - If any PR is not merged, STOP and report the issue — do not proceed
   - Also verify main has the commits: `git checkout main && git pull`
1b. **Verify no unmerged feature branches** (guard against orphaned work):
   - Run: `git branch --no-merged main`
   - Cross-reference against the work tree's PR groups (not just the plan):
     {{ implementation.output }}
   - If ANY branch matches a planned PR group that should be complete, STOP and
     report — code exists on a branch that was never PR'd or merged
1c. **Verify all child items are Done** (guard against premature Epic closure):
   - `twig set {{ workflow.input.work_item_id }} --output json`
   - `twig tree --output json` — inspect all children
   - If ANY child Issue or Task is NOT in state "Done":
     1. Set `epic_completed: false`
     2. Record which items are still open (include IDs and current states)
     3. **SKIP Steps 2, 3, 4, 9, and 10** — do NOT transition the Epic,
        do NOT create a close commit, do NOT create a version tag
     4. **Proceed to Step 1e** (state rollback), then **continue with Steps 5–8**
        (observations and notes are still valuable for diagnosing the incomplete run)
   - If ALL children are Done: set `epic_completed: true`, continue normally with Step 2
1e. **Roll back orphaned "Doing" items** (prevents state leaks from incomplete runs):
   - From the `twig tree` output in Step 1c, identify any child Issues in state
     "Doing" whose IDs are NOT in the completed Issues list above:
     {{ implementation.output | json }}
   - For each such orphaned Issue:
     1. `twig set <id> --output json`
     2. `twig note --text "State rollback: reverted from Doing → To Do. Workflow ended without completing this item's PR group."`
     3. `twig state "To Do" --force --output json`
   - This ensures no Issues are left in a misleading "Doing" state after any
     workflow run (crash, partial completion, or scope mismatch)
2. **Check current state (idempotency):**
   - `twig set {{ workflow.input.work_item_id }} --output json` — read the current state
   - `git log --oneline -10` — check if a close commit already exists
   - If state is already "Done" AND a close commit exists, skip steps 3-4 and go to step 5
3. **Transition the Epic to Done** (only if not already Done):
   - `twig note --text "All work complete. <progress summary>"`
   - `twig state Done --output json`
4. **Update the plan document** at `{{ workflow.input.work_item_id }}`:
   - Change the Status line from its current value to `> **Status**: ✅ Done`
   - Mark all Epics and Tasks as DONE in the plan file
   - Add a completion section with date and summary
5. **Full workflow git log** — for richer observations, capture the entire commit history:
   - `git log --oneline --all` (or scope to the workflow's branches/main)
   - Note commit cadence, rework patterns, time-to-completion indicators
6. **Produce meta-observations:**
   Reflect on the entire workflow execution:
   - What went well? Which agents performed effectively?
   - Where did agents struggle? (hallucinations, wrong tools, missed context)
   - What workflow improvements would help future runs?
   - Were the PR groupings effective?
   - Was the plan accurate, or did implementation diverge significantly?
   - Commit cadence and rework analysis from the git log
7. **Record observations in ADO** — add a twig note summarizing key meta-observations:
   - `twig set {{ workflow.input.work_item_id }} --output json`
   - `twig note --text "Workflow observations: <2-3 sentence summary of what went well, what struggled, and top improvement>"`
   - `twig sync --output json` — flush the note to ADO; capture the JSON output
7b. **Verify note persistence** (guard against staged-but-not-flushed notes; see #1635):
   - Inspect the `twig sync` JSON from Step 7 — it contains `flush.notesPushed` and `flush.failed` counters
   - `flush.notesPushed` MUST be >= the number of notes you posted in Step 7 (usually 1)
   - `flush.failed` MUST be 0
   - If `notesPushed` is too low OR `failed > 0`:
     1. Retry once: re-run `twig note --text "..."` → `twig sync --output json` and re-check counters
     2. If counters still indicate the note did not land, **surface the failure explicitly**
        in your output: set `note_verification_failed: true` and include the raw sync JSON
        — do NOT silently continue. The Epic MUST NOT be transitioned to Done until the
        observation note is confirmed flushed.
8. **Ensure all work is upstream:**
   - `git push` — push any pending commits (e.g., reduction sweeps, plan status updates)
   - If push fails (nothing to push), that's fine — continue
9. **Final commit** (only if there are uncommitted changes AND `epic_completed` is true):
   - **If `epic_completed` is false**: **SKIP this step.** Do not create a close commit for incomplete work.
   - `git diff --stat HEAD` — check for changes
   - If changes exist: `git add -A && git commit -m "close: {{ workflow.input.work_item_id }}" && git push`
   - If no changes: skip commit
10. **Tag the release** (after all pushes are complete — **only if `epic_completed` is true**):
   - **If `epic_completed` is false** (Step 1c found incomplete children): **SKIP this step entirely.**
     The version tag will be created on a successful future run that completes all work.
     Record in observations: "Version tag skipped — not all child items are Done."
   - Get the latest tag: `git tag -l "v*" --sort=-version:refname | head -1`
   - Parse the version components (major.minor.patch)
   - Determine increment based on item type (the work item type (read from twig tree output)):
     - **Issue** → increment patch (e.g., v0.25.2 → v0.25.3)
     - **Epic** → increment minor, reset patch (e.g., v0.25.2 → v0.26.0)
   - Create the tag: `git tag v<new_version>`
   - Push the tag: `git push origin v<new_version>`
