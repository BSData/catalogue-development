[CmdletBinding()]
param (
  [Parameter(Mandatory, Position = 0)]
  [object] $EventPayload,

  [Parameter(Mandatory)]
  [string] $Token
)

$infoArgs = @{
  IssueTitle         = $EventPayload.issue.title
  IssueBody          = $EventPayload.issue.body
  IssueAuthor        = $EventPayload.issue.user.login
  TargetOrganization = $EventPayload.organization.login
}
$info = & "$PSScriptRoot/Get-NewRepoInfo.ps1" @infoArgs
if (-not $info.NameAvailable) {
  throw "Repository '$($info.RepositoryUrl)' already exists"
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
return $result.CreateRepo
