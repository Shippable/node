#!/bin/bash
set -e
set -o pipefail


###########################################################
###########################################################
# Initialization script for Shippable node on
#   - Ubuntu 16.04
#   - Docker 1.13
###########################################################
###########################################################

readonly MESSAGE_STORE_LOCATION="/tmp/cexec"
readonly KEY_STORE_LOCATION="/tmp/ssh"
readonly DOCKER_VERSION="1.13.0"
readonly CEXEC_LOCATION_ON_HOST="/home/shippable/cexec"

# Indicates if docker service should be restarted
export docker_restart=false

#
# Prints the command start and end markers with timestamps
# and executes the supplied command
#
exec_cmd() {
  local cmd=$@
  __process_msg "Running $cmd"
  eval $cmd
  cmd_status=$?
  if [ "$2" ]; then
    echo $2;
  fi

  if [ $cmd_status == 0 ]; then
    __process_msg "Completed $cmd"
    return $cmd_status
  else
    __process_error "Failed $cmd"
    exit 99
  fi
}

exec_grp() {
  local group_name=$1
  __process_marker "Starting $group_name"
  eval "$group_name"
  group_status=$?
  __process_marker "Completed $group_name"
}

_run_update() {
  update_cmd="sudo apt-get update"
  exec_cmd "$update_cmd"
}

setup_directories() {
  exec_cmd "sudo mkdir -p '$MESSAGE_STORE_LOCATION'"
  exec_cmd "sudo mkdir -p '$KEY_STORE_LOCATION'"
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

install_prereqs() {
  echo "Installing prerequisite binaries"
  _run_update

  install_prereqs_cmd="sudo apt-get -yy install git python-pip"
  exec_cmd "$install_prereqs_cmd"
}

docker_install() {
  echo "Installing docker"

  _run_update

  inst_extras_cmd='sudo apt-get install -y linux-image-extra-`uname -r`'
  exec_cmd "$inst_extras_cmd"

  inst_extras_cmd='sudo apt-get install -y linux-image-extra-virtual software-properties-common ca-certificates'
  exec_cmd "$inst_extras_cmd"

  add_docker_repo_keys='curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add -'
  exec_cmd "$add_docker_repo_keys"

  add_docker_repo='sudo add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"'
  exec_cmd "$add_docker_repo"

  _run_update

  install_docker="sudo -E apt-get install -q --force-yes -y -o Dpkg::Options::='--force-confnew' docker-engine=$DOCKER_VERSION-0~ubuntu-xenial"
  exec_cmd "$install_docker"

  get_static_docker_binary="wget https://get.docker.com/builds/Linux/x86_64/docker-$DOCKER_VERSION.tgz -P /tmp/docker"
  exec_cmd "$get_static_docker_binary"

  extract_static_docker_binary="sudo tar -xzf /tmp/docker/docker-$DOCKER_VERSION.tgz --directory /opt"
  exec_cmd "$extract_static_docker_binary"

  remove_static_docker_binary='rm -rf /tmp/docker'
  exec_cmd "$remove_static_docker_binary"

  _run_update

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

pull_exec_image() {
  exec_cmd "docker pull '$EXEC_IMAGE'"
}

pull_exec_repo() {
  if [ -d "$CEXEC_LOCATION_ON_HOST" ]; then
    exec_cmd "sudo rm -rf $CEXEC_LOCATION_ON_HOST"
  fi
  exec_cmd "git clone https://github.com/Shippable/cexec.git $CEXEC_LOCATION_ON_HOST"
  exec_cmd "echo 'Checking out tag: $SHIPPABLE_RELEASE_VERSION in $CEXEC_LOCATION_ON_HOST'"
  pushd $CEXEC_LOCATION_ON_HOST
  exec_cmd "git checkout $SHIPPABLE_RELEASE_VERSION"
  popd
}

set_mounts() {
  exec_cmd "echo 'Setting volume mounts in environments'"

  local docker_mounts="$EXEC_MOUNTS \
    -v /usr/lib/x86_64-linux-gnu/libapparmor.so.1.1.0:/lib/x86_64-linux-gnu/libapparmor.so.1:rw \
    -v /var/run:/var/run:rw \
    -v /opt/docker/docker:/usr/bin/docker:rw \
    -v /var/run/docker.sock:/var/run/docker.sock:rw \
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
  exec_grp "pull_exec_image"

  trap before_exit EXIT
  exec_grp "pull_exec_repo"

  trap before_exit EXIT
  exec_grp "set_mounts"
}

main
