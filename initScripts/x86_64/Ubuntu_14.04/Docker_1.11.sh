#!/bin/bash
set -e
set -o pipefail

# initScript for Ubuntu 16.04 and Docker 1.9
# ------------------------------------------------------------------------------

readonly DOCKER_VERSION="1.11.1"
readonly SWAP_FILE_PATH="/root/.__sh_swap__"

# Indicates if docker service should be restarted
export docker_restart=false
export install_docker_only="$install_docker_only"

if [ -z "$install_docker_only" ]; then
  install_docker_only="false"
fi

_run_update() {
  update_cmd="sudo apt-get update"
  exec_cmd "$update_cmd"
}

check_init_input() {
  local expected_envs=(
    'NODE_SHIPCTL_LOCATION'
    'NODE_ARCHITECTURE'
    'NODE_OPERATING_SYSTEM'
    'LEGACY_CI_CEXEC_LOCATION_ON_HOST'
    'SHIPPABLE_RELEASE_VERSION'
    'SHIPPABLE_AMI_VERSION'
    'EXEC_IMAGE'
    'REQKICK_DIR'
    'IS_SWAP_ENABLED'
    'REQKICK_DOWNLOAD_URL'
    'CEXEC_DOWNLOAD_URL'
    'REPORTS_DOWNLOAD_URL'
  )

  check_envs "${expected_envs[@]}"
}

create_shippable_dir() {
  create_dir_cmd="mkdir -p /home/shippable"
  exec_cmd "$create_dir_cmd"
}

upgrade_kernel() {
  ## This is required to fix this docker bug where java builds hang
  ## https://github.com/docker/docker/issues/18180#issuecomment-184359636
  ## once the updated kernel is released, we can remove this function
  exec_cmd "echo 'deb http://archive.ubuntu.com/ubuntu/ trusty-proposed restricted main multiverse universe' | sudo tee -a /etc/apt/sources.list"
  exec_cmd "echo -e 'Package: *\nPin: release a=trusty-proposed\nPin-Priority: 400' | sudo tee -a  /etc/apt/preferences.d/proposed-updates"
  _run_update
  exec_cmd "sudo apt-get -y  install linux-image-3.19.0-51-generic linux-image-extra-3.19.0-51-generic"
}

install_prereqs() {
  local nodejs_version="8.11.3"

  echo "Installing prerequisite binaries"
  _run_update

  install_prereqs_cmd="sudo apt-get -yy install git python-pip"
  exec_cmd "$install_prereqs_cmd"

  pushd /tmp
  echo "Installing node $nodejs_version"

  get_node_tar_cmd="wget https://nodejs.org/dist/v$nodejs_version/node-v$nodejs_version-linux-x64.tar.xz"
  exec_cmd "$get_node_tar_cmd"

  node_extract_cmd="tar -xf node-v$nodejs_version-linux-x64.tar.xz"
  exec_cmd "$node_extract_cmd"

  node_copy_cmd="cp -Rf node-v$nodejs_version-linux-x64/{bin,include,lib,share} /usr/local"
  exec_cmd "$node_copy_cmd"

  check_node_version_cmd="node -v"
  exec_cmd "$check_node_version_cmd"
  popd

  echo "Installing shipctl components"
  exec_cmd "$NODE_SHIPCTL_LOCATION/$NODE_ARCHITECTURE/$NODE_OPERATING_SYSTEM/install.sh"

  _run_update
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

  _run_update

  add_docker_repo_keys='sudo -E apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D'
  exec_cmd "$add_docker_repo_keys"

  local docker_repo_entry="deb https://apt.dockerproject.org/repo ubuntu-trusty main"
  local docker_sources_file="/etc/apt/sources.list.d/docker.list"
  local add_docker_hosts=true

  if [ -f "$docker_sources_file" ]; then
    local docker_source_present=""
    {
      docker_source_present=$(grep "$docker_repo_entry" $docker_sources_file)
    } || {
      true
    }

    if [ "$docker_source_present" != "" ]; then
      ## docker hosts entry already present in file
      add_docker_hosts=false
    fi
  fi

  if [ $add_docker_hosts == true ]; then
    add_docker_repo="echo $docker_repo_entry | sudo tee -a $docker_sources_file"
    exec_cmd "$add_docker_repo"
  else
    exec_cmd "echo 'Docker sources already present, skipping'"
  fi

  _run_update

  install_kernel_extras='sudo -E apt-get install -y -q linux-image-extra-$(uname -r) linux-image-extra-virtual'
  exec_cmd "$install_kernel_extras"

  local docker_version=$DOCKER_VERSION"-0~trusty"
  install_docker="sudo -E apt-get install -q --force-yes -y -o Dpkg::Options::='--force-confnew' docker-engine=$docker_version"
  exec_cmd "$install_docker"

  get_static_docker_binary="wget https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz -P /tmp/docker"
  exec_cmd "$get_static_docker_binary"

  extract_static_docker_binary="sudo tar -xzf /tmp/docker/docker-$DOCKER_VERSION.tgz --directory /opt"
  exec_cmd "$extract_static_docker_binary"

  remove_static_docker_binary='rm -rf /tmp/docker'
  exec_cmd "$remove_static_docker_binary"

}

