# This is the pre-build script for AppVeyor CI builds
# It produces artifacts for use in BattleScribe

echo "BSData PowerShell 'install' script for AppVeyor CI builds - v1.0"

# install 'wham' - .NET Core global tool for datafile management
dotnet tool install -g wham `
--version 0.5.23-alpha `
--add-source https://www.myget.org/F/warhub/api/v3/index.json
