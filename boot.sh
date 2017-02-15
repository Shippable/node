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
readonly USR_DIR="$ROOT_DIR/usr"
readonly LOGS_DIR="$USR_DIR/logs"
readonly TIMESTAMP="$(date +%Y_%m_%d_%H:%M:%S)"
readonly LOG_FILE="$LOGS_DIR/${TIMESTAMP}_logs.txt"
readonly MAX_DEFAULT_LOG_COUNT=6
readonly NODE_ENV="$USR_DIR/node.env"

source "$LIB_DIR/logger.sh"

# End Global variables #################################### 
###########################################################

info() {
  echo "Executing node boot script"

  echo "Env file location: $NODE_ENV"
  if [ ! -f "$NODE_ENV" ]; then
    echo "Error!!! No environment file found at $NODE_ENV"
    exit 1
  else
    echo "Loading shippable envs"
    cat $NODE_ENV
    source $NODE_ENV
  fi

  readonly NODE_INIT_SCRIPT="$SCRIPTS_DIR/$SHIPPABLE_NODE_INIT_SCRIPT"
  echo "Init script location: $NODE_INIT_SCRIPT"
  if [ ! -f "$NODE_INIT_SCRIPT" ]; then
    echo "Error!!! No init script found at $NODE_INIT_SCRIPT"
    exit 1
  else 
    echo "Found init script at: $NODE_INIT_SCRIPT"
  fi

}

initialize() {
  echo "Executing node init script: $NODE_INIT_SCRIPT"
  source $NODE_INIT_SCRIPT
}

boot() {
  echo "Executing genexec boot..."
}

main() {
  info

  if [ $SHIPPABLE_NODE_INIT == true ]; then
    echo "Node init set to true, initializing node"
    initialize
  else
    echo "Node init set to false, skipping node init"
  fi

  boot
}

main
