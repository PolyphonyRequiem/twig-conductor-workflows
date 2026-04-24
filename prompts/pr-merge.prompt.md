Merge the approved PR.
**PR:** {{ pr_submit.output.pr_url }} (#{{ pr_submit.output.pr_number }})

## Steps
1. Merge: `gh pr merge {{ pr_submit.output.pr_number }} --merge --delete-branch`
2. Switch to main: `git checkout main && git pull`
3. Verify clean state: `git status`
4. **Post-merge regression testing:**
   Run the full test suite on main to catch integration breaks:
   ```
   pwsh -NoProfile -File scripts/post-merge-regression.ps1
   ```
   - If `passed=true`: continue.
   - If `passed=false`: set `merged=false` and include the error in your output.
     The workflow will route back for fixes.
5. **Verify branch deletion:**
   - `git branch -D {{ pr_group_manager.output.branch_name }}` — delete local branch
   - Verify remote is gone: `git ls-remote --heads origin {{ pr_group_manager.output.branch_name }}`
   - If remote branch still exists: `git push origin --delete {{ pr_group_manager.output.branch_name }}`
6. **Verify merge landed:** `git branch --no-merged main` — the PR group's branch
   must NOT appear. If it does, set merged=false.
7. **Capture merge metadata** for downstream verification:
   - `git --no-pager log -1 --format="%H"` — record the merge commit SHA
   - Record the PR group name from `{{ pr_group_manager.output.current_pr_group }}`
   - Record the branch name from `{{ pr_group_manager.output.branch_name }}`
   - Record the issue IDs from `{{ pr_group_manager.output.pr_group_issue_ids | json }}`