check_docker_opts() {
  # SHIPPABLE docker options required for every node
  echo "Checking docker options"

  OLD_SHIPPABLE_DOCKER_OPTS='DOCKER_OPTS="$DOCKER_OPTS -H unix:///var/run/docker.sock -g=/data --storage-driver aufs"'
  old_opts_exist=$(sudo sh -c "grep '$OLD_SHIPPABLE_DOCKER_OPTS' /etc/default/docker || echo ''")

  if [ ! -z "$old_opts_exist" ]; then
    ## old docker opts exist
    echo "removing old DOCKER_OPTS from /etc/default/docker"
    sudo sh -c "sed -e s/\"DOCKER_OPTS=\\\"\\\$DOCKER_OPTS -H unix:\\\/\\\/\\\/var\\\/run\\\/docker.sock -g=\\\/data --storage-driver aufs\\\"\"//g -i /etc/default/docker"
    docker_restart=true
  fi

  is_gce_header=$(curl -I -s metadata.google.internal | grep "Metadata-Flavor: Google") || true
  if [ -z "$is_gce_header" ]; then
    SHIPPABLE_DOCKER_OPTS='DOCKER_OPTS="$DOCKER_OPTS -H unix:///var/run/docker.sock -g=/data --storage-driver aufs"'
  else
    SHIPPABLE_DOCKER_OPTS='DOCKER_OPTS="$DOCKER_OPTS -H unix:///var/run/docker.sock -g=/data --storage-driver aufs --mtu 1460"'
  fi
  opts_exist=$(sudo sh -c "grep '$SHIPPABLE_DOCKER_OPTS' /etc/default/docker || echo ''")

  if [ -z "$opts_exist" ]; then
    ## docker opts do not exist
    echo "Removing existing DOCKER_OPTS in /etc/default/docker, if any"
    sudo sed -i '/^DOCKER_OPTS/d' "/etc/default/docker"

    echo "appending DOCKER_OPTS to /etc/default/docker"
    sudo sh -c "echo '$SHIPPABLE_DOCKER_OPTS' >> /etc/default/docker"
    docker_restart=true
  else
    echo "Shippable docker options already present in /etc/default/docker"
  fi

  ## remove the docker option to listen on all ports
  echo "Disabling docker tcp listener"
  sudo sh -c "sed -e s/\"-H tcp:\/\/0.0.0.0:4243\"//g -i /etc/default/docker"
}

