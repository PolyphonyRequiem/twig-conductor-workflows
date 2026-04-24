<#
.SYNOPSIS
    Idempotency check: does an approved plan exist for this work item?
.PARAMETER WorkItemId
    ADO work item ID to check.
#>
param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId
)

$ErrorActionPreference = 'Stop'

$planExists = $false
$planPath = ''
$planSource = 'none'

# Priority 1: Artifact link on work item
# TODO: Once twig status --output json exposes artifact links, check here.
# For now, skip to filesystem fallback.

# Priority 2: Filesystem fallback
$planDir = 'docs/projects'
if (Test-Path $planDir) {
    $planFiles = Get-ChildItem "$planDir/*.plan.md" -ErrorAction SilentlyContinue
    $found = @()
    foreach ($pf in $planFiles) {
        $content = Get-Content $pf.FullName -Raw
        $matchedId = $null
        $fmMatch = [regex]::Match($content, '(?s)^---\s*\n(.*?)\n---')
        if ($fmMatch.Success) {
            $idMatch = [regex]::Match($fmMatch.Groups[1].Value, 'work_item_id:\s*(\d+)')
            if ($idMatch.Success) { $matchedId = [int]$idMatch.Groups[1].Value }
        }
        if (-not $matchedId) {
            $tblMatch = [regex]::Match($content, '\|\s*\*{0,2}Work\s*Item\*{0,2}\s*\|\s*#(\d+)')
            if ($tblMatch.Success) { $matchedId = [int]$tblMatch.Groups[1].Value }
        }
        if ($matchedId -eq $WorkItemId) {
            # Check approval status
            $statusMatch = [regex]::Match($content, '>\s*\*{0,2}Status\*{0,2}:\s*(.+)')
            $status = if ($statusMatch.Success) { $statusMatch.Groups[1].Value.Trim() } else { '' }
            $isApproved = $status -match 'Approved|In Progress|Complete|Done'
            $found += [PSCustomObject]@{ Path = $pf.FullName; Approved = $isApproved }
        }
    }

    if ($found.Count -eq 1) {
        $planExists = $found[0].Approved
        $planPath = $found[0].Path
        $planSource = 'filesystem_fallback'
    }
    elseif ($found.Count -gt 1) {
        # Ambiguous — multiple plans match. Take the approved one if unique.
        $approved = $found | Where-Object { $_.Approved }
        if ($approved.Count -eq 1) {
            $planExists = $true
            $planPath = $approved[0].Path
            $planSource = 'filesystem_fallback'
        }
    }
}

[ordered]@{
    plan_exists = $planExists
    plan_path   = $planPath
    plan_source = $planSource
} | ConvertTo-Json
