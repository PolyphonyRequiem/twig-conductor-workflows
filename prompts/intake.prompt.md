Gather context for the SDLC workflow.
{% if workflow.input.work_item_id %}
**Existing work item:** #{{ workflow.input.work_item_id }}
1. Run: `twig set {{ workflow.input.work_item_id }} --output json`
2. Run: `twig status --output json` to get full details
3. Run: `twig tree --output json` to see any existing child items
4. Read the work item's description, acceptance criteria, and any linked items
5. Check the item's type (Epic, Issue, or Task) and current state
If the item already has child Issues with descriptions, include them in existing_issues.
{% endif %}
{% if workflow.input.prompt %}
**New work request:** {{ workflow.input.prompt }}
1. Create a new Epic via twig:
   - `twig set 1 --output json` (set to the root Epic)
   - `twig seed new --title "<derived title>" --type Epic --output json`
   - `twig seed publish --all --output json`
2. Wait 3 seconds, refresh, then set context to the new item
3. Assign and describe it:
   - `twig update System.AssignedTo "Daniel Green"`
   - `twig update System.Description "<rich markdown with headings, context, acceptance criteria>" --format markdown`
   Write a comprehensive description (2+ paragraphs) with `## What`, `## Why`, `## Acceptance Criteria` headings.
{% endif %}
Output the work item details for the next phase.
