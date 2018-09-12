$ErrorActionPreference = "Stop"

$NODE_JS_VERSION = "8.11.3"
$DOCKER_VERSION = "18.03.1-ee-3"
$DOCKER_CONFIG_FILE="C:\ProgramData\Docker\config\daemon.json"

Function check_win_containers_enabled() {
  Write-Output "Checking if Windows Containers are enabled"
  $winConInstallState = (Get-WindowsFeature containers).InstallState
  if ($winConInstallState -ne "Installed") {
    Write-Error "Windows Containers must be enabled. Please install the feature, restart this machine and run this script again."
    exit -1
  }
}

Function install_prereqs() {
  Write-Output "Installing choco"
  Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

  Write-Output "Enabling ChocolateyGet"
  Install-PackageProvider ChocolateyGet -Force

  Write-Output "Checking for node.js v$NODE_JS_VERSION"
  $nodejs_package = Get-Package nodejs -provider ChocolateyGet -ErrorAction SilentlyContinue
  if (!$nodejs_package -or ($nodejs_package.Version -ne "$NODE_JS_VERSION")) {
    Write-Output "Installing node.js v$NODE_JS_VERSION"
    Install-Package -ProviderName ChocolateyGet -Name nodejs -RequiredVersion $NODE_JS_VERSION -Force
  }

  Write-Output "Checking for git"
  $git_package = Get-Package git -provider ChocolateyGet -ErrorAction SilentlyContinue
  if (!$git_package) {
    Write-Output "Installing git"
    choco install -y git
  }

  Write-Output "Checking for nssm"
  $nssm_package = Get-Package nssm -provider ChocolateyGet -ErrorAction SilentlyContinue
  if (!$nssm_package) {
    Write-Output "Installing nssm"
    choco install -y nssm
  }

  Write-Output "Refreshing PATH"
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

  Write-Output "Installing shipctl from $NODE_SHIPCTL_LOCATION"
  & "$NODE_SHIPCTL_LOCATION/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/install.ps1"
}

Function add_firewall_rule() {
  $existingFWRule = Get-NetFirewallRule -DisplayName $SHIPPABLE_FIREWALL_RULE_NAME -ErrorAction SilentlyContinue

  if ($ExistingFWRule) {
    Write-Output "Removing Windows Firewall rule: ${SHIPPABLE_FIREWALL_RULE_NAME}"
    Remove-NetFirewallRule -DisplayName $SHIPPABLE_FIREWALL_RULE_NAME
  }

  Write-Output "Adding new Windows Firewall rule: ${SHIPPABLE_FIREWALL_RULE_NAME}"
  New-NetFirewallRule -DisplayName $SHIPPABLE_FIREWALL_RULE_NAME -Action allow -Direction Inbound -LocalPort 2375 -Protocol TCP
}

Function docker_install() {
  Write-Output "Installing DockerProvider module"
  Install-Module DockerProvider -Force

  Write-Output "Looking for Docker package"
  $docker_package = Get-Package docker -ProviderName DockerProvider -ErrorAction SilentlyContinue
  if (!$docker_package -or $docker_package.Version -ne "$DOCKER_VERSION") {
    Write-Output "Installing Docker v$DOCKER_VERSION"
    Install-Package Docker -ProviderName DockerProvider -RequiredVersion $DOCKER_VERSION -Force
  }

  Write-Output "Verifying Docker service has started"
  $dockerService = Get-Service docker

  if ($dockerService.Status -ne "Running") {
    Start-Service docker
  }

  wait_for_docker

  # Output docker version
  & "docker" -v
}

Function wait_for_docker() {
  # wait for a few seconds for Docker to Start
  Do {
    Write-Progress -Activity "Waiting for Docker to respond"
    Start-Sleep -s 1
    & "docker" ps > out.txt 2>&1
  }	While ($LastExitCode -eq 1)

  Write-Output "Docker is running"
}
Function check_docker_opts() {
  Write-Output "Enforcing docker daemon config"
  $script_dir = Split-Path -Path $MyInvocation.ScriptName
  Copy-Item $script_dir\daemon.json $DOCKER_CONFIG_FILE -Force

  Write-Output "Restarting docker service"
  Restart-Service docker

  wait_for_docker

  # Output docker info
  & "docker" info
}

Function pull_reqProc() {
  Write-Output "Pulling reqProc... $EXEC_IMAGE"
  Write-Output "The docker pull operation may take up to 15 minutes to complete and use 15GB of storage."
  docker pull $EXEC_IMAGE
}

Function fetch_reqKick() {
  Write-Output "Fetching reqKick from.... $REQKICK_DOWNLOAD_URL"

  $reqKick_zip_download_location="$env:TEMP/reqKick.zip"
  Invoke-RestMethod "$REQKICK_DOWNLOAD_URL" `
    -OutFile $reqKick_zip_download_location

  if (Test-Path $REQKICK_DIR) {
    Remove-Item -Recurse -Force $REQKICK_DIR
  }
  mkdir -p $REQKICK_DIR
  Expand-Archive -LiteralPath $reqKick_zip_download_location -DestinationPath $REQKICK_DIR

  pushd $REQKICK_DIR
  npm install
  popd
}

check_win_containers_enabled
install_prereqs
add_firewall_rule
docker_install
check_docker_opts

Write-Output "Completed base installs..."

Write-Output "Is this install only for Docker...$INSTALL_DOCKER_ONLY"

if (($INSTALL_DOCKER_ONLY) ) {
  Write-Output "Current context will skip Shippable components..."
  Write-Output "Completed Machine setup"
}

if (-not ($INSTALL_DOCKER_ONLY) ) {
  Write-Output "Fetching Shippable components..."
  pull_reqProc
  fetch_reqKick
  Write-Output "Completed Machine setup"
}
