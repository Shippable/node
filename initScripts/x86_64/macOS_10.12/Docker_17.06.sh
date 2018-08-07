#!/bin/bash
set -e
set -o pipefail

# initScript for macOS 10.12 and Docker 17.06
# ------------------------------------------------------------------------------

export SHIPPABLE_RUNTIME_DIR="$HOME/shippableRuntime"
export BASE_UUID="$(uuidgen | awk '{print tolower($0)}')"
export BASE_DIR="$SHIPPABLE_RUNTIME_DIR/$BASE_UUID"
export REQPROC_DIR="$BASE_DIR/reqProc"
export REQEXEC_DIR="$BASE_DIR/reqExec"
export REQEXEC_BIN_PATH="$REQEXEC_DIR/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/dist/main/main"
export REQKICK_DIR="$BASE_DIR/reqKick"
export REQKICK_SERVICE_DIR="$REQKICK_DIR/init/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM"
export BUILD_DIR="$BASE_DIR/build"
export STATUS_DIR=$BUILD_DIR/status
export SCRIPTS_DIR=$BUILD_DIR/scripts
export REQPROC_MOUNTS=""
export REQPROC_ENVS=""
export REQPROC_OPTS=""
export REQPROC_CONTAINER_NAME_PATTERN="reqProc"
export REQPROC_CONTAINER_NAME="$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
export REQKICK_SERVICE_NAME_PATTERN="com.shippable.reqKick"
export DEFAULT_TASK_CONTAINER_MOUNTS="-v $BUILD_DIR:$BUILD_DIR \
  -v $REQEXEC_DIR:/reqExec"
export TASK_CONTAINER_COMMAND="/reqExec/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/dist/main/main"
export DEFAULT_TASK_CONTAINER_OPTIONS="-d --rm"

export SERVICE_DIR="/Library/LaunchDaemons"
export FILE_SUFFIX="plist"

install_prereqs() {
  echo "Installing prerequisite binaries"

  echo "Installing shipctl components"
  exec_cmd "$NODE_SHIPCTL_LOCATION/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/install.sh"
}

setup_mounts() {
  __process_marker "Setting up mounts..."

  rm -rf $SHIPPABLE_RUNTIME_DIR
  mkdir -p $BASE_DIR
  mkdir -p $REQPROC_DIR
  mkdir -p $REQEXEC_DIR
  mkdir -p $REQKICK_DIR
  mkdir -p $BUILD_DIR

  REQPROC_MOUNTS="$REQPROC_MOUNTS \
    -v $BASE_DIR:$BASE_DIR \
    -v /var/run/docker.sock:/var/run/docker.sock"
  if [ "$IS_RESTRICTED_NODE" != "true" ]; then
    DEFAULT_TASK_CONTAINER_MOUNTS="$DEFAULT_TASK_CONTAINER_MOUNTS \
      -v /var/run/docker.sock:/var/run/docker.sock"
  fi
}

setup_envs() {
  __process_marker "Setting up envs..."

  REQPROC_ENVS="$REQPROC_ENVS \
    -e SHIPPABLE_AMQP_URL=$SHIPPABLE_AMQP_URL \
    -e SHIPPABLE_AMQP_DEFAULT_EXCHANGE=$SHIPPABLE_AMQP_DEFAULT_EXCHANGE \
    -e SHIPPABLE_API_URL=$SHIPPABLE_API_URL \
    -e LISTEN_QUEUE=$LISTEN_QUEUE \
    -e NODE_ID=$NODE_ID \
    -e RUN_MODE=$RUN_MODE \
    -e SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
    -e NODE_TYPE_CODE=$NODE_TYPE_CODE \
    -e BASE_DIR=$BASE_DIR \
    -e REQPROC_DIR=$REQPROC_DIR \
    -e REQEXEC_DIR=$REQEXEC_DIR \
    -e REQEXEC_BIN_DIR=$REQEXEC_BIN_DIR \
    -e REQKICK_DIR=$REQKICK_DIR \
    -e BUILD_DIR=$BUILD_DIR \
    -e REQPROC_CONTAINER_NAME=$REQPROC_CONTAINER_NAME \
    -e DEFAULT_TASK_CONTAINER_MOUNTS='$DEFAULT_TASK_CONTAINER_MOUNTS' \
    -e TASK_CONTAINER_COMMAND=$TASK_CONTAINER_COMMAND \
    -e DEFAULT_TASK_CONTAINER_OPTIONS='$DEFAULT_TASK_CONTAINER_OPTIONS' \
    -e EXEC_IMAGE=$EXEC_IMAGE \
    -e SHIPPABLE_DOCKER_VERSION=$DOCKER_VERSION \
    -e SHIPPABLE_NODE_ARCHITECTURE=$NODE_ARCHITECTURE \
    -e SHIPPABLE_NODE_OPERATING_SYSTEM=$NODE_OPERATING_SYSTEM \
    -e SHIPPABLE_RELEASE_VERSION=$SHIPPABLE_RELEASE_VERSION \
    -e SHIPPABLE_AMI_VERSION=$SHIPPABLE_AMI_VERSION \
    -e SHIPPABLE_NODE_SCRIPTS_LOCATION=$NODE_SCRIPTS_LOCATION \
    -e CLUSTER_TYPE_CODE=$CLUSTER_TYPE_CODE \
    -e IS_RESTRICTED_NODE=$IS_RESTRICTED_NODE"
}

