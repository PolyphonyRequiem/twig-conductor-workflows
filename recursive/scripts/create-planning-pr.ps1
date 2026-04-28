# create-planning-pr.ps1 — Creates a GitHub PR for a planning branch
# Extracted from inline YAML to avoid Spectre.Console markup collisions
# with PowerShell type accelerators like [ordered], [int], etc.
param(
    [Parameter(Mandatory)][int]$WorkItemId,
    [string]$Title = '',
    [Parameter(Mandatory)][string]$BranchName,
    [string]$PlanUrl = ''
)

$ErrorActionPreference = 'Stop'
$env:GH_PROMPT_DISABLED = "1"

# Derive repo slug from git remote so gh never prompts for repo selection
$remoteUrl = (git remote get-url origin 2>$null) ?? ''
$repo = if ($remoteUrl -match 'github\.com(?:/|:)([^/]+/[^/.]+)') { $Matches[1] } else { '' }
if (-not $repo) {
    [ordered]@{ pr_number = 0; pr_url = ""; error = "Could not determine GitHub repo from git remote" } | ConvertTo-Json
    exit 0
}

$body = "## Planning Artifacts`n`nSolution design and implementation plan for #$WorkItemId.`n`n**Plan document:** $PlanUrl`n`nThis PR contains planning artifacts only - no code changes."
$prTitle = "docs: plan for #$WorkItemId - $Title"
$prUrl = gh pr create --repo $repo --base main --head $BranchName --title $prTitle --body $body 2>&1

if ($LASTEXITCODE -eq 0) {
    $prNumber = if ($prUrl -match '/pull/(\d+)') { [int]$Matches[1] } else { 0 }
    twig set $WorkItemId --output json 2>$null | Out-Null
    twig link artifact $prUrl --name "Planning PR" --output json 2>$null | Out-Null
    [ordered]@{ pr_number = $prNumber; pr_url = $prUrl.Trim() } | ConvertTo-Json
} else {
    [ordered]@{ pr_number = 0; pr_url = ""; error = ($prUrl -join "`n") } | ConvertTo-Json
}
