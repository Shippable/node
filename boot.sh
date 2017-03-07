#!/bin/bash
set -e
set -o pipefail

###########################################################
#
# Shippable Node Manager
#
# Supported OS: Ubuntu 14.04
# Supported bash: 4.3.11
###########################################################

# Global variables ########################################
###########################################################

readonly ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SCRIPTS_DIR="$ROOT_DIR/scripts"
readonly LIB_DIR="$ROOT_DIR/lib"
readonly SHIPPABLE_DIR="/etc/shippable"
readonly LOGS_DIR="$SHIPPABLE_DIR/logs"
readonly TIMESTAMP="$(date +%Y_%m_%d_%H:%M:%S)"
readonly LOG_FILE="$LOGS_DIR/${TIMESTAMP}_logs.txt"
readonly MAX_DEFAULT_LOG_COUNT=6
readonly NODE_ENV="$SHIPPABLE_DIR/node.env"
readonly MESSAGE_STORE_LOCATION="/tmp/cexec"
readonly KEY_STORE_LOCATION="/tmp/ssh"
readonly CEXEC_LOCATION_ON_HOST="/home/shippable/cexec"
readonly BUILD_LOCATION="/build"
readonly DOCKER_CLIENT_LEGACY="/usr/bin/docker"
readonly DOCKER_CLIENT_LATEST="/opt/docker/docker"

source "$LIB_DIR/logger.sh"
source "$LIB_DIR/headers.sh"

# End Global variables ####################################
###########################################################
info() {
  __process_marker "Checking environment"

  __process_msg "Env file location: $NODE_ENV"
  if [ ! -f "$NODE_ENV" ]; then
    __process_error "Error!!! No environment file found at $NODE_ENV"
    exit 1
  else
    __process_msg "Loading shippable envs"
    cat $NODE_ENV
    source $NODE_ENV
  fi

  readonly NODE_INIT_SCRIPT="$SCRIPTS_DIR/$SHIPPABLE_NODE_INIT_SCRIPT"
  __process_msg "Init script location: $NODE_INIT_SCRIPT"
  if [ ! -f "$NODE_INIT_SCRIPT" ]; then
    __process_msg "Error!!! No init script found at $NODE_INIT_SCRIPT"
    exit 1
  else
    __process_msg "Found init script at: $NODE_INIT_SCRIPT"
  fi

}

initialize() {
  __process_marker "Executing node init script: $NODE_INIT_SCRIPT"
  source $NODE_INIT_SCRIPT

  __process_msg "Pulling exec image"
  if [ "$EXEC_IMAGE" == "" ]; then
    __process_msg "No exec image defined, skipping pull"
  else
    __process_msg "Pulling exec image: $EXEC_IMAGE"
    exec_cmd "docker pull '$EXEC_IMAGE'"
  fi

  __process_msg "Pulling cexec repo"
  if [ -d "$CEXEC_LOCATION_ON_HOST" ]; then
    exec_cmd "sudo rm -rf $CEXEC_LOCATION_ON_HOST"
  fi
  exec_cmd "git clone https://github.com/Shippable/cexec.git $CEXEC_LOCATION_ON_HOST"
  __process_msg "Checking out tag: $SHIPPABLE_RELEASE_VERSION in $CEXEC_LOCATION_ON_HOST"
  pushd $CEXEC_LOCATION_ON_HOST
  exec_cmd "git checkout $SHIPPABLE_RELEASE_VERSION"
  popd
}

remove_stale_containers() {
  __process_marker "Removing stale containers"
  if [ "$EXEC_CONTAINER_NAME" == "" ]; then
    __process_msg "No exec container name specified for stopping"
  else
    local rm_cmd="sudo docker rm -f -v $EXEC_CONTAINER_NAME"
    __process_msg "Executing $rm_cmd"
    eval "$rm_cmd" || true
  fi
}

boot() {
  __process_marker  "Executing genexec boot..."

  __process_msg "Loading shippable envs"
  source $NODE_ENV

  if [ "$EXEC_CONTAINER_NAME" == "" ]; then
    __process_msg "No container name specified for booting, skipping"
  else
    local docker_client_location=$DOCKER_CLIENT_LEGACY
    local is_docker_legacy=true

    if [ -f "$DOCKER_CLIENT_LATEST" ]; then
      is_docker_legacy=false
      docker_client_location=$DOCKER_CLIENT_LATEST
    fi

    local exec_mounts="$EXEC_MOUNTS \
      -v /usr/lib/x86_64-linux-gnu/libapparmor.so.1.1.0:/lib/x86_64-linux-gnu/libapparmor.so.1:rw \
      -v /var/run:/var/run:rw \
      -v $docker_client_location:/usr/bin/docker:rw \
      -v /var/run/docker.sock:/var/run/docker.sock:rw"

    local exec_envs=" -e SHIPPABLE_AMQP_URL=$SHIPPABLE_AMQP_URL \
      -e SHIPPABLE_API_URL=$SHIPPABLE_API_URL \
      -e LISTEN_QUEUE=$LISTEN_QUEUE \
      -e NODE_ID=$NODE_ID \
      -e RUN_MODE=$RUN_MODE \
      -e COMPONENT=$COMPONENT \
      -e SHIPPABLE_AMQP_DEFAULT_EXCHANGE=$SHIPPABLE_AMQP_DEFAULT_EXCHANGE \
      -e SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
      -e NODE_TYPE_CODE=$NODE_TYPE_CODE \
      -e IS_DOCKER_LEGACY=$is_docker_legacy \
      -e DOCKER_CLIENT_LATEST=$DOCKER_CLIENT_LATEST \
      -e DOCKER_CLIENT_LEGACY=$DOCKER_CLIENT_LEGACY "

    local start_cmd="sudo docker run -d \
            --restart=always \
            $exec_envs \
            $EXEC_MOUNTS \
            --name=$EXEC_CONTAINER_NAME \
            $EXEC_OPTS \
            $EXEC_IMAGE"
    __process_msg "executing $start_cmd"
    eval "$start_cmd"
  fi

}

main() {
  info

  if [ $SHIPPABLE_NODE_INIT == true ]; then
    echo "Node init set to true, initializing node"
    initialize
  else
    echo "Node init set to false, skipping node init"
  fi

  remove_stale_containers
  boot
}

main
