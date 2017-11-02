#!/bin/bash -e
set -o pipefail

# initScript for Ubuntu 16.04 and Docker 17.06
# ------------------------------------------------------------------------------

readonly DOCKER_VERSION="17.06.0"
readonly SWAP_FILE_PATH="/root/.__sh_swap__"
export docker_restart=false

export SHIPPABLE_RUNTIME_DIR="/var/lib/shippable"
export BASE_UUID="$(cat /proc/sys/kernel/random/uuid)"
export BASE_DIR="$SHIPPABLE_RUNTIME_DIR/$BASE_UUID"
export REQPROC_DIR="$BASE_DIR/reqProc"
export REQEXEC_DIR="$BASE_DIR/reqExec"
export REQEXEC_BIN_DIR="$BASE_DIR/reqExec/bin"
export REQKICK_DIR="$BASE_DIR/reqKick"
export REQKICK_SERVICE_DIR="$REQKICK_DIR/init/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM"
export REQKICK_CONFIG_DIR="/etc/shippable/reqKick"
export BUILD_DIR="$BASE_DIR/build"
export STATUS_DIR=$BUILD_DIR/status
export REQPROC_MOUNTS=""
export REQPROC_ENVS=""
export REQPROC_OPTS=""
export REQPROC_CONTAINER_NAME_PATTERN="reqProc"
export REQPROC_CONTAINER_NAME="$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
export REQKICK_SERVICE_NAME_PATTERN="shippable-reqKick@"

setup_shippable_user() {
  if id -u 'shippable' >/dev/null 2>&1; then
    echo "User shippable already exists"
  else
    exec_cmd "sudo useradd -d /home/shippable -m -s /bin/bash -p shippablepwd shippable"
  fi

  exec_cmd "sudo echo 'shippable ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers"
  exec_cmd "sudo chown -R $USER:$USER /home/shippable/"
  exec_cmd "sudo chown -R shippable:shippable /home/shippable/"
}

install_prereqs() {
  echo "Installing prerequisite binaries"

  update_cmd="sudo apt-get update"
  exec_cmd "$update_cmd"

  install_prereqs_cmd="sudo apt-get -yy install apt-transport-https git python-pip software-properties-common ca-certificates curl wget tar"
  exec_cmd "$install_prereqs_cmd"

  add_docker_repo_keys='curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -'
  exec_cmd "$add_docker_repo_keys"

  add_docker_repo='sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"'
  exec_cmd "$add_docker_repo"

  pushd /tmp
  echo "Installing node 4.8.5"

  get_node_tar_cmd="wget https://nodejs.org/dist/v4.8.5/node-v4.8.5-linux-x64.tar.xz"
  exec_cmd "$get_node_tar_cmd"

  node_extract_cmd="tar -xf node-v4.8.5-linux-x64.tar.xz"
  exec_cmd "$node_extract_cmd"

  node_copy_cmd="cp -Rf node-v4.8.5-linux-x64/{bin,include,lib,share} /usr/local"
  exec_cmd "$node_copy_cmd"

  check_node_version_cmd="node -v"
  exec_cmd "$check_node_version_cmd"
  popd

  exec_cmd "$update_cmd"
}

check_swap() {
  echo "Checking for swap space"

  swap_available=$(free | grep Swap | awk '{print $2}')
  if [ $swap_available -eq 0 ]; then
    echo "No swap space available, adding swap"
    is_swap_required=true
  else
    echo "Swap space available, not adding"
  fi
}

add_swap() {
  echo "Adding swap file"
  echo "Creating Swap file at: $SWAP_FILE_PATH"
  add_swap_file="sudo touch $SWAP_FILE_PATH"
  exec_cmd "$add_swap_file"

  swap_size=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
  swap_size=$(($swap_size/1024))
  echo "Allocating swap of: $swap_size MB"
  initialize_file="sudo dd if=/dev/zero of=$SWAP_FILE_PATH bs=1M count=$swap_size"
  exec_cmd "$initialize_file"

  echo "Updating Swap file permissions"
  update_permissions="sudo chmod -c 600 $SWAP_FILE_PATH"
  exec_cmd "$update_permissions"

  echo "Setting up Swap area on the device"
  initialize_swap="sudo mkswap $SWAP_FILE_PATH"
  exec_cmd "$initialize_swap"

  echo "Turning on Swap"
  turn_swap_on="sudo swapon $SWAP_FILE_PATH"
  exec_cmd "$turn_swap_on"

}

