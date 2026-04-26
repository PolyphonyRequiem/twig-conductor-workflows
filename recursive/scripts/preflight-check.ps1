<#
.SYNOPSIS
    Preflight check — validates external dependencies before SDLC workflow starts.
.DESCRIPTION
    Checks: gh auth, ADO connectivity, dotnet SDK, git status, gh repo permissions.
    Outputs JSON with pass/fail per check and an overall 'ready' boolean.
    Checks are classified as 'required' (block workflow) or 'advisory' (warn only).
    If any required check fails, ready=$false and the workflow routes to a human gate.
.PARAMETER WorkItemId
    Target work item ID (used to test ADO connectivity).
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
    $requiredChecks += [ordered]@{ name = 'gh_auth'; passed = $true; detail = "Logged in as $ghUser"; category = 'required' }
} catch {
    $requiredChecks += [ordered]@{ name = 'gh_auth'; passed = $false; detail = "gh auth failed: $_"; remediation = "Run: gh auth login"; category = 'required' }
    $allPassed = $false
}

# ── Required Check 2: gh repo push permission ──────────────────────────
try {
    $repoInfo = git remote get-url origin 2>$null
    if ($repoInfo -match 'github\.com[:/](.+?)(?:\.git)?$') {
        $repoSlug = $Matches[1]
        $pushAccess = gh api "repos/$repoSlug" --jq '.permissions.push' 2>$null
        if ($pushAccess -eq 'true') {
            $requiredChecks += [ordered]@{ name = 'gh_push'; passed = $true; detail = "Push access confirmed on $repoSlug"; category = 'required' }
        } else {
            $requiredChecks += [ordered]@{ name = 'gh_push'; passed = $false; detail = "No push access on $repoSlug (active account: $(gh api user --jq '.login' 2>$null))"; remediation = "Run: gh auth switch --user <owner>"; category = 'required' }
            $allPassed = $false
        }
    } else {
        $requiredChecks += [ordered]@{ name = 'gh_push'; passed = $false; detail = "Origin remote is not a GitHub URL — cannot verify push access"; remediation = "Ensure origin is a github.com remote or run: git remote set-url origin <github-url>"; category = 'required' }
        $allPassed = $false
    }
} catch {
    $requiredChecks += [ordered]@{ name = 'gh_push'; passed = $false; detail = "Could not check repo permissions: $_"; remediation = "Run: gh auth login && gh auth status"; category = 'required' }
    $allPassed = $false
}

