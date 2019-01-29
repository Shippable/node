#!/bin/bash
set -e
set -o pipefail

# initScript for RHEL_7 and Docker 17.06
# ------------------------------------------------------------------------------

readonly DOCKER_VERSION="17.06.0"
readonly SWAP_FILE_PATH="/root/.__sh_swap__"
export docker_restart=false
export install_docker_only="$install_docker_only"

if [ -z "$install_docker_only" ]; then
  install_docker_only="false"
fi

export SHIPPABLE_RUNTIME_DIR="/var/lib/shippable"
export BASE_UUID="$(cat /proc/sys/kernel/random/uuid)"
export BASE_DIR="$SHIPPABLE_RUNTIME_DIR/$BASE_UUID"
export REQPROC_DIR="$BASE_DIR/reqProc"
export REQEXEC_DIR="$BASE_DIR/reqExec"
export REQEXEC_BIN_PATH="$REQEXEC_DIR/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/dist/main/main"
export REQKICK_DIR="$BASE_DIR/reqKick"
export REQKICK_SERVICE_DIR="$REQKICK_DIR/init/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM"
export REQKICK_CONFIG_DIR="/etc/shippable/reqKick"
export BUILD_DIR="$BASE_DIR/build"
export STATUS_DIR=$BUILD_DIR/status
export SCRIPTS_DIR=$BUILD_DIR/scripts
export REQPROC_MOUNTS=""
export REQPROC_ENVS=""
export REQPROC_OPTS=""
export REQPROC_CONTAINER_NAME_PATTERN="reqProc"
export REQPROC_CONTAINER_NAME="$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
export REQKICK_SERVICE_NAME_PATTERN="shippable-reqKick@"
export LEGACY_CI_CACHE_STORE_LOCATION="/home/shippable/cache"
export LEGACY_CI_KEY_STORE_LOCATION="/tmp/ssh"
export LEGACY_CI_MESSAGE_STORE_LOCATION="/tmp/cexec"
export LEGACY_CI_BUILD_LOCATION="/build"
export LEGACY_CI_CEXEC_LOCATION_ON_HOST="/home/shippable/cexec"
export LEGACY_CI_DOCKER_CLIENT_LATEST="/opt/docker/docker"
export DEFAULT_TASK_CONTAINER_MOUNTS="-v $BUILD_DIR:$BUILD_DIR \
  -v $REQEXEC_DIR:/reqExec"
export TASK_CONTAINER_COMMAND="/reqExec/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/dist/main/main"
export DEFAULT_TASK_CONTAINER_OPTIONS="-d --rm"

create_shippable_dir() {
  create_dir_cmd="mkdir -p /home/shippable"
  exec_cmd "$create_dir_cmd"
}

install_docker_prereqs() {
  echo "Installing docker prerequisites"

  expire_cache="yum clean expire-cache"
  exec_cmd "$expire_cache"

  update_cmd="yum check-update || true"
  exec_cmd "$update_cmd"

  install_prereqs_cmd="yum -y install apt-transport-https git python-pip software-properties-common ca-certificates curl wget tar yum-utils"
  exec_cmd "$install_prereqs_cmd"

  add_docker_repo_keys='rpm --import https://download.docker.com/linux/centos/gpg'
  exec_cmd "$add_docker_repo_keys"

  add_docker_repo='yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo'
  exec_cmd "$add_docker_repo"

  # Check that package isn't installed by manually checking as if its already installed, rpm package installs fail
  local container_selinux_package="container-selinux-2.74-1.el7.noarch"
  if [[ $(rpm -q container-selinux) != "$container_selinux_package" ]]; then
    install_container_selinux="sudo yum install -y http://mirror.centos.org/centos/7/extras/x86_64/Packages/$container_selinux_package.rpm"
    exec_cmd "$install_container_selinux"
  fi
}

