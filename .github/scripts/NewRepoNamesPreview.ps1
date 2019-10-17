#!/usr/bin/env pwsh

# This script should only be run by Actions with the following variables set:
# $env:GITHUB_EVENT_PATH (set in Actions by default)
# $env:GH_TOKEN (can't use GITHUB prefix: https://help.github.com/en/articles/virtual-environments-for-github-actions#naming-conventions)

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
  "**First collaborator to invite:** ``@$($event.issue.user.login)``"
  ""
  "If you'd like to change either of these:"
  "* _description_ is taken from the issue title, skipping 'New Repo: ' prefix - to change, edit issue title."
  "* _name_ is taken from the first line of the issue body if it starts with 'name: ' prefix, or if it doesn't," +
  " by normalizing the _description_ with some simple regex. To change, add a first line in format" +
  " ``name: example-repo-name`` in the issue body."
  ""
  "Comment ``.preview`` to re-check."
  ) -join "`n"
Write-Output $comment
$restParams = @{
  Method = 'Post'
  Uri = $event.issue.comments_url
  Headers = @{
    'Authorization' = "token $env:GH_TOKEN"
  }
  ContentType = 'application/json'
  Body = @{
    'body' = $comment
  } | ConvertTo-Json
}
Invoke-RestMethod @restParams
