#!/bin/bash -e
set -o pipefail

# initScript for macOS 10.12
# ------------------------------------------------------------------------------

readonly DOCKER_VERSION="17.11.0-ce-rc3"
export docker_restart=false
export NODE_ARCHITECTURE="x86_64"
export NODE_OPERATING_SYSTEM="macOS_10.12"
export BASE_UUID="$(/usr/bin/uuidgen)"

export SERVICE_DIR="/Library/LaunchDaemons"
export CONFIG_DIR="/Library/LaunchAgents"

export SHIPPABLE_LOG_DIR="/var/log/shippable"
export SHIPPABLE_RUNTIME_DIR="/var/lib/shippable"

export BASE_DIR="$SHIPPABLE_RUNTIME_DIR/$BASE_UUID"
export REQPROC_DIR="$BASE_DIR/reqProc"
export REQEXEC_DIR="$BASE_DIR/reqExec"
export REQKICK_DIR="$BASE_DIR/reqKick"
export BUILD_DIR="$BASE_DIR/build"

export REQPROC_CONTAINER_NAME_PATTERN="reqProc"
export REQKICK_SERVICE_NAME_PATTERN="com.shippable.reqKick.cron"
export REQKICK_CONFIG_NAME_PATTERN="com.shippable.setEnv"
export FILE_SUFFIX="plist"

install_prereqs() {
  echo "Installing prerequisite binaries"
  brew update
  easy_install pip
  brew install git wget curl ntp
  #echo 'export PATH="/usr/local/opt/node@4/bin:$PATH"' >> ~/.bash_profile

  pushd /tmp
    echo "Installing node 4.8.5"

    get_node_tar_cmd="wget https://nodejs.org/dist/latest-v4.x/node-v4.8.6-darwin-x64.tar.gz"
    eval "$get_node_tar_cmd"

    node_extract_cmd="tar -xf node-v4.8.6-darwin-x64.tar.gz"
    eval "$node_extract_cmd"

    node_copy_cmd="cp -Rf node-v4.8.6-darwin-x64/{bin,include,lib,share} /usr/local"
    eval "$node_copy_cmd"

    check_node_version_cmd="node -v"
    eval "$check_node_version_cmd"
  popd

  brew update
}

setup_folders() {
  sudo mkdir -p SHIPPABLE_LOG_DIR
  sudo mkdir -p $SHIPPABLE_RUNTIME_DIR

  # clean up if it already exists. This is a problem as multi tenancy is still
  # not going to work. This will delete all running UUIDs
  sudo rm -rf $SHIPPABLE_RUNTIME_DIR

  sudo mkdir -p $BASE_DIR
  sudo mkdir -p $REQPROC_DIR
  sudo mkdir -p REQEXEC_DIR
  sudo mkdir -p $REQKICK_DIR
  sudo mkdir -p $BUILD_DIR
}

remove_reqProc() {
  echo "Removing existing reqProc containers..."

  # clean up if it already exists. This is a problem as multi tenancy is still
  # not going to work. This will delete all running UUIDs
  local running_container_ids=$(sudo docker ps -a \
    | grep $REQPROC_CONTAINER_NAME_PATTERN \
    | awk '{print $1}')

  if [ ! -z "$running_container_ids" ]; then
    sudo docker rm -f -v $running_container_ids || true
  fi
}

boot_reqProc() {
  echo "Setup reqProc container options..."

  local reqproc_container_name="$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
  local reqexec_bin_dir="$REQEXEC_DIR/bin"
  sudo mkdir -p $reqexec_bin_dir

  local default_task_container_mounts=" \
  -v $BUILD_DIR:$BUILD_DIR \
  -v $REQEXEC_DIR:/reqExec \
  "

  local default_task_container_options="--rm"

  local env=" \
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
    -e REQEXEC_BIN_DIR=$reqexec_bin_dir \
    -e REQKICK_DIR=$REQKICK_DIR \
    -e BUILD_DIR=$BUILD_DIR \
    -e REQPROC_CONTAINER_NAME='$reqproc_container_name' \
    -e DEFAULT_TASK_CONTAINER_MOUNTS='$default_task_container_mounts' \
    -e DEFAULT_TASK_CONTAINER_OPTIONS='$default_task_container_options' \
    -e EXEC_IMAGE=$EXEC_IMAGE \
    -e SHIPPABLE_DOCKER_VERSION=$DOCKER_VERSION \
    -e IS_DOCKER_LEGACY=false \
    -e SHIPPABLE_NODE_ARCHITECTURE=$NODE_ARCHITECTURE \
    "

  local mounts=" \
    -v $BASE_DIR:$BASE_DIR \
    "

  local opts=" \
    -d \
    --restart=always \
    --name=$reqproc_container_name \
    "

  echo "Booting up reqProc..."
  sudo docker pull $EXEC_IMAGE
  local start_cmd="sudo docker run $opts $mounts $env $EXEC_IMAGE"
  eval "$start_cmd"
}