check_proxy_envs() {
  if [ ! -z "$SHIPPABLE_HTTP_PROXY" ]; then
    http_proxy_env="export http_proxy=\"$SHIPPABLE_HTTP_PROXY\""
    http_proxy_exists=$(grep "^$http_proxy_env$" /etc/default/docker || echo "")
    if [ -z "$http_proxy_exists" ]; then
      __process_msg "Configuring docker http_proxy"
      sed -i '/^export http_proxy/d' /etc/default/docker
      echo "$http_proxy_env" >> /etc/default/docker
      docker_restart=true
    fi
  else
    # Clean up any env configured already if we do not find it in our
    # environment
    http_proxy_exists=$(grep "^export http_proxy=" /etc/default/docker || echo "")
    if [ ! -z "$http_proxy_exists" ]; then
      __process_msg "Removing docker http_proxy"
      sed -i '/^export http_proxy/d' /etc/default/docker
      docker_restart=true
    fi
  fi

  if [ ! -z "$SHIPPABLE_HTTPS_PROXY" ]; then
    https_proxy_env="export https_proxy=\"$SHIPPABLE_HTTPS_PROXY\""
    https_proxy_exists=$(grep "^$https_proxy_env$" /etc/default/docker || echo "")
    if [ -z "$https_proxy_exists" ]; then
      __process_msg "Configuring docker https_proxy"
      sed -i '/^export https_proxy/d' /etc/default/docker
      echo "$https_proxy_env" >> /etc/default/docker
      docker_restart=true
    fi
  else
    # Clean up any env configured already if we do not find it in our
    # environment
    https_proxy_exists=$(grep "^export https_proxy=" /etc/default/docker || echo "")
    if [ ! -z "$https_proxy_exists" ]; then
      __process_msg "Removing docker https_proxy"
      sed -i '/^export https_proxy/d' /etc/default/docker
      docker_restart=true
    fi
  fi

  if [ ! -z "$SHIPPABLE_NO_PROXY" ]; then
    no_proxy_env="export no_proxy=\"$SHIPPABLE_NO_PROXY\""
    no_proxy_exists=$(grep "^$no_proxy_env$" /etc/default/docker || echo "")
    if [ -z "$no_proxy_exists" ]; then
      __process_msg "Configuring docker no_proxy"
      sed -i '/^export no_proxy/d' /etc/default/docker
      echo "$no_proxy_env" >> /etc/default/docker
      docker_restart=true
    fi
  else
    # Clean up any env configured already if we do not find it in our
    # environment
    no_proxy_exists=$(grep "^export no_proxy=" /etc/default/docker || echo "")
    if [ ! -z "$no_proxy_exists" ]; then
      __process_msg "Removing docker no_proxy"
      sed -i '/^export no_proxy/d' /etc/default/docker
      docker_restart=true
    fi
  fi
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

  # Download and extract reports bin file into a path that cexec expects it in
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

pull_reqProc() {
  __process_marker "Pulling reqProc..."
  docker pull $EXEC_IMAGE
}

fetch_reqKick() {
  __process_marker "Fetching reqKick..."
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
  popd
}

before_exit() {
  # flush streams
  echo $1
  echo $2

  echo "Node  init script completed"
}

main() {
  if [ "$install_docker_only" == "true" ]; then
    trap before_exit EXIT
    exec_grp "upgrade_kernel"

    trap before_exit EXIT
    exec_grp "docker_install"

    trap before_exit EXIT
    exec_grp "check_docker_opts"

    trap before_exit EXIT
    exec_grp "restart_docker_service"
  else
    check_init_input

    trap before_exit EXIT
    exec_grp "create_shippable_dir"

    trap before_exit EXIT
    exec_grp "upgrade_kernel"

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
    exec_grp "check_proxy_envs"

    trap before_exit EXIT
    exec_grp "restart_docker_service"

    trap before_exit EXIT
    exec_grp "install_ntp"

    trap before_exit EXIT
    exec_grp "fetch_cexec"

    trap before_exit EXIT
    exec_grp "pull_reqProc"

    trap before_exit EXIT
    exec_grp "fetch_reqKick"
  fi
}

main
