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

bootstrap_node() {
  #readonly SHIPPABLE_NODE_INIT_REPO_LOCATION=https://api.github.com/repos/Shippable/node/tarball
  readonly SHIPPABLE_NODE_INIT_REPO_LOCATION=https://api.github.com/repos/ric03uec/node/tarball
  readonly SHIPPABLE_NODE_INIT_REPO_DOWNLOAD_LOCATION=/tmp/shippable/node.tar.gz
  readonly SHIPPABLE_NODE_INIT_REPO_LOCAL=/tmp/shippable/node

  echo "Creating $SHIPPABLE_NODE_INIT_REPO_LOCAL"
  mkdir -p $SHIPPABLE_NODE_INIT_REPO_LOCAL

  # TODO:
  #   check curl and tar availability
  #   print bash version

  echo "Downloading Shippable node init repo"
  curl -LkSs \
    "$SHIPPABLE_NODE_INIT_REPO_LOCATION" \
    -o $SHIPPABLE_NODE_INIT_REPO_DOWNLOAD_LOCATION

  echo "Un-taring Shippable node init repo"
  tar -xvzf \
    "$SHIPPABLE_NODE_INIT_REPO_DOWNLOAD_LOCATION" \
    -C $SHIPPABLE_NODE_INIT_REPO_LOCAL \
    --strip-components=1

  /bin/bash $SHIPPABLE_NODE_INIT_REPO_LOCAL/boot.sh
}

main() {
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

  source "$LIB_DIR/logger.sh"

  # End Global variables #################################### 
  ###########################################################

  echo "Running node boot script........."

  # source the file node.env
  # check if SHIPPABLE_NODE_INIT is set
  #   check if SHIPPABLE_NODE_INIT_FILE value is set
  #   execute that script from scripts/ directory
  # run genexec boot command
}

if [ "$0" == "bash" ]; then
  # Running script directly after piping it into bash
  bootstrap_node
else
  # run initialization
  main
fi
