#!/usr/bin/env pwsh

# This script uses the following env variables:
# - GITHUB_EVENT_PATH
# - GITHUB_ACTOR
# - CREATE_REPO_TOKEN

$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json
$author = $env:GITHUB_ACTOR

# check whether comment author is org owner
$membershipParams = @{
    Method  = 'Get'
    Uri     = $event.repository.owner.url + "/memberships/$author"
    Headers = @{
        Authorization = "token $env:CREATE_REPO_TOKEN"
    }
}
$membership = Invoke-RestMethod @membershipParams -SkipHttpErrorCheck -StatusCodeVariable memberStatusCode
$isOwner = $false
if ($memberStatusCode -ne 200) {
    Write-Host "Author not a member of organization." -ForegroundColor Cyan
}
elseif ($membership.role -ne 'admin' -or $membership.state -ne 'active') {
    Write-Host "Author not an active owner of organization." -ForegroundColor Cyan
}
else {
    $isOwner = $true
}

if ($isOwner) {
    # create the repo
    $info = & $PSScriptRoot/Get-NewRepoInfo.ps1
    $newRepoParams = @{
        AccessToken = $env:CREATE_REPO_TOKEN
    } + $info
    $newRepoParams.Remove('PreviewComment')
    # install module for bsdatarepo
    Install-Module PowerShellForGitHub -Force
    $result = ./.github/scripts/New-BsdataRepo.ps1 @newRepoParams -Verbose
    Write-Host $result
    $commentText = "**Created:** $($result.CreateRepo.html_url)"
}
else {
    # inform in the comment only an owner can do that
    $commentText = "Only an active organization owner can approve."
}

# add a comment about the result of this action
$commentParams = @{
    Method      = 'Post'
    Uri         = $event.issue.comments_url
    Headers     = @{
        Authorization = "token $env:GITHUB_TOKEN"
    }
    ContentType = 'application/json'
    Body        = @{
        'body' = $commentText
    } | ConvertTo-Json
}
Invoke-RestMethod @commentParams

if ($isOwner) {
    # if an owner approved, repo was created - issue can be closed
    $closeParams = @{
        Method      = 'Patch'
        Uri         = $event.issue.url
        Headers     = @{
            Authorization = "token $env:GITHUB_TOKEN"
        }
        ContentType = 'application/json'
        Body        = @{
            'state' = 'closed'
        } | ConvertTo-Json
    }
    Invoke-RestMethod @closeParams
}
