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

Write-Verbose "Processing parameters"
# disable telemetry for CI
Set-GitHubConfiguration -DisableTelemetry
# defaulting description from name
if ([string]::IsNullOrWhiteSpace($Description)) {
    $Description = $RepositoryName
}
$sanitizedName = $RepositoryName.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
if ($sanitizedName -cne $RepositoryName) {
    Write-Warning "Sanitized RepositoryName: '$RepositoryName' -> '$sanitizedName'"
    $RepositoryName = $sanitizedName
}
$authParams = @{
    AccessToken = $AccessToken
}
$repoParams = @{
    OwnerName      = $OwnerName
    RepositoryName = $RepositoryName
}
$homepage = "http://battlescribedata.appspot.com/#/repo/$RepositoryName"

Write-Verbose "Starting operations."
$result = @{}

$newRepoParams = @{
    OwnerName            = $OwnerName
    RepositoryName       = "TemplateDataRepo"
    TargetOwnerName      = $OwnerName
    TargetRepositoryName = $RepositoryName
    Description          = $Description
}
$repo = New-GitHubRepositoryFromTemplate @newRepoParams @authParams
$result['CreateRepo'] = $repo
Write-Verbose "Repo created at $($repo.html_url)"

Write-Verbose "Waiting 10s to give GitHub some time to apply template..."
Start-Sleep -Seconds 10 -Verbose

$result['SecureRepo'] = . {
    $defaultBranch = ($repo | Get-GitHubRepository @authParams).default_branch
    $protectParams = @{
        Method      = 'PUT'
        UriFragment = "repos/$OwnerName/$RepositoryName/branches/$defaultBranch/protection"
        Body        = @{
            enforce_admins                = $true
            required_status_checks        = $null
            required_pull_request_reviews = $null
            restrictions                  = $null
        } | ConvertTo-Json
    }
    Write-Verbose "Setting up protection on '$defaultBranch'..."
    Invoke-GHRestMethod @protectParams @authParams
}
Write-Verbose "Security rules applied"

$result['UpdateHomepage'] = $repo | Update-GitHubRepository @authParams -Homepage $homepage
Write-Verbose "Homepage updated to $homepage"


$topicsResponse = $repo | Get-GitHubRepositoryTopic @authParams
$topics = @($topicsResponse.names, "battlescribe-data") | Where-Object { $_ }
| Set-GitHubRepositoryTopic @repoParams @authParams -PassThru
$result['UpdateTopics'] = $topics
Write-Verbose "Topics set to $($topics.names)"

$result['UpdateReadme'] = . {
    # https://developer.github.com/v3/repos/contents/#get-the-readme
    $getReadmeParams = @{
        Method      = 'GET'
        UriFragment = "repos/$OwnerName/$RepositoryName/readme"
    }
    $getReadmeResult = Invoke-GHRestMethod @getReadmeParams @authParams
    if ($getReadmeResult.encoding -ne 'base64') {
        Write-Warning "Unknown readme content encoding: $($getReadmeResult.encoding)"
        return "Unknown encoding"
    }
    $readme = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($getReadmeResult.content))
    $readmePatched = $readme.Replace('TemplateDataRepo', $RepositoryName).Replace('Template Data Repo', $Description)
    if ($readme -ceq $readmePatched) {
        return "Skipped"
    }
    $updateReadmeParams = @{
        Method      = 'PUT'
        UriFragment = "repos/$OwnerName/$RepositoryName/contents/" + $getReadmeResult.path
        Body        = ConvertTo-Json @{
            'message' = "docs: Replace template values in README"
            'sha'     = $getReadmeResult.sha
            'content' = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($readmePatched))
        }
    }
    Invoke-GHRestMethod @updateReadmeParams @authParams
}
Write-Verbose "Readme updated"

if (-not $KeepCreator -and $env:GITHUB_ACTOR) {
    $login = $env:GITHUB_ACTOR
    $uri = "/repos/$OwnerName/$RepositoryName/collaborators/$login"
    $result["RemoveCreator"] = Invoke-GHRestMethod -UriFragment $uri -Method Delete @authParams
    Write-Verbose "Collaborator removed: $login"
}
$Collaborators
| ForEach-Object { $_ -replace "^@" }
| Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
| ForEach-Object {
    $login = $_
    $uri = "/repos/$OwnerName/$RepositoryName/collaborators/$login"
    $result["Invite-$login"] = Invoke-GHRestMethod -UriFragment $uri -Method Put @authParams
    Write-Verbose "Collaborator added: $login"
}
return $result