install_prereqs() {
  echo "Installing prerequisite binaries"

  pushd /tmp
  local nodejs_version="8.11.3"
  echo "Installing node $nodejs_version"

  get_node_tar_cmd="wget https://nodejs.org/dist/v$nodejs_version/node-v$nodejs_version-linux-x64.tar.xz"
  exec_cmd "$get_node_tar_cmd"

  node_extract_cmd="tar -xf node-v$nodejs_version-linux-x64.tar.xz"
  exec_cmd "$node_extract_cmd"

  node_copy_cmd="cp -Rf node-v$nodejs_version-linux-x64/{bin,include,lib,share} /usr/local"
  exec_cmd "$node_copy_cmd"

  export PATH="$PATH:/usr/local/bin/"

  check_node_version_cmd="node -v"
  exec_cmd "$check_node_version_cmd"
  popd

  echo "Installing shipctl components"

  remove_existing_epel_release='yum remove -y epel-release-7-11 || true'
  exec_cmd "$remove_existing_epel_release"

  get_epel_repo_rpm="curl -O https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"
  exec_cmd "$get_epel_repo_rpm"
  install_epel_release_cmd="yum install -y epel-release-latest-7.noarch.rpm"
  exec_cmd "$install_epel_release_cmd"
  exec_cmd "$NODE_SHIPCTL_LOCATION/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/install.sh"

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
  add_swap_file="touch $SWAP_FILE_PATH"
  exec_cmd "$add_swap_file"

  swap_size=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
  swap_size=$(($swap_size/1024))
  echo "Allocating swap of: $swap_size MB"
  initialize_file="dd if=/dev/zero of=$SWAP_FILE_PATH bs=1M count=$swap_size"
  exec_cmd "$initialize_file"

  echo "Updating Swap file permissions"
  update_permissions="chmod -c 600 $SWAP_FILE_PATH"
  exec_cmd "$update_permissions"

  echo "Setting up Swap area on the device"
  initialize_swap="mkswap $SWAP_FILE_PATH"
  exec_cmd "$initialize_swap"

  echo "Turning on Swap"
  turn_swap_on="swapon $SWAP_FILE_PATH"
  exec_cmd "$turn_swap_on"

}

check_fstab_entry() {
  echo "Checking fstab entries"

  if grep -q $SWAP_FILE_PATH /etc/fstab; then
    exec_cmd "echo /etc/fstab updated, swap check complete"
  else
    echo "No entry in /etc/fstab, updating ..."
    add_swap_to_fstab="echo $SWAP_FILE_PATH none swap sw 0 0 | tee -a /etc/fstab"
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

  install_docker="yum -y install docker-ce-$DOCKER_VERSION.ce"
  exec_cmd "$install_docker"

  get_static_docker_binary="wget https://download.docker.com/linux/static/stable/x86_64/docker-$DOCKER_VERSION-ce.tgz -P /tmp/docker"
  exec_cmd "$get_static_docker_binary"

  extract_static_docker_binary="tar -xzf /tmp/docker/docker-$DOCKER_VERSION-ce.tgz --directory /opt"
  exec_cmd "$extract_static_docker_binary"

  remove_static_docker_binary='rm -rf /tmp/docker'
  exec_cmd "$remove_static_docker_binary"

  enable_docker='systemctl enable docker'
  exec_cmd "$enable_docker"
}

check_docker_opts() {
  mkdir -p /etc/docker

  is_gce_header=$(curl -I -s metadata.google.internal | grep "Metadata-Flavor: Google") || true
  if [ -z "$is_gce_header" ]; then
    config="{\"graph\": \"/data\"}"
  else
    config="{\"graph\": \"/data\", \"mtu\": 1460 }"
  fi

  config_file="/etc/docker/daemon.json"
  if [ -f "$config_file" ] && [ "$(echo -e $config)" == "$(cat $config_file)" ]; then
    echo "Skipping adding config as its already added"
  else
    echo "Adding Docker config"
    echo -e "$config" > "$config_file"
    docker_restart=true
  fi
}

