#!/usr/bin/env pwsh

# This script should only be run by Actions with the following variables set:
# $env:GITHUB_EVENT_PATH (set in Actions by default)
# $env:GITHUB_TOKEN

$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json
$description = $event.issue.title -replace "^New Repo: "
$name = $description.ToLowerInvariant() -replace "[^a-z0-9]+", '-'
$body_first_line = $event.issue.body -split "`n" | ? {$_} | select -first 1
$name_match = "^(name|tag|url): "
if ($body_first_line -match $name_match) {
  $name = $body_first_line -replace $name_match
}
$comment = (
  "**Repository name:** ``$name``",
  "**Repository description:** ``$description``"
  ) -join "`n"
Write-Output $comment
$restParams = @{
  Method = 'Post'
  Uri = $event.issue.comments_url
  Headers = @{
    'Authorization' = "token $env:GITHUB_TOKEN"
  }
  ContentType = 'application/json'
  Body = @{
    'body' = $comment
  } | ConvertTo-Json
}
Invoke-RestMethod @restParams
