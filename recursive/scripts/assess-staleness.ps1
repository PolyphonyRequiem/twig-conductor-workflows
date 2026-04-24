<#
.SYNOPSIS
    Per-PG staleness assessor. Checks if plan assumptions still hold
    before starting a PR group.

.PARAMETER PlanPath
    Path to the plan file.
.PARAMETER FilesAffected
    Comma-separated list of files referenced in this PG's scope.
#>
param(
    [Parameter(Mandatory)][string]$PlanPath,
    [string]$FilesAffected = ''
)

$ErrorActionPreference = 'Stop'

$stale = $false
$classification = 'proceed'
$changes = @()

if (-not (Test-Path $PlanPath)) {
    [ordered]@{
        stale          = $true
        classification = 'replan'
        reason         = "Plan file not found: $PlanPath"
        changes        = @()
    } | ConvertTo-Json -Depth 3
    return
}

# Get plan's last commit date
$planDate = git log -1 --format="%aI" -- $PlanPath 2>$null
if (-not $planDate) {
    # Plan not committed yet — can't assess staleness
    [ordered]@{
        stale          = $false
        classification = 'proceed'
        reason         = "Plan not yet committed — no baseline for staleness check"
        changes        = @()
    } | ConvertTo-Json -Depth 3
    return
}

# Check if any referenced files changed since plan was written
$files = if ($FilesAffected) { $FilesAffected -split ',' | ForEach-Object { $_.Trim() } } else { @() }

foreach ($file in $files) {
    if (-not $file) { continue }
    $commits = git log --oneline --since="$planDate" -- $file 2>$null
    if ($commits) {
        $commitCount = ($commits | Measure-Object).Count
        $changes += [ordered]@{
            file    = $file
            commits = $commitCount
            latest  = ($commits | Select-Object -First 1)
        }
    }
}

if ($changes.Count -eq 0) {
    $classification = 'proceed'
}
elseif ($changes.Count -le 3) {
    $classification = 'adapt'
    $stale = $true
}
else {
    $classification = 'replan'
    $stale = $true
}

[ordered]@{
    stale          = $stale
    classification = $classification
    reason         = if ($stale) { "$($changes.Count) files changed since plan was written" } else { "No relevant files changed since plan" }
    plan_date      = $planDate
    changes        = $changes
} | ConvertTo-Json -Depth 3
