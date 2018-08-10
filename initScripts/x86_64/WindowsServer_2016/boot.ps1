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
    "SHIPPABLE_AMI_VERSION",
    "SHIPPABLE_RELEASE_VERSION",
    "REQKICK_DOWNLOAD_URL")

$SHIPPABLE_ROOT_DIR = "$env:USERPROFILE\Shippable"
$SHIPPABLE_RUNTIME_DIR = "$SHIPPABLE_ROOT_DIR\Runtime"
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

$REQKICK_DIR = "$SHIPPABLE_ROOT_DIR\reqKick"
$CONTAINER_REQKICK_DIR = "$SHIPPABLE_ROOT_DIR\reqKick"
$REQKICK_SERVICE_DIR = "$REQKICK_DIR\init\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM"
$REQKICK_CONFIG_DIR = "$SHIPPABLE_RUNTIME_DIR\config\reqKick"
$REQKICK_SERVICE_NAME = "shippable-reqkick-$BASE_UUID"

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

$CONTAINER_NODE_DIR = "C:\Users\Administrator\Shippable\node"

# TODO: update container directories while mounting
$DEFAULT_TASK_CONTAINER_MOUNTS = "-v ${BUILD_DIR}:${CONTAINER_BUILD_DIR} -v ${REQEXEC_DIR}:${CONTAINER_REQEXEC_DIR} " + `
"-v ${NODE_SCRIPTS_LOCATION}:${CONTAINER_NODE_DIR}"
$TASK_CONTAINER_COMMAND = "$CONTAINER_REQEXEC_DIR\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM\dist\main\main.exe"
$DEFAULT_TASK_CONTAINER_OPTIONS = "-d --rm"
$DOCKER_CLIENT_LATEST = "C:\Program Files\Docker\docker.exe"

$SHIPPABLE_FIREWALL_RULE_NAME = "shippable-docker"

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
  if (Get-Command "nssm" -ErrorAction SilentlyContinue)
  {
    Get-Service shippable-reqkick-* | %{
      nssm stop $_.Name
      nssm remove $_.Name confirm
    }
  }
}

Function remove_reqProc() {
  Write-Output "Remove existing reqProc containers"
  if (Get-Command "docker" -ErrorAction SilentlyContinue)
  {
    docker ps -a --filter "NAME=$REQPROC_CONTAINER_NAME_PATTERN" --format '{{.Names}}' | %{ docker rm -f $_ }
  }
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
  $global:REQPROC_MOUNTS = " -v ${BASE_DIR}:${CONTAINER_BASE_DIR} " + `
    "-v ${REQKICK_DIR}:${CONTAINER_REQKICK_DIR} "
}

Function setup_envs() {
  # Get docker NAT gateway ip address
  $DOCKER_NAT_IP=(Get-NetIPConfiguration | Where-Object InterfaceAlias -eq "vEthernet (HNS Internal NIC)").IPv4Address.IPAddress

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
    "-e SHIPPABLE_AMI_VERSION=$SHIPPABLE_AMI_VERSION " + `
    "-e DOCKER_HOST=${DOCKER_NAT_IP}:2375 " + `
    "-e SHIPPABLE_NODE_SCRIPTS_LOCATION=$NODE_SCRIPTS_LOCATION " + `
    "-e CLUSTER_TYPE_CODE=$CLUSTER_TYPE_CODE " + `
    "-e IS_RESTRICTED_NODE=$IS_RESTRICTED_NODE"
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

  # Create stdout and stderr files for reqkick service
  $stdout_file = "$env:TEMP\$REQKICK_SERVICE_NAME.out"
  $stderr_file = "$env:TEMP\$REQKICK_SERVICE_NAME.err"
  echo "" | Out-File -Encoding utf8 $stdout_file
  echo "" | Out-File -Encoding utf8 $stderr_file

  $nodejs_exe_path =  Get-Command "node" | Select-Object -ExpandProperty Definition

  nssm install $REQKICK_SERVICE_NAME $nodejs_exe_path "$REQKICK_DIR\reqKick.app.js"
  if ($NODE_TYPE_CODE -ne 7002) {
    nssm set $REQKICK_SERVICE_NAME AppEnvironmentExtra STATUS_DIR="$STATUS_DIR" SCRIPTS_DIR="$SCRIPTS_DIR" RUN_MODE="$RUN_MODE" REQEXEC_BIN_PATH="$REQEXEC_BIN_PATH" NODE_ID="$NODE_ID" SUBSCRIPTION_ID="$SUBSCRIPTION_ID" NODE_TYPE_CODE="$NODE_TYPE_CODE" SHIPPABLE_NODE_ARCHITECTURE="$NODE_ARCHITECTURE" SHIPPABLE_NODE_OPERATING_SYSTEM="$NODE_OPERATING_SYSTEM" SHIPPABLE_API_URL="$SHIPPABLE_API_URL"
  }
  if ($NODE_TYPE_CODE -eq 7002) {
    nssm set $REQKICK_SERVICE_NAME AppEnvironmentExtra STATUS_DIR="$STATUS_DIR" SCRIPTS_DIR="$SCRIPTS_DIR" RUN_MODE="$RUN_MODE" REQEXEC_BIN_PATH="$REQEXEC_BIN_PATH" NODE_ID="$NODE_ID" NODE_TYPE_CODE="$NODE_TYPE_CODE" SHIPPABLE_NODE_ARCHITECTURE="$NODE_ARCHITECTURE" SHIPPABLE_NODE_OPERATING_SYSTEM="$NODE_OPERATING_SYSTEM" SHIPPABLE_API_URL="$SHIPPABLE_API_URL"
  }
  nssm set $REQKICK_SERVICE_NAME AppStdout $stdout_file
  nssm set $REQKICK_SERVICE_NAME AppStderr $stderr_file
  nssm start $REQKICK_SERVICE_NAME

  popd
}

Function cleanup() {
  Write-Output "==== Cleaning up ===="
  Remove-Item -force "$NODE_ENV"
}

Function print_summary() {
  Write-Output "==== Summary ===="
  Write-Output "- A firewall rule (${SHIPPABLE_FIREWALL_RULE_NAME}) to allow connections on port 2375 was added"
  Write-Output "- A new windows service (${REQKICK_SERVICE_NAME}) was created"
}

check_required_envs($REQUIRED_ENVS)
remove_reqKick
remove_reqProc
setup_dirs
if ($NODE_TYPE_CODE -ne 7001) {
  initialize
}
# DOCKER_VERSION needs to be set here because Docker will definitely be available
# at this point and we use it it the setup_envs function that's called below
$DOCKER_VERSION = iex "docker version --format '{{.Server.Version}}'"
setup_mounts
setup_envs
setup_opts
boot_reqProc
boot_reqKick
cleanup
print_summary
