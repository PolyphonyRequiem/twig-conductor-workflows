Review the plan at `{{ architect.output.plan_path }}` for readability.

## Expected Document Structure

The document should contain the following sections:
1. Executive Summary (one paragraph)
2. Background (current state, motivation, prior art, call-site audit if applicable)
3. Problem Statement (specific problems being solved)
4. Goals and Non-Goals
5. Requirements (functional and non-functional)
6. Proposed Design (architecture overview, key components, data flow, design decisions)
7. Alternatives Considered *(optional — include when non-obvious choices exist)*
8. Dependencies
9. Impact Analysis *(optional — include for multi-component or compatibility-sensitive changes)*
10. Security Considerations *(optional — include when security boundaries are affected)*
11. Risks and Mitigations *(optional — include for meaningful risks)*
12. Open Questions
13. Files Affected (new, modified, deleted)
14. ADO Work Item Structure (Issues, Tasks, acceptance criteria)
15. PR Groups (reviewable PR clusters with sizing and ordering)
16. References *(optional)*

## Scoring Rubric (P11 — dimension-by-dimension)

Score each dimension on a 1-5 scale. Provide a brief rationale per dimension.
Focus exclusively on **structure and readability** — not technical accuracy.

| Dimension | Weight | What to evaluate |
|-----------|--------|-----------------|
| **Clarity** (30%) | 1-5 | Writing is clear, precise, free of ambiguity. No vague language. |
| **Actionability** (25%) | 1-5 | After reading, a developer or AI agent knows exactly what to build. Tasks are concrete. |
| **Structure** (20%) | 1-5 | Follows expected sections. Information logically organized. Tables, lists, code refs used well. |
| **Traceability** (15%) | 1-5 | Requirements → Issues → Tasks → PGs mapping is clear and complete. |
| **Scoping** (10%) | 1-5 | Boundaries explicit — what's in, what's out, what's deferred. Non-goals stated. |

**Composite score** = weighted sum mapped to 0-100.
**Critical issue** = any dimension scored ≤ 2.

Do NOT evaluate technical correctness — a separate reviewer handles that.

## What counts as a CRITICAL issue (dimension ≤ 2)

A dimension scores ≤ 2 ONLY when:
- A required section is missing (sections 1-6, 8, 12-15)
- Ambiguity makes it impossible to proceed with implementation
- Contradictory statements within the document

Do NOT score ≤ 2 for: optional sections absent, stylistic preferences,
suggested rewording, or "could be clearer" observations.

## Output

```json
{
  "dimensions": {
    "clarity": {"score": 5, "rationale": "..."},
    "actionability": {"score": 4, "rationale": "..."},
    "structure": {"score": 4, "rationale": "..."},
    "traceability": {"score": 3, "rationale": "..."},
    "scoping": {"score": 5, "rationale": "..."}
  },
  "score": 91,
  "critical_issues": [],
  "feedback": "Advisory feedback here (not forwarded to architect)"
}
