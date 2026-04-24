<#
.SYNOPSIS
    Deterministic state detector for the twig SDLC apex workflow.
    Inspects ADO work item state, plan artifacts, and git state to determine
    the current lifecycle phase and validate user intent.

.DESCRIPTION
    This script replaces the LLM-based plan_detector agent. It answers one
    routing question: what phase is this work item in?

    Outputs JSON with: work_item_id, work_item_type, work_item_state, intent,
    phase, plan info, seed status, and error/conflict flags.

.PARAMETER WorkItemId
    ADO work item ID to inspect.

.PARAMETER Intent
    User intent: new, redo, or resume (default: resume).

.PARAMETER PlanPath
    Explicit plan file override for debugging/recovery.
#>
param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId,

    [ValidateSet('new', 'redo', 'resume')]
    [string]$Intent = 'resume',

    [string]$PlanPath = ''
)

$ErrorActionPreference = 'Stop'

# ── Step 1: Read work item and tree ──────────────────────────────────────────

$treeJson = twig set $WorkItemId --output json 2>$null | Out-Null
$treeOutput = twig tree --depth 2 --output json 2>$null
$tree = $treeOutput | ConvertFrom-Json

$focus = $tree.focus
$children = $tree.children

$workItemType = $focus.type      # Epic, Issue, or Task
$workItemState = $focus.state    # To Do, Doing, Done
$workItemTitle = $focus.title

# ── Step 2: Analyze children ─────────────────────────────────────────────────

$childCount = if ($children) { $children.Count } else { 0 }
$doneCount = if ($children) { ($children | Where-Object { $_.state -eq 'Done' }).Count } else { 0 }
$doingCount = if ($children) { ($children | Where-Object { $_.state -eq 'Doing' }).Count } else { 0 }
$todoCount = if ($children) { ($children | Where-Object { $_.state -eq 'To Do' }).Count } else { 0 }

$hasSeededChildren = $childCount -gt 0
$seedStatus = if ($childCount -eq 0) { 'unseeded' }
              elseif ($todoCount -eq $childCount) { 'seeded' }
              else { 'partial' }

$childrenSummary = @{
    total = $childCount
    done  = $doneCount
    doing = $doingCount
    todo  = $todoCount
} | ConvertTo-Json -Compress

# ── Step 3: Plan discovery ───────────────────────────────────────────────────

$planStatus = 'none'
$planSource = 'none'
$resolvedPlanPath = ''

# Priority 1: Explicit plan_path override
if ($PlanPath -and (Test-Path $PlanPath)) {
    $planStatus = 'complete'
    $planSource = 'explicit_override'
    $resolvedPlanPath = $PlanPath
}

# Priority 2: Artifact link on work item (requires #2059 — artifact link sync)
# TODO: Once twig status --output json exposes artifact links, check here.
# For now, skip to Priority 3 (filesystem fallback).

# Priority 3: Filesystem fallback — scan docs/projects/*.plan.md
if ($planStatus -eq 'none') {
    $planDir = 'docs/projects'
    if (Test-Path $planDir) {
        $planFiles = Get-ChildItem "$planDir/*.plan.md" -ErrorAction SilentlyContinue
        $foundPlans = @()
        foreach ($pf in $planFiles) {
            $content = Get-Content $pf.FullName -Raw
            $matchedId = $null
            # YAML frontmatter
            $fmMatch = [regex]::Match($content, '(?s)^---\s*\n(.*?)\n---')
            if ($fmMatch.Success) {
                $idMatch = [regex]::Match($fmMatch.Groups[1].Value, 'work_item_id:\s*(\d+)')
                if ($idMatch.Success) { $matchedId = [int]$idMatch.Groups[1].Value }
            }
            # Legacy table metadata
            if (-not $matchedId) {
                $tblMatch = [regex]::Match($content, '\|\s*\*{0,2}Work\s*Item\*{0,2}\s*\|\s*#(\d+)')
                if ($tblMatch.Success) { $matchedId = [int]$tblMatch.Groups[1].Value }
            }
            if (-not $matchedId) {
                $issMatch = [regex]::Match($content, '\|\s*\*{0,2}Issue\*{0,2}\s*\|\s*#(\d+)')
                if ($issMatch.Success) { $matchedId = [int]$issMatch.Groups[1].Value }
            }
            if ($matchedId -eq $WorkItemId) {
                $foundPlans += $pf.FullName
            }
        }

        if ($foundPlans.Count -eq 1) {
            $planStatus = 'complete'
            $planSource = 'filesystem_fallback'
            $resolvedPlanPath = $foundPlans[0]
        }
        elseif ($foundPlans.Count -gt 1) {
            $planStatus = 'ambiguous'
            $planSource = 'filesystem_fallback'
        }
    }
}

