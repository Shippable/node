#!/bin/bash
set -e
set -o pipefail

###########################################################
###########################################################
# Initialization script for Shippable node on
#   - Architecture aarch64
#   - Ubuntu 16.04
#   - Docker 17.06
###########################################################
###########################################################

readonly DOCKER_VERSION="17.06.0"

# Indicates if docker service should be restarted
export docker_restart=false

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

  install_prereqs_cmd="sudo apt-get -yy install apt-transport-https git python-pip software-properties-common ca-certificates curl golang"
  exec_cmd "$install_prereqs_cmd"

  update_cmd="sudo apt-get update"
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

install_docker_io() {
  install_docker_io=false
  {
    docker -v > /dev/null 2>&1
  } ||
  {
    install_docker_io=true
  }
  if [ "$install_docker_io" = true ]; then
    sudo apt-get install -q -yy docker.io
    sudo systemctl start docker
  fi
}

upgrade_golang() {
  local golang_version=1.8.3
  upgrade_required=$((go version | grep $golang_version) || echo '')
  if [ -z "$upgrade_required" ]; then
    local go_binary_upgade_failed=false
    pushd /tmp
      mkdir -p /usr/src/go
      curl -fsSL https://golang.org/dl/go$golang_version.src.tar.gz | tar -v -C /usr/src/go -xz --strip-components=1
      cd /usr/src/go/src
      local temp_path=$PATH
      export PATH=/usr/bin:$PATH
      if [ ! -d /usr/src/go/bin ]; then
        echo "Building Go $golang_version binary"
        {
          GOROOT=
          GOOS=linux GOARCH=arm64 GOROOT_BOOTSTRAP="$(go env GOROOT)" ./make.bash
        } || {
          go_binary_failed=true
        }
      fi
      export PATH=$temp_path
    popd
    if [ $go_binary_upgade_failed = true ]; then
      echo "Upgrading Go binary failed"
      exit 1
    fi
  fi
}

build_docker_cli() {
  pushd $docker_ce_cli_dir
    export GOPATH="$HOME/go"
    mkdir -p $HOME/go
    export GOROOT="/usr/src/go"
    export PATH=/usr/src/go/bin:$PATH
    if [ ! -d $GOPATH/src/github.com/docker/cli ]; then
      go get -d github.com/docker/cli/...
    fi
    make clean
    make binary
  popd
}

build_docker_engine() {
  pushd $docker_ce_engine_dir
    make clean
    make binary
  popd
}

build_docker_binary() {
  docker_ce_dir="/home/shippable/docker-ce"
  docker_ce_engine_dir=$docker_ce_dir"/components/engine"
  docker_ce_cli_dir=$docker_ce_dir"/components/cli"

  upgrade_golang

  if [ ! -d $docker_ce_dir ]; then
    pushd /home/shippable
    git clone https://github.com/docker/docker-ce.git
    popd
  fi

  pushd $docker_ce_dir
    checkout_required=$((git name-rev --name-only HEAD | grep $DOCKER_VERSION ) || echo '')
    if [ -z $checkout_required ]; then
      local tag="v$DOCKER_VERSION-ce"
      git checkout $tag
    fi
  popd

  if [ ! -f $docker_ce_cli_dir/build/docker ]; then
    build_docker_cli
  fi

  if [ ! -d $docker_ce_engine_dir/bundles/$DOCKER_VERSION-ce ]; then
    build_docker_engine
  fi
}

upgrade_docker() {
  mkdir -p /opt/docker
  pushd $docker_ce_cli_dir/build
    cp -f $docker_ce_cli_dir/build/docker /usr/bin
    cp -f $docker_ce_cli_dir/build/docker /opt/docker
  popd

  pushd $docker_ce_engine_dir/bundles/$DOCKER_VERSION-ce/binary-daemon
    cp -f docker-containerd docker-containerd-ctr docker-containerd-shim docker-init docker-proxy docker-runc dockerd /usr/bin
    cp -f docker-containerd docker-containerd-ctr docker-containerd-shim docker-init docker-proxy docker-runc dockerd /opt/docker
  popd
}

docker_install() {
  echo "Installing docker"

  install_docker_io

  docker_version="$DOCKER_VERSION-ce"
  docker_version_installed=$(sudo docker version --format {{.Server.Version}})
  if [ "$docker_version" != "$docker_version_installed" ]; then
    echo "Building $DOCKER_VERSION binary"
    build_docker_binary
    upgrade_docker
    docker_restart=true
  fi

}

check_docker_opts() {
  # SHIPPABLE docker options required for every node
  echo "Checking docker options"

  SHIPPABLE_DOCKER_CONFIGURATION='{"dns":["8.8.8.8","8.8.4.4"],"data-root":"/data"}'

  # daemon.json is not present
  if [ ! -f /etc/docker/daemon.json ]; then
    touch /etc/docker/daemon.json
  fi

  touch temp_ship_docker_config
  echo $SHIPPABLE_DOCKER_CONFIGURATION > temp_ship_docker_config
  local write_daemon_config=false
  {
    diff temp_ship_docker_config /etc/docker/daemon.json > /dev/null
  } ||
  {
    write_daemon_config=true
  }
  if [ "$write_daemon_config" = true ]; then
    echo $SHIPPABLE_DOCKER_CONFIGURATION > /etc/docker/daemon.json
    docker_restart=true
  fi

  sudo rm temp_ship_docker_config

  SHIPPABLE_DOCKER_OPTS='DOCKER_OPTS="--config-file /etc/docker/daemon.json"'
  opts_exist=$(grep "$SHIPPABLE_DOCKER_OPTS" /etc/default/docker || echo '')

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

  if [ ! -f /etc/systemd/system/docker.service ]; then
    touch /etc/systemd/system/docker.service
    curl https://raw.githubusercontent.com/moby/moby/master/contrib/init/systemd/docker.service > /etc/systemd/system/docker.service
    docker_restart=true
  fi

  if [ ! -f /etc/systemd/system/docker.socket ]; then
    touch /etc/systemd/system/docker.socket
    curl https://raw.githubusercontent.com/moby/moby/master/contrib/init/systemd/docker.socket > /etc/systemd/system/docker.socket
    docker_restart=true
  fi

  ## remove the docker option to listen on all ports
  echo "Disabling docker tcp listener"
  sudo sh -c "sed -e s/\"-H tcp:\/\/0.0.0.0:4243\"//g -i /etc/default/docker"
}

restart_docker_service() {
  echo "checking if docker restart is necessary"

  {
    sudo systemctl is-active docker
  } ||
  {
    docker_restart=true
  }

  if [ "$docker_restart" = true ]; then
    echo "restarting docker service on reset"
    exec_cmd "sudo systemctl daemon-reload"
    exec_cmd "sudo systemctl restart docker"
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
}

main
