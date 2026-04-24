<#
.SYNOPSIS
    Post-merge regression testing. Runs full test suite on main after PR merge.

.PARAMETER BuildConfig
    Build configuration (default: Release).
#>
param(
    [string]$BuildConfig = 'Release'
)

$ErrorActionPreference = 'Stop'

# Ensure we're on main with latest
git checkout main 2>$null
git pull --ff-only 2>$null

# Build
$buildResult = dotnet build --configuration $BuildConfig --no-restore 2>&1
$buildSuccess = $LASTEXITCODE -eq 0

if (-not $buildSuccess) {
    [ordered]@{
        passed       = $false
        phase        = 'build'
        error        = ($buildResult | Select-Object -Last 20) -join "`n"
        test_count   = 0
        failed_count = 0
    } | ConvertTo-Json -Depth 3
    return
}

# Test
$testResult = dotnet test --configuration $BuildConfig --no-build --logger "console;verbosity=minimal" 2>&1
$testSuccess = $LASTEXITCODE -eq 0

# Parse test counts from output
$totalMatch = [regex]::Match(($testResult -join "`n"), 'Total tests:\s*(\d+)')
$failedMatch = [regex]::Match(($testResult -join "`n"), 'Failed:\s*(\d+)')
$testCount = if ($totalMatch.Success) { [int]$totalMatch.Groups[1].Value } else { 0 }
$failedCount = if ($failedMatch.Success) { [int]$failedMatch.Groups[1].Value } else { 0 }

[ordered]@{
    passed       = $testSuccess
    phase        = 'test'
    error        = if (-not $testSuccess) { ($testResult | Select-Object -Last 20) -join "`n" } else { '' }
    test_count   = $testCount
    failed_count = $failedCount
} | ConvertTo-Json -Depth 3