$hasPlan = $planStatus -in @('complete')

# ── Step 4: Implementation status ────────────────────────────────────────────

$implementationStatus = 'not_started'
if ($workItemState -eq 'Done' -and $doneCount -eq $childCount -and $childCount -gt 0) {
    $implementationStatus = 'done'
}
elseif ($doneCount -gt 0 -or $doingCount -gt 0) {
    $implementationStatus = 'in_progress'
}

# ── Step 5: Intent validation and phase determination ────────────────────────

$errorMsg = ''
$intentConflict = $false
$needsCleanup = $false
$phase = 'needs_planning'

# Input validation
if ($Intent -eq 'new' -and $hasSeededChildren) {
    # Don't hard error — flag conflict for human gate
    $intentConflict = $true
}
elseif ($Intent -eq 'new' -and $hasPlan) {
    $intentConflict = $true
}

if ($Intent -eq 'redo') {
    $needsCleanup = $hasSeededChildren -or $hasPlan
}

# Phase determination — check done FIRST before inconsistency checks
if ($implementationStatus -eq 'done') {
    $phase = 'done'
}
elseif (-not $errorMsg -and -not $intentConflict -and -not $needsCleanup) {
    if ($planStatus -eq 'ambiguous') {
        $errorMsg = "Multiple plan files match work item #$WorkItemId. Resolve ambiguity manually or use --plan_path override."
    }

    if (-not $errorMsg) {
        if ($hasSeededChildren) {
            # Children exist — go to implementation regardless of plan status.
            # The plan is context (P2), not required for implementation.
            $phase = 'ready_for_implementation'
        }
        elseif ($hasPlan) {
            # Plan exists but no children — planning needs to seed
            $phase = 'needs_planning'
        }
        else {
            $phase = 'needs_planning'
        }
    }
}

# ── Step 6: Output───────────────────────────────────────────────────────────

$output = [ordered]@{
    work_item_id          = $WorkItemId
    work_item_type        = $workItemType
    work_item_state       = $workItemState
    work_item_title       = $workItemTitle
    intent                = $Intent
    phase                 = $phase
    has_plan              = $hasPlan
    plan_status           = $planStatus
    plan_path             = $resolvedPlanPath
    plan_source           = $planSource
    has_seeded_children   = $hasSeededChildren
    seed_status           = $seedStatus
    children_summary      = $childrenSummary
    implementation_status = $implementationStatus
    intent_conflict       = $intentConflict
    needs_cleanup         = $needsCleanup
    error                 = $errorMsg
}

$output | ConvertTo-Json -Depth 3

# Exit codes for conductor routing (script agents route on exit_code, not output fields):
#   0 = error (default if errorMsg is set)
#   2 = intent_conflict → intent_correction_gate
#   3 = needs_cleanup → cleanup
#  10 = needs_planning → planning
#  20 = ready_for_implementation → implementation
#  30 = done → close_out
#  40 = done (already complete) → $end

if ($errorMsg) { exit 1 }
elseif ($intentConflict) { exit 2 }
elseif ($needsCleanup) { exit 3 }
elseif ($phase -eq 'needs_planning') { exit 10 }
elseif ($phase -eq 'ready_for_implementation') { exit 20 }
elseif ($phase -eq 'done') { exit 40 }
else { exit 1 }