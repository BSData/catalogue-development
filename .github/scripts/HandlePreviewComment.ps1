#!/usr/bin/env pwsh

# This script uses the following env variables:
# - GITHUB_EVENT_PATH

$event = Get-Content $env:GITHUB_EVENT_PATH | ConvertFrom-Json

# check comment text
if ('.preview' -ne $event.comment.body.Trim())
{
    Write-Host "Comment formatted incorrectly." -ForegroundColor Cyan
    exit 0;
}

& "$PSScriptRoot/NewRepoNamesPreview.ps1"