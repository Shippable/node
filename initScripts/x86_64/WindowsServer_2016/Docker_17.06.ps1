$ErrorActionPreference = "Stop"

$NODE_JS_VERSION = "4.8.5"
$DOCKER_VERSION = "17.06.2-ee-5"
$DOCKER_CONFIG_FILE="C:\ProgramData\Docker\config\daemon.json"

Function create_shippable_dir() {
  if (!(Test-Path $SHIPPABLE_RUNTIME_DIR)) {
    mkdir -p "$SHIPPABLE_RUNTIME_DIR"
  }
}

Function check_win_containers_enabled() {
  Write-Output "Checking if Windows Containers are enabled"
  $winConInstallState = (Get-WindowsFeature containers).InstallState
  if ($winConInstallState -ne "Installed") {
    Write-Error "Windows Containers must be enabled. Please install the feature, restart this machine and run this script again."
    exit -1
  }
}

Function install_prereqs() {
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

  Write-Output "Installing shipctl"
  & "$NODE_SHIPCTL_LOCATION/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/install.ps1"
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

  # Get docker NAT gateway ip address
  $global:DOCKER_NAT_IP=(Get-NetIPConfiguration | Where-Object InterfaceAlias -eq "vEthernet (HNS Internal NIC)").IPv4Address.IPAddress
}

Function pull_reqProc() {
  Write-Output "Pulling reqProc..."
  docker pull $EXEC_IMAGE
}

Function fetch_reqKick() {
  Write-Output "Fetching reqKick..."

  $reqKick_tar_download_location="$env:TEMP/reqKick.tar.gz"
  Invoke-RestMethod "$REQKICK_DOWNLOAD_URL" `
    -OutFile $reqKick_tar_download_location

  gzip -df $reqKick_tar_download_location
  $reqKick_tar=($reqKick_tar_download_location).replace(".gz", "").replace("\", "/")
  pushd "$env:TEMP/"
  tar -xf "$reqKick_tar" --force-local
  if (!(Test-Path $REQKICK_DIR)) {
    mkdir -p $REQKICK_DIR
  }
  mv reqKick-master/* $REQKICK_DIR
  Remove-Item -recur -force reqKick-master
  Remove-Item -recur -force $reqKick_tar_download_location -ErrorAction SilentlyContinue
  Remove-Item -recur -force $reqKick_tar -ErrorAction SilentlyContinue
  popd

  pushd $REQKICK_DIR
  npm install
  popd
}

create_shippable_dir
check_win_containers_enabled
install_prereqs
docker_install
check_docker_opts
pull_reqProc
fetch_reqKick
