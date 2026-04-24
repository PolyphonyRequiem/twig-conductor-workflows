<#
.SYNOPSIS
    Assess child work item complexity to determine if it needs a plan document
    or just description enrichment.

.PARAMETER WorkItemId
    ADO work item ID of the child to assess.
#>
param(
    [Parameter(Mandatory = $true)]
    [int]$WorkItemId
)

$ErrorActionPreference = 'Stop'

twig set $WorkItemId --output json 2>$null | Out-Null
$treeJson = twig tree --depth 1 --output json 2>$null
$tree = $treeJson | ConvertFrom-Json

$focus = $tree.focus
$children = $tree.children
$taskCount = if ($children) { $children.Count } else { 0 }

# Threshold: >=3 tasks or complex type warrants a plan document
$needsPlan = $taskCount -ge 3

[ordered]@{
    work_item_id = $WorkItemId
    title        = $focus.title
    type         = $focus.type
    task_count   = $taskCount
    needs_plan   = $needsPlan
} | ConvertTo-Json
