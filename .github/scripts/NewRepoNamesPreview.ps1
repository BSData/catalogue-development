#!/usr/bin/env pwsh

# This script should only be run by Actions with the following variables set:
# $env:GITHUB_EVENT_PATH (set in Actions by default)
# $env:GITHUB_TOKEN

[CmdletBinding()] param()

# read event
$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json

# get repo info from issue
$info = & "$PSScriptRoot/Get-NewRepoInfo.ps1"

# format the comment
$commentFormat = Get-Content $PSScriptRoot/newrepoinfo.md -Raw
$comment = $commentFormat -f $info.RepositoryName, $info.Description, "$($info.Collaborators | ForEach-Object { "@$_" } )"
if (!$info.NameAvailable) {
    $commentPrefix = "> ⚠ Repository with this name already exists: " + $info.ExistingRepoUrl + "`n"
    $commentPrefix += "> `n"
    $commentPrefix += "> Please select a **different name**, or contact maintainers of the existing repository.`n"
    $commentPrefix += "`n"
    $comment = $commentPrefix + $comment
}

# print the comment
Write-Verbose $comment

# post the comment
$restParams = @{
    Method      = 'Post'
    Uri         = $event.issue.comments_url
    Headers     = @{
        'Authorization' = "token $env:GITHUB_TOKEN"
    }
    ContentType = 'application/json'
    Body        = @{
        'body' = $comment
    } | ConvertTo-Json
}
Invoke-RestMethod @restParams
