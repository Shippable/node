#!/bin/bash
set -e
set -o pipefail

# Main directories
readonly SHIPPABLE_DIR="/etc/shippable"

# Logs
readonly LOGS_DIR="$SHIPPABLE_DIR/logs"
readonly TIMESTAMP="$(date +%Y_%m_%d_%H:%M:%S)"
readonly LOG_FILE="$LOGS_DIR/${TIMESTAMP}_logs.txt"
readonly MAX_DEFAULT_LOG_COUNT=5

# Node ENVs
readonly NODE_ENV="$SHIPPABLE_DIR/_node.env"
source $NODE_ENV

# Scripts
readonly NODE_INIT_SCRIPT="$NODE_SCRIPTS_LOCATION/initScripts/$NODE_INIT_SCRIPT"
readonly NODE_LIB_DIR="$NODE_SCRIPTS_LOCATION/lib"
readonly NODE_SHIPCTL_LOCATION="$NODE_SCRIPTS_LOCATION/shipctl"

# Source libraries
source "$NODE_LIB_DIR/logger.sh"
source "$NODE_LIB_DIR/headers.sh"
source "$NODE_LIB_DIR/helpers.sh"

check_input() {
  local expected_envs=(
    'EXEC_IMAGE'
    'LISTEN_QUEUE'
    'NODE_ARCHITECTURE'
    'NODE_ID'
    'NODE_INIT_SCRIPT'
    'NODE_OPERATING_SYSTEM'
    'NODE_TYPE_CODE'
    'RUN_MODE'
    'SHIPPABLE_AMQP_DEFAULT_EXCHANGE'
    'SHIPPABLE_AMQP_URL'
    'SHIPPABLE_API_URL'
    'SHIPPABLE_AMI_VERSION'
    'SHIPPABLE_RELEASE_VERSION'
  )

  check_envs "${expected_envs[@]}"
}

export_envs() {
  export SHIPPABLE_RUNTIME_DIR="/var/lib/shippable"
  if [ "$NODE_TYPE_CODE" -eq 7001 ]; then
    export BASE_UUID="$NODE_ID"
    export BASE_DIR="$SHIPPABLE_RUNTIME_DIR"
  else
    export BASE_UUID="$(cat /proc/sys/kernel/random/uuid)"
    export BASE_DIR="$SHIPPABLE_RUNTIME_DIR/$BASE_UUID"
  fi
  export REQPROC_DIR="$BASE_DIR/reqProc"
  export REQEXEC_DIR="$BASE_DIR/reqExec"
  export REQEXEC_BIN_PATH="$REQEXEC_DIR/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/dist/main/main"
  export REQKICK_DIR="$BASE_DIR/reqKick"
  export REQKICK_SERVICE_DIR="$REQKICK_DIR/init/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM"
  export REQKICK_CONFIG_DIR="/etc/shippable/reqKick"
  export BUILD_DIR="$BASE_DIR/build"
  export STATUS_DIR=$BUILD_DIR/status
  export SCRIPTS_DIR=$BUILD_DIR/scripts
  # This is set while booting dynamic nodes
  export REQPROC_MOUNTS="$REQPROC_MOUNTS"
  export REQPROC_ENVS="$REQPROC_ENVS"
  export REQPROC_OPTS="$REQPROC_OPTS"
  export REQPROC_CONTAINER_NAME_PATTERN="reqProc"
  export EXEC_CONTAINER_NAME_PATTERN="shippable-exec"

  if [ "$NODE_TYPE_CODE" -eq 7001 ]; then
    export REQPROC_CONTAINER_NAME="$REQPROC_CONTAINER_NAME_PATTERN-$NODE_ID"
  else
    export REQPROC_CONTAINER_NAME="$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
  fi
  export REQKICK_SERVICE_NAME_PATTERN="shippable-reqKick@"
  export LEGACY_CI_CACHE_STORE_LOCATION="/home/shippable/cache"
  export LEGACY_CI_KEY_STORE_LOCATION="/tmp/ssh"
  export LEGACY_CI_MESSAGE_STORE_LOCATION="/tmp/cexec"
  export LEGACY_CI_BUILD_LOCATION="/build"
  export LEGACY_CI_CEXEC_LOCATION_ON_HOST="/home/shippable/cexec"
  export LEGACY_CI_DOCKER_CLIENT_LATEST="/opt/docker/docker"
  export DEFAULT_TASK_CONTAINER_MOUNTS="-v $BUILD_DIR:$BUILD_DIR \
    -v $REQEXEC_DIR:/reqExec"
  export TASK_CONTAINER_COMMAND="/reqExec/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/dist/main/main"
  export DEFAULT_TASK_CONTAINER_OPTIONS="-d --rm"
  export DOCKER_VERSION="$(sudo docker version --format {{.Server.Version}})"
}

