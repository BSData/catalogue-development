# This is the build script for AppVeyor CI builds
# It produces artifacts for use in BattleScribe:
# * a standalone repo distribution (standalone.bsr)
# * for non-PullRequest builds, a branch-trackable index and distro (<repo>-branch-latest.bs[i|r])
# * for tag builds, GitHub Release uploads - index and distro (<repo>.bs[i|r])

function BuildScript {

Write-Host "Executing build script v1.0" -fore Green

#setup flags
$pr = $env:APPVEYOR_PULL_REQUEST_NUMBER -ne $null
$branch = $env:APPVEYOR_REPO_BRANCH
$index_url_part = "$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG"
Write-Host "Branch: $branch, is PR: $pr"

# standalone BSR
wham publish bsr -v Verbose -bsr-filename snapshot

# latest only from non-PR
if (-not $pr) {

  Write-Host "Publishing artifacts for $branch branch-feed - links currently not supported by BattleScribe"
  $filename_core = "$slug-branch-latest"
  
  wham publish bsr,bsi `
  -v Verbose `
  -i $filename_core `
  -url "https://ci.appveyor.com/api/projects/$index_url_part/artifacts/artifacts/$filename_core.bsi?branch=$branch&pr=false" `
  -no-index-datafiles `
  -bsr-filename $filename_core `
  -additional-urls "https://ci.appveyor.com/api/projects/$index_url_part/artifacts/artifacts/$filename_core.bsr?branch=$branch&pr=false"
  
}

# for release tags
if ($env:APPVEYOR_REPO_TAG -eq $true) {
  Write-Host "Publishing artifacts for $tag release feed" -fore Green
  
  wham publish bsr,bsi `
  -v Verbose `
  -i $slug `
  -url "https://github.com/$index_url_part/releases/download/$tag/$slug.bsi" `
  -no-index-datafiles `
  -bsr-filename $slug `
  -additional-urls "https://github.com/$index_url_part/releases/download/$tag/$slug.bsr"
}

} # end BuildScript
BuildScript
