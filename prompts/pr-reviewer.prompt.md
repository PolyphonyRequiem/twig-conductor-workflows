Review the PR: {{ pr_submit.output.pr_url }}
**Work Item:** #{{ intake.output.work_item_id }}

## Available Tools
- **GitHub MCP**: Use `pull_request_read` with method `get_diff` to review the full diff,
  `get_files` to list changed files, and `search_code` for cross-referencing patterns.
- **Shell**: Use `dotnet test` for targeted test validation.

## Scoring Rubric (P11 — Code Review)

Score each dimension on a 1-5 scale. Provide a brief rationale per dimension.

| Dimension | Weight | What to evaluate |
|-----------|--------|-----------------|
| **Correctness** (30%) | 1-5 | Logic is right, components integrate correctly, edge cases handled |
| **Safety** (25%) | 1-5 | No regressions, error handling consistent, AOT/trim safe, resource management |
| **Completeness** (20%) | 1-5 | All acceptance criteria from the work item addressed, tests cover changes |
| **Conventions** (15%) | 1-5 | Consistent patterns, naming, style across all changes in the PR |
| **Reviewability** (10%) | 1-5 | Changes well-scoped, commit messages clear, git history clean |

**Composite score** = weighted sum mapped to 0-100.
**Critical issue** = any dimension scored ≤ 2 → REQUEST_CHANGES.
**Pass** = no dimension ≤ 2 and composite ≥ 80 → APPROVE.

Review all commits: Use GitHub MCP `pull_request_read` with method `get_diff` for PR #{{ pr_submit.output.pr_number }} (owner: {{ workflow.input.pr_owner }}, repo: {{ workflow.input.pr_repo_name }}).
Run targeted tests: `dotnet test tests/<RelevantProject>.Tests --no-build --settings test.runsettings`
Note what was done well — strengths reinforce good patterns.

## Output

```json
{
  "dimensions": { "correctness": {"score": 4, "rationale": "..."}, ... },
  "score": 88,
  "decision": "APPROVE",
  "feedback": "...",
  "issues": [],
  "approved": true,
  "strengths": [],
  "architecture_issues": [],
  "code_issues": [],
  "test_gaps": []
}
```