setup_dirs() {
  if [ "$NODE_TYPE_CODE" -ne 7001 ]; then
    rm -rf $SHIPPABLE_RUNTIME_DIR
  fi
  mkdir -p $BASE_DIR
  mkdir -p $REQPROC_DIR
  mkdir -p $REQEXEC_DIR
  mkdir -p $REQKICK_DIR
  mkdir -p $BUILD_DIR
  mkdir -p $LEGACY_CI_CACHE_STORE_LOCATION
  mkdir -p $LEGACY_CI_KEY_STORE_LOCATION
  mkdir -p $LEGACY_CI_MESSAGE_STORE_LOCATION
  mkdir -p $LEGACY_CI_BUILD_LOCATION
}

initialize() {
  __process_marker "Initializing node..."
  source $NODE_INIT_SCRIPT
}

setup_mounts() {
  REQPROC_MOUNTS="$REQPROC_MOUNTS \
    -v $BASE_DIR:$BASE_DIR \
    -v /opt/docker/docker:/usr/bin/docker \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $LEGACY_CI_CACHE_STORE_LOCATION:$LEGACY_CI_CACHE_STORE_LOCATION:rw \
    -v $LEGACY_CI_KEY_STORE_LOCATION:$LEGACY_CI_KEY_STORE_LOCATION:rw \
    -v $LEGACY_CI_MESSAGE_STORE_LOCATION:$LEGACY_CI_MESSAGE_STORE_LOCATION:rw \
    -v $LEGACY_CI_BUILD_LOCATION:$LEGACY_CI_BUILD_LOCATION:rw"

  if [ "$IS_RESTRICTED_NODE" == "true" ]; then
    DEFAULT_TASK_CONTAINER_MOUNTS="$DEFAULT_TASK_CONTAINER_MOUNTS \
      -v $NODE_SCRIPTS_LOCATION:/var/lib/shippable/node"
  else
    DEFAULT_TASK_CONTAINER_MOUNTS="$DEFAULT_TASK_CONTAINER_MOUNTS \
      -v /opt/docker/docker:/usr/bin/docker \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v $NODE_SCRIPTS_LOCATION:/var/lib/shippable/node"
  fi
}