remove_reqKick_service() {
  echo "Removing existing reqKick service..."

  local service_location="$SERVICE_DIR/$REQKICK_SERVICE_NAME_PATTERN.$FILE_SUFFIX"

  # clean up if it already exists. This is a problem as multi tenancy is still
  # not going to work. This will delete all running UUIDs
  local running_service_names=$(sudo launchctl list \
    | grep $REQKICK_SERVICE_NAME_PATTERN \
    | awk '{ print $3 }')

  if [ ! -z "$running_service_names" ]; then
    sudo launchctl stop $service_location  || true
    sudo launchctl unload $service_location || true
  fi

  sudo rm -f $service_location
}

remove_reqKick_config() {
  echo "Removing existing reqKick config..."

  local config_location="$CONFIG_DIR/$REQKICK_CONFIG_NAME_PATTERN.$FILE_SUFFIX"

  # clean up if it already exists. This is a problem as multi tenancy is still
  # not going to work. This will delete all running UUIDs
  local running_service_names=$(sudo launchctl list \
    | grep $REQKICK_CONFIG_NAME_PATTERN \
    | awk '{ print $3 }')

  if [ ! -z "$running_service_names" ]; then
    sudo launchctl stop $config_location || true
    sudo launchctl unload $config_location || true
  fi

  sudo rm -f $config_location
}

boot_reqKick() {
  echo "Booting up reqKick service..."
  sudo git clone https://github.com/Shippable/reqKick.git $REQKICK_DIR

  local status_dir="$BUILD_DIR/status"
  local scripts_dir="$BUILD_DIR/scripts"
  local reqexec_bin_path="$REQEXEC_DIR/bin/dist/main/main"

  local reqkick_template_dir="$REQKICK_DIR/init/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM"

  local config_file="$REQKICK_CONFIG_NAME_PATTERN.$FILE_SUFFIX"
  local config_location="$CONFIG_DIR/$config_file"
  local config_template_location="$reqkick_template_dir/$config_file.template"

  local service_file="$REQKICK_SERVICE_NAME_PATTERN.$FILE_SUFFIX"
  local service_location="$SERVICE_DIR/$service_file"
  local service_template_location="$reqkick_template_dir/$service_file.template"

  pushd $REQKICK_DIR
    #sudo npm install

    # start the config
    sudo cp $config_template_location $config_location
    chmod 644 $config_location

    sudo sed -i '' "s#{{STATUS_DIR}}#$status_dir#g" $config_location
    sudo sed -i '' "s#{{SCRIPTS_DIR}}#$scripts_dir#g" $config_location
    sudo sed -i '' "s#{{REQEXEC_BIN_PATH}}#$reqexec_bin_path#g" $config_location

    sudo launchctl load $config_location || true
    sudo launchctl start $config_location || true

    # start service
    sudo cp $service_template_location $service_location
    chmod 644 $service_location

    sudo sed -i '' "s#{{UUID}}#$BASE_UUID#g" $service_location
    sudo sed -i '' "s#{{LOG_DIR}}#$SHIPPABLE_LOG_DIR#g" $service_location

    sudo launchctl load $service_location || true
    sudo launchctl start $service_location || true

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
  install_prereqs
  remove_reqProc
  remove_reqKick_service
  remove_reqKick_config
#  boot_reqProc
#  boot_reqKick
}

main
