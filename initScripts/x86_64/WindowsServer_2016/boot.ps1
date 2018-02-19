$ErrorActionPreference = "Stop"

$NODE_DATA_LOCATION="$env:USERPROFILE\node"
$NODE_ENV="$NODE_DATA_LOCATION\_node.env.ps1"
$NODE_INIT_SCRIPT_FULL_PATH="$NODE_SCRIPTS_LOCATION\initScripts\$NODE_INIT_SCRIPT"
$NODE_SHIPCTL_LOCATION="$NODE_SCRIPTS_LOCATION/shipctl"

Write-Output "Sourcing $NODE_ENV"
. "$NODE_ENV"

$REQUIRED_ENVS = @(
    "EXEC_IMAGE",
    "LISTEN_QUEUE",
    "NODE_ARCHITECTURE",
    "NODE_DOCKER_VERSION",
    "NODE_ID",
    "NODE_INIT_SCRIPT",
    "NODE_OPERATING_SYSTEM",
    "NODE_TYPE_CODE",
    "RUN_MODE",
    "SHIPPABLE_AMQP_DEFAULT_EXCHANGE",
    "SHIPPABLE_AMQP_URL",
    "SHIPPABLE_API_URL",
    "SHIPPABLE_RELEASE_VERSION",
    "REQKICK_DOWNLOAD_URL")

$SHIPPABLE_RUNTIME_DIR = "$env:USERPROFILE\Shippable\Runtime"
$BASE_UUID = New-Guid
$BASE_DIR = "$SHIPPABLE_RUNTIME_DIR\$BASE_UUID"
$CONTAINER_RUNTIME_DIR = "$env:USERPROFILE\Shippable\Runtime"
$CONTAINER_BASE_DIR = "$CONTAINER_RUNTIME_DIR\$BASE_UUID"

$REQPROC_DIR = "$BASE_DIR\reqProc"
$CONTAINER_REQPROC_DIR = "$CONTAINER_BASE_DIR\reqProc"

$REQEXEC_DIR = "$BASE_DIR\reqExec"
$CONTAINER_REQEXEC_DIR = "$CONTAINER_BASE_DIR\reqExec"
$REQEXEC_BIN_DIR = "$BASE_DIR\reqExec"
$REQEXEC_BIN_PATH = "$REQEXEC_BIN_DIR\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM\dist\main\main.exe"

$REQKICK_DIR = "$BASE_DIR\reqKick"
$CONTAINER_REQKICK_DIR = "$CONTAINER_BASE_DIR\reqKick"
$REQKICK_SERVICE_DIR = "$REQKICK_DIR\init\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM"
$REQKICK_CONFIG_DIR = "$SHIPPABLE_RUNTIME_DIR\config\reqKick"

$BUILD_DIR = "$BASE_DIR\build"
$CONTAINER_BUILD_DIR = "$CONTAINER_BASE_DIR\build"
$STATUS_DIR = "$BUILD_DIR\status"
$SCRIPTS_DIR = "$BUILD_DIR\scripts"

$REQPROC_MOUNTS = ""
$REQPROC_ENVS = ""
$REQPROC_OPTS = ""
$REQPROC_CONTAINER_NAME_PATTERN = "reqProc"
$REQPROC_CONTAINER_NAME = "$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
$REQKICK_SERVICE_NAME_PATTERN = "shippable-reqKick@"

# TODO: update container directories while mounting
$DEFAULT_TASK_CONTAINER_MOUNTS = "-v ${BUILD_DIR}:${CONTAINER_BUILD_DIR} -v ${REQEXEC_DIR}:${CONTAINER_REQEXEC_DIR}"
$TASK_CONTAINER_COMMAND = "$CONTAINER_REQEXEC_DIR\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM\dist\main\main.exe"
$DEFAULT_TASK_CONTAINER_OPTIONS = "-d --rm"
$DOCKER_CLIENT_LATEST = "C:\Program Files\Docker\docker.exe"

