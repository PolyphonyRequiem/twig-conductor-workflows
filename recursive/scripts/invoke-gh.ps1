<#
.SYNOPSIS
    Invokes any gh CLI command with a per-attempt timeout and retry/backoff.

.DESCRIPTION
    Wraps gh CLI calls with the same timeout + retry pattern used for auth token
    resolution. Prevents any gh command from hanging indefinitely due to credential
    helper deadlocks, network stalls, or GCM popups in non-TTY environments.

    Dot-source this file, then call _InvokeGh with the gh arguments:
        . "$PSScriptRoot/invoke-gh.ps1"
        $json = _InvokeGh @('pr', 'list', '--repo', 'owner/repo', '--state', 'merged', '--json', 'number')

    Returns stdout as a string on success, or $null after all retries exhausted.

.NOTES
    - 10-second timeout per attempt (gh pr list typically completes in 1-3s)
    - Up to 5 retries with exponential backoff (1s, 2s, 4s, 8s, 10s cap)
    - GH_PROMPT_DISABLED=1 is always injected into the child environment
    - Ensure GH_TOKEN is set (via resolve-gh-token.ps1) before calling
#>

function _InvokeGh {
    param([string[]]$GhArgs)
    $maxAttempts = 5
    $baseDelay = 1  # seconds

    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        try {
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName = 'gh'
            foreach ($a in $GhArgs) { $psi.ArgumentList.Add($a) }
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            # Propagate auth token and disable prompts
            if ($env:GH_TOKEN) { $psi.Environment['GH_TOKEN'] = $env:GH_TOKEN }
            $psi.Environment['GH_PROMPT_DISABLED'] = '1'

            $proc = [System.Diagnostics.Process]::Start($psi)
            if ($proc.WaitForExit(10000)) {    # 10-second timeout
                $stdout = $proc.StandardOutput.ReadToEnd().Trim()
                if ($proc.ExitCode -eq 0 -and $stdout) {
                    return $stdout
                }
                # Non-zero exit or empty output — retry
            } else {
                # Hung — kill and retry
                try { $proc.Kill() } catch {}
            }
        } catch {}

        if ($attempt -lt $maxAttempts) {
            $delay = [math]::Min($baseDelay * [math]::Pow(2, $attempt - 1), 10)
            Start-Sleep -Milliseconds ([int]($delay * 1000))
        }
    }
    return $null
}
