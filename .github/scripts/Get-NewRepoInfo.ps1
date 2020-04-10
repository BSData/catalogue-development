#!/usr/bin/env pwsh

# This script should only be run with the following variable set:
# $env:GITHUB_EVENT_PATH (set in Actions by default)

[CmdletBinding()] param()

$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json
$description = ($event.issue.title -replace "^New Repo:\s?").Trim()
$body_first_line = $event.issue.body -split "`n" | Where-Object {$_} | Select-Object -First 1
$name_match = "^(name|tag|url):\s?"
if ($body_first_line -match $name_match)
{
    $name = ($body_first_line.Trim() -replace $name_match).Trim()
}
else
{
    $name = $description
}
$name = ($name.ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')
$collaborators = @($event.issue.user.login)
# TODO support adding more collaborators via OP tag like "collaborators: @login1 @login2 ..."
$commentFormat = Get-Content $PSScriptRoot/newrepoinfo.md
$comment = $commentFormat -f $name, $description, "$($collaborators | ForEach-Object { "@$_" } )"
return @{
    RepositoryName = $name
    Description = $description
    PreviewComment = $comment
    Collaborators = $collaborators
}
