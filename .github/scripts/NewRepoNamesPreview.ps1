#!/usr/bin/env pwsh

# This script should only be run by Actions with the following variables set:
# $env:GITHUB_EVENT_PATH (set in Actions by default)
# $env:GITHUB_TOKEN

$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json
$info = & "$PSScriptRoot/Get-NewRepoInfo.ps1"
Write-Output $info.PreviewComment
$restParams = @{
  Method = 'Post'
  Uri = $event.issue.comments_url
  Headers = @{
    'Authorization' = "token $env:GITHUB_TOKEN"
  }
  ContentType = 'application/json'
  Body = @{
    'body' = $info.PreviewComment
  } | ConvertTo-Json
}
Invoke-RestMethod @restParams
