[CmdletBinding()]
[OutputType([string])]
param (
  [Parameter(Mandatory, Position = 0)]
  [object] $EventPayload
)

$infoArgs = @{
  IssueTitle         = $EventPayload.issue.title
  IssueBody          = $EventPayload.issue.body
  IssueAuthor        = $EventPayload.issue.user.login
  TargetOrganization = $EventPayload.organization.login
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
return $comment