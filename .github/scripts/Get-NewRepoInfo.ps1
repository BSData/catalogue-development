#!/usr/bin/env pwsh

# This script should only be run with the following variable set:
# $env:GITHUB_EVENT_PATH (set in Actions by default)

[CmdletBinding()] param()

# read GitHub Actions event
$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json

# get description from issue title
$description = ($event.issue.title -replace "^New Repo:\s?").Trim()

# get first line of issue body
$body_first_line = $event.issue.body -split "`n" | Where-Object { $_ } | Select-Object -First 1

# if first line starts with "name: " we use the following text, otherwise we use description for repo name
$name_match = "^(name|tag|url):\s?"
if ($body_first_line -match $name_match) {
    $name = ($body_first_line.Trim() -replace $name_match).Trim()
}
else {
    $name = $description
}
# normalize repo name: lower-case, only a-z, '-' and 0-9 characters (and no leading/trailing '-')
$name = ($name.ToLowerInvariant() -replace "[^a-z0-9]+", '-').Trim('-')

# check whether repo name is available:
$repoCheckParams = @{
    Method = 'Get'
    Uri    = "https://api.github.com/repos/" + $event.organization.login + "/$name"
}
$repoObject = Invoke-RestMethod @repoCheckParams -SkipHttpErrorCheck -StatusCodeVariable repoCheckStatus
$repoNameAvailable = $repoCheckStatus -ne 200
$existingUrl = $repoObject.html_url

# collaborators to be invited
$collaborators = @($event.issue.user.login)
# TODO support adding more collaborators via OP tag like "collaborators: @login1 @login2 ..."
return @{
    RepositoryName  = $name
    Description     = $description
    Collaborators   = $collaborators
    NameAvailable   = $repoNameAvailable
    ExistingRepoUrl = $existingUrl
}
