Review the implementation plan at `{{ architect.output.plan_path }}`.
**Context:** Implementing #{{ workflow.input.work_item_id }} — {{ workflow.input.title if workflow.input.title is defined else '' }}

## Fact-Checking

To verify the document's claims, independently check:
- Technical claims by reading referenced source files and project configuration
- File paths, API names, and type references exist in the actual codebase
- Whether the described current state actually matches the codebase
- Whether the proposed design is feasible given AOT/trim constraints
- Whether dependencies and sequencing are realistic

## Scoring Rubric (P11 — dimension-by-dimension)

Score each dimension on a 1-5 scale. Provide a brief rationale per dimension.

| Dimension | Weight | What to evaluate |
|-----------|--------|-----------------|
| **Correctness** (30%) | 1-5 | Requirements addressed, no contradictions with codebase reality. File paths, API references, patterns are accurate. |
| **Feasibility** (25%) | 1-5 | Implementable given AOT, trim, InvariantGlobalization, TreatWarningsAsErrors. Design is grounded in actual codebase. |
| **Completeness** (20%) | 1-5 | All affected files/components identified. Tests, edge cases, migration concerns covered. |
| **Testability** (15%) | 1-5 | Design enables clear test strategy. Acceptance criteria are verifiable. |
| **Risk awareness** (10%) | 1-5 | Breaking changes surfaced. Dependencies identified. Mitigations concrete. |

**Composite score** = weighted sum mapped to 0-100.
**Critical issue** = any dimension scored ≤ 2.

Do NOT evaluate structure, readability, or formatting — a separate reviewer handles that.
Research the actual codebase to verify claims in the plan.

## What counts as a CRITICAL issue (dimension ≤ 2)

A dimension scores ≤ 2 ONLY when:
- A factual error that would cause implementation to fail
- A missing required component that a downstream agent needs
- An infeasibility given project constraints
- Ambiguity so severe that an implementer could not proceed

Do NOT score ≤ 2 for: style, optional sections, additional analysis you'd prefer,
or anything described as "consider" or "could be enhanced".

## Output

```json
{
  "dimensions": {
    "correctness": {"score": 4, "rationale": "..."},
    "feasibility": {"score": 5, "rationale": "..."},
    "completeness": {"score": 3, "rationale": "..."},
    "testability": {"score": 4, "rationale": "..."},
    "risk_awareness": {"score": 4, "rationale": "..."}
  },
  "score": 88,
  "critical_issues": [],
  "feedback": "Advisory feedback here (not forwarded to architect)"
}
