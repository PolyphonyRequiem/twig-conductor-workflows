Review issue #{{ task_manager.output.current_issue_id }} — {{ task_manager.output.current_issue_title }}.
**Work Item:** #{{ intake.output.work_item_id }}
**Completed Tasks:** {{ task_manager.output.completed_tasks | json }}
**Reducer findings:** {{ reducer_issue.output.findings | join(", ") }}

## Scoring Rubric (P11 — Code Review, issue-level)

Score each dimension on a 1-5 scale. This is a holistic review across all tasks.

| Dimension | Weight | What to evaluate |
|-----------|--------|-----------------|
| **Correctness** (30%) | 1-5 | Combined implementation satisfies acceptance criteria |
| **Safety** (25%) | 1-5 | No regressions, cross-task integration is sound, error handling consistent |
| **Completeness** (20%) | 1-5 | All acceptance criteria met, edge cases covered, tests pass |
| **Conventions** (15%) | 1-5 | Consistent patterns across all tasks, documentation updated |
| **Reviewability** (10%) | 1-5 | Changes are coherent as a unit, easy to follow |

**Composite score** = weighted sum mapped to 0-100.
**Critical issue** = any dimension scored ≤ 2 → REQUEST_CHANGES.
**Pass** = no dimension ≤ 2 and composite ≥ 80 → APPROVE.

Run `dotnet test --settings test.runsettings` to verify all tests pass.
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
  "strengths": []
}
```
