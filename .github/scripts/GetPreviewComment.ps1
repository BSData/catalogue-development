[CmdletBinding()]
param (
  [Parameter(Mandatory, Position = 0)]
  [object]
  $Event
)

$ErrorActionPreference = 'Stop'
Import-Module "$PSScriptRoot/lib/GitHubActionsCore" -Force
$infoArgs = @{
  IssueTitle         = $Event.issue.title
  IssueBody          = $Event.issue.body
  IssueAuthor        = $Event.issue.user.login
  TargetOrganization = $Event.organization.login
}
$info = & "$PSScriptRoot/Get-NewRepoInfo.ps1" @infoArgs
# format the comment
if ($info.NameAvailable) {
  $commentFormat = Get-Content "$PSScriptRoot/RepoInfoPreviewComment.md" -Raw
}
else {
  $commentFormat = Get-Content "$PSScriptRoot/RepoExistsComment.md" -Raw
}
$collaborators = "$($info.Collaborators | ForEach-Object { "@$_" } )"
$comment = $commentFormat -f $info.RepositoryName, $info.Description, $collaborators, $info.RepositoryUrl
Set-ActionOutput 'comment' $comment