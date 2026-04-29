<#
.SYNOPSIS
    Enumerate direct children of a work item with their task counts.
    Used by task-decomposition.yaml to build the for_each source array.

.DESCRIPTION
    For each non-Done child, checks grandchildren (Tasks) from tree data.
    Outputs JSON: { children: [ { id, title, type, task_count } ] }

.PARAMETER WorkItemId
    Root work item ID whose children to enumerate.
#>
param(
    [Parameter(Mandatory)]
    [int]$WorkItemId
)

$ErrorActionPreference = 'Stop'

twig set $WorkItemId --output json 2>$null | Out-Null
$treeJson = twig tree --depth 2 --output json 2>$null
$tree = $treeJson | ConvertFrom-Json

$children = @()
foreach ($child in $tree.children) {
    # Skip Done children — they don't need task decomposition
    if ($child.state -eq 'Done') { continue }

    $taskCount = if ($child.children) { $child.children.Count } else { 0 }

    $children += @{
        id         = $child.id
        title      = $child.title
        type       = $child.type
        task_count = $taskCount
    }
}

@{ children = $children } | ConvertTo-Json -Depth 3