setup_opts() {
  __process_marker "Setting up opts..."

  REQPROC_OPTS="$REQPROC_OPTS \
    -d \
    --restart=always \
    --name=$REQPROC_CONTAINER_NAME \
    "
}

remove_reqProc() {
  __process_marker "Removing exisiting reqProc containers..."

  local running_container_ids=$(docker ps -a \
    | grep $REQPROC_CONTAINER_NAME_PATTERN \
    | awk '{print $1}')

  if [ ! -z "$running_container_ids" ]; then
    docker rm -f -v $running_container_ids || true
  fi
}

remove_reqKick() {
  __process_marker "Removing existing reqKick services..."

  sudo launchctl unload $SERVICE_DIR/$REQKICK_SERVICE_NAME_PATTERN.*.$FILE_SUFFIX
  sudo rm -f $SERVICE_DIR/$REQKICK_SERVICE_NAME_PATTERN.*.$FILE_SUFFIX || true
}

boot_reqProc() {
  __process_marker "Booting up reqProc..."

  docker pull $EXEC_IMAGE
  local start_cmd="docker run $REQPROC_OPTS $REQPROC_MOUNTS $REQPROC_ENVS $EXEC_IMAGE"
  eval "$start_cmd"
}

boot_reqKick() {
  __process_marker "Booting up reqKick service..."

  local reqKick_tar_file="reqKick.tar.gz"

  rm -rf $REQKICK_DIR
  rm -rf $reqKick_tar_file
  pushd /tmp
    curl -LkSsv $REQKICK_DOWNLOAD_URL -o $reqKick_tar_file
    mkdir -p $REQKICK_DIR
    tar -xzf $reqKick_tar_file -C $REQKICK_DIR --strip-components=1
    rm -rf $reqKick_tar_file
  popd
  pushd $REQKICK_DIR
    npm install

    local reqkick_template_dir="$REQKICK_DIR/init/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM"
    local service_template_location="$reqkick_template_dir/$REQKICK_SERVICE_NAME_PATTERN.$FILE_SUFFIX.template"

    local service_file="$REQKICK_SERVICE_NAME_PATTERN.$BASE_UUID.$FILE_SUFFIX"
    local service_location="$SERVICE_DIR/$service_file"

    sudo cp $service_template_location $service_location
    sudo chmod 644 $service_location

    sudo sed -i '' "s#{{STATUS_DIR}}#$STATUS_DIR#g" $service_location
    sudo sed -i '' "s#{{SCRIPTS_DIR}}#$SCRIPTS_DIR#g" $service_location
    sudo sed -i '' "s#{{REQEXEC_BIN_PATH}}#$REQEXEC_BIN_PATH#g" $service_location
    sudo sed -i '' "s#{{RUN_MODE}}#$RUN_MODE#g" $service_location
    sudo sed -i '' "s#{{UUID}}#$BASE_UUID#g" $service_location
    sudo sed -i '' "s#{{REQKICK_DIR}}#$REQKICK_DIR#g" $service_location
    sudo sed -i '' "s#{{NODE_PATH}}#$(which node)#g" $service_location
    sudo sed -i '' "s#{{USER_NAME}}#$USER#g" $service_location
    sudo sed -i '' "s#{{PATH}}#$PATH#g" $service_location
    sudo sed -i '' "s#{{NODE_ID}}#$NODE_ID#g" $service_location
    sudo sed -i '' "s#{{SUBSCRIPTION_ID}}#$SUBSCRIPTION_ID#g" $service_location
    sudo sed -i '' "s#{{NODE_TYPE_CODE}}#$NODE_TYPE_CODE#g" $service_location
    sudo sed -i '' "s#{{SHIPPABLE_NODE_ARCHITECTURE}}#$NODE_ARCHITECTURE#g" $service_location
    sudo sed -i '' "s#{{SHIPPABLE_NODE_OPERATING_SYSTEM}}#$NODE_OPERATING_SYSTEM#g" $service_location
    sudo sed -i '' "s#{{SHIPPABLE_API_URL}}#$SHIPPABLE_API_URL#g" $service_location

    sudo launchctl load $service_location

    local running_service_names=$(sudo launchctl list \
      | grep $REQKICK_SERVICE_NAME_PATTERN | awk '{ print $3 }')

    if [ ! -z "$running_service_names" ]; then
      echo "$service_location is RUNNING"
    else
      echo "$service_location FAILED to start"
      exit 1
    fi
  popd
}

before_exit() {
  echo $1
  echo $2

  echo "Node init script completed"
}

main() {
  trap before_exit EXIT
  exec_grp "install_prereqs"

  trap before_exit EXIT
  exec_grp "setup_mounts"

  trap before_exit EXIT
  exec_grp "setup_envs"

  trap before_exit EXIT
  exec_grp "setup_opts"

  trap before_exit EXIT
  exec_grp "remove_reqProc"

  trap before_exit EXIT
  exec_grp "remove_reqKick"

  trap before_exit EXIT
  exec_grp "boot_reqProc"

  trap before_exit EXIT
  exec_grp "boot_reqKick"
}

main
