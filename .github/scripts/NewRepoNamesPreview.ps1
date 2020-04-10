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
if ($info.NameAvailable)
{
    $commentFormat = Get-Content $PSScriptRoot/RepoInfoPreviewComment.md -Raw
} else {
    $commentFormat = Get-Content $PSScriptRoot/RepoExistsComment.md -Raw
}
$collaborators = "$($info.Collaborators | ForEach-Object { "@$_" } )"
$comment = $commentFormat -f $info.RepositoryName, $info.Description, $collaborators, $info.ExistingRepoUrl

# print the comment
Write-Verbose $comment

# post the comment
$bodyJson = @{
    'body' = $comment
} | ConvertTo-Json
$body = [System.Text.Encoding]::UTF8.GetBytes($bodyJson)
$restParams = @{
    Method      = 'Post'
    Uri         = $event.issue.comments_url
    Headers     = @{
        'Authorization' = "token $env:GITHUB_TOKEN"
    }
    ContentType = 'application/json; charset=utf-8'
    SkipHeaderValidation = $true
    Body        = $body
}
Invoke-RestMethod @restParams
