param(
  $SCRIPT_DIR = $PSScriptRoot,
  $ARTIFACTS = "$SCRIPT_DIR\..\artifacts",
  
  $KUDU_SYNC_CMD = $env:KUDU_SYNC_CMD,
  
  $DEPLOYMENT_SOURCE = $env:DEPLOYMENT_SOURCE,
  $DEPLOYMENT_TARGET = $env:DEPLOYMENT_TARGET,
  
  $NEXT_MANIFEST_PATH = $env:NEXT_MANIFEST_PATH,
  $PREVIOUS_MANIFEST_PATH = $env:PREVIOUS_MANIFEST_PATH
)
$ErrorActionPreference = 'stop'

# ----------------------
# KUDU Deployment Script
# Version: 1.0.15
# ----------------------

# Helpers
# -------

function exitWithMessageOnError($1) {
  if ($? -eq $false) {
    echo "An error has occurred during web site deployment."
    echo $1
    exit 1
  }
}

# Prerequisites
# -------------

# Verify node.js installed
where.exe node 2> $null > $null
exitWithMessageOnError "Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment."

# Setup
# -----


if ($DEPLOYMENT_SOURCE -eq $null) {
  $DEPLOYMENT_SOURCE = $SCRIPT_DIR
}

if ($DEPLOYMENT_TARGET -eq $null) {
  $DEPLOYMENT_TARGET = "$ARTIFACTS\wwwroot"
}

if ($NEXT_MANIFEST_PATH -eq $null) {
  $NEXT_MANIFEST_PATH = "$ARTIFACTS\manifest"

  if ($PREVIOUS_MANIFEST_PATH -eq $null) {
    $PREVIOUS_MANIFEST_PATH = $NEXT_MANIFEST_PATH
  }
}

if ($KUDU_SYNC_CMD -eq $null) {
  if (-not(get-command kudusync -ErrorAction SilentlyContinue)) {
    # Install kudu sync
    Write-output "Installing Kudu Sync"
    npm install kudusync -g --silent
    exitWithMessageOnError "npm failed"
  }
  $KUDU_SYNC_CMD = 'kudusync'
}

$DEPLOYMENT_TEMP = $env:DEPLOYMENT_TEMP
$MSBUILD_PATH = $env:MSBUILD_PATH

if ($DEPLOYMENT_TEMP -eq $null) {
  $DEPLOYMENT_TEMP = "$env:temp\___deployTemp$env:random"
  $CLEAN_LOCAL_DEPLOYMENT_TEMP = $true
}

if ($CLEAN_LOCAL_DEPLOYMENT_TEMP -eq $true) {
  if (Test-Path $DEPLOYMENT_TEMP) {
    rd -Path $DEPLOYMENT_TEMP -Recurse -Force
  }
  mkdir "$DEPLOYMENT_TEMP"
}

if ($MSBUILD_PATH -eq $null) {
  $MSBUILD_PATH = "${env:ProgramFiles(x86)}\MSBuild\14.0\Bin\MSBuild.exe"
}
##################################################################################################################################
# Deployment
# ----------

echo "Handling ASP.NET Core Web Application deployment."

# 1. Restore nuget packages
dotnet restore "src/vandelay.sln"
exitWithMessageOnError "Restore failed"

dotnet build "src/vandelay.xunittests/vandelay.xunittests.csproj" --configuration Release
exitWithMessageOnError "Test compilation failed"

if (-not(Get-ChildItem .\build\xunit.runner.console.2* -ErrorAction SilentlyContinue)) {
  nuget install xunit.runner.console -outputdirectory build
}
$xunit, $null = Get-ChildItem .\build\xunit.runner.console.2*\tools\netcoreapp2.0\xunit.console.dll `
  | Sort-Object -property name -Descending `
  | Select-Object -expandproperty Fullname

dotnet $xunit ".\src\vandelay.xunittests\bin\release\netcoreapp2.0\vandelay.xunittests.dll"
exitWithMessageOnError "Test(s) failed"

# 2. Build and publish
dotnet publish "src/vandelay.web/vandelay.web.csproj" --output "$DEPLOYMENT_TEMP" --configuration Release
exitWithMessageOnError "dotnet publish failed"

# 3. KuduSync
& $KUDU_SYNC_CMD -v 50 -f "$DEPLOYMENT_TEMP" -t "$DEPLOYMENT_TARGET" -n "$NEXT_MANIFEST_PATH" -p "$PREVIOUS_MANIFEST_PATH" -i ".git;.hg;.deployment;deploy.ps1"
exitWithMessageOnError "Kudu Sync failed"

##################################################################################################################################
echo "Finished successfully."
