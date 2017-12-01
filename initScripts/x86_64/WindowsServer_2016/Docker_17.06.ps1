$ErrorActionPreference = "Stop"

$NODE_JS_VERSION = "4.8.5"
$DOCKER_VERSION = "17.06.2-ee-5"

$SHIPPABLE_RUNTIME_DIR = "$env:USERPROFILE\shippable"
$BASE_UUID = New-Guid
$BASE_DIR = "$SHIPPABLE_RUNTIME_DIR\$BASE_UUID"
$CONTAINER_BASE_DIR = "C:\Users\ContainerAdministrator\Shippable"

$REQPROC_DIR = "$BASE_DIR\reqProc"

$REQEXEC_DIR = "$BASE_DIR\reqExec"
$REQEXEC_BIN_DIR = "$BASE_DIR\reqExec\bin"
$REQEXEC_BIN_PATH = "$REQEXEC_BIN_DIR\$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/dist/main/main"

$REQKICK_DIR = "$BASE_DIR\reqKick"
$REQKICK_SERVICE_DIR = "$REQKICK_DIR\init\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM"
$REQKICK_CONFIG_DIR = "$SHIPPABLE_RUNTIME_DIR\config\reqKick"

$BUILD_DIR = "$BASE_DIR\build"
$STATUS_DIR = "$BUILD_DIR\status"
$SCRIPTS_DIR = "$BUILD_DIR\scripts"

# TODO: move these to reqproc image
$IMAGE_REQEXEC_DIR = "$CONTAINER_BASE_DIR\reqExec"
$IMAGE_EXEC_TEMPLATES_DIR = "$CONTAINER_BASE_DIR\execTemplates"

$REQPROC_MOUNTS = ""
$REQPROC_ENVS = ""
$REQPROC_OPTS = ""
$REQPROC_CONTAINER_NAME_PATTERN = "reqProc"
$REQPROC_CONTAINER_NAME = "$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
$REQKICK_SERVICE_NAME_PATTERN = "shippable-reqKick@"

# TODO: update container directories while mounting
$DEFAULT_TASK_CONTAINER_MOUNTS = "-v ${BUILD_DIR}:${BUILD_DIR} -v ${REQEXEC_DIR}:/reqExec"
$TASK_CONTAINER_COMMAND = "/reqExec/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/dist/main/main"
$DEFAULT_TASK_CONTAINER_OPTIONS = "--rm"
$DOCKER_CLIENT_LATEST = "C:\Program Files\Docker\docker.exe"

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
    Install-Package -ProviderName ChocolateyGet -Name git -Force
  }

  Write-Output "Refreshing PATH"
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

  Write-Output "Installing global node packages"
  npm install pm2 pm2-windows-startup -g
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

  # wait for a few seconds for Docker to Start
  Do {
    Write-Progress -Activity "Waiting for Docker to respond"
    Start-Sleep -s 1
    & "docker" ps > out.txt 2>&1
  }	While ($LastExitCode -eq 1)

  Write-Output "Docker is running"

  # Output docker version
  & "docker" -v
}

Function check_docker_opts() {
  Write-Output "!!! TODO: Update docker configuration !!!"
}

Function remove_reqKick() {
  Write-Output "Remove existing reqKick"

  pm2 delete all /shippable-reqKick*/
}

Function remove_reqProc() {
  Write-Output "Remove existing reqProc containers"
  docker ps -a --filter "NAME=$REQPROC_CONTAINER_NAME_PATTERN" --format '{{.Names}}' | %{ docker rm -f $_ }
}

Function setup_mounts() {
  if (Test-Path $SHIPPABLE_RUNTIME_DIR) {
    Write-Output "Deleting Shippable runtime directory"
    Remove-Item -recur -force $SHIPPABLE_RUNTIME_DIR
  }

  if (!(Test-Path $BASE_DIR)) {
    mkdir -p $BASE_DIR
  }

  if (!(Test-Path $REQPROC_DIR)) {
    mkdir -p $REQPROC_DIR
  }

  if (!(Test-Path $REQEXEC_DIR)) {
    mkdir -p $REQEXEC_DIR
  }

  if (!(Test-Path $REQKICK_DIR)) {
    mkdir -p $REQKICK_DIR
  }

  if (!(Test-Path $BUILD_DIR)) {
    mkdir -p $BUILD_DIR
  }

  $global:REQPROC_MOUNTS= " -v ${BASE_DIR}:${BASE_DIR} "
}