add_docker_proxy_envs() {
  mkdir -p /etc/systemd/system/docker.service.d

  proxy_envs="[Service]\nEnvironment="
  if [ ! -z "$SHIPPABLE_HTTP_PROXY" ]; then
    proxy_envs="$proxy_envs \"HTTP_PROXY=$SHIPPABLE_HTTP_PROXY\""
  fi

  if [ ! -z "$SHIPPABLE_HTTPS_PROXY" ]; then
    proxy_envs="$proxy_envs \"HTTPS_PROXY=$SHIPPABLE_HTTPS_PROXY\""
  fi

  if [ ! -z "$SHIPPABLE_NO_PROXY" ]; then
    proxy_envs="$proxy_envs \"NO_PROXY=$SHIPPABLE_NO_PROXY\""
  fi

  local docker_proxy_config_file="/etc/systemd/system/docker.service.d/proxy.conf"

  if [ -f "$docker_proxy_config_file" ] && [ "$(echo -e $proxy_envs)" == "$(cat $docker_proxy_config_file)" ]; then
    echo "Skipping Docker proxy config, as its already added"
  else
    echo "Adding Docker proxy config"
    echo -e "$proxy_envs" > "$docker_proxy_config_file"
    docker_restart=true
  fi
}

restart_docker_service() {
  echo "checking if docker restart is necessary"
  if [ $docker_restart == true ]; then
    echo "restarting docker service on reset"
    exec_cmd "systemctl daemon-reload"
    exec_cmd "systemctl restart docker"
  else
    echo "docker_restart set to false, not restarting docker daemon"
  fi
}

install_ntp() {
  {
    check_ntp=$(systemctl 2>&1 | grep ntp)
  } || {
    true
  }

  if [ ! -z "$check_ntp" ]; then
    echo "NTP already installed, skipping."
  else
    echo "Installing NTP"
    exec_cmd "yum install -y ntp"
    exec_cmd "systemctl restart ntpd"
  fi
}

