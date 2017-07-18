#! /bin/bash
set -e
set -o pipefail

readonly SWAP_FILE_PATH="/home/shippable/.__sh_swap__"
readonly ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly LIB_DIR="$ROOT_DIR/lib"
source "$LIB_DIR/logger.sh"
source "$LIB_DIR/headers.sh"

check_swap() {
  __process_marker "Checking for swap space"

  swap_available=$(free | grep Swap | awk '{print $2}')
  if [ $swap_available -eq 0 ]; then
    __process_msg "No swap space available, adding swap"
    is_swap_required=true
  else
    __process_msg "Swap space available, not adding"
  fi
}

add_swap() {
  __process_marker "Adding swap file"

  __process_msg "Creating Swap file at: $SWAP_FILE_PATH"
  add_swap_file="sudo touch $SWAP_FILE_PATH"
  exec_cmd "$add_swap_file"

  swap_size=$(cat /proc/meminfo | grep MemTotal | awk '{print $2}')
  swap_size=$(($swap_size/1024))
  __process_msg "Allocating swap of: $swap_size MB"
  initialize_file="sudo dd if=/dev/zero of=$SWAP_FILE_PATH bs=1M count=$swap_size"
  exec_cmd "$initialize_file"

  __process_msg "Updating Swap file permissions"
  update_permissions="sudo chmod -c 600 $SWAP_FILE_PATH"
  exec_cmd "$update_permissions"

  __process_msg "Setting up Swap area on the device"
  initialize_swap="sudo mkswap $SWAP_FILE_PATH"
  exec_cmd "$initialize_swap"

  __process_msg "Turning on Swap"
  turn_swap_on="sudo swapon $SWAP_FILE_PATH"
  exec_cmd "$turn_swap_on"

}

check_fstab_entry() {
  __process_marker "Checking fstab entries"

  if grep -q $SWAP_FILE_PATH /etc/fstab; then
    __process_msg "/etc/fstab updated, swap check complete"
  else
    __process_msg "No entry in /etc/fstab, updating ..."
    add_swap_to_fstab="echo $SWAP_FILE_PATH none swap sw 0 0 | sudo tee -a /etc/fstab"
    exec_cmd "$add_swap_to_fstab"
    __process_msg "/etc/fstab updated"
  fi
}

main() {
  check_swap
  if [ "$is_swap_required" == true ]; then
    add_swap
  fi
  check_fstab_entry
}

main
