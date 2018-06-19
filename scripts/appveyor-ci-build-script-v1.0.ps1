# This is the build script for AppVeyor CI builds
# It produces artifacts for use in BattleScribe:
# * a standalone repo distribution (standalone.bsr)
# * for non-PullRequest builds, a branch-trackable index and distro (<repo>-branch-latest.bs[i|r])
# * for tag builds, GitHub Release uploads - index and distro (<repo>.bs[i|r])

function BuildScript {

Write-Host "Executing build script v1.0" -fore Green

#setup variables
$tag = $env:APPVEYOR_REPO_TAG_NAME
$pr = $env:APPVEYOR_PULL_REQUEST_NUMBER -ne $null
$branch = $env:APPVEYOR_REPO_BRANCH
$repo_owner,$repo_name = $env:APPVEYOR_REPO_NAME -split '/'

Write-Host "Branch: $branch, is PR: $pr"

# standalone BSR
wham publish bsr -v Verbose -bsr-filename snapshot
if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }

# latest only from non-PR
if (-not $pr) {
  Write-Host "Publishing artifacts for $branch branch-feed - links currently not supported by BattleScribe"
  
  $slug = $env:APPVEYOR_PROJECT_SLUG
  $index_url_part = "$env:APPVEYOR_ACCOUNT_NAME/$slug"
  $filename_core = "$repo_name-branch-latest"
  
  wham publish bsr,bsi `
  -v Verbose `
  -i $filename_core `
  -url "https://ci.appveyor.com/api/projects/$index_url_part/artifacts/artifacts/$filename_core.bsi?branch=$branch&pr=false" `
  -no-index-datafiles `
  -bsr-filename $filename_core `
  -additional-urls "https://ci.appveyor.com/api/projects/$index_url_part/artifacts/artifacts/$filename_core.bsr?branch=$branch&pr=false"
  if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }
}

# for release tags
if ($env:APPVEYOR_REPO_TAG -eq $true) {

  Write-Host "Publishing artifacts for $tag release feed" -fore Green
  
  wham publish bsr,bsi `
  -v Verbose `
  -i $repo_name `
  -url "https://github.com/$env:APPVEYOR_REPO_NAME/releases/download/$tag/$repo_name.bsi" `
  -no-index-datafiles `
  -bsr-filename $repo_name `
  -additional-urls "https://github.com/$env:APPVEYOR_REPO_NAME/releases/download/$tag/$repo_name.bsr"
  if ($LastExitCode -ne 0) { $host.SetShouldExit($LastExitCode)  }
}

} # end BuildScript
BuildScript