# Helper functions

Function check_required_envs($requiredEnvs) {
    Write-Output "Verifying environment variables"
    foreach ($reqEnv in $requiredEnvs) {
        if (!($reqEnv)) {
            Write-Error "$reqEnv is not defined"
            exit -1;
        }
    }
}

# End helper functions

Function remove_reqKick() {
  Write-Output "Remove existing reqKick"

  # remove pm2 managed reqkick services
  if (Get-Command "pm2" -ErrorAction SilentlyContinue)
  {
    pm2 delete all /shippable-reqKick*/
  }

  # remove nssm managed reqkick services
  Get-Service shippable-reqkick-* | %{
    nssm stop $_.Name
    nssm remove $_.Name confirm
  }
}

Function remove_reqProc() {
  Write-Output "Remove existing reqProc containers"
  docker ps -a --filter "NAME=$REQPROC_CONTAINER_NAME_PATTERN" --format '{{.Names}}' | %{ docker rm -f $_ }
}

Function setup_dirs() {
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
}

Function initialize() {
    Write-Output "Initializing node..."
    & "$NODE_INIT_SCRIPT_FULL_PATH"
}

Function setup_mounts() {
  $global:REQPROC_MOUNTS = " -v ${BASE_DIR}:${CONTAINER_BASE_DIR} "
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
    "-e BASE_DIR='$CONTAINER_BASE_DIR' " + `
    "-e REQPROC_DIR='$CONTAINER_REQPROC_DIR' " + `
    "-e REQEXEC_DIR='$CONTAINER_REQEXEC_DIR' " + `
    "-e REQKICK_DIR='$CONTAINER_REQKICK_DIR' " + `
    "-e BUILD_DIR='$CONTAINER_BUILD_DIR' " + `
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
    "-e DOCKER_HOST=${DOCKER_NAT_IP}:2375 " + `
    "-e SHIPPABLE_NODE_SCRIPTS_LOCATION=$NODE_SCRIPTS_LOCATION"
}

Function setup_opts() {
  $global:REQPROC_OPTS = " -d " + `
    "--restart=always " + `
    "--name=$REQPROC_CONTAINER_NAME "
}

Function boot_reqProc() {
  Write-Output "Boot reqProc..."

  $start_cmd = "docker run $global:REQPROC_OPTS $global:REQPROC_MOUNTS $global:REQPROC_ENVS $EXEC_IMAGE"
  Write-Output "Executing docker run command: " $start_cmd
  iex "$start_cmd"
}

Function boot_reqKick() {
  echo "Booting up reqKick service..."

  pushd $REQKICK_DIR
  $service_name = "shippable-reqkick-$BASE_UUID"

  # Create stdout and stderr files for reqkick service
  $stdout_file = "$env:TEMP\$service_name.out"
  $stderr_file = "$env:TEMP\$service_name.err"
  echo "" | Out-File -Encoding utf8 $stdout_file
  echo "" | Out-File -Encoding utf8 $stderr_file

  $nodejs_exe_path =  Get-Command "node" | Select-Object -ExpandProperty Definition

  nssm install $service_name $nodejs_exe_path "$REQKICK_DIR\reqKick.app.js"
  nssm set $service_name AppEnvironmentExtra STATUS_DIR="$STATUS_DIR" SCRIPTS_DIR="$SCRIPTS_DIR" RUN_MODE="$RUN_MODE" REQEXEC_BIN_PATH="$REQEXEC_BIN_PATH"
  nssm set $service_name AppStdout $stdout_file
  nssm set $service_name AppStderr $stderr_file
  nssm start $service_name

  popd
}

check_required_envs($REQUIRED_ENVS)
remove_reqKick
remove_reqProc
setup_dirs
initialize
setup_mounts
setup_envs
setup_opts
boot_reqProc
boot_reqKick
