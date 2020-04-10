#!/usr/bin/env pwsh

# This script uses the following env variables:
# - GITHUB_EVENT_PATH
# - GITHUB_ACTOR
# - CREATE_REPO_TOKEN

$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json

# check comment text
if ('.approve' -ne $event.comment.body.Trim()) {
    Write-Host "Comment formatted incorrectly." -ForegroundColor Cyan
    exit 0;
}

$author = $env:GITHUB_ACTOR

# check whether comment author is org owner
$membershipParams = @{
    Method  = 'Get'
    Uri     = $event.organization.url + "/memberships/$author"
    Headers = @{
        Authorization = "token $env:CREATE_REPO_TOKEN"
    }
}
Write-Host "Membership Uri: $($membershipParams.Uri)"
$membership = Invoke-RestMethod @membershipParams -SkipHttpErrorCheck -StatusCodeVariable memberStatusCode
$isOwner = $false
Write-Host "Membership response code: $memberStatusCode"
Write-Host "Membership response content:"
ConvertTo-Json $membership -Depth 5 | Write-Host
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
    if (-not $info.NameAvailable) {
        # name not available, treat as `.preview` command
        Write-Host "Repo name taken, executing '.preview' command instead."
        & $PSScriptRoot/NewRepoNamesPreview.ps1
        exit 0
    }
    $newRepoParams = @{
        RepositoryName = $info.RepositoryName
        Description = $info.Description
        Collaborators = $info.Collaborators
        AccessToken = $env:CREATE_REPO_TOKEN
    }
    try {
        # install module for bsdatarepo creation
        Install-Module PowerShellForGitHub -Force
        $result = ./.github/scripts/New-BsdataRepo.ps1 @newRepoParams -Verbose
        Write-Host $result
        $commentText = "**Created:** $($result.CreateRepo.html_url)"
    }
    catch {
        $commentText = "Operation failed. See https://github.com/BSData/catalogue-development/runs/$env:GITHUB_RUN_ID"
    }
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
