#!/usr/bin/env pwsh

# This script should only be run with the following variable set:
# $env:GITHUB_EVENT_PATH (set in Actions by default)

[CmdletBinding()] param()

$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json
$description = $event.issue.title -replace "^New Repo: "
$body_first_line = $event.issue.body -split "`n" | Where-Object {$_} | Select-Object -First 1
$name_match = "^(name|tag|url): "
if ($body_first_line -match $name_match)
{
    $name = $body_first_line -replace $name_match
}
else
{
    $name = $description
}
$name = $name.ToLowerInvariant() -replace "[^a-z0-9]+", '-'
$collaborators = @($event.issue.user.login)
# TODO support adding more collaborators via OP tag like "collaborators: @login1 @login2 ..."
$comment = (
    "**Repository name:** ``$name``",
    "**Repository description:** ``$description``",
    "**Collaborators to invite:** ``$( $collaborators | ForEach-Object { "@$_" } )``",
    "",
    "If you'd like to change either of these:",
    "* _description_ is taken from the issue title, skipping 'New Repo: ' prefix - to change, edit issue title.",
    "* _name_ is taken from the first line of the issue body if it starts with 'name: ' prefix, or if it doesn't," +
    " by normalizing the _description_ with some simple regex. To change, add a first line in format" +
    " ``name: example-repo-name`` in the issue body.",
    "",
    "Comment ``.preview`` to re-check, ``.approve`` (owner only) to create the new repository as shown above."
    ) -join "`n"
return @{
    RepositoryName = $name
    Description = $description
    PreviewComment = $comment
    Collaborators = $collaborators
}
