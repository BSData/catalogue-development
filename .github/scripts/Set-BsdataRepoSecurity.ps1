#!/usr/bin/env pwsh

# This script requires PowerShellForGitHub module. Install using "Install-Module PowerShellForGitHub".

[CmdletBinding(SupportsShouldProcess)]
param (
    # Repo name
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $RepositoryName,
    # Owner name
    [string] $OwnerName = "BSData",
    # Branch name to protect
    [string] $Branch = "master",
    # GitHub API access token
    [string] $AccessToken
)

$authParams = @{
    AccessToken = $AccessToken
}

# check if $Branch branch is protected
# https://developer.github.com/v3/repos/branches/#get-branch
$masterInfo = Get-GitHubRepositoryBranch -OwnerName $OwnerName -RepositoryName $RepositoryName -Name $Branch @authParams
if ($masterInfo.protected -eq $false) {
    # if it's not, add protection and enforce on admins
    # https://developer.github.com/v3/repos/branches/#update-branch-protection
    $protectionParams = @{
        Method = "PUT"
        UriFragment = "/repos/$OwnerName/$RepositoryName/branches/$Branch/protection"
        Body = @{
            required_status_checks = $null
            enforce_admins = $true
            required_pull_request_reviews = $null
            restrictions = $null
        } | ConvertTo-Json
    }
    $protectionResult = Invoke-GHRestMethod @protectionParams @authParams
}
else {
    # if it's protected, assert that it's enforced on admins
    # https://developer.github.com/v3/repos/branches/#add-admin-enforcement-of-protected-branch
    $protectionParams = @{
        Method = "POST"
        UriFragment = "/repos/$OwnerName/$RepositoryName/branches/$Branch/protection/enforce_admins"
    }
    $protectionResult = Invoke-GHRestMethod @protectionParams @authParams
}
return $protectionResult
