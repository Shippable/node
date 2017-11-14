#!/bin/bash -e
set -o pipefail

# Main directories
readonly NODE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly SHIPPABLE_DIR="/etc/shippable"

# Node Sub-directories
readonly NODE_INIT_SCRIPTS_DIR="$NODE_DIR/initScripts"
readonly NODE_LIB_DIR="$NODE_DIR/lib"

# Logs
readonly LOGS_DIR="$SHIPPABLE_DIR/logs"
readonly TIMESTAMP="$(date +%Y_%m_%d_%H:%M:%S)"
readonly LOG_FILE="$LOGS_DIR/${TIMESTAMP}_logs.txt"
readonly MAX_DEFAULT_LOG_COUNT=5

# Node ENVs
readonly NODE_ENV="$SHIPPABLE_DIR/_node.env"
source $NODE_ENV

# Scripts
readonly NODE_INIT_SCRIPT="$NODE_INIT_SCRIPTS_DIR/$NODE_INIT_SCRIPT"

# Source libraries
source "$NODE_LIB_DIR/logger.sh"
source "$NODE_LIB_DIR/headers.sh"
source "$NODE_LIB_DIR/helpers.sh"

check_input() {
  local expected_envs=(
    'EXEC_IMAGE'
    'IS_SWAP_ENABLED'
    'LISTEN_QUEUE'
    'NODE_ARCHITECTURE'
    'NODE_DOCKER_VERSION'
    'NODE_ID'
    'NODE_INIT_SCRIPT'
    'NODE_OPERATING_SYSTEM'
    'NODE_TYPE_CODE'
    'RUN_MODE'
    'SHIPPABLE_AMQP_DEFAULT_EXCHANGE'
    'SHIPPABLE_AMQP_URL'
    'SHIPPABLE_API_URL'
    'SHIPPABLE_RELEASE_VERSION'
    'SUBSCRIPTION_ID',
  )

  check_envs "${expected_envs[@]}"
}

initialize() {
  __process_marker "Initializing node..."
  source $NODE_INIT_SCRIPT
}


main() {
  check_input
  initialize
}

main
