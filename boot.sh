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
readonly SHIPPABLE_NODE_INIT_SCRIPT="$SCRIPTS_DIR/$SHIPPABLE_NODE_INIT_SCRIPT"
readonly SHIPPABLE_ENV="$USR_DIR/node.env"

source "$LIB_DIR/logger.sh"

# End Global variables #################################### 
###########################################################

info() {
  echo "Executing node boot script"
  echo "Init script location: $SHIPPABLE_NODE_INIT_SCRIPT"
  if [ ! -f "$SHIPPABLE_NODE_INIT_SCRIPT" ]; then
    echo "Error!!! No init script found at $SHIPPABLE_NODE_INIT_SCRIPT"
    exit 1
  fi

  echo "Env file location: $SHIPPABLE_ENV"
  if [ ! -f "$SHIPPABLE_ENV" ]; then
    echo "Error!!! No environment file found at $SHIPPABLE_ENV"
    exit 1
  else
    echo "Loading shippable envs"
    cat $SHIPPABLE_ENV
    source $SHIPPABLE_ENV
  fi
}

boot() {
  echo "Executing genexec boot..."
}

main() {
  info

  if [ $SHIPPABLE_NODE_INIT == true ]; then
    echo "Node init set to true, initializing node"
    source $SHIPPABLE_NODE_INIT_SCRIPT
  else
    echo "Node init set to false, skipping node init"
  fi

  boot
}

main
