# This is the pre-build script for AppVeyor CI builds
# It installs required tools

function InstallScript {

Write-Host "Executing install script v1.0" -fore Green

# install 'wham' - .NET Core global tool for datafile management
dotnet tool install -g wham `
  --version 0.5.23-alpha `
  --add-source https://www.myget.org/F/warhub/api/v3/index.json
  
} # end InstallScript
InstallScript
