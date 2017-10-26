#!/bin/bash -e
set -o pipefail

# Main directories
readonly NODE_SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SHIPPABLE_DIR="/etc/shippable"

# Node Sub-directories
readonly SCRIPTS_DIR="$NODE_SCRIPTS_DIR/initScripts"
readonly LIB_DIR="$NODE_SCRIPTS_DIR/lib"

# Logs
readonly LOGS_DIR="$SHIPPABLE_DIR/logs"
readonly TIMESTAMP="$(date +%Y_%m_%d_%H:%M:%S)"
readonly LOG_FILE="$LOGS_DIR/${TIMESTAMP}_logs.txt"
readonly MAX_DEFAULT_LOG_COUNT=5

# Node ENVs
readonly NODE_ENV="$SHIPPABLE_DIR/_node.env"
source $NODE_ENV

# Scripts
readonly NODE_INIT_SCRIPT="$SCRIPTS_DIR/$NODE_INIT_SCRIPT"

# Source libraries
source "$LIB_DIR/logger.sh"
source "$LIB_DIR/headers.sh"
source "$LIB_DIR/helpers.sh"

check_input() {
  local expected_envs=(
    'EXEC_IMAGE'
    'IS_SWAP_ENABLED'
    'LISTEN_QUEUE'
    'NODE_ARCHITECTURE'
    'NODE_DOCKER_VERSION'
    'NODE_ID'
    'NODE_INIT_SCRIPT'
    'NODE_OPERATING_SYSTEM_NAME'
    'NODE_OPERATING_SYSTEM_VERSION'
    'NODE_TYPE_CODE'
    'RUN_MODE'
    'SHIPPABLE_AMQP_DEFAULT_EXCHANGE'
    'SHIPPABLE_AMQP_URL'
    'SHIPPABLE_API_URL'
    'SUBSCRIPTION_ID',
  )

  check_envs "${expected_envs[@]}"
}

initialize() {
  __process_marker "Initializing node..."
  source $NODE_INIT_SCRIPT

  local expected_envs=(
    'REQPROC_CONTAINER_NAME_PATTERN'
    'REQPROC_OPTS'
    'REQPROC_MOUNTS'
    'REQPROC_ENVS'
    'REQKICK_DIR'
  )

  check_envs "${expected_envs[@]}"
}

remove_reqProc() {
  __process_marker "Remove exisiting reqProc containers..."

  local running_container_ids=$(sudo docker ps -a \
    | grep $REQPROC_CONTAINER_NAME_PATTERN \
    | awk '{print $1}')

  if [ ! -z "$running_container_ids" ]; then
    sudo docker rm -f -v $running_container_ids || true
  fi
}

boot_reqProc() {
  __process_marker "Booting up reqProc..."
  sudo docker run $REQPROC_OPTS $REQPROC_MOUNTS $REQPROC_ENVS $EXEC_IMAGE
}

boot_reqKick() {
  __process_marker "Booting up reqKick..."
  # TODO: This is just for the plumbing. This needs to change once we have
  # reqKick service available.
  git clone https://github.com/Shippable/reqKick.git $REQKICK_DIR
  $REQKICK_DIR/init.sh &>/dev/null &
}

main () {
  check_input
  initialize
  remove_reqProc
  boot_reqProc
  boot_reqKick
}

main
