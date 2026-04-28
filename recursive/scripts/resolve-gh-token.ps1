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
    gh auth token *should* only read the local keyring, but it can still hang
    in non-TTY subprocess chains (credential helper deadlocks, GCM popups).
    All calls are wrapped with a 10-second timeout to prevent indefinite hangs.
#>

if ($env:GH_TOKEN) { return }

$env:GH_PROMPT_DISABLED = "1"

# Helper: run gh auth token with a timeout to prevent indefinite hangs.
# Returns the token string or $null if the call hangs or fails.
function _InvokeGhAuthToken {
    param([string[]]$GhArgs)
    try {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName = 'gh'
        foreach ($a in @('auth', 'token') + $GhArgs) { $psi.ArgumentList.Add($a) }
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.Environment['GH_PROMPT_DISABLED'] = '1'

        $proc = [System.Diagnostics.Process]::Start($psi)
        if ($proc.WaitForExit(10000)) {    # 10-second timeout
            if ($proc.ExitCode -eq 0) {
                $tok = $proc.StandardOutput.ReadToEnd().Trim()
                if ($tok) { return $tok }
            }
        } else {
            # Hung — kill it
            try { $proc.Kill() } catch {}
        }
    } catch {}
    return $null
}

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
    $_token = _InvokeGhAuthToken @('--user', $_ghUser)
}
if (-not $_token) {
    $_token = _InvokeGhAuthToken @()
}

if ($_token) {
    $env:GH_TOKEN = $_token
}

# Clean up temp variables and helper function (dot-sourced into caller's scope)
Remove-Variable -Name _ghUser, _remoteUrl, _token -ErrorAction SilentlyContinue
Remove-Item -Path Function:\_InvokeGhAuthToken -ErrorAction SilentlyContinue
