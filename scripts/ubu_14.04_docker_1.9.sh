#!/bin/bash
set -e
set -o pipefail


###########################################################
###########################################################
# Initialization script for Shippable node on
#   - Ubuntu 14.04
#   - Docker 1.9
###########################################################
###########################################################

readonly DOCKER_VERSION="1.9.1"

# Indicates if docker service should be restarted
export docker_restart=false

_run_update() {
  update_cmd="sudo apt-get update"
  exec_cmd "$update_cmd"
}

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
  echo "Installing prerequisite binaries"
  _run_update

  install_prereqs_cmd="sudo apt-get -yy install git python-pip"
  exec_cmd "$install_prereqs_cmd"
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

  get_static_docker_binary="wget https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION -P /tmp/docker"
  exec_cmd "$get_static_docker_binary"

  create_docker_directory="mkdir -p /opt/docker"
  exec_cmd "$create_docker_directory"

  move_docker_binary="mv /tmp/docker/docker-$DOCKER_VERSION /opt/docker/docker"
  exec_cmd "$move_docker_binary"

  make_docker_executable="chmod +x /opt/docker/docker"
  exec_cmd "$make_docker_executable"

  remove_static_docker_binary='rm -rf /tmp/docker'
  exec_cmd "$remove_static_docker_binary"

}

check_docker_opts() {
  # SHIPPABLE docker options required for every node
  echo "Checking docker options"

  SHIPPABLE_DOCKER_OPTS='DOCKER_OPTS="$DOCKER_OPTS -H unix:///var/run/docker.sock -g=/data --storage-driver aufs --dns 8.8.8.8 --dns 8.8.4.4"'
  opts_exist=$(sudo sh -c "grep '$SHIPPABLE_DOCKER_OPTS' /etc/default/docker || echo ''")

  if [ -z "$opts_exist" ]; then
    ## docker opts do not exist
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

set_mounts() {
  exec_cmd "echo 'Setting volume mounts in environments'"

  local docker_mounts="$EXEC_MOUNTS \
    -v /home/shippable/cache:/home/shippable/cache:rw \
    -v /tmp/ssh:/tmp/ssh:rw \
    -v /tmp/cexec:/tmp/cexec:rw \
    -v /build:/build:rw "

  exec_cmd "echo 'Deleting mounts env to update with new values'"
  exec_cmd "sed -i.bak '/EXEC_MOUNTS/d' $NODE_ENV"

  echo "EXEC_MOUNTS='$docker_mounts'" | sudo tee -a $NODE_ENV

  exec_cmd "echo 'Successfully updated mount values in env'"
  exec_cmd "cat $NODE_ENV"
}

before_exit() {
  # flush streams
  echo $1
  echo $2

  echo "Node  init script completed"
}

main() {
  trap before_exit EXIT
  exec_grp "setup_shippable_user"

  trap before_exit EXIT
  exec_grp "upgrade_kernel"

  trap before_exit EXIT
  exec_grp "setup_directories"

  trap before_exit EXIT
  exec_grp "install_prereqs"

  trap before_exit EXIT
  exec_grp "docker_install"

  trap before_exit EXIT
  exec_grp "check_docker_opts"

  trap before_exit EXIT
  exec_grp "restart_docker_service"

  trap before_exit EXIT
  exec_grp "install_ntp"

  trap before_exit EXIT
  exec_grp "set_mounts"
}

main
