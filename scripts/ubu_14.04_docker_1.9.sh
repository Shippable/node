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

readonly SHIPPABLE_DOCKER_VERSION=1.9
readonly MESSAGE_STORE_LOCATION="/tmp/cexec"
readonly KEY_STORE_LOCATION="/tmp/ssh"
readonly DOCKER_VERSION="1.13.0-0~ubuntu-trusty"

# Indicates whether the script has succeeded
export is_success=false

# Indicates if docker service should be restarted
export docker_restart=false

#
# Prints the command start and end markers with timestamps
# and executes the supplied command
#
exec_cmd() {
  cmd=$@
  cmd_uuid=$(python -c 'import uuid; print str(uuid.uuid4())')
  cmd_start_timestamp=`date +"%s"`
  echo "Running $cmd"
  eval $cmd
  cmd_status=$?
  if [ "$2" ]; then
    echo $2;
  fi

  cmd_end_timestamp=`date +"%s"`
  if [ $cmd_status == 0 ]; then
    echo "Completed $cmd"
    return $cmd_status
  else
    echo "Failed $cmd"
    exit 99
  fi
}

exec_grp() {
  group_name=$1
  group_uuid=$(python -c 'import uuid; print str(uuid.uuid4())')
  group_start_timestamp=`date +"%s"`
  echo "Starting $group_name"
  eval "$group_name"
  group_status=$?
  group_end_timestamp=`date +"%s"`
  echo "Completed $group_name"
}

_run_update() {
  is_success=false
  update_cmd="sudo apt-get update"
  exec_cmd "$update_cmd"
  is_success=true
}

setup_directories() {
  sudo mkdir -p "$MESSAGE_STORE_LOCATION"
  sudo mkdir -p "$KEY_STORE_LOCATION"
}

setup_shippable_user() {
  is_success=false
  if id -u 'shippable' >/dev/null 2>&1; then
    echo "User shippable already exists"
  else
    exec_cmd "sudo useradd -d /home/shippable -m -s /bin/bash -p shippablepwd shippable"
  fi

  exec_cmd "sudo echo 'shippable ALL=(ALL) NOPASSWD:ALL' | sudo tee -a /etc/sudoers"
  exec_cmd "sudo chown -R $USER:$USER /home/shippable/"
  exec_cmd "sudo chown -R shippable:shippable /home/shippable/"
  is_success=true
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
  is_success=false
  echo "Installing docker"

  _run_update

  inst_extras_cmd='sudo apt-get install -y linux-image-extra-`uname -r`'
  exec_cmd "$inst_extras_cmd"

  inst_extras_cmd='sudo apt-get install -y linux-image-extra-virtual software-properties-common ca-certificates'
  exec_cmd "$inst_extras_cmd"

  add_docker_repo_keys='curl -fsSL https://yum.dockerproject.org/gpg | sudo apt-key add -'
  exec_cmd "$add_docker_repo_keys"

  add_docker_repo='sudo add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"'
  exec_cmd "$add_docker_repo"

  _run_update

  install_docker='sudo apt-get -y install docker-engine=$DOCKER_VERSION'
  exec_cmd "$install_docker"

  is_success=true
}

check_docker_opts() {
  is_success=false
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
  is_success=true
}

restart_docker_service() {
  is_success=false
  echo "checking if docker restart is necessary"
  if [ $docker_restart == true ]; then
    echo "restarting docker service on reset"
    exec_cmd "sudo service docker restart"
  else
    echo "docker_restart set to false, not restarting docker daemon"
  fi
  is_success=true
}

install_ntp() {
  is_success=false
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
  is_success=true
}

before_exit() {
  if [ "$is_success" == true ]; then
    echo "__SH__SCRIPT_END_SUCCESS__";
  else
    echo "__SH__SCRIPT_END_FAILURE__";
  fi
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
}

main
echo "AMI init script completed"