check_fstab_entry() {
  echo "Checking fstab entries"

  if grep -q $SWAP_FILE_PATH /etc/fstab; then
    exec_cmd "echo /etc/fstab updated, swap check complete"
  else
    echo "No entry in /etc/fstab, updating ..."
    add_swap_to_fstab="echo $SWAP_FILE_PATH none swap sw 0 0 | sudo tee -a /etc/fstab"
    exec_cmd "$add_swap_to_fstab"
    exec_cmd "echo /etc/fstab updated"
  fi
}

initialize_swap() {
  check_swap
  if [ "$is_swap_required" == true ]; then
    add_swap
  fi
  check_fstab_entry
}

docker_install() {
  echo "Installing docker"

  install_docker="sudo -E apt-get install -q --force-yes -y -o Dpkg::Options::='--force-confnew' docker-ce=$DOCKER_VERSION~ce-0~ubuntu"
  exec_cmd "$install_docker"

  get_static_docker_binary="wget https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VERSION-ce.tgz -P /tmp/docker"
  exec_cmd "$get_static_docker_binary"

  extract_static_docker_binary="sudo tar -xzf /tmp/docker/docker-$DOCKER_VERSION-ce.tgz --directory /opt"
  exec_cmd "$extract_static_docker_binary"

  remove_static_docker_binary='rm -rf /tmp/docker'
  exec_cmd "$remove_static_docker_binary"
}

check_docker_opts() {
  # SHIPPABLE docker options required for every node
  echo "Checking docker options"

  SHIPPABLE_DOCKER_OPTS='DOCKER_OPTS="$DOCKER_OPTS -H unix:///var/run/docker.sock -g=/data --dns 8.8.8.8 --dns 8.8.4.4"'
  opts_exist=$(sudo sh -c "grep '$SHIPPABLE_DOCKER_OPTS' /etc/default/docker || echo ''")

  # DOCKER_OPTS do not exist or match.
  if [ -z "$opts_exist" ]; then
    echo "Removing existing DOCKER_OPTS in /etc/default/docker, if any"
    sudo sed -i '/^DOCKER_OPTS/d' "/etc/default/docker"

    echo "Appending DOCKER_OPTS to /etc/default/docker"
    sudo sh -c "echo '$SHIPPABLE_DOCKER_OPTS' >> /etc/default/docker"
    docker_restart=true
  else
    echo "Shippable docker options already present in /etc/default/docker"
  fi

  ## remove the docker option to listen on all ports
  echo "Disabling docker tcp listener"
  sudo sh -c "sed -e s/\"-H tcp:\/\/0.0.0.0:4243\"//g -i /etc/default/docker"
}

restart_docker_service() {
  echo "checking if docker restart is necessary"
  if [ $docker_restart == true ]; then
    echo "restarting docker service on reset"
    exec_cmd "sudo service docker restart"
  else
    echo "docker_restart set to false, not restarting docker daemon"
  fi
}

install_ntp() {
  {
    check_ntp=$(sudo service --status-all 2>&1 | grep ntp)
  } || {
    true
  }

  if [ ! -z "$check_ntp" ]; then
    echo "NTP already installed, skipping."
  else
    echo "Installing NTP"
    exec_cmd "sudo apt-get install -y ntp"
    exec_cmd "sudo service ntp restart"
  fi
}