setup_mounts() {
  rm -rf $SHIPPABLE_RUNTIME_DIR
  mkdir -p $BASE_DIR
  mkdir -p $REQPROC_DIR
  mkdir -p $REQEXEC_DIR
  mkdir -p $REQKICK_DIR
  mkdir -p $BUILD_DIR
  mkdir -p $LEGACY_CI_CACHE_STORE_LOCATION
  mkdir -p $LEGACY_CI_KEY_STORE_LOCATION
  mkdir -p $LEGACY_CI_MESSAGE_STORE_LOCATION
  mkdir -p $LEGACY_CI_BUILD_LOCATION

  REQPROC_MOUNTS="$REQPROC_MOUNTS \
    -v $BASE_DIR:$BASE_DIR \
    -v /opt/docker/docker:/usr/bin/docker \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $LEGACY_CI_CACHE_STORE_LOCATION:$LEGACY_CI_CACHE_STORE_LOCATION:rw \
    -v $LEGACY_CI_KEY_STORE_LOCATION:$LEGACY_CI_KEY_STORE_LOCATION:rw \
    -v $LEGACY_CI_MESSAGE_STORE_LOCATION:$LEGACY_CI_MESSAGE_STORE_LOCATION:rw \
    -v $LEGACY_CI_BUILD_LOCATION:$LEGACY_CI_BUILD_LOCATION:rw"

  if [ "$IS_RESTRICTED_NODE" == "true" ]; then
    DEFAULT_TASK_CONTAINER_MOUNTS="$DEFAULT_TASK_CONTAINER_MOUNTS \
      -v $NODE_SCRIPTS_LOCATION:/var/lib/shippable/node"
  else
    DEFAULT_TASK_CONTAINER_MOUNTS="$DEFAULT_TASK_CONTAINER_MOUNTS \
      -v /opt/docker/docker:/usr/bin/docker \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v $NODE_SCRIPTS_LOCATION:/var/lib/shippable/node"
  fi
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
    -e REQPROC_CONTAINER_NAME=$REQPROC_CONTAINER_NAME \
    -e DEFAULT_TASK_CONTAINER_MOUNTS='$DEFAULT_TASK_CONTAINER_MOUNTS' \
    -e TASK_CONTAINER_COMMAND=$TASK_CONTAINER_COMMAND \
    -e DEFAULT_TASK_CONTAINER_OPTIONS='$DEFAULT_TASK_CONTAINER_OPTIONS' \
    -e CACHE_STORE_LOCATION=$LEGACY_CI_CACHE_STORE_LOCATION \
    -e KEY_STORE_LOCATION=$LEGACY_CI_KEY_STORE_LOCATION \
    -e MESSAGE_STORE_LOCATION=$LEGACY_CI_MESSAGE_STORE_LOCATION \
    -e BUILD_LOCATION=$LEGACY_CI_BUILD_LOCATION \
    -e EXEC_IMAGE=$EXEC_IMAGE \
    -e DOCKER_CLIENT_LATEST=$LEGACY_CI_DOCKER_CLIENT_LATEST \
    -e SHIPPABLE_DOCKER_VERSION=$DOCKER_VERSION \
    -e IS_DOCKER_LEGACY=false \
    -e SHIPPABLE_NODE_ARCHITECTURE=$NODE_ARCHITECTURE \
    -e SHIPPABLE_NODE_OPERATING_SYSTEM=$NODE_OPERATING_SYSTEM \
    -e SHIPPABLE_RELEASE_VERSION=$SHIPPABLE_RELEASE_VERSION \
    -e SHIPPABLE_AMI_VERSION=$SHIPPABLE_AMI_VERSION \
    -e SHIPPABLE_NODE_SCRIPTS_LOCATION=$NODE_SCRIPTS_LOCATION \
    -e CLUSTER_TYPE_CODE=$CLUSTER_TYPE_CODE \
    -e IS_RESTRICTED_NODE=$IS_RESTRICTED_NODE"

  if [ ! -z "$SHIPPABLE_HTTP_PROXY" ]; then
    REQPROC_ENVS="$REQPROC_ENVS \
      -e http_proxy=$SHIPPABLE_HTTP_PROXY"
  fi

  if [ ! -z "$SHIPPABLE_HTTPS_PROXY" ]; then
    REQPROC_ENVS="$REQPROC_ENVS \
      -e https_proxy=$SHIPPABLE_HTTPS_PROXY"
  fi

  if [ ! -z "$SHIPPABLE_NO_PROXY" ]; then
    REQPROC_ENVS="$REQPROC_ENVS \
      -e no_proxy=$SHIPPABLE_NO_PROXY"
  fi

  if [ "$NO_VERIFY_SSL" == "true" ]; then
    REQPROC_ENVS="$REQPROC_ENVS \
      -e NODE_TLS_REJECT_UNAUTHORIZED=0"
  fi
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

  local running_container_ids=$(docker ps -a \
    | grep $REQPROC_CONTAINER_NAME_PATTERN \
    | awk '{print $1}')

  if [ ! -z "$running_container_ids" ]; then
    docker rm -f -v $running_container_ids || true
  fi
}

remove_reqKick() {
  __process_marker "Removing existing reqKick services..."

  local running_service_names=$(systemctl list-units -a \
    | grep $REQKICK_SERVICE_NAME_PATTERN \
    | awk '{ print $1 }')

  if [ ! -z "$running_service_names" ]; then
    systemctl stop $running_service_names || true
    systemctl disable $running_service_names || true
  fi

  rm -rf $REQKICK_CONFIG_DIR
  rm -f /etc/systemd/system/shippable-reqKick@.service

  systemctl daemon-reload
}

