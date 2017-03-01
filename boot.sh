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

source "$LIB_DIR/logger.sh"

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
}

remove_stale_containers() {
  __process_marker "Removing stale containers"
  local rm_cmd="sudo docker rm -f -v $EXEC_CONTAINER_NAME"
  __process_marker "Executing $rm_cmd"
  eval "$rm_cmd" || true
}

boot() {
  __process_marker  "Executing genexec boot..."

  local exec_envs=" -e SHIPPABLE_AMQP_URL=$SHIPPABLE_AMQP_URL \
    -e SHIPPABLE_API_URL=$SHIPPABLE_API_URL \
    -e LISTEN_QUEUE=$LISTEN_QUEUE \
    -e NODE_ID=$NODE_ID \
    -e SHIPPABLE_API_TOKEN=$SHIPPABLE_API_TOKEN \
    -e RUN_MODE=$RUN_MODE \
    -e COMPONENT=$COMPONENT \
    -e SHIPPABLE_AMQP_DEFAULT_EXCHANGE=$SHIPPABLE_AMQP_DEFAULT_EXCHANGE \
    -e SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
    -e NODE_TYPE_CODE=$NODE_TYPE_CODE \
    -e DOCKER_CLIENT_LATEST=/opt/docker/docker "

  local start_cmd="sudo docker run -d \
          --restart=always \
          $exec_envs \
          $EXEC_MOUNTS \
          --name=$EXEC_CONTAINER_NAME \
          $EXEC_OPTS \
          $EXEC_IMAGE"

  __process_msg "executing $start_cmd"
  eval "$start_cmd"

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
