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
    'SHIPPABLE_AMI_VERSION'
    'REQKICK_DOWNLOAD_URL'
    'CEXEC_DOWNLOAD_URL'
    'REPORTS_DOWNLOAD_URL'
  )

  check_envs "${expected_envs[@]}"
}

initialize() {
  __process_marker "Initializing node..."
  source $NODE_INIT_SCRIPT
}

cleanup() {
  __process_marker "Cleaning up..."
  rm -f "$NODE_ENV"
}

main() {
  check_input
  initialize
  cleanup
}

main