setup_envs() {
  REQPROC_ENVS="$REQPROC_ENVS \
    -e SHIPPABLE_AMQP_URL=$SHIPPABLE_AMQP_URL \
    -e SHIPPABLE_AMQP_DEFAULT_EXCHANGE=$SHIPPABLE_AMQP_DEFAULT_EXCHANGE \
    -e SHIPPABLE_API_URL=$SHIPPABLE_API_URL \
    -e LISTEN_QUEUE=$LISTEN_QUEUE \
    -e NODE_ID=$NODE_ID \
    -e RUN_MODE=$RUN_MODE \
    -e SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
    -e NODE_TYPE_CODE=$NODE_TYPE_CODE \
    -e BASE_DIR=$BASE_DIR \
    -e REQPROC_DIR=$REQPROC_DIR \
    -e REQEXEC_DIR=$REQEXEC_DIR \
    -e REQEXEC_BIN_DIR=$REQEXEC_BIN_DIR \
    -e REQKICK_DIR=$REQKICK_DIR \
    -e BUILD_DIR=$BUILD_DIR \
    -e REQPROC_CONTAINER_NAME=$REQPROC_CONTAINER_NAME \
    -e DEFAULT_TASK_CONTAINER_MOUNTS='$DEFAULT_TASK_CONTAINER_MOUNTS' \
    -e TASK_CONTAINER_COMMAND=$TASK_CONTAINER_COMMAND \
    -e DEFAULT_TASK_CONTAINER_OPTIONS='$DEFAULT_TASK_CONTAINER_OPTIONS' \
    -e CACHE_STORE_LOCATION=$LEGACY_CI_CACHE_STORE_LOCATION \
    -e KEY_STORE_LOCATION=$LEGACY_CI_KEY_STORE_LOCATION \
    -e MESSAGE_STORE_LOCATION=$LEGACY_CI_MESSAGE_STORE_LOCATION \
    -e BUILD_LOCATION=$LEGACY_CI_BUILD_LOCATION \
    -e EXEC_IMAGE=$EXEC_IMAGE \
    -e DOCKER_CLIENT_LATEST=$LEGACY_CI_DOCKER_CLIENT_LATEST \
    -e SHIPPABLE_DOCKER_VERSION=$DOCKER_VERSION \
    -e IS_DOCKER_LEGACY=false \
    -e SHIPPABLE_NODE_ARCHITECTURE=$NODE_ARCHITECTURE \
    -e SHIPPABLE_NODE_OPERATING_SYSTEM=$NODE_OPERATING_SYSTEM \
    -e SHIPPABLE_RELEASE_VERSION=$SHIPPABLE_RELEASE_VERSION \
    -e SHIPPABLE_AMI_VERSION=$SHIPPABLE_AMI_VERSION \
    -e SHIPPABLE_NODE_SCRIPTS_LOCATION=$NODE_SCRIPTS_LOCATION \
    -e CLUSTER_TYPE_CODE=$CLUSTER_TYPE_CODE \
    -e IS_RESTRICTED_NODE=$IS_RESTRICTED_NODE"

  if [ ! -z "$SHIPPABLE_HTTP_PROXY" ]; then
    REQPROC_ENVS="$REQPROC_ENVS \
      -e http_proxy=$SHIPPABLE_HTTP_PROXY"
  fi

  if [ ! -z "$SHIPPABLE_HTTPS_PROXY" ]; then
    REQPROC_ENVS="$REQPROC_ENVS \
      -e https_proxy=$SHIPPABLE_HTTPS_PROXY"
  fi

  if [ ! -z "$SHIPPABLE_NO_PROXY" ]; then
    REQPROC_ENVS="$REQPROC_ENVS \
      -e no_proxy=$SHIPPABLE_NO_PROXY"
  fi

  if [ "$NO_VERIFY_SSL" == "true" ]; then
    REQPROC_ENVS="$REQPROC_ENVS \
      -e NODE_TLS_REJECT_UNAUTHORIZED=0"
  fi
}

setup_opts() {
  REQPROC_OPTS="$REQPROC_OPTS \
    -d \
    --restart=always \
    --name=$REQPROC_CONTAINER_NAME \
    "
}

remove_genexec() {
  __process_marker "Removing exisiting genexec containers..."

  local running_container_ids=$(docker ps -a \
    | grep $EXEC_CONTAINER_NAME_PATTERN \
    | awk '{print $1}')

  if [ ! -z "$running_container_ids" ]; then
    docker rm -f -v $running_container_ids || true
  fi
}

remove_reqProc() {
  __process_marker "Removing exisiting reqProc containers..."

  local running_container_ids=$(docker ps -a \
    | grep $REQPROC_CONTAINER_NAME_PATTERN \
    | awk '{print $1}')

  if [ ! -z "$running_container_ids" ]; then
    docker rm -f -v $running_container_ids || true
  fi
}

remove_reqKick() {
  __process_marker "Removing existing reqKick services..."

  local running_service_names=$(systemctl list-units -a \
    | grep $REQKICK_SERVICE_NAME_PATTERN \
    | awk '{ print $1 }')

  if [ ! -z "$running_service_names" ]; then
    systemctl stop $running_service_names || true
    systemctl disable $running_service_names || true
  fi

  rm -rf $REQKICK_CONFIG_DIR
  rm -f /etc/systemd/system/shippable-reqKick@.service

  systemctl daemon-reload
}