fetch_cexec() {
  __process_marker "Fetching cexec..."
  local cexec_tar_file="cexec.tar.gz"

  if [ -d "$LEGACY_CI_CEXEC_LOCATION_ON_HOST" ]; then
    exec_cmd "rm -rf $LEGACY_CI_CEXEC_LOCATION_ON_HOST"
  fi
  rm -rf $cexec_tar_file
  pushd /tmp
    wget $CEXEC_DOWNLOAD_URL -O $cexec_tar_file
    mkdir -p $LEGACY_CI_CEXEC_LOCATION_ON_HOST
    tar -xzf $cexec_tar_file -C $LEGACY_CI_CEXEC_LOCATION_ON_HOST --strip-components=1
    rm -rf $cexec_tar_file
  popd

  #Download and extract reports bin file into a path that cexec expects it in
  local reports_dir="$LEGACY_CI_CEXEC_LOCATION_ON_HOST/bin"
  local reports_tar_file="reports.tar.gz"
  rm -rf $reports_dir
  mkdir -p $reports_dir
  pushd $reports_dir
    wget $REPORTS_DOWNLOAD_URL -O $reports_tar_file
    tar -xf $reports_tar_file
    rm -rf $reports_tar_file
  popd
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
    wget $REQKICK_DOWNLOAD_URL -O $reqKick_tar_file
    mkdir -p $REQKICK_DIR
    tar -xzf $reqKick_tar_file -C $REQKICK_DIR --strip-components=1
    rm -rf $reqKick_tar_file
  popd
  pushd $REQKICK_DIR
  npm install

  mkdir -p $REQKICK_CONFIG_DIR

  cp $REQKICK_SERVICE_DIR/shippable-reqKick@.service.template /etc/systemd/system/shippable-reqKick@.service
  chmod 644 /etc/systemd/system/shippable-reqKick@.service

  local reqkick_env_template=$REQKICK_SERVICE_DIR/shippable-reqKick.env.template
  local reqkick_env_file=$REQKICK_CONFIG_DIR/$BASE_UUID.env
  touch $reqkick_env_file
  sed "s#{{STATUS_DIR}}#$STATUS_DIR#g" $reqkick_env_template > $reqkick_env_file
  sed -i "s#{{SCRIPTS_DIR}}#$SCRIPTS_DIR#g" $reqkick_env_file
  sed -i "s#{{REQEXEC_BIN_PATH}}#$REQEXEC_BIN_PATH#g" $reqkick_env_file
  sed -i "s#{{RUN_MODE}}#$RUN_MODE#g" $reqkick_env_file
  sed -i "s#{{NODE_ID}}#$NODE_ID#g" $reqkick_env_file
  sed -i "s#{{SUBSCRIPTION_ID}}#$SUBSCRIPTION_ID#g" $reqkick_env_file
  sed -i "s#{{NODE_TYPE_CODE}}#$NODE_TYPE_CODE#g" $reqkick_env_file
  sed -i "s#{{SHIPPABLE_NODE_ARCHITECTURE}}#$NODE_ARCHITECTURE#g" $reqkick_env_file
  sed -i "s#{{SHIPPABLE_NODE_OPERATING_SYSTEM}}#$NODE_OPERATING_SYSTEM#g" $reqkick_env_file
  sed -i "s#{{SHIPPABLE_API_URL}}#$SHIPPABLE_API_URL#g" $reqkick_env_file

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
  if [ "$install_docker_only" == "true" ]; then
    trap before_exit EXIT
    exec_grp "install_docker_prereqs"

    trap before_exit EXIT
    exec_grp "docker_install"

    trap before_exit EXIT
    exec_grp "check_docker_opts"

    if [ ! -z "$SHIPPABLE_HTTP_PROXY" ] || [ ! -z "$SHIPPABLE_HTTPS_PROXY" ] || [ ! -z "$SHIPPABLE_NO_PROXY" ]; then
      trap before_exit EXIT
      exec_grp "add_docker_proxy_envs"
    fi

    trap before_exit EXIT
    exec_grp "restart_docker_service"
  else
    trap before_exit EXIT
    exec_grp "create_shippable_dir"

    trap before_exit EXIT
    exec_grp "install_docker_prereqs"

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

    if [ ! -z "$SHIPPABLE_HTTP_PROXY" ] || [ ! -z "$SHIPPABLE_HTTPS_PROXY" ] || [ ! -z "$SHIPPABLE_NO_PROXY" ]; then
      trap before_exit EXIT
      exec_grp "add_docker_proxy_envs"
    fi

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
    exec_grp "fetch_cexec"

    trap before_exit EXIT
    exec_grp "boot_reqProc"

    trap before_exit EXIT
    exec_grp "boot_reqKick"
  fi
}

main
