Run a postmortem review of the SDLC run for work item #{{ close_out.output.work_item_id | default(state_detector.output.work_item_id) }}.

**Work Item:** {{ state_detector.output.work_item_title | default('Unknown') }}
**Type:** {{ state_detector.output.work_item_type | default('Unknown') }}
**Close-out result:** {{ close_out.output.summary | default('No close-out data') }}

## Steps

### 1. Gather evidence

Review the run artifacts:
```
twig set {{ close_out.output.work_item_id | default(state_detector.output.work_item_id) }} --output json
twig tree --output json
```

Check merged PRs using the `list_pull_requests` MCP tool:
- owner: `{{ workflow.input.pr_owner }}`, repo: `{{ workflow.input.pr_repo_name }}`, state: `closed`
- Filter for PRs related to work item {{ close_out.output.work_item_id | default(state_detector.output.work_item_id) }}
- **Do NOT use `gh pr list` CLI** — the `gh` CLI hangs in non-TTY environments.

Check git log for this run:
```
git --no-pager log --oneline -20
```

### 2. Analyze

For each category (Process, Quality, Efficiency, Tooling):
- Identify 1-3 observations
- Rate severity: info, warning, actionable
- Include specific evidence (PR numbers, file counts, retry counts)

### 3. File findings

Create an ADO Issue under Epic #1603 (Closeout Findings):
```
twig set 1603
twig seed new --title "<Work Item Title> SDLC Retrospective" --type Issue
twig seed publish --all
```

Then add a rich description with the structured observations:
```
twig set <new_issue_id>
twig update System.Description "<markdown observations>" --format markdown
twig update System.AssignedTo "Daniel Green"
```

Add a note to the original work item:
```
twig set {{ close_out.output.work_item_id | default(state_detector.output.work_item_id) }}
twig note --text "Retrospective filed as #<new_issue_id>"
```

## Output

```json
{
  "observations": [
    {"category": "...", "severity": "...", "finding": "...", "evidence": "..."}
  ],
  "improvements": ["..."],
  "retrospective_issue_id": <number>,
  "summary": "..."
}
```
