# This is the build script for AppVeyor CI builds
# It produces artifacts for use in BattleScribe

echo "BSData PowerShell script for AppVeyor CI builds - v1.0"

#setup flags
$pr = $env:APPVEYOR_PULL_REQUEST_NUMBER -ne $null
$branch = $env:APPVEYOR_REPO_BRANCH
$index_url_part = "$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG"
echo "Branch: $branch, is PR: $pr"

# standalone BSR
wham publish bsr -v Verbose -bsr-filename snapshot

# latest only from non-PR

if (-not $pr) {

  echo "publishing artifacts for $branch branch-feed - links currently not supported by BattleScribe"
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

if ($env:APPVEYOR_REPO_TAG) {

  echo "Publishing artifacts for $tag release feed"
  
  wham publish bsr,bsi `
  -v Verbose `
  -i $slug `
  -url "https://github.com/$index_url_part/releases/download/$tag/$slug.bsi" `
  -no-index-datafiles `
  -bsr-filename $slug `
  -additional-urls "https://github.com/$index_url_part/releases/download/$tag/$slug.bsr"
  
}