boot_reqProc() {
  __process_marker "Booting up reqProc..."

  local start_cmd="docker run $REQPROC_OPTS $REQPROC_MOUNTS $REQPROC_ENVS $EXEC_IMAGE"
  eval "$start_cmd"
}

boot_reqKick() {
  __process_marker "Booting up reqKick service..."

  mkdir -p $REQKICK_CONFIG_DIR

  cp $REQKICK_SERVICE_DIR/shippable-reqKick@.service.template /etc/systemd/system/shippable-reqKick@.service
  chmod 644 /etc/systemd/system/shippable-reqKick@.service

  if [ "$NODE_TYPE_CODE" -eq 7001 ]; then
    sed -i "s#/var/lib/shippable/%i/reqKick/reqKick.app.js#/var/lib/shippable/reqKick/reqKick.app.js#g" /etc/systemd/system/shippable-reqKick@.service
  fi

  local reqkick_env_template=$REQKICK_SERVICE_DIR/shippable-reqKick.env.template
  local reqkick_env_file=$REQKICK_CONFIG_DIR/$BASE_UUID.env
  touch $reqkick_env_file
  sed "s#{{STATUS_DIR}}#$STATUS_DIR#g" $reqkick_env_template > $reqkick_env_file
  sed -i "s#{{SCRIPTS_DIR}}#$SCRIPTS_DIR#g" $reqkick_env_file
  sed -i "s#{{REQEXEC_BIN_PATH}}#$REQEXEC_BIN_PATH#g" $reqkick_env_file
  sed -i "s#{{RUN_MODE}}#$RUN_MODE#g" $reqkick_env_file
  sed -i "s#{{NODE_ID}}#$NODE_ID#g" $reqkick_env_file
  sed -i "s#{{SUBSCRIPTION_ID}}#$SUBSCRIPTION_ID#g" $reqkick_env_file
  sed -i "s#{{NODE_TYPE_CODE}}#$NODE_TYPE_CODE#g" $reqkick_env_file
  sed -i "s#{{SHIPPABLE_NODE_ARCHITECTURE}}#$NODE_ARCHITECTURE#g" $reqkick_env_file
  sed -i "s#{{SHIPPABLE_NODE_OPERATING_SYSTEM}}#$NODE_OPERATING_SYSTEM#g" $reqkick_env_file
  sed -i "s#{{SHIPPABLE_API_URL}}#$SHIPPABLE_API_URL#g" $reqkick_env_file

  systemctl daemon-reload
  systemctl enable shippable-reqKick@$BASE_UUID.service
  systemctl start shippable-reqKick@$BASE_UUID.service

  {
    echo "Checking if shippable-reqKick@$BASE_UUID.service is active"
    local check_reqKick_is_active=$(systemctl is-active shippable-reqKick@$BASE_UUID.service)
    echo "shippable-reqKick@$BASE_UUID.service is $check_reqKick_is_active"
  } ||
  {
    echo "shippable-reqKick@$BASE_UUID.service failed to start"
    journalctl -n 100 -u shippable-reqKick@$BASE_UUID.service
    popd
    exit 1
  }
}

cleanup() {
  __process_marker "Cleaning up..."
  rm -f "$NODE_ENV"
}

before_exit() {
  echo $1
  echo $2

  echo "Boot script completed"
}

main() {
  trap before_exit EXIT
  exec_grp "check_input"

  trap before_exit EXIT
  exec_grp "export_envs"

  trap before_exit EXIT
  exec_grp "setup_dirs"

  if [ "$NODE_TYPE_CODE" -ne 7001 ]; then
    initialize
  fi

  trap before_exit EXIT
  exec_grp "setup_mounts"

  trap before_exit EXIT
  exec_grp "setup_envs"

  trap before_exit EXIT
  exec_grp "setup_opts"

  trap before_exit EXIT
  exec_grp "remove_genexec"

  trap before_exit EXIT
  exec_grp "remove_reqProc"

  trap before_exit EXIT
  exec_grp "remove_reqKick"

  trap before_exit EXIT
  exec_grp "boot_reqProc"

  trap before_exit EXIT
  exec_grp "boot_reqKick"

  trap before_exit EXIT
  exec_grp "cleanup"
}

main
