<#
.SYNOPSIS
    Deterministic review router. Replaces the LLM review_router agent.
    Checks reviewer scores, counts blocking issues, determines routing.

.PARAMETER TechScore
    Technical reviewer composite score (0-100).
.PARAMETER ReadScore
    Readability reviewer composite score (0-100).
.PARAMETER TechCritical
    JSON array of technical reviewer critical issues.
.PARAMETER ReadCritical
    JSON array of readability reviewer critical issues.
.PARAMETER RevisionCount
    Number of architect revisions so far.
.PARAMETER Intent
    User intent: new, redo, or resume.
#>
param(
    [Parameter(Mandatory = $true)][int]$TechScore,
    [Parameter(Mandatory = $true)][int]$ReadScore,
    [string]$TechCritical = '[]',
    [string]$ReadCritical = '[]',
    [int]$RevisionCount = 0,
    [string]$Intent = 'resume'
)

$ErrorActionPreference = 'Stop'

$techIssues = $TechCritical | ConvertFrom-Json
$readIssues = $ReadCritical | ConvertFrom-Json

$blockingCount = $techIssues.Count + $readIssues.Count
$bothPass = ($blockingCount -eq 0) -and ($TechScore -ge 80) -and ($ReadScore -ge 80)

# Skip approval if intent=resume (plan was previously approved)
$skipApproval = ($Intent -eq 'resume')

# Determine route
$route = 'plan_approval'
if (-not $bothPass -and $RevisionCount -lt 2) {
    $route = 'architect'
}
elseif ($RevisionCount -ge 2 -and -not $bothPass) {
    $route = 'revision_cap_gate'
}
elseif ($bothPass -and $skipApproval) {
    $route = 'plan_status_updater'
}

# Assemble combined feedback (critical issues only)
$feedback = @()
if ($techIssues.Count -gt 0) {
    $feedback += "**Technical Reviewer** ($($techIssues.Count) blocking):"
    foreach ($issue in $techIssues) {
        $feedback += "  - $issue"
    }
}
if ($readIssues.Count -gt 0) {
    $feedback += "**Readability Reviewer** ($($readIssues.Count) blocking):"
    foreach ($issue in $readIssues) {
        $feedback += "  - $issue"
    }
}

[ordered]@{
    tech_score          = $TechScore
    read_score          = $ReadScore
    blocking_issue_count = $blockingCount
    both_pass           = $bothPass
    skip_approval       = $skipApproval
    combined_feedback   = ($feedback -join "`n")
    revision_count      = $RevisionCount
    route               = $route
} | ConvertTo-Json
