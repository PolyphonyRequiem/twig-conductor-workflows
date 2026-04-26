<#
.SYNOPSIS
    Lightweight preflight check for SDLC sub-workflows (planning, implement).
.DESCRIPTION
    Performs 3 fast checks: gh auth, git repo status, ADO connectivity.
    Outputs JSON with pass/fail per check and an overall 'ready' boolean.
    All checks are required — no advisory category in lite mode.
.PARAMETER WorkItemId
    Target work item ID (used to test ADO connectivity via twig set).
#>
param(
    [Parameter(Mandatory)][int]$WorkItemId
)

$ErrorActionPreference = 'Stop'
$requiredChecks = @()
$advisoryChecks = @()
$allPassed = $true

# ── Required Check 1: gh auth ──────────────────────────────────────────
try {
    $ghUser = gh api user --jq '.login' 2>$null
    if ($ghUser) {
        $requiredChecks += [ordered]@{ name = 'gh_auth'; passed = $true; detail = "Logged in as $ghUser"; category = 'required' }
    } else {
        $requiredChecks += [ordered]@{ name = 'gh_auth'; passed = $false; detail = "gh auth returned empty user"; remediation = "Run: gh auth login"; category = 'required' }
        $allPassed = $false
    }
} catch {
    $requiredChecks += [ordered]@{ name = 'gh_auth'; passed = $false; detail = "gh auth failed: $_"; remediation = "Run: gh auth login"; category = 'required' }
    $allPassed = $false
}

# ── Required Check 2: git repo status ──────────────────────────────────
try {
    $gitDir = git rev-parse --git-dir 2>$null
    if ($gitDir) {
        $gitBranch = git branch --show-current 2>$null
        $requiredChecks += [ordered]@{ name = 'git_repo'; passed = $true; detail = "Git repo found, on branch $gitBranch"; category = 'required' }
    } else {
        $requiredChecks += [ordered]@{ name = 'git_repo'; passed = $false; detail = "Not in a git repository"; remediation = "cd into a git repository before running the workflow"; category = 'required' }
        $allPassed = $false
    }
} catch {
    $requiredChecks += [ordered]@{ name = 'git_repo'; passed = $false; detail = "git not available: $_"; remediation = "Install git and ensure it is in PATH"; category = 'required' }
    $allPassed = $false
}

# ── Required Check 3: ADO connectivity via twig ────────────────────────
try {
    $setOutput = twig set $WorkItemId 2>$null | Out-String
    if ($setOutput -match "#$WorkItemId\b") {
        $requiredChecks += [ordered]@{ name = 'ado_access'; passed = $true; detail = "ADO reachable, work item #$WorkItemId found"; category = 'required' }
    } else {
        $requiredChecks += [ordered]@{ name = 'ado_access'; passed = $false; detail = "twig set could not find work item #$WorkItemId"; remediation = "Run: twig sync"; category = 'required' }
        $allPassed = $false
    }
} catch {
    $requiredChecks += [ordered]@{ name = 'ado_access'; passed = $false; detail = "ADO unreachable: $_"; remediation = "Run: az login OR set TWIG_PAT"; category = 'required' }
    $allPassed = $false
}

# ── Output ──────────────────────────────────────────────────────────────
$failedCount = ($requiredChecks | Where-Object { -not $_.passed }).Count
$hasWarnings = $false

if ($allPassed) {
    $summary = "All preflight checks passed"
} else {
    $failedNames = ($requiredChecks | Where-Object { -not $_.passed } | ForEach-Object { $_.name }) -join ', '
    $summary = "Failed required: $failedNames"
}

[ordered]@{
    ready           = $allPassed
    has_warnings    = $hasWarnings
    required_checks = $requiredChecks
    advisory_checks = $advisoryChecks
    failed_count    = $failedCount
    warning_count   = 0
    summary         = $summary
} | ConvertTo-Json -Depth 3
