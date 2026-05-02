<#
.SYNOPSIS
    Deterministic child-review router. Checks reviewer score, counts blocking
    issues, and determines whether to loop back to architect or proceed.

.PARAMETER Score
    Child reviewer composite score (0-100).
.PARAMETER CriticalIssues
    JSON array of critical issues from the child reviewer.
.PARAMETER RevisionCount
    Number of architect → reviewer cycles so far.
#>
param(
    [Parameter(Mandatory = $true)][int]$Score,
    [string]$CriticalIssues = '[]',
    [int]$RevisionCount = 0
)

$ErrorActionPreference = 'Stop'

$issues = $CriticalIssues | ConvertFrom-Json
$blockingCount = $issues.Count
$passes = ($blockingCount -eq 0) -and ($Score -ge 80)

# Determine route
$route = '$end'
if (-not $passes -and $RevisionCount -lt 2) {
    $route = 'child_architect'
}
elseif ($RevisionCount -ge 2 -and -not $passes) {
    # Hit revision cap — pass through anyway to avoid infinite loop
    $route = '$end'
}

# Assemble feedback summary
$feedback = @()
if ($issues.Count -gt 0) {
    $feedback += "**Child Reviewer** ($($issues.Count) blocking):"
    foreach ($issue in $issues) {
        $feedback += "  - $issue"
    }
}

[ordered]@{
    score              = $Score
    blocking_issue_count = $blockingCount
    passes             = $passes
    combined_feedback  = ($feedback -join "`n")
    revision_count     = $RevisionCount
    route              = $route
} | ConvertTo-Json
