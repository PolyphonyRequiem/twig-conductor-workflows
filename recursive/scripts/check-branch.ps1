<#
.SYNOPSIS
    Idempotency check: does a planning branch exist for this work item?
.PARAMETER WorkItemId
    ADO work item ID to check.
#>
param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId
)

$ErrorActionPreference = 'Stop'

$branchName = "planning/$WorkItemId"
$branchExists = $false

# Check local branches
$localMatch = git branch --list $branchName 2>$null
if ($localMatch) { $branchExists = $true }

# Check remote branches
if (-not $branchExists) {
    $remoteMatch = git branch -r --list "origin/$branchName" 2>$null
    if ($remoteMatch) { $branchExists = $true }
}

[ordered]@{
    branch_exists = $branchExists
    branch_name   = $branchName
} | ConvertTo-Json