Function setup_envs() {
  $global:REQPROC_ENVS = " -e SHIPPABLE_AMQP_URL=$SHIPPABLE_AMQP_URL " + `
    "-e SHIPPABLE_AMQP_DEFAULT_EXCHANGE=$SHIPPABLE_AMQP_DEFAULT_EXCHANGE " + `
    "-e SHIPPABLE_API_URL=$SHIPPABLE_API_URL " + `
    "-e LISTEN_QUEUE='$LISTEN_QUEUE' " + `
    "-e NODE_ID=$NODE_ID " + `
    "-e RUN_MODE=$RUN_MODE " + `
    "-e SUBSCRIPTION_ID=$SUBSCRIPTION_ID " + `
    "-e NODE_TYPE_CODE=$NODE_TYPE_CODE " + `
    "-e BASE_DIR='$BASE_DIR' " + `
    "-e REQPROC_DIR='$REQPROC_DIR' " + `
    "-e REQEXEC_DIR='$REQEXEC_DIR' " + `
    "-e REQEXEC_BIN_DIR='$REQEXEC_BIN_DIR' " + `
    "-e REQKICK_DIR='$REQKICK_DIR' " + `
    "-e BUILD_DIR='$BUILD_DIR' " + `
    "-e REQPROC_CONTAINER_NAME='$REQPROC_CONTAINER_NAME' " + `
    "-e DEFAULT_TASK_CONTAINER_OPTIONS='$DEFAULT_TASK_CONTAINER_OPTIONS' " + `
    "-e EXEC_IMAGE=$EXEC_IMAGE " + `
    "-e TASK_CONTAINER_COMMAND='$TASK_CONTAINER_COMMAND' " + `
    "-e DEFAULT_TASK_CONTAINER_MOUNTS='$DEFAULT_TASK_CONTAINER_MOUNTS' " + `
    "-e DOCKER_CLIENT_LATEST='$DOCKER_CLIENT_LATEST' " + `
    "-e SHIPPABLE_DOCKER_VERSION='$DOCKER_VERSION' " + `
    "-e IS_DOCKER_LEGACY=false " + `
    "-e SHIPPABLE_NODE_ARCHITECTURE=$NODE_ARCHITECTURE " + `
    "-e SHIPPABLE_NODE_OPERATING_SYSTEM=$NODE_OPERATING_SYSTEM " + `
    "-e SHIPPABLE_RELEASE_VERSION=$SHIPPABLE_RELEASE_VERSION " + `
    "-e IMAGE_EXEC_TEMPLATES_DIR='$IMAGE_EXEC_TEMPLATES_DIR' " + `
    "-e IMAGE_REQEXEC_DIR='$IMAGE_REQEXEC_DIR' "
}

Function setup_opts() {
  $global:REQPROC_OPTS= " -d " + `
    "--restart=always " + `
    "--name=$REQPROC_CONTAINER_NAME "
}

Function boot_reqProc() {
  Write-Output "Boot reqProc..."
  docker pull $EXEC_IMAGE

  $start_cmd = "docker run $global:REQPROC_OPTS $global:REQPROC_MOUNTS $global:REQPROC_ENVS $EXEC_IMAGE"
  Write-Output "Executing docker run command: " $start_cmd
  iex "$start_cmd"
}

Function boot_reqKick() {
  echo "Booting up reqKick service..."

  git clone https://github.com/Shippable/reqKick.git $REQKICK_DIR
  pushd $REQKICK_DIR
  git checkout $SHIPPABLE_RELEASE_VERSION
  npm install

  $reqkick_env_template = "$REQKICK_SERVICE_DIR/shippable-reqKick@.yml.template"
  New-Item -ItemType Directory -Force -Path $REQKICK_CONFIG_DIR
  $reqkick_env = "$REQKICK_CONFIG_DIR/shippable-reqKick.yml"

  if (!(Test-Path "$reqkick_env_template")) {
    Write-Error "Reqkick env template file not found: $reqkick_env_template"
    exit -1
  }

  Write-Output "Writing reqKick specific envs to $reqkick_env"
  $template=(Get-Content $reqkick_env_template)
  $template=$template.replace("{{UUID}}", $BASE_UUID)
  $template=$template.replace("{{STATUS_DIR}}", $STATUS_DIR)
  $template=$template.replace("{{SCRIPTS_DIR}}", $SCRIPTS_DIR)
  $template=$template.replace("{{RUN_MODE}}", $RUN_MODE)
  $template=$template.replace("{{REQEXEC_BIN_PATH}}", $REQEXEC_BIN_PATH)
  $template=$template.replace("{{REQKICK_DIR}}", $REQKICK_DIR) | Set-Content $reqkick_env

  pm2 start $REQKICK_CONFIG_DIR/shippable-reqKick.yml
  pm2 save
  popd
}


create_shippable_dir
check_win_containers_enabled
install_prereqs
docker_install
check_docker_opts
remove_reqKick
remove_reqProc
setup_mounts
setup_envs
setup_opts
boot_reqProc
boot_reqKick

exit 0;