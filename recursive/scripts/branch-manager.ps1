<#
.SYNOPSIS
    Creates or rebases a feature branch for a PR group.

.DESCRIPTION
    Stacked-PR branch management. If the branch doesn't exist, creates it
    from latest main. If it already exists (PG-2+ after PG-1 merged),
    rebases it onto updated main so the coder works against current code.

    Safety: only rebases when the branch is behind origin/main AND the
    worktree is clean. Skips rebase if already up-to-date.

.PARAMETER BranchName
    The branch name to create or rebase (e.g., "feature/2151-pg-2").
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$BranchName)

$ErrorActionPreference = 'Stop'

function Assert-CleanGitState {
    # Ensure no in-progress rebase or merge
    if (Test-Path ".git/rebase-merge") { git rebase --abort *>$null 2>&1 }
    if (Test-Path ".git/rebase-apply") { git rebase --abort *>$null 2>&1 }
    if (Test-Path ".git/MERGE_HEAD")   { git merge --abort *>$null 2>&1 }
}

try {
    Assert-CleanGitState

    # Fetch latest main and the target branch
    git fetch origin main *>$null 2>&1
    git fetch origin $BranchName *>$null 2>&1

    # Check if branch already exists (local or remote)
    $localExists = (git branch --list $BranchName 2>$null) -match $BranchName
    $remoteExists = (git branch -r --list "origin/$BranchName" 2>$null) -match "origin/$BranchName"

    if ($localExists -or $remoteExists) {
        # ── REBASE PATH: branch exists from prior PG cycle or earlier run ──
        if (-not $localExists) {
            git checkout -b $BranchName "origin/$BranchName" *>$null 2>&1
        } else {
            git checkout $BranchName *>$null 2>&1
            # Sync with remote if it exists
            if ($remoteExists) { git reset --hard "origin/$BranchName" *>$null 2>&1 }
        }

        # Check if rebase is actually needed
        $behind = (git rev-list --count "HEAD..origin/main" 2>$null) ?? '0'
        if ([int]$behind -eq 0) {
            # Already up-to-date with main — no rebase needed
            [ordered]@{
                branch_name = $BranchName
                created = $false
                rebased = $false
                rebase_strategy = 'up-to-date'
                base = 'main'
            } | ConvertTo-Json
            exit 0
        }

        # Check for dirty worktree — don't rebase if uncommitted changes exist
        $dirty = git status --porcelain 2>$null
        if ($dirty) {
            [ordered]@{
                error = "Worktree has uncommitted changes — cannot rebase safely"
                branch_name = $BranchName
                created = $false
                rebased = $false
                dirty = $true
            } | ConvertTo-Json
            exit 1
        }

        # Attempt rebase
        $rebaseOutput = git rebase origin/main 2>&1
        $rebaseExit = $LASTEXITCODE

        if ($rebaseExit -ne 0) {
            # Rebase conflict — abort cleanly
            git rebase --abort *>$null 2>&1
            Assert-CleanGitState

            # Fall back to merge
            $mergeOutput = git merge origin/main --no-edit 2>&1
            $mergeExit = $LASTEXITCODE

            if ($mergeExit -ne 0) {
                # Merge also failed — clean up and report
                git merge --abort *>$null 2>&1
                Assert-CleanGitState

                [ordered]@{
                    error = "Both rebase and merge from main failed — manual conflict resolution needed"
                    branch_name = $BranchName
                    created = $false
                    rebased = $false
                    conflict = $true
                } | ConvertTo-Json
                exit 1
            }

            # Merge succeeded — force push the updated branch
            git push --force-with-lease origin $BranchName *>$null 2>&1

            [ordered]@{
                branch_name = $BranchName
                created = $false
                rebased = $true
                rebase_strategy = 'merge'
                base = 'main'
            } | ConvertTo-Json
        } else {
            # Clean rebase — force push the rebased branch
            git push --force-with-lease origin $BranchName *>$null 2>&1

            [ordered]@{
                branch_name = $BranchName
                created = $false
                rebased = $true
                rebase_strategy = 'rebase'
                base = 'main'
            } | ConvertTo-Json
        }
    } else {
        # ── CREATE PATH: new branch from latest main ──
        git checkout origin/main *>$null 2>&1
        git checkout -b $BranchName *>$null 2>&1
        git push -u origin $BranchName *>$null 2>&1

        [ordered]@{
            branch_name = $BranchName
            created = $true
            rebased = $false
            base = 'main'
        } | ConvertTo-Json
    }
}
catch {
    Assert-CleanGitState
    [ordered]@{
        error = $_.Exception.Message
        branch_name = $BranchName
        created = $false
        rebased = $false
    } | ConvertTo-Json
    exit 1
}
