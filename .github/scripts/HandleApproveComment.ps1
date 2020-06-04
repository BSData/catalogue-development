[CmdletBinding()]
param (
  [Parameter(Mandatory, Position = 0)]
  [object]
  $Event,
  [Parameter(Mandatory)]
  [string]
  $Token
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/lib/GitHubActionsCore" -Force
$event = $env:EVENT_JSON | ConvertFrom-Json
$infoArgs = @{
  IssueTitle         = $Event.issue.title
  IssueBody          = $Event.issue.body
  IssueAuthor        = $Event.issue.user.login
  TargetOrganization = $Event.organization.login
}
$info = & "$PSScriptRoot/Get-NewRepoInfo.ps1" @infoArgs
if (-not $info.NameAvailable) {
  $errMessage = "Repository '$($info.RepositoryUrl)' already exists"
  Set-ActionOutput 'error' $errMessage
  Write-ActionError $errMessage
  exit 1
}
# install module for bsdatarepo creation
Install-Module PowerShellForGitHub -Force
$newRepoParams = @{
  RepositoryName = $info.RepositoryName
  Description    = $info.Description
  Collaborators  = $info.Collaborators
  AccessToken    = $Token
}
$result = & "$PSScriptRoot/New-BsdataRepo.ps1" @newRepoParams -Verbose
Set-ActionOutput 'url' $result.CreateRepo.html_url
