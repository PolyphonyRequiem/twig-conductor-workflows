<#
.SYNOPSIS
    Loads the ADO work tree for an Epic/Issue and outputs structured JSON
    for the pr_group_manager orchestrator.

.DESCRIPTION
    Deterministic replacement for the LLM-based work_tree_seeder in the
    implement workflow. Reads the ADO hierarchy via twig CLI and outputs
    the work_tree and pr_groups structure expected by downstream agents.

    When given an Epic, auto-discovers per-issue plan files in PlanDir
    by matching frontmatter work_item_id to child Issue IDs. Aggregates
    PR groups across all discovered plans with sequential numbering.

    Reads PR group assignments from the plan file if provided, otherwise
    creates a single PR group containing all tasks.

.PARAMETER WorkItemId
    The Epic or Issue ADO ID.

.PARAMETER PlanPath
    Optional path to a single .plan.md file for PR group extraction.

.PARAMETER PlanDir
    Directory to scan for per-issue .plan.md files (default: docs/projects).
    Used when PlanPath is empty and the work item is an Epic with child Issues.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$WorkItemId,
    [string]$PlanPath = "",
    [string]$PlanDir = "docs/projects"
)

$ErrorActionPreference = 'Stop'

# Set context and get tree
$null = twig set $WorkItemId --output json 2>$null
$treeJson = twig tree --output json 2>$null
$tree = $treeJson | ConvertFrom-Json

if (-not $tree -or -not $tree.focus) {
    Write-Error "Failed to load work tree for #$WorkItemId"
    exit 1
}

$focus = $tree.focus
$children = $tree.children

# Build issue/task hierarchy
$issues = @()
$allTasks = @()
foreach ($child in $children) {
    if ($child.type -eq 'Issue') {
        # Get tasks under this issue
        $null = twig set $child.id --output json 2>$null
        $issueTree = twig tree --output json 2>$null | ConvertFrom-Json
        $tasks = @()
        if ($issueTree.children) {
            foreach ($t in $issueTree.children) {
                if ($t.type -eq 'Task') {
                    $tasks += [ordered]@{
                        id    = $t.id
                        title = $t.title
                        state = $t.state
                    }
                    $allTasks += $t
                }
            }
        }
        $issues += [ordered]@{
            id         = $child.id
            title      = $child.title
            state      = $child.state
            task_count = $tasks.Count
            tasks      = $tasks
        }
    }
    elseif ($child.type -eq 'Task') {
        # Direct child tasks (Issue-level input)
        $allTasks += $child
    }
}

# Try to extract PR groups from plan file(s)
$prGroups = @()
$planPaths = @()

# Helper: extract PGs from a single plan file
function Extract-PGsFromPlan {
    param([string]$Path, [array]$AllTasks, [array]$Issues, [int]$PGOffset)
    $pgs = @()
    $content = Get-Content $Path -Raw
    $pgMatches = [regex]::Matches($content, '(?m)^#+\s*(PG-\d+)[:\s\u2014\-]+(.+?)$')
    $pgIndex = 0
    foreach ($m in $pgMatches) {
        $pgName = "PG-$($PGOffset + $pgIndex + 1)"
        $pgTitle = $m.Groups[2].Value.Trim()
        $pgIndex++

        $startPos = $m.Index + $m.Length
        $endPos = if ($pgIndex -lt $pgMatches.Count) { $pgMatches[$pgIndex].Index } else { $content.Length }
        $section = $content.Substring($startPos, [Math]::Min($endPos - $startPos, 2000))
        $idMatches = [regex]::Matches($section, '#(\d{4,})')
        $taskIds = @()
        $issueIds = @()
        foreach ($idm in $idMatches) {
            $refId = [int]$idm.Groups[1].Value
            if ($AllTasks | Where-Object { $_.id -eq $refId }) {
                $taskIds += $refId
            }
            elseif ($Issues | Where-Object { $_.id -eq $refId }) {
                $issueIds += $refId
            }
        }

        $slug = ($pgTitle -replace '[^a-zA-Z0-9]+', '-' -replace '-+$', '').ToLower()
        $branchName = "feature/$($pgName.ToLower())-$slug"
        if ($branchName.Length -gt 60) { $branchName = $branchName.Substring(0, 60) }

        $pgs += [ordered]@{
            name                   = $pgName
            title                  = $pgTitle
            task_ids               = $taskIds
            issue_ids              = $issueIds
            branch_name_suggestion = $branchName
            source_plan            = $Path
        }
    }
    return $pgs
}

if ($PlanPath -and (Test-Path $PlanPath)) {
    # Single plan path provided — use it directly
    $planPaths = @($PlanPath)
}
elseif ($issues.Count -gt 0 -and (Test-Path $PlanDir)) {
    # Epic with child Issues — auto-discover plans per Issue via frontmatter or table metadata
    $planFiles = Get-ChildItem "$PlanDir/*.plan.md" -ErrorAction SilentlyContinue
    $issueIds = @($issues | ForEach-Object { $_.id })
    foreach ($pf in $planFiles) {
        $content = Get-Content $pf.FullName -Raw
        $matchedId = $null

        # Try YAML frontmatter first (preferred)
        if ($content -match '(?s)^---\s*\n(.*?)\n---') {
            $fm = $Matches[1]
            if ($fm -match 'work_item_id:\s*(\d+)') {
                $matchedId = [int]$Matches[1]
            }
        }

        # Fallback: table-based metadata (e.g. "| **Work Item** | #2016 |")
        if (-not $matchedId) {
            if ($content -match '\|\s*\*{0,2}Work\s*Item\*{0,2}\s*\|\s*#(\d+)') {
                $matchedId = [int]$Matches[1]
            }
            # Also try "| **Issue** | #XXXX" pattern
            elseif ($content -match '\|\s*\*{0,2}Issue\*{0,2}\s*\|\s*#(\d+)') {
                $matchedId = [int]$Matches[1]
            }
        }

        # Match to any child Issue ID
        if ($matchedId -and ($issueIds -contains $matchedId)) {
            $planPaths += $pf.FullName
        }
    }
}

# Extract PGs from all discovered plans
$pgOffset = 0
foreach ($pp in $planPaths) {
    $extractedPGs = Extract-PGsFromPlan -Path $pp -AllTasks $allTasks -Issues $issues -PGOffset $pgOffset
    if ($extractedPGs) {
        $prGroups += $extractedPGs
        $pgOffset += $extractedPGs.Count
    }
}

# Fallback: single PR group with all tasks if none found in plan
if ($prGroups.Count -eq 0) {
    $slug = ($focus.title -replace '[^a-zA-Z0-9]+', '-').ToLower()
    if ($slug.Length -gt 50) { $slug = $slug.Substring(0, 50) }
    $prGroups += [ordered]@{
        name                   = "PG-1"
        title                  = $focus.title
        task_ids               = @($allTasks | ForEach-Object { $_.id })
        issue_ids              = @($issues | ForEach-Object { $_.id })
        branch_name_suggestion = "feature/$slug"
    }
}

# Output
$result = [ordered]@{
    work_tree    = [ordered]@{
        epic_id    = $focus.id
        epic_title = $focus.title
        epic_type  = $focus.type
        issues     = $issues
    }
    pr_groups    = $prGroups
    plan_paths   = $planPaths
    total_tasks  = $allTasks.Count
    total_issues = $issues.Count
}

$result | ConvertTo-Json -Depth 10 -Compress