setup_mounts() {
  rm -rf $SHIPPABLE_RUNTIME_DIR
  mkdir -p $BASE_DIR
  mkdir -p $REQPROC_DIR
  mkdir -p $REQEXEC_DIR
  mkdir -p $REQEXEC_BIN_DIR
  mkdir -p $REQKICK_DIR
  mkdir -p $BUILD_DIR

  REQPROC_MOUNTS="$REQPROC_MOUNTS \
    -v $BASE_DIR:$BASE_DIR \
    -v /opt/docker/docker:/usr/bin/docker \
    -v /var/run/docker.sock:/var/run/docker.sock
  "
}

setup_envs() {
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
    -e REQPROC_CONTAINER_NAME=$REQPROC_CONTAINER_NAME
  "
}

setup_opts() {
  REQPROC_OPTS="$REQPROC_OPTS \
    -d \
    --restart=always \
    --name=$REQPROC_CONTAINER_NAME \
    "
}

remove_reqProc() {
  __process_marker "Removing exisiting reqProc containers..."

  local running_container_ids=$(sudo docker ps -a \
    | grep $REQPROC_CONTAINER_NAME_PATTERN \
    | awk '{print $1}')

  if [ ! -z "$running_container_ids" ]; then
    sudo docker rm -f -v $running_container_ids || true
  fi
}

remove_reqKick() {
  __process_marker "Removing existing reqKick services..."

  local running_service_names=$(sudo systemctl list-units -a \
    | grep $REQKICK_SERVICE_NAME_PATTERN \
    | awk '{ print $1 }')

  if [ ! -z "$running_service_names" ]; then
    sudo systemctl stop $running_service_names || true
    sudo systemctl disable $running_service_names || true
  fi

  sudo rm -rf $REQKICK_CONFIG_DIR
  sudo rm -f /etc/systemd/system/shippable-reqKick@.service

  sudo systemctl daemon-reload
}

boot_reqProc() {
  __process_marker "Booting up reqProc..."
  sudo docker pull $EXEC_IMAGE
  sudo docker run $REQPROC_OPTS $REQPROC_MOUNTS $REQPROC_ENVS $EXEC_IMAGE
}

boot_reqKick() {
  __process_marker "Booting up reqKick service..."
  git clone https://github.com/Shippable/reqKick.git $REQKICK_DIR
  pushd $REQKICK_DIR
  npm install

  mkdir -p $REQKICK_CONFIG_DIR

  cp $REQKICK_SERVICE_DIR/shippable-reqKick@.service.template /etc/systemd/system/shippable-reqKick@.service
  chmod 644 /etc/systemd/system/shippable-reqKick@.service

  local reqkick_env_template=$REQKICK_SERVICE_DIR/shippable-reqKick.env.template
  local reqkick_env_file=$REQKICK_CONFIG_DIR/$BASE_UUID.env
  touch $reqkick_env_file
  sed "s#{{STATUS_DIR}}#$STATUS_DIR#g" $reqkick_env_template > $reqkick_env_file

  systemctl daemon-reload
  systemctl enable shippable-reqKick@$BASE_UUID.service
  systemctl start shippable-reqKick@$BASE_UUID.service

  {
    echo "Checking if shippable-reqKick@$BASE_UUID.service is active"
    local check_reqKick_is_active=$(systemctl is-active shippable-reqKick@$BASE_UUID.service)
    echo "shippable-reqKick@$BASE_UUID.service is $check_reqKick_is_active"
  } ||
  {
    echo "shippable-reqKick@$BASE_UUID.service failed to start"
    journalctl -n 100 -u shippable-reqKick@$BASE_UUID.service
    popd
    exit 1
  }
  popd
}

before_exit() {
  echo $1
  echo $2

  echo "Node init script completed"
}

main() {
  trap before_exit EXIT
  exec_grp "setup_shippable_user"

  trap before_exit EXIT
  exec_grp "install_prereqs"

  if [ "$IS_SWAP_ENABLED" == "true" ]; then
    trap before_exit EXIT
    exec_grp "initialize_swap"
  fi

  trap before_exit EXIT
  exec_grp "docker_install"

  trap before_exit EXIT
  exec_grp "check_docker_opts"

  trap before_exit EXIT
  exec_grp "restart_docker_service"

  trap before_exit EXIT
  exec_grp "install_ntp"

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
