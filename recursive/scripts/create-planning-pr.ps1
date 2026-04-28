# create-planning-pr.ps1 — Creates a GitHub PR for a planning branch
# Uses GitHub REST API directly to avoid gh CLI hangs in non-TTY environments.
param(
    [Parameter(Mandatory)][int]$WorkItemId,
    [string]$Title = '',
    [Parameter(Mandatory)][string]$BranchName,
    [string]$PlanUrl = ''
)

$ErrorActionPreference = 'Stop'

# Derive repo slug from git remote
$remoteUrl = (git remote get-url origin 2>$null) ?? ''
$repo = if ($remoteUrl -match 'github\.com(?:/|:)([^/]+/[^/.]+)') { $Matches[1] } else { '' }
if (-not $repo) {
    [ordered]@{ pr_number = 0; pr_url = ""; error = "Could not determine GitHub repo from git remote" } | ConvertTo-Json
    exit 0
}

# Get token from gh CLI (reads local config, no network call)
$env:GH_PROMPT_DISABLED = "1"
$token = (gh auth token 2>$null) ?? ''
if (-not $token) {
    [ordered]@{ pr_number = 0; pr_url = ""; error = "Could not get GitHub token from gh auth token" } | ConvertTo-Json
    exit 0
}

$prTitle = "docs: plan for #$WorkItemId - $Title"
$prBody = "## Planning Artifacts`n`nSolution design and implementation plan for #$WorkItemId.`n`n**Plan document:** $PlanUrl`n`nThis PR contains planning artifacts only - no code changes."

try {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/pulls" -Method Post `
        -Headers @{
            Authorization = "Bearer $token"
            Accept = "application/vnd.github+json"
            'X-GitHub-Api-Version' = '2022-11-28'
        } `
        -ContentType 'application/json' `
        -Body ([ordered]@{
            title = $prTitle
            head  = $BranchName
            base  = 'main'
            body  = $prBody
        } | ConvertTo-Json)

    $prNumber = $response.number
    $prUrl = $response.html_url

    twig set $WorkItemId --output json 2>$null | Out-Null
    twig link artifact $prUrl --name "Planning PR" --output json 2>$null | Out-Null
    [ordered]@{ pr_number = $prNumber; pr_url = $prUrl } | ConvertTo-Json
}
catch {
    $msg = $_.Exception.Message
    # 422 = PR already exists or no commits — not fatal
    [ordered]@{ pr_number = 0; pr_url = ""; error = $msg } | ConvertTo-Json
}
