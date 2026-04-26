<#
.SYNOPSIS
    Creates a feature branch for a PR group.

.DESCRIPTION
    Deterministic branch creation script. Checks out main, pulls latest,
    creates the feature branch, and pushes it to origin.

.PARAMETER BranchName
    The branch name to create (e.g., "feature/pg-1").
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BranchName)

$ErrorActionPreference = 'Stop'

try {
    # Ensure we start from latest main
    git checkout main *>$null
    git pull --ff-only *>$null 2>&1

    # Create and push the feature branch
    git checkout -b $BranchName *>$null 2>&1
    git push -u origin $BranchName *>$null 2>&1

    [ordered]@{
        branch_name = $BranchName
        created = $true
        base = 'main'
    } | ConvertTo-Json
}
catch {
    [ordered]@{
        error = $_.Exception.Message
        branch_name = $BranchName
        created = $false
    } | ConvertTo-Json
    exit 1
}
