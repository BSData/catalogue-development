# This is the build script for AppVeyor CI builds
# It produces artifacts for use in BattleScribe

echo "BSData PowerShell script for AppVeyor CI builds - v1.0"

#setup flags
$pr = $env:APPVEYOR_PULL_REQUEST_NUMBER -ne $null
$branch = $env:APPVEYOR_REPO_BRANCH
$index_url_part = "$env:APPVEYOR_ACCOUNT_NAME/$env:APPVEYOR_PROJECT_SLUG"
echo "Branch: $branch, is PR: $pr"

# standalone BSR
wham publish bsr -v Verbose -bsr-filename standalone

# latest only from non-PR

if (-not $pr) {

  echo "publishing artifacts for $branch branch-feed - links currently not supported by BattleScribe";
  
  wham publish bsr,bsi `
  -v Verbose `
  -i index-latest `
  -url "https://ci.appveyor.com/api/projects/$index_url_part/artifacts/artifacts/index-latest.bsi?branch=$branch&pr=false" `
  -name wh40k-ci `
  -no-index-datafiles `
  -bsr-filename latest `
  -additional-urls "https://ci.appveyor.com/api/projects/$index_url_part/artifacts/artifacts/latest.bsr?branch=$branch&pr=false"
  
}
