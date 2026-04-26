<#
.SYNOPSIS
    Push planning branch, commit plan artifacts, link to work item.

.PARAMETER WorkItemId
    ADO work item ID.
.PARAMETER PlanPath
    Path to the plan file to commit.
#>
param(
    [Parameter(Mandatory = $true)][int]$WorkItemId,
    [Parameter(Mandatory = $true)][string]$PlanPath
)

$ErrorActionPreference = 'Stop'

$branchName = "planning/$WorkItemId"
$pushed = $false
$linked = $false
$planUrl = ''

# Create and checkout branch (or switch to it if it exists)
$existingBranch = git branch --list $branchName 2>$null
if ($existingBranch) {
    git checkout $branchName *>$null
}
else {
    git checkout -b $branchName *>$null
}

# Stage and commit plan documents
git add docs/projects/ *>$null
$hasChanges = git diff --cached --quiet 2>$null; $hasChanges = $LASTEXITCODE -ne 0
if ($hasChanges) {
    twig set $WorkItemId --output json 2>$null | Out-Null
    twig commit "docs: planning artifacts for AB#$WorkItemId" --output json 2>$null | Out-Null
}

# Push
git push -u origin $branchName *>$null
$pushed = $LASTEXITCODE -eq 0

# Generate plan URL
$remoteUrl = git remote get-url origin 2>$null
if ($remoteUrl -match 'github\.com[:/](.+?)(?:\.git)?$') {
    $repoPath = $Matches[1]
    $planUrl = "https://github.com/$repoPath/blob/$branchName/$PlanPath"
}

# Link plan to work item
if ($planUrl) {
    twig set $WorkItemId --output json 2>$null | Out-Null
    $linkResult = twig link artifact $planUrl --name "Plan Document" --output json 2>$null
    $linked = $LASTEXITCODE -eq 0
}

[ordered]@{
    branch_name = $branchName
    pushed      = $pushed
    plan_url    = $planUrl
    linked      = $linked
} | ConvertTo-Json
