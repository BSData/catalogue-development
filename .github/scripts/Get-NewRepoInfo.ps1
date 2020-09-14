#!/usr/bin/env pwsh

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string] $IssueTitle,
    
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string] $IssueBody,

    [Parameter(Mandatory)]
    [string] $IssueAuthor,

    [Parameter()]
    [string] $TargetOrganization = 'BSData'
)

# get description from issue title
$description = ($IssueTitle -replace "^New Repo:\s?").Trim()

# get first line of issue body
$body_first_line = $IssueBody -split "`n" | Where-Object { $_ } | Select-Object -First 1

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
    Uri    = "https://github.com/" + $TargetOrganization + "/$name"
}
if ($PSCmdlet.ShouldProcess('GET ' + $repoCheckParams.Uri)) {
    Invoke-RestMethod @repoCheckParams -SkipHttpErrorCheck -StatusCodeVariable repoCheckStatus | Out-Null
    Write-Host ($repoCheckParams.Uri + " returned HTTP $repoCheckStatus")
}

# TODO support adding more collaborators via OP tag like "collaborators: @login1 @login2 ..."
return @{
    RepositoryName = $name
    Description    = $description
    Collaborators  = @($IssueAuthor)
    NameAvailable  = $repoCheckStatus -eq 404
    RepositoryUrl  = $repoCheckParams.Uri
}