# ── Required Check 3: ADO connectivity via twig ────────────────────────
try {
    twig sync --output json 2>$null | Out-Null
    # Just verify twig can reach ADO and the work item exists
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

# ── Required Check 4: twig state transition test ───────────────────────
try {
    # Just check that process config is available (don't actually transition)
    $stateResult = twig state --help 2>$null | Out-String
    if ($stateResult -match 'twig state') {
        $requiredChecks += [ordered]@{ name = 'twig_state'; passed = $true; detail = "twig state command available"; category = 'required' }
    } else {
        $requiredChecks += [ordered]@{ name = 'twig_state'; passed = $false; detail = "twig state output unrecognized"; remediation = "Run: ./publish-local.ps1"; category = 'required' }
        $allPassed = $false
    }
} catch {
    $requiredChecks += [ordered]@{ name = 'twig_state'; passed = $false; detail = "twig state not available: $_"; remediation = "Run: twig sync"; category = 'required' }
    $allPassed = $false
}

# ── Required Check 5: dotnet SDK ───────────────────────────────────────
try {
    $dotnetVersion = dotnet --version 2>$null
    $requiredChecks += [ordered]@{ name = 'dotnet_sdk'; passed = $true; detail = "dotnet $dotnetVersion"; category = 'required' }
} catch {
    $requiredChecks += [ordered]@{ name = 'dotnet_sdk'; passed = $false; detail = "dotnet SDK not found"; remediation = "Install .NET SDK"; category = 'required' }
    $allPassed = $false
}

# ── Required Check 6: git status ──────────────────────────────────────
try {
    $gitBranch = git branch --show-current 2>$null
    $requiredChecks += [ordered]@{ name = 'git_status'; passed = $true; detail = "On branch $gitBranch"; category = 'required' }
} catch {
    $requiredChecks += [ordered]@{ name = 'git_status'; passed = $false; detail = "git not available or not in a repo"; category = 'required' }
    $allPassed = $false
}

# ── Required Check 7: gh repo set-default (elevated from silent advisory) ──
try {
    if ($repoSlug) {
        gh repo set-default $repoSlug 2>$null | Out-Null
        $requiredChecks += [ordered]@{ name = 'gh_default_repo'; passed = $true; detail = "Set default repo to $repoSlug"; category = 'required' }
    } else {
        $requiredChecks += [ordered]@{ name = 'gh_default_repo'; passed = $false; detail = "Could not determine repo slug from git remote"; remediation = "Run: gh repo set-default <owner/repo>"; category = 'required' }
        $allPassed = $false
    }
} catch {
    $requiredChecks += [ordered]@{ name = 'gh_default_repo'; passed = $false; detail = "Could not set default repo"; remediation = "Run: gh repo set-default <owner/repo>"; category = 'required' }
    $allPassed = $false
}

# ── Advisory Check 1: conductor version ────────────────────────────────
try {
    $job = Start-Job -ScriptBlock { conductor --version 2>&1 | Out-String }
    $completed = $job | Wait-Job -Timeout 3
    if ($completed -and $completed.State -eq 'Completed') {
        $conductorVer = Receive-Job $job | Out-String
        $conductorVer = $conductorVer.Trim()
        $advisoryChecks += [ordered]@{ name = 'conductor_version'; passed = $true; detail = "conductor $conductorVer"; remediation = ""; category = 'advisory' }
    } else {
        $job | Stop-Job -ErrorAction SilentlyContinue
        $advisoryChecks += [ordered]@{ name = 'conductor_version'; passed = $false; detail = "Conductor not found — MCP server startup may fail"; remediation = "Install conductor CLI or add it to PATH"; category = 'advisory' }
    }
    $job | Remove-Job -Force -ErrorAction SilentlyContinue
} catch {
    $advisoryChecks += [ordered]@{ name = 'conductor_version'; passed = $false; detail = "Conductor not found — MCP server startup may fail"; remediation = "Install conductor CLI or add it to PATH"; category = 'advisory' }
}

# ── Advisory Check 2: twig-mcp binary ─────────────────────────────────
try {
    $twigMcp = Get-Command twig-mcp -ErrorAction SilentlyContinue
    if ($twigMcp) {
        $advisoryChecks += [ordered]@{ name = 'twig_mcp_binary'; passed = $true; detail = "twig-mcp found at $($twigMcp.Source)"; remediation = ""; category = 'advisory' }
    } else {
        $advisoryChecks += [ordered]@{ name = 'twig_mcp_binary'; passed = $false; detail = "twig-mcp binary not in PATH"; remediation = "Run: ./publish-local.ps1 to build and deploy twig-mcp"; category = 'advisory' }
    }
} catch {
    $advisoryChecks += [ordered]@{ name = 'twig_mcp_binary'; passed = $false; detail = "twig-mcp binary not in PATH"; remediation = "Run: ./publish-local.ps1 to build and deploy twig-mcp"; category = 'advisory' }
}

# ── Advisory Check 3: twig config directory ────────────────────────────
try {
    if (Test-Path '.twig/') {
        $advisoryChecks += [ordered]@{ name = 'twig_config'; passed = $true; detail = ".twig/ workspace directory found"; remediation = ""; category = 'advisory' }
    } else {
        $advisoryChecks += [ordered]@{ name = 'twig_config'; passed = $false; detail = "No .twig/ workspace directory found in current folder"; remediation = "Run: twig init OR clone a repo with .twig/ checked in"; category = 'advisory' }
    }
} catch {
    $advisoryChecks += [ordered]@{ name = 'twig_config'; passed = $false; detail = "No .twig/ workspace directory found in current folder"; remediation = "Run: twig init OR clone a repo with .twig/ checked in"; category = 'advisory' }
}

# ── Advisory Check 4: network — dev.azure.com ──────────────────────────
try {
    $adoResponse = Invoke-WebRequest -Method Head -Uri 'https://dev.azure.com' -TimeoutSec 3 -UseBasicParsing
    $advisoryChecks += [ordered]@{ name = 'network_ado'; passed = $true; detail = "dev.azure.com reachable (HTTP $($adoResponse.StatusCode))"; remediation = ""; category = 'advisory' }
} catch {
    $advisoryChecks += [ordered]@{ name = 'network_ado'; passed = $false; detail = "dev.azure.com unreachable"; remediation = "Check network connectivity and proxy settings"; category = 'advisory' }
}

# ── Advisory Check 5: network — github.com ─────────────────────────────
try {
    $ghResponse = Invoke-WebRequest -Method Head -Uri 'https://github.com' -TimeoutSec 3 -UseBasicParsing
    $advisoryChecks += [ordered]@{ name = 'network_github'; passed = $true; detail = "github.com reachable (HTTP $($ghResponse.StatusCode))"; remediation = ""; category = 'advisory' }
} catch {
    $advisoryChecks += [ordered]@{ name = 'network_github'; passed = $false; detail = "github.com unreachable"; remediation = "Check network connectivity and proxy settings"; category = 'advisory' }
}

# ── Output ──────────────────────────────────────────────────────────────
$allChecks = $requiredChecks + $advisoryChecks
$failedRequired = ($requiredChecks | Where-Object { -not $_.passed }).Count
$failedAdvisory = ($advisoryChecks | Where-Object { -not $_.passed }).Count
$hasWarnings = $failedAdvisory -gt 0

if ($allPassed -and -not $hasWarnings) {
    $summary = "All preflight checks passed"
} elseif ($allPassed -and $hasWarnings) {
    $summary = "All required checks passed. $failedAdvisory advisory warning$(if ($failedAdvisory -ne 1) { 's' })."
} else {
    $failedNames = ($requiredChecks | Where-Object { -not $_.passed } | ForEach-Object { $_.name }) -join ', '
    $summary = "Failed required: $failedNames"
    if ($hasWarnings) {
        $summary += ". $failedAdvisory advisory warning$(if ($failedAdvisory -ne 1) { 's' })."
    }
}

[ordered]@{
    ready           = $allPassed
    has_warnings    = $hasWarnings
    required_checks = $requiredChecks
    advisory_checks = $advisoryChecks
    checks          = $allChecks
    failed_count    = $failedRequired
    warning_count   = $failedAdvisory
    summary         = $summary
} | ConvertTo-Json -Depth 3
