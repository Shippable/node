#!/bin/bash -e
__process_marker() {
  local prompt="$@"
  echo ""
  echo "# $(date +"%T") #######################################"
  echo "# $prompt"
  echo "##################################################"
}

__process_msg() {
  local message="$@"
  echo "|___ $@"
}

__process_error() {
  local message="$1"
  local error="$2"
  local bold_red_text='\e[91m'
  local reset_text='\033[0m'

  echo -e "$bold_red_text|___ $message$reset_text"
  echo -e "     $error"
}

__check_logsdir() {
  if [ ! -d "$LOGS_DIR" ]; then
    mkdir -p "$LOGS_DIR"
  fi
}

__cleanup_logfiles() {
  local maxlogfilescount=$(cat $STATE_FILE | jq -r '.logCount')
  if [ "$maxlogfilescount" == "" ] || [ "$maxlogfilescount" == null ]; then
    maxlogfilescount="$MAX_DEFAULT_LOG_COUNT"
  fi
  # ls -t | tail -n +"$maxlogfilescount" | xargs rm -- lists al the files sorted
  # by timestamp tails all the files except last 5 files and runs rm on them
  # one by one
  pushd "$LOGS_DIR"
  local filecount=$(ls | wc -l)
  if [ "$filecount" -gt "$maxlogfilescount" ]; then
    ls -t | tail -n +"$maxlogfilescount" | xargs rm --
  fi
  popd
}
