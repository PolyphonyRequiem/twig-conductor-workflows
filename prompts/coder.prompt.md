Implement the following task.
**Task:** #{{ task_router.output.task_id }} — {{ task_router.output.task_title }}
**Issue:** #{{ task_router.output.issue_id }} — {{ task_router.output.issue_title }}
**Branch:** {{ pg_router.output.branch_name }}
**Plan:** {% if workflow is defined and workflow.input is defined and workflow.input.plan_path %}Read `{{ workflow.input.plan_path }}` for full design context and PG scope.{% else %}Check `docs/projects/` for the relevant plan document.{% endif %}
**PR Group:** {{ pg_router.output.current_pg }}
**Remaining tasks in this PG:** {{ task_router.output.remaining_count }}
{% if pr_reviewer is defined and pr_reviewer.output and not pr_reviewer.output.approved %}
**PR review feedback — fix these issues:**
{{ pr_reviewer.output.feedback | default('') }}
{% for issue in pr_reviewer.output.issues %}
- {{ issue }}
{% endfor %}
{% endif %}
## Steps

### Step 0 — Read Task Details & Prior State Check (< 3 minutes, MANDATORY)
First, read the full task description from ADO:
- `twig set {{ task_router.output.task_id }}` — set active work item
- Use the twig MCP tool `twig_show` to read the task's full description and acceptance criteria

**Code discovery**: Use the GitHub MCP `search_code` tool to find relevant symbols, patterns,
and existing implementations in `{{ workflow.input.pr_owner }}/{{ workflow.input.pr_repo_name }}` before writing code. This is faster
and more reliable than grepping through the local filesystem.

Then check if this task was already worked on:
```
git --no-pager log --oneline -10
git --no-pager diff --stat HEAD
git --no-pager status --short
```
**If commits already exist for this task** (matching the task ID, issue, or description):
- Verify the existing work is correct with *targeted* spot-checks — NOT a full re-verification
- If it looks good: run the scope-appropriate tests (see **Step 4**), commit any uncommitted changes, and go straight to **Step 5**
- If it has problems: fix only what's broken, don't redo from scratch
- **Budget: spend ≤ 5 minutes verifying prior work. Trust prior commits unless you find concrete evidence of breakage.**

**If no prior work exists**, proceed to Step 1.

### Step 1 — Targeted Research (< 10 minutes)
Research ONLY what you need for THIS task — not the whole codebase:
- Read the plan file for this task's specific section
- **Use the C# Intelligence MCP** (`find_definition`, `find_references`, `find_implementations`)
  to navigate the codebase precisely. This is faster and more reliable than grepping.
- Check the conventions of 1-2 similar existing files as reference
- Add a twig note: `twig note --text "Research: <findings>"`

Do NOT: enumerate all modules, review every interface, or catalog the entire codebase.

### Step 2 — Implement
Implement the changes following existing conventions.
- Add a twig note: `twig note --text "Impl: <what was done>"`

### Step 3 — Write Tests
Write tests covering the new functionality and edge cases.
- Track edge cases you explicitly handled (for reviewer visibility)

### Step 4 — Run Tests (scope-aware)
Pick the narrowest suite that covers your changes. **Use the `dotnet` MCP tools** for
structured build and test results instead of parsing terminal output:

- **`dotnet_build`** — returns structured errors/warnings with file, line, code
- **`dotnet_test`** — returns pass/fail counts and structured failure details (test name, message, stack trace)

Scope rules:
- **Changes confined to `ext/twig-vscode/**`** → `cd ext/twig-vscode && npm run compile && npm run test:unit`
- **Otherwise (.NET changes)** → Use `dotnet_build` MCP tool first, then `dotnet_test` with appropriate project and settings
- **Mixed** → run both suites.

Add a twig note: `twig note --text "Tests: <count> passed"`

**Shell watchdog.** If a test/build shell produces zero output after ~3 consecutive
`read_powershell` polls (~6 minutes), `stop_powershell` and do one of:
1. Narrow scope (single test project: `dotnet test tests/<Project>.Tests --no-restore --no-build`).
2. Run `dotnet build-server shutdown` to clear stuck MSBuild/VBCS servers, then retry.
3. If still stuck, emit a failure note (`twig note --text "Blocked: tests hung"`) and
   stop — do not re-arm the same broad command. A blocked run that surfaces quickly
   is better than burning the full session budget on one stalled shell.

Never launch a `dotnet test` and an `npm`/`mocha` shell in parallel from the same repo
— overlapping TypeScript/NuGet restores can produce minutes of silent stalls.

### Step 5 — Commit, Push & Close Task
`git add -A && git commit -m "<descriptive message>" && git push`

Push after every commit for crash recovery — if the workflow restarts, committed
work is safe on the remote. The branch was already pushed by branch_manager.

After a successful push, transition the task to Done:
```
twig set {{ task_router.output.task_id }}
twig note --text "Done: <brief summary of what was implemented>"
twig state Done
```

Do NOT implement anything beyond this single task.
Do NOT implement tasks from other PR groups — stay within {{ pg_router.output.current_pg }}.
If this task requires changes outside this repository, STOP and set output blocked with a description of what's needed elsewhere.

## Pre-Review Checklist (avoid review round-trips)
Before committing, self-check against these criteria that the reviewer will enforce:
- [ ] Requirements met — implementation satisfies the task description
- [ ] Code quality — clean, idiomatic C#, follows project conventions (sealed classes, primary constructors)
- [ ] AOT compliance — no reflection, all JSON uses TwigJsonContext, no dynamic loading
- [ ] Test coverage — edge cases covered, tests verify behavior not implementation
- [ ] No stale references — renamed/removed methods updated at ALL call sites
- [ ] Builds clean — `dotnet build` produces zero warnings (TreatWarningsAsErrors) *(skip for ext/-only changes)*
- [ ] All tests pass — scope-appropriate suite from **Step 4** is green
  (`npm run test:unit` for `ext/twig-vscode/**`, else `dotnet test --settings test.runsettings --no-restore --no-build`)
