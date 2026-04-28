<#
.SYNOPSIS
    Resolves a GitHub token and sets $env:GH_TOKEN to bypass the credential
    helper chain (gh → git → GCM) that can deadlock in non-TTY environments.

.DESCRIPTION
    Resolution order:
      1. If GH_TOKEN is already set, do nothing (caller or CI provided it).
      2. If GH_CONDUCTOR_USER is set, use that as the --user for gh auth token.
      3. Derive the repo owner from git remote origin and try --user <owner>.
      4. Fall back to plain gh auth token (active account).

    Dot-source this file at the top of any script that calls gh CLI:
        . "$PSScriptRoot/resolve-gh-token.ps1"

.NOTES
    gh auth token reads from the local keyring — no network call, no git,
    no credential manager. It is safe to call in non-TTY subprocess chains.
#>

if ($env:GH_TOKEN) { return }

$env:GH_PROMPT_DISABLED = "1"

# 1. Explicit user override
$_ghUser = $env:GH_CONDUCTOR_USER

# 2. Derive from repo remote owner
if (-not $_ghUser) {
    $_remoteUrl = (git remote get-url origin 2>$null) ?? ''
    if ($_remoteUrl -match 'github\.com[:/]([^/]+)/') {
        $_ghUser = $Matches[1]
    }
}

# 3. Try user-specific token, then fall back to active account
$_token = $null
if ($_ghUser) {
    $_token = (gh auth token --user $_ghUser 2>$null) ?? $null
}
if (-not $_token) {
    $_token = (gh auth token 2>$null) ?? $null
}

if ($_token) {
    $env:GH_TOKEN = $_token
}

# Clean up temp variables (dot-sourced into caller's scope)
Remove-Variable -Name _ghUser, _remoteUrl, _token -ErrorAction SilentlyContinue
