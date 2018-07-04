#!/bin/bash
set -e
set -o pipefail

# Main directories
readonly SHIPPABLE_DIR="$HOME/nodeData"

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

# Helper methods
source "$NODE_LIB_DIR/logger.sh"
source "$NODE_LIB_DIR/helpers.sh"

# TODO: The regular headers don't work for macOS due to differences in obtained uuid.
# We need a way to have OS specific commons.
exec_cmd() {
  cmd=$@
  cmd_uuid=$(uuidgen | awk '{print tolower($0)}')
  cmd_start_timestamp=`date +"%s"`
  echo "__SH__CMD__START__|{\"type\":\"cmd\",\"sequenceNumber\":\"$cmd_start_timestamp\",\"id\":\"$cmd_uuid\"}|$cmd"
  eval $cmd
  cmd_status=$?
  cmd_end_timestamp=`date +"%s"`
  echo "__SH__CMD__END__|{\"type\":\"cmd\",\"sequenceNumber\":\"$cmd_start_timestamp\",\"id\":\"$cmd_uuid\",\"completed\":\"$cmd_status\"}|$cmd"
  return $cmd_status
}

exec_grp() {
  group_name=$1
  group_uuid=$(uuidgen | awk '{print tolower($0)}')
  group_start_timestamp=`date +"%s"`
  echo "__SH__GROUP__START__|{\"type\":\"grp\",\"sequenceNumber\":\"$group_start_timestamp\",\"id\":\"$group_uuid\"}|$group_name"
  eval "$group_name"
  group_status=$?
  group_end_timestamp=`date +"%s"`
  echo "__SH__GROUP__END__|{\"type\":\"grp\",\"sequenceNumber\":\"$group_end_timestamp\",\"id\":\"$group_uuid\",\"completed\":\"$group_status\"}|$group_name"
}
# End helper methods

check_input() {
  local expected_envs=(
    'EXEC_IMAGE'
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
  )

  check_envs "${expected_envs[@]}"
}

cleanup() {
  __process_marker "Cleaning up..."
  rm -f "$NODE_ENV"
}

initialize() {
  __process_marker "Initializing node..."
  source $NODE_INIT_SCRIPT
}

main() {
  check_input
  initialize
  cleanup
}

main
