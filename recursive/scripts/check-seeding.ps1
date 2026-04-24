<#
.SYNOPSIS
    Idempotency check: are child work items already seeded for this work item?
.PARAMETER WorkItemId
    ADO work item ID to check.
#>
param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId
)

$ErrorActionPreference = 'Stop'

twig set $WorkItemId --output json 2>$null | Out-Null
$treeJson = twig tree --depth 1 --output json 2>$null
$tree = $treeJson | ConvertFrom-Json

$children = $tree.children
$childCount = if ($children) { $children.Count } else { 0 }
$seeded = $childCount -gt 0

$doneCount = if ($children) { ($children | Where-Object { $_.state -eq 'Done' }).Count } else { 0 }
$doingCount = if ($children) { ($children | Where-Object { $_.state -eq 'Doing' }).Count } else { 0 }
$todoCount = if ($children) { ($children | Where-Object { $_.state -eq 'To Do' }).Count } else { 0 }

[ordered]@{
    seeded           = $seeded
    child_count      = $childCount
    children_summary = [ordered]@{
        total = $childCount
        done  = $doneCount
        doing = $doingCount
        todo  = $todoCount
    }
} | ConvertTo-Json -Depth 3
