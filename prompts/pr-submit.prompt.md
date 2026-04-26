Create a PR for the current PR group.
**Branch:** {{ pg_router.output.branch_name }}
**PR Group:** {{ pg_router.output.current_pg }}
**Issues in this PG:** {{ pg_router.output.issue_ids | json }}

## Idempotency Check
First, use the GitHub MCP `list_pull_requests` tool to check if a PR already exists:
- Owner: `PolyphonyRequiem`, Repo: `twig`, head filter: `{{ pg_router.output.branch_name }}`, state: `open`
If a PR exists, return its info (number, url, title) without creating a duplicate.

## Steps (only if no existing PR)
1. **PR group boundary validation** — verify this PR contains exactly one PR group:
   - Identify the current PR group identifier from `{{ pg_router.output.current_pg }}`
     (plans use `PG-N` naming, e.g. `PG-1`, `PG-2`)
   - **Branch name check:** the branch `{{ pg_router.output.branch_name }}` should
     encode the PR group (e.g. `feature/pg-1`). If the branch name contains
     references to multiple PG identifiers (e.g. both `pg-1` and `pg-2`), flag it.
   - **Scope check:** cross-reference the issues in
     `{{ pg_router.output.issue_ids | json }}` against the plan's PR group
     assignments. If issues from different PR groups are mixed, this PR combines multiple
     PR groups.
   - **If a violation is detected:**
     - Do NOT proceed with PR creation automatically
     - Report the violation: which PG identifiers are mixed, which issues are out-of-group
     - Ask the user for explicit approval via human gate — they must provide a justification
       string (e.g. "PG-1 and PG-2 are tightly coupled, splitting would break the build")
     - If approved, include the justification in the PR description under a
       `## PR Group Override` section
     - If not approved or no response, STOP and return to pg_router for re-grouping
2. **Pre-submit validation** — quick build check and targeted tests:
   - `dotnet build --no-restore -v quiet 2>&1` — must produce zero errors
   - If build fails, fix the issues (stale references to renamed/removed methods,
     missing usings, broken call sites) and commit the fixes before proceeding
   - Run **only the test projects relevant to the changed files**, not the full suite:
     - Changes in `src/Twig.Domain/` → `dotnet test tests/Twig.Domain.Tests --no-build --settings test.runsettings`
     - Changes in `src/Twig.Infrastructure/` → `dotnet test tests/Twig.Infrastructure.Tests --no-build --settings test.runsettings`
     - Changes in `src/Twig/` → `dotnet test tests/Twig.Cli.Tests --no-build --settings test.runsettings`
     - Changes in `src/Twig.Mcp/` → `dotnet test tests/Twig.Mcp.Tests --no-build --settings test.runsettings`
     - Changes in `src/Twig.Tui/` → `dotnet test tests/Twig.Tui.Tests --no-build --settings test.runsettings`
   - Use `git diff --name-only main` to determine which source directories were touched
   - **Do NOT run the full test suite** — the CI/CD pipeline handles comprehensive testing on the PR
3. Push the branch: `git push -u origin {{ pg_router.output.branch_name }}`
4. Create the PR:
   ```
   gh pr create --base main --head {{ pg_router.output.branch_name }} \
     --title "[{{ pg_router.output.current_pg }}] <PR group title>" \
     --body "<description with AB# references>"
   ```
   - The PR title MUST be prefixed with `[PG-N]` matching the current PR group identifier
5. The PR body should include:
   - Summary of changes
   - List of ADO work items (AB#<id> format for linking)
   - Files changed summary
   - Test coverage notes
