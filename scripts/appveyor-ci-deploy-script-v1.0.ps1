# This is the deployment script for AppVeyor CI builds
# It uploads .bsi and .bsr artifact to the GitHub Release whose creation triggered this build

function DeployScript {

# Deploy to GitHub Releases on master branch and when building repo tag
Write-Host "Executing deployment script v1.0" -fore Green

$repo_owner,$repo_name = $env:APPVEYOR_REPO_NAME -split '/'
$tag = $env:APPVEYOR_REPO_TAG_NAME
$upload_asset_names = @("$repo_name.bsr","$repo_name.bsi")
$is_master = $env:APPVEYOR_REPO_BRANCH -eq 'master'
$is_tag = $env:APPVEYOR_REPO_TAG -eq $true
Write-Host "Checking deployment conditions. Branch: $env:APPVEYOR_REPO_BRANCH, building tag: $is_tag"

if (-not $is_master -or -not $is_tag) {
  $reason = `
    $(if (-not $is_master) {
      "branch should be master, is $env:APPVEYOR_REPO_BRANCH"
    } else {
      "build wasn't triggered by tag push"
    })
  Write-Host "Deployment to GitHub Releases skipped because $reason" -fore Green
  return;
}

Write-Host "Deploying to GiHub Release $tag started..."
try {
  # get release from tag
  $release_details_url = "https://api.github.com/repos/$env:APPVEYOR_REPO_NAME/releases/tags/$tag"
  $release_details = Invoke-RestMethod $release_details_url
} catch {
  $error_msg = "Failed to fetch release details for tag $tag - check if there was a release created for this tag."
  Write-Host $error_msg -back Red
  Write-Output $_                 # is this necessary?
  return $_;
}

# since I've found no way to expand RFC6570 Uri Templates in PowerShell, we'll execute dotnet script to do that
dotnet tool install -g dotnet-script
$expandUriTemplateScriptUrl = 'https://gist.githubusercontent.com/amis92/0b30e5e72cb0180b0ac9d04fe6e0e59d/raw/6b0e7430ef30fa24b435999d97f55a68e84aa08f/ExpandUriTemplate.csx'
$expandUriTemplateScript = $((New-TemporaryFile).FullName + '.csx')
# let's download the script into a temporary file
Invoke-WebRequest $expandUriTemplateScriptUrl -OutFile "$expandUriTemplateScript"

foreach ($name in $upload_asset_names) {
  #let's expand the Uri Template
  $upload_url = & dotnet-script $expandUriTemplateScriptUrl -- $release_details.upload_url $name
  
  # now we can upload the artifact
  $response = `
    Invoke-RestMethod $upload_url -Method Post `
    -InFile "artifacts\\$name" -ContentType 'application/zip' `
    -Headers @{ 'Authorization'= "Bearer $env:github_auth_token" }

  Write-Host $('Release asset available for download at ' + $response.browser_download_url) -fore Green
}

} # end DeployScript
DeployScript
