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
readonly CACHE_STORE_LOCATION="/home/shippable/cache"
readonly BUILD_LOCATION="/build"
readonly DOCKER_CLIENT_LEGACY="/usr/bin/docker"
readonly DOCKER_CLIENT_LATEST="/opt/docker/docker"
readonly BOOT_WAIT_TIME=10
readonly SWAP_FILE_PATH="/root/.__sh_swap__"

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
    exec_cmd "sudo docker pull '$EXEC_IMAGE'"
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

remove_stale_exec() {
  __process_marker "Removing stale exec containers"

  local running_container_ids=$(sudo docker ps -a \
    | grep $EXEC_CONTAINER_NAME_PATTERN \
    | awk '{print $1}')

  if [ ! -z "$running_container_ids" ]; then
    __process_msg "Stopping containers: $running_container_ids"
    local rm_cmd="sudo docker rm -f -v $running_container_ids"
    __process_msg "Executing $rm_cmd"
    eval "$rm_cmd" || true
  else
    __process_msg "No exec containers running"
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
    __process_msg "Docker client location on host: $docker_client_location"

    mkdir -p $CACHE_STORE_LOCATION
    mkdir -p $KEY_STORE_LOCATION
    mkdir -p $MESSAGE_STORE_LOCATION
    mkdir -p $BUILD_LOCATION

    local exec_mounts="$EXEC_MOUNTS \
      -v /usr/lib/x86_64-linux-gnu/libapparmor.so.1.1.0:/lib/x86_64-linux-gnu/libapparmor.so.1:rw \
      -v /var/run:/var/run:rw \
      -v $docker_client_location:/usr/bin/docker:rw \
      -v /var/run/docker.sock:/var/run/docker.sock:rw \
      -v $CACHE_STORE_LOCATION:$CACHE_STORE_LOCATION:rw \
      -v $KEY_STORE_LOCATION:$KEY_STORE_LOCATION:rw \
      -v $MESSAGE_STORE_LOCATION:$MESSAGE_STORE_LOCATION:rw \
      -v $BUILD_LOCATION:$BUILD_LOCATION:rw "

    local exec_envs=" -e SHIPPABLE_AMQP_URL=$SHIPPABLE_AMQP_URL \
      -e SHIPPABLE_API_URL=$SHIPPABLE_API_URL \
      -e LISTEN_QUEUE=$LISTEN_QUEUE \
      -e NODE_ID=$NODE_ID \
      -e RUN_MODE=$RUN_MODE \
      -e COMPONENT=$COMPONENT \
      -e CACHE_STORE_LOCATION=$CACHE_STORE_LOCATION \
      -e KEY_STORE_LOCATION=$KEY_STORE_LOCATION \
      -e MESSAGE_STORE_LOCATION=$MESSAGE_STORE_LOCATION \
      -e BUILD_LOCATION=$BUILD_LOCATION \
      -e SHIPPABLE_AMQP_DEFAULT_EXCHANGE=$SHIPPABLE_AMQP_DEFAULT_EXCHANGE \
      -e SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
      -e NODE_TYPE_CODE=$NODE_TYPE_CODE \
      -e IS_DOCKER_LEGACY=$is_docker_legacy \
      -e DOCKER_CLIENT_LATEST=$DOCKER_CLIENT_LATEST \
      -e EXEC_IMAGE=$EXEC_IMAGE \
      -e DOCKER_CLIENT_LEGACY=$DOCKER_CLIENT_LEGACY "

    local start_cmd="sudo docker run -d \
            --restart=always \
            $exec_envs \
            $exec_mounts \
            --name=$EXEC_CONTAINER_NAME \
            $EXEC_OPTS \
            $EXEC_IMAGE"
    __process_msg "executing $start_cmd"
    eval "$start_cmd"
  fi

}

verify_running_exec() {
  if [ "$NODE_TYPE_CODE" != "7001" ]; then
    ## only check for non-dynamic nodes
    sleep $BOOT_WAIT_TIME
    local inspect_json=$(sudo docker inspect $EXEC_CONTAINER_NAME)
    {
      local is_running=$(echo $inspect_json \
        | grep 'Running' \
        | grep 'true')
      __process_msg "Container $EXEC_CONTAINER_NAME successfully running"
    } || {
      __process_error "Container $EXEC_CONTAINER_NAME not running"
      exit 1
    }
  else
    __process_msg "Skipping exec run check for dynamic nodes"
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

  remove_stale_exec
  boot
  verify_running_exec
}

main
