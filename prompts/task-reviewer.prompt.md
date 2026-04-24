Review the implementation of task #{{ task_manager.output.current_task_id }} — {{ task_manager.output.current_task_title }}.
**Task description:** {{ task_manager.output.current_task_description }}
**Coder's changes:** {{ coder.output.changes_summary }}
**Files:** {{ coder.output.files_modified | join(", ") }}
**Tests:** {{ coder.output.tests_added | join(", ") }}
{% if coder.output.edge_cases_handled | length > 0 %}
**Edge cases handled:** {{ coder.output.edge_cases_handled | join(", ") }}
{% endif %}

{% if task_reviewer is defined and task_reviewer.output %}
**Review attempt:** {{ (task_reviewer.output.review_attempt | default(0)) + 1 }}
{% endif %}

## Review Cap

If this is review attempt 3 or higher, you MUST either APPROVE (if the code is
functional even if imperfect) or escalate to the user via a clear note in your
feedback. Do NOT reject indefinitely — 2 rejections is the cap before the coder
has had enough guidance to succeed or fail definitively.

## Scoring Rubric (P11 — Code Review)

Score each dimension on a 1-5 scale. Provide a brief rationale per dimension.

| Dimension | Weight | What to evaluate |
|-----------|--------|-----------------|
| **Correctness** (30%) | 1-5 | Logic is right, handles edge cases, requirements met |
| **Safety** (25%) | 1-5 | No regressions, AOT/trim safe, no reflection, uses TwigJsonContext |
| **Completeness** (20%) | 1-5 | All acceptance criteria addressed, tests written |
| **Conventions** (15%) | 1-5 | Follows project patterns (sealed, primary constructors, naming) |
| **Reviewability** (10%) | 1-5 | Changes are minimal, well-scoped, clear commit messages |

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
  "strengths": ["..."]
}
```
