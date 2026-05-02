Review the task decomposition for Issue #{{ workflow.input.work_item_id }} — {{ workflow.input.title }}.
**Plan:** Read `{{ workflow.input.plan_path | default('(no plan path available — review tasks directly)') }}` for this issue's scope.

Check the ADO work items:
```
twig set {{ workflow.input.work_item_id }} --output json
twig tree --output json
```

## Scoring Rubric (dimension-by-dimension)

Score each dimension on a 1-5 scale. Provide a brief rationale per dimension.

| Dimension | Weight | What to evaluate |
|-----------|--------|-----------------|
| **Completeness** (30%) | 1-5 | Do the Tasks cover everything in the Issue description? No missing requirements. |
| **Granularity** (25%) | 1-5 | Is each Task independently committable? Not too big (multi-day), not too small (rename-only). |
| **Descriptions** (20%) | 1-5 | Does each Task specify files, changes, and expected behavior clearly enough for a coder agent? |
| **Dependencies** (15%) | 1-5 | Are Task ordering and successor links correct? No circular deps. |
| **Test coverage** (10%) | 1-5 | Are there Tasks for tests where needed? Test strategy is realistic. |

**Composite score** = weighted sum mapped to 0-100.
**Critical issue** = any dimension scored ≤ 2.

## What counts as a CRITICAL issue (dimension ≤ 2)

A dimension scores ≤ 2 ONLY when:
- A Task is completely missing for a required piece of the Issue scope
- A Task is so large it cannot be implemented in a single commit
- A Task description is so vague that a coder could not begin work
- Dependencies would cause implementation to fail (circular or wrong order)

Do NOT score ≤ 2 for: style preferences, optional enhancements, additional tests
you'd prefer, or anything described as "nice to have."

## Output

```json
{
  "dimensions": {
    "completeness": {"score": 4, "rationale": "..."},
    "granularity": {"score": 5, "rationale": "..."},
    "descriptions": {"score": 3, "rationale": "..."},
    "dependencies": {"score": 4, "rationale": "..."},
    "test_coverage": {"score": 4, "rationale": "..."}
  },
  "score": 85,
  "critical_issues": [],
  "feedback": "Advisory observations here"
}
```
