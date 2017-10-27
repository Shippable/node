#!/bin/bash -e
set -e
set -o pipefail

#
# Prints the command start and end markers with timestamps
# and executes the supplied command
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

setup_directories() {
  exec_cmd "mkdir -p '$MESSAGE_STORE_LOCATION'"
  exec_cmd "mkdir -p '$KEY_STORE_LOCATION'"
  exec_cmd "mkdir -p '$BUILD_LOCATION'"
}
