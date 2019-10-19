#!/usr/bin/env pwsh

# This script requires PowerShellForGitHub module. Install using "Install-Module PowerShellForGitHub".

[CmdletBinding(SupportsShouldProcess)]
param (
    # Repo name
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $RepositoryName,
    # Owner name
    [string] $OwnerName = 'BSData',
    # Repo description
    [string] $Description = $RepositoryName,
    # Keep $env:GITHUB_ACTOR as collaborator (by default is removed)
    [switch] $KeepCreator,
    # List of collaborators to invite
    [string[]] $Collaborators,
    # GitHub API access token
    [string] $AccessToken
)

function CreateRepo {
    [CmdletBinding(SupportsShouldProcess)] param()
    # https://developer.github.com/v3/repos/#create-repository-using-a-repository-template
    $repotemplateAcceptHeader = 'application/vnd.github.baptiste-preview+json'
    $generateParams = @{
        Method = 'POST'
        UriFragment = "/repos/$OwnerName/TemplateDataRepo/generate"
        AcceptHeader = $repotemplateAcceptHeader
        Body = @{
            owner = $OwnerName
            name = $RepositoryName
            description = $Description
        } | ConvertTo-Json
    }
    Invoke-GHRestMethod @generateParams @authParams
}
function UpdateTopics {
    [CmdletBinding(SupportsShouldProcess)] param()
    # https://developer.github.com/v3/repos/#list-all-topics-for-a-repository
    # https://developer.github.com/v3/repos/#replace-all-topics-for-a-repository
    $getTopicsResult = Get-GitHubRepositoryTopic @repoParams @authParams
    $topics = @($getTopicsResult.names, "battlescribe-data") | Where-Object { $_ }
    Set-GitHubRepositoryTopic -Name $topics @repoParams @authParams
}
function UpdateReadme {
    [CmdletBinding(SupportsShouldProcess)] param()
    # https://developer.github.com/v3/repos/contents/#get-the-readme
    $getReadmeParams = @{
        Method = 'GET'
        UriFragment = "/repos/$OwnerName/$RepositoryName/readme"
    }
    $getReadmeResult = Invoke-GHRestMethod @getReadmeParams @authParams
    if ($getReadmeResult.encoding -ne 'base64') {
        Write-Warning "Unknown readme content encoding: $($getReadmeResult.encoding)"
        return "Unknown encoding"
    }
    $readmePath = $getReadmeResult.path
    $readme = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($getReadmeResult.content))
    $readmePatched = $readme.Replace('TemplateDataRepo', $RepositoryName).Replace('Template Data Repo', $Description)
    if ($readme -ceq $readmePatched) {
        return "Skipped"
    }
    $base64Patched = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($readmePatched))
    # https://developer.github.com/v3/repos/contents/#create-or-update-a-file
    $setReadmeParams = @{
        Method = 'PUT'
        UriFragment = "/repos/$OwnerName/$RepositoryName/contents/$readmePath"
        Body = @{
            'message' = "docs: Replace template values in $readmePath"
            'content' = $base64Patched
            'sha' = $getReadmeResult.sha
        } | ConvertTo-Json
    }
    Invoke-GHRestMethod @setReadmeParams @authParams
}

Write-Verbose "Processing parameters"
# defaulting description from name
if ([string]::IsNullOrWhiteSpace($Description))
{
    $Description = $RepositoryName
}
$sanitizedName = $RepositoryName.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
if ($sanitizedName -ne $RepositoryName)
{
    Write-Warning "Sanitized RepositoryName: '$RepositoryName' -> '$sanitizedName'"
    $RepositoryName = $sanitizedName
}
$authParams = @{
    AccessToken = $AccessToken
}
$repoParams = @{
    OwnerName = 'BSData'
    RepositoryName = $RepositoryName
}
$homepage = "http://battlescribedata.appspot.com/#/repo/$RepositoryName"

Write-Verbose "Starting operations."
$result = @{}
$result['CreateRepo'] = CreateRepo
Write-Verbose "Repo created at $($result.CreateRepo.html_url)"

$result['SecureRepo'] = & "$PSScriptRoot/Set-BsdataRepoSecurity.ps1" @repoParams @authParams
Write-Verbose "Security rules applied"

$result['UpdateHomepage'] = Update-GitHubRepository @repoParams @authParams -Homepage $homepage
Write-Verbose "Homepage updated to $homepage"

$result['UpdateTopics'] = UpdateTopics
Write-Verbose "Topics set to $($result.UpdateTopics.names)"

$result['UpdateReadme'] = UpdateReadme
Write-Verbose "Readme updated"

if (-not $KeepCreator -and $env:GITHUB_ACTOR)
{
    $login = $env:GITHUB_ACTOR
    $uri = "/repos/$OwnerName/$RepositoryName/collaborators/$login"
    $result["RemoveCreator"] = Invoke-GHRestMethod -UriFragment $uri -Method Delete @authParams
    Write-Verbose "Collaborator removed: $login"
}
$Collaborators |
    ForEach-Object { $_ -replace "^@" } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object {
        $login = $_
        $uri = "/repos/$OwnerName/$RepositoryName/collaborators/$login"
        $result["Invite-$login"] = Invoke-GHRestMethod -UriFragment $uri -Method Put @authParams
        Write-Verbose "Collaborator added: $login"
}
return $result
