#!/bin/bash -e

sanitize_shippable_string() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl sanitize_shippable_string $NAME"
    exit 99
  fi
  echo "$1" | sed -e 's/[^a-zA-Z_0-9]//g'
}

to_uppercase(){
  if [ "$1" == "" ]; then
    echo "Usage: shipctl to_uppercase ANY_STRING"
    exit 99
  fi
  echo "$1" | awk '{print toupper($0)}'
}

get_resource_name() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_name RESOURCE_NAME"
    exit 99
  fi
  sanitize_shippable_string "$(to_uppercase "$1")"
}

get_resource_id() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_id RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  eval echo "$""$UP"_ID
}

get_resource_meta() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_meta RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  eval echo "$""$UP"_META
}

get_resource_state() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_state RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  eval echo "$""$UP"_STATE
}

# a reflection of get_resource_state
get_resource_path() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_path RESOURCE_NAME"
    exit 99
  fi
  get_resource_state $1
}

get_resource_operation() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_operation RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  eval echo "$""$UP"_OPERATION
}

get_resource_type() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_type RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  eval echo "$""$UP"_TYPE
}

get_resource_env() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl get_resource_env RESOURCE_NAME ENV_NAME"
    exit 99
  fi
  UP_RES=$(get_resource_name "$1")
  UP_ENV=$(to_uppercase "$2")
  eval echo "$""$UP_RES"_"$UP_ENV"
}

get_params_resource() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl get_params_resource RESOURCE_NAME PARAM_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  PARAMNAME=$(sanitize_shippable_string "$(to_uppercase "$2")")
  eval echo "$""$UP"_PARAMS_"$PARAMNAME"
}

get_integration_resource_keys() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_integration_resource_keys RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  RESOURCE_META=$(get_resource_meta $UP)
  if [ ! -d $RESOURCE_META ]; then
    echo "IN directory not present for resource: $1"
    exit 99
  fi
  RESOURCE_INTEGRATION_ENV_FILE=$RESOURCE_META/integration.env
  if [ ! -f $RESOURCE_INTEGRATION_ENV_FILE ]; then
    echo "integration.env not present for resource: $1"
    exit 99
  fi
  cat $RESOURCE_INTEGRATION_ENV_FILE | awk -F "=" '{print $1}'
}

get_integration_resource_field() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl get_integration_resource_field RESOURCE_NAME KEY_NAME"
    exit 99
  fi
  RESOURCE_INTEGRATION_MASTERNAME=$(get_integration_resource "$1" masterName)
  if [ "$RESOURCE_INTEGRATION_MASTERNAME" == "keyValuePair" ]; then
    eval echo "$""$2"
  else
    UP=$(get_resource_name "$1")
    INTKEYNAME=$(sanitize_shippable_string "$(to_uppercase "$2")")
    eval echo "$""$UP"_INTEGRATION_"$INTKEYNAME"
  fi
}

get_integration_keys() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_integration_keys INTEGRATION_NAME"
    exit 99
  fi
  INTEGRATION_ENV_FILE=$JOB_INTEGRATIONS/$1/integration.env
  if [ ! -f $INTEGRATION_ENV_FILE ]; then
    echo "integration.env not present for integration: $1"
    exit 99
  fi
  cat $INTEGRATION_ENV_FILE | awk -F "=" '{print $1}'
}

get_integration_field() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl get_integration_field INTEGRATION_NAME KEY_NAME"
    exit 99
  fi
  INTEGRATION_JSON_FILE=$JOB_INTEGRATIONS/$1/integration.json
  if [ ! -f $INTEGRATION_JSON_FILE ]; then
    echo "integration.json not present for integration: $1"
    exit 99
  fi
  if [ $(jq -r '.masterName' $INTEGRATION_JSON_FILE) == "keyValuePair" ]; then
    eval echo "$""$2"
  else
    UP=$(sanitize_shippable_string "$(to_uppercase "$1")")
    INTKEYNAME=$(sanitize_shippable_string "$(to_uppercase "$2")")
    eval echo "$""$UP"_INTEGRATION_"$INTKEYNAME"
  fi
}

get_resource_version_name() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_version_name RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  eval echo "$""$UP"_VERSIONNAME
}

get_resource_version_id() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_version_id RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  eval echo "$""$UP"_VERSIONID
}

get_resource_version_number() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_resource_version_number RESOURCE_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  eval echo "$""$UP"_VERSIONNUMBER
}

get_resource_version_key() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl get_resource_version_key RESOURCE_NAME KEY"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  RESOURCE_META=$(get_resource_meta $UP)
  if [ ! -d $RESOURCE_META ]; then
    echo "IN directory not present for resource: $1"
    exit 99
  fi
  RESOURCE_VERSION_FILE=$RESOURCE_META/version.json
  if [ ! -f $RESOURCE_VERSION_FILE ]; then
    echo "version.json not present for resource: $1"
    exit 99
  fi
  VERSION_KEYS_ARRAY=("versionName" "versionId" "versionNumber")
  FETCH_FROM_PROPERTYBAG=true
  for KEY in ${VERSION_KEYS_ARRAY[@]}
  do
    if [ "$KEY" == "$2" ]; then
      FETCH_FROM_PROPERTYBAG=false
      break
    fi
  done
  if [ "$FETCH_FROM_PROPERTYBAG" = true ]; then
    VERSION_KEY_CMD="cat $RESOURCE_VERSION_FILE | jq -r '.version.propertyBag.$2'"
  else
    VERSION_KEY_CMD="cat $RESOURCE_VERSION_FILE | jq -r '.version.$2'"
  fi
  eval $VERSION_KEY_CMD
}

get_integration_resource() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_integration_resource RESOURCE_NAME"
    exit 99
  fi
  META=$(get_resource_meta "$1")
  if [ -z "$2" ]; then
    if [ -f "$META/integration.json" ]; then
      cat "$META/integration.json"
    else
      echo "The given resource is not of type integration. $META/integration.json: No such file or directory"
    fi
  else
    if [ -f "$META/integration.json" ]; then
      cat "$META/integration.json" | jq -r '.'"$2"
    else
      echo "The given resource is not of type integration. $META/integration.json: No such file or directory"
    fi
  fi
}

get_json_value() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl get_json_value JSON_PATH FIELD"
    exit 99
  fi
  if [ -f "$1" ]; then
    cat "$1" | jq -r '.'"$2"
  else
    echo "$1: No such file present in this directory"
  fi
}

post_resource_state() {
  if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]; then
    echo "Usage: shipctl post_resource_state RESOURCE_NAME STATE_NAME STATE_VALUE"
    exit 99
  fi
  RES=$1
  STATENAME=$2
  STATEVALUE=$3
  echo "$STATENAME"="$STATEVALUE" > "$JOB_STATE/$RES.env"
}

put_resource_state() {
  if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]; then
    echo "Usage: shipctl put_resource_state RESOURCE_NAME STATE_NAME STATE_VALUE"
    exit 99
  fi
  RES=$1
  STATENAME=$2
  STATEVALUE=$3
  echo "$STATENAME"="$STATEVALUE" >> "$JOB_STATE/$RES.env"
}

copy_file_to_state() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl copy_file_to_state FILE_PATH"
    exit 99
  fi
  FILENAME=$1
  cp -vr "$FILENAME" "$JOB_STATE"
}

copy_file_from_prev_state() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl copy_file_from_prev_state FILE_PATH RESTORE_PATH"
    exit 99
  fi
  PREV_TF_STATEFILE=$JOB_PREVIOUS_STATE/$1
  PATH_TO_RESTORE_IN=$2

  echo "---------------- Restoring file from state -------------------"
  if [ -f "$PREV_TF_STATEFILE" ]; then
    echo "------  File exists, copying -----"
    cp -vr "$PREV_TF_STATEFILE" "$PATH_TO_RESTORE_IN"
  else
    echo "------  File does not exist in previous state, skipping -----"
  fi
}

refresh_file_to_state() {
  if [ "$1" == "" ]; then
    echo "Usage: shipctl refresh_file_to_state FILE_PATH"
    exit 99
  fi
  NEWSTATEFILE=$1
  #this could contain path i.e / too and hence try and find only filename
  #greedy trimming ## is greedy, / is the string to look for and return last
  #part
  ONLYFILENAME=${NEWSTATEFILE##*/}

  echo "---------------- Copying file to state -------------------"
  if [ -f "$NEWSTATEFILE" ]; then
    echo "---------------  New file exists, copying  ----------------"
    cp -vr "$NEWSTATEFILE" "$JOB_STATE"
  else
    echo "---  New file does not exist, hence try to copy from prior state ---"
    local PREVSTATE="$JOB_PREVIOUS_STATE/$ONLYFILENAME"
    if [ -f "$PREVSTATE" ]; then
      echo ""
      echo "------  File exists in previous state, copying -----"
      cp -vr "$PREVSTATE" "$JOB_STATE"
    else
      echo "-------  No previous state file exists. Skipping  ---------"
    fi
  fi
}

copy_resource_file_from_state() {
  if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]; then
    echo "Usage: shipctl copy_resource_file_from_state RESOURCE_NAME FILE_NAME PATH_TO_COPY_INTO"
    exit 99
  fi
  RES_NAME=$1
  FILE_NAME=$2
  RES_TYPE=$(get_resource_type $RES_NAME)
  PATH_TO_COPY_INTO=$3
  FULL_PATH="/build/IN/$RES_NAME/$RES_TYPE/$FILE_NAME"

  echo "---------------- Restoring file from state -------------------"
  if [ -f "$FULL_PATH" ]; then
    echo "----------------  File exists, copying -----------------------"
    cp -vr "$FULL_PATH" "$PATH_TO_COPY_INTO"
  else
    echo "------  File does not exist in $RES_NAME state, skipping -----"
  fi
}

#reflection of copy_resource_file_from_state
copy_file_from_resource_state() {
  if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ]; then
    echo "Usage: shipctl copy_file_from_resource_state RESOURCE_NAME FILE_NAME PATH_TO_COPY_INTO"
    exit 99
  fi
  copy_resource_file_from_state $1 $2 $3
}

refresh_file_to_out_path() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl refresh_file_to_out_path FILE_NAME RES_NAME"
    exit 99
  fi
  FILE_NAME=$1
  RES_NAME=$2

  #this could contain path i.e / too and hence try and find only filename
  #greedy trimming ## is greedy, / is the string to look for and return last
  #part
  ONLYFILENAME=${FILE_NAME##*/}
  RES_OUT_PATH="/build/OUT/$RES_NAME/state"
  RES_IN_PATH="/build/IN/$RES_NAME/state"

  echo "---------------- Copying file to state -------------------"
  if [ -f "$FILE_NAME" ]; then
      echo "---------------  New file exists, copying  ----------------"
      cp -vr "$FILE_NAME" "$RES_OUT_PATH"
  else
    echo "---  New file does not exist, hence try to copy from prior state ---"
    local PREVSTATE="$RES_IN_PATH/$ONLYFILENAME"
    if [ -f "$PREVSTATE" ]; then
      echo "------  File exists in previous state, copying -----"
      cp -vr "$PREVSTATE" "$RES_OUT_PATH"
    else
      echo "------  File does not exist in previous state, skipping -----"
    fi
  fi
}

#reflection of refresh_file_to_out_path
copy_file_to_resource_state() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl copy_file_to_resource_state FILE_NAME RES_NAME"
    exit 99
  fi
  refresh_file_to_out_path $1 $2
}

get_resource_pointer_key() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl get_resource_pointer RESOURCE_NAME POINTER_KEY"
    exit 99
  fi
  UP=$(get_resource_name "$1")
  RESOURCE_META=$(get_resource_meta $UP)
  if [ ! -d $RESOURCE_META ]; then
    echo "IN directory not present for resource: $1"
    exit 99
  fi
  RESOURCE_VERSION_FILE=$RESOURCE_META/version.json
  if [ ! -f $RESOURCE_VERSION_FILE ]; then
    echo "version.json not present for resource: $1"
    exit 99
  fi
  VERSION_KEY_CMD="cat $RESOURCE_VERSION_FILE | jq -r '.propertyBag.yml.pointer.$2'"
  eval $VERSION_KEY_CMD
}

post_resource_state_multi() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl post_resource_state_multi RESOURCE_NAME STATE_ARRAY"
    exit 99
  fi

  RES=$1; shift
  STATE_ARRAY=("$@")
  rm -rf "$JOB_STATE/$RES.env"
  for a in ${STATE_ARRAY[@]}; do
    echo $a >> "$JOB_STATE/$RES.env"
  done
}

put_resource_state_multi() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl put_resource_state_multi RESOURCE_NAME STATE_ARRAY"
    exit 99
  fi
  RES=$1; shift
  STATE_ARRAY=("$@")
  for a in ${STATE_ARRAY[@]}; do
    echo $a >> "$JOB_STATE/$RES.env"
  done
}

bump_version() {
  local version_to_bump=$1
  local action=$2
  local versionParts=$(echo "$version_to_bump" | cut -d "-" -f 1 -s)
  local prerelease=$(echo "$version_to_bump" | cut -d "-" -f 2 -s)
  if [[ $versionParts == "" && $prerelease == "" ]]; then
    # when no prerelease is present
    versionParts=$version_to_bump
  fi
  local major=$(echo "$versionParts" | cut -d "." -f 1 | sed "s/v//")
  local minor=$(echo "$versionParts" | cut -d "." -f 2)
  local patch=$(echo "$versionParts" | cut -d "." -f 3)
  if ! [[ $action == "major" || $action == "minor" || $action == "patch" ||
    $action == "rc" || $action == "alpha" || $action == "beta" || $action == "final" ]]; then
    echo "error: Invalid action given in the argument." >&2; exit 99
  fi
  local numRegex='^[0-9]+$'
  if ! [[ $major =~ $numRegex && $minor =~ $numRegex && $patch =~ $numRegex ]] ; then
    echo "error: Invalid semantics given in the argument." >&2; exit 99
  fi
  if [[ $(echo "$versionParts" | cut -d "." -f 1) == $major ]]; then
    appendV=false
  else
    appendV=true
  fi
  if [[ $action == "final" ]];then
    local new_version="$major.$minor.$patch"
  else
    if [[ $action == "major" ]]; then
      major=$((major + 1))
      minor=0
      patch=0
    elif [[ $action == "minor" ]]; then
      minor=$((minor + 1))
      patch=0
    elif [[ $action == "patch" ]]; then
      patch=$((patch + 1))
    elif [[ $action == "rc" || $action == "alpha" || $action == "beta" ]]; then
      local prereleaseCount="";
      local prereleaseText="";
      if [ ! -z $(echo "$prerelease" | grep -oP "$action") ]; then
        local count=$(echo "$prerelease" | grep -oP "$action.[0-9]*")
        if [ ! -z $count ]; then
          prereleaseCount=$(echo "$count" | cut -d "." -f 2 -s)
          prereleaseCount=$(($prereleaseCount + 1))
        else
          prereleaseCount=1
        fi
        prereleaseText="$action.$prereleaseCount"
      else
        prereleaseText=$action
      fi
    fi
    local new_version="$major.$minor.$patch"
    if [[ $prereleaseText != "" ]]; then
      new_version="$new_version-$prereleaseText"
    fi
  fi
  if [[ $appendV == true ]]; then
    new_version="v$new_version"
  fi
  echo $new_version
}

get_git_changes() {
  if [[ $# -le 0 ]]; then
    echo "Usage: shipctl get_git_changes [--path | --resource]"
    exit 99
  fi

  # declare options
  local opt_path=""
  local opt_resource=""
  local opt_depth=0
  local opt_directories_only=false
  local opt_commit_range=""

  for arg in "$@"
  do
    case $arg in
      --path=*)
      opt_path="${arg#*=}"
      shift
      ;;
      --resource=*)
      opt_resource="${arg#*=}"
      shift
      ;;
      --depth=*)
      opt_depth="${arg#*=}"
      shift
      ;;
      --directories-only)
      opt_directories_only=true
      shift
      ;;
      --commit-range=*)
      opt_commit_range="${arg#*=}"
      shift
      ;;
    esac
  done

  # obtain the path of git repository
  if [[ "$opt_path" == "" ]] && [[ "$opt_resource" == "" ]]; then
    echo "Usage: shipctl get_git_changes [--path|--resource]"
    exit 99
  fi

  # set file path of git repository
  local git_repo_path="$opt_path"
  if [[ "$git_repo_path" == "" ]]; then
    git_repo_path=$(get_resource_state "$opt_resource")
  fi

  if [[ ! -d "$git_repo_path/.git" ]]; then
    echo "git repository not found at path: $git_repo_path"
    exit 99
  fi

  # set default commit range
  # for CI
  local commit_range="$SHIPPABLE_COMMIT_RANGE"

  # for runSh with IN: gitRepo
  if [[ "$opt_resource" != "" ]]; then
    # for runSh with IN: gitRepo commits
    local current_commit_sha=$(shipctl get_resource_version_key $opt_resource shaData.commitSha)
    local before_commit_sha=$(shipctl get_resource_version_key $opt_resource shaData.beforeCommitSha)
    commit_range="$before_commit_sha..$current_commit_sha"

    # for runSh with IN: gitRepo pull requests
    local is_pull_request=$(shipctl get_resource_env $opt_resource is_pull_request)
    if [[ "$is_pull_request" == true ]]; then
      local current_commit_sha=$(shipctl get_resource_version_key $opt_resource shaData.commitSha)
      local base_branch=$(shipctl get_resource_env $opt_resource base_branch)
      commit_range="origin/$base_branch...$current_commit_sha"
    fi
  fi

  if [[ "$opt_commit_range" != "" ]]; then
    commit_range="$opt_commit_range"
  fi
  if [[ "$commit_range" == "" ]]; then
    echo "Unknown commit range. use --commit-range."
    exit 99
  fi

  local result=""
  pushd $git_repo_path > /dev/null
    result=$(git diff --name-only $commit_range)

    if [[ "$opt_directories_only" == true ]]; then
      result=$(git diff --dirstat $commit_range | awk '{print $2}')
    fi

    if [[ $opt_depth -gt 0 ]]; then
      if [[ result != "" ]]; then
        result=$(echo "$result" | awk -F/ -v depth=$opt_depth '{print $depth}')
      fi
    fi
  popd > /dev/null

  echo "$result" | uniq
}

notify() {
  if [[ $# -le 0 ]]; then
    echo "Usage: shipctl notify RESOURCE [OPTIONS]"
    exit 99
  fi

  # parse and validate the resource details
  local r_name="$1"
  shift

  local r_type=$(get_resource_type "$r_name")
  if [ -z "$r_type" ]; then
    echo "Error: resource data not found for $r_name"
    exit 99
  elif [ "$r_type" != "notification" ]; then
    echo "Error: resource $r_name is not of type 'notification'"
    exit 99
  fi

  local meta=$(shipctl get_resource_meta $r_name)
  local r_method=$(jq -r ".version.propertyBag.method" $meta/version.json)

  # declare options and defaults, and parse arguments

  export opt_color="$NOTIFY_COLOR"
  if [ -z "$opt_color" ]; then
    opt_color="#65cea7"
  fi

  export opt_icon_url="$NOTIFY_ICON_URL"
  if [ -z "$opt_icon_url" ]; then
    opt_icon_url="${SHIPPABLE_WWW_URL}/images/slack-aye-aye-yoga.png"
  fi

  export opt_payload="$NOTIFY_PAYLOAD"
  if [ -z "$opt_payload" ]; then
    opt_payload=""
  fi
  export opt_pretext="$NOTIFY_PRETEXT"
  if [ -z "$opt_pretext" ]; then
    opt_pretext="`date`\n"
  fi

  export opt_recipient="$NOTIFY_RECIPIENT"
  if [ -z "$opt_recipient" ]; then
    opt_recipient=""
  fi

  export opt_username="$NOTIFY_USERNAME"
  if [ -z "$opt_username" ]; then
    if [ "$r_method" == "irc" ]; then
      opt_username="Shippable-$BUILD_NUMBER"
    else
      opt_username="Shippable"
    fi
  fi

  export opt_password="$NOTIFY_PASSWORD"
  if [ -z "$opt_password" ]; then
    opt_password="none"
  fi

  export opt_text="$NOTIFY_TEXT"
  if [ -z "$opt_text" ]; then
    # set up default text
    opt_text=""
    case $JOB_TYPE in
      "runCI" )
        if [ "$r_method" == "irc" ]; then
          opt_text="[${REPO_FULL_NAME}:${BRANCH}] Build #${BUILD_NUMBER} ${BUILD_URL}"
        else
          opt_text="[${REPO_FULL_NAME}:${BRANCH}] <${BUILD_URL}|Build#${BUILD_NUMBER}>"
        fi
        ;;
      "runSh" )
        if [ "$r_method" == "irc" ]; then
          opt_text="[${JOB_NAME}] Build #${BUILD_NUMBER} ${BUILD_URL}"
        else
          opt_text="[${JOB_NAME}] <${BUILD_URL}|Build#${BUILD_NUMBER}>"
        fi
        ;;
      *)
        echo "Error: unsupported job type: $JOB_TYPE"
        exit 99
        ;;
    esac
  fi

  for arg in "$@"
  do
    case $arg in
      --color=*)
        opt_color="${arg#*=}"
        shift
        ;;
      --icon_url=*)
        opt_icon_url="${arg#*=}"
        shift
        ;;
      --payload=*)
        opt_payload="${arg#*=}"
        shift
        ;;
      --pretext=*)
        opt_pretext="${arg#*=}"
        shift
        ;;
      --recipient=*)
        opt_recipient="${arg#*=}"
        shift
        ;;
      --text=*)
        opt_text="${arg#*=}"
        shift
        ;;
      --username=*)
        opt_username="${arg#*=}"
        shift
        ;;
      --password=*)
        opt_password="${arg#*=}"
        shift
        ;;
    esac
  done

  local recipients_list=()

  if [ "$r_method" == "irc" ]; then
    if [ -z "$opt_recipient" ]; then
      recipients_list=($(jq -r ".version.propertyBag.recipients[]" $meta/version.json))
    fi
    if [ ${#recipients_list[@]} -gt 0 ]; then
      for recipient in ${recipients_list[@]};
      do
        opt_recipient="$recipient"

        IFS='#' read -a irc_recipient <<< "$opt_recipient"

        if [ -z "${irc_recipient[1]}" ]; then
          echo "Error: no channel found in recipient $opt_recipient"
          exit 99
        fi
        if [ -z "${irc_recipient[0]}" ]; then
          echo "Error: no server address found in recipient $opt_recipient"
          exit 99
        fi

        echo "sending notification to $opt_recipient"
        {
          sleep 10;
          echo "PASS $opt_password";
          echo "USER `whoami` 0 * :$opt_username";
          echo "NICK $opt_username";
          sleep 5;
          echo "JOIN #${irc_recipient[1]}";
          echo "NOTICE #${irc_recipient[1]} :$opt_text";
          echo "QUIT";
        } | nc ${irc_recipient[0]} 6667
      done
    else
      if [ -n "$opt_recipient" ]; then
        echo "sending notification to \"$opt_recipient\""
      fi

      IFS='#' read -a irc_recipient <<< "$opt_recipient"

      if [ -z "${irc_recipient[1]}" ]; then
        echo "Error: no channel found in recipient $opt_recipient"
        exit 99
      fi
      if [ -z "${irc_recipient[0]}" ]; then
        echo "Error: no server address found in recipient $opt_recipient"
        exit 99
      fi

      {
        sleep 10;
        echo "PASS $opt_password";
        echo "USER `whoami` 0 * :$opt_username";
        echo "NICK $opt_username";
        sleep 5;
        echo "JOIN #${irc_recipient[1]}";
        echo "NOTICE #${irc_recipient[1]} :$opt_text";
        echo "QUIT";
      } | nc ${irc_recipient[0]} 6667
    fi
  else
    local r_mastername=$(get_integration_resource "$r_name" masterName)
    local curl_auth=""

    # set up the default payloads once options have been parsed
    local default_slack_payload="{\"username\":\"\${opt_username}\",\"attachments\":[{\"pretext\":\"\${opt_pretext}\",\"text\":\"\${opt_text}\",\"color\":\"\${opt_color}\"}],\"channel\":\"\${opt_recipient}\",\"icon_url\":\"\${opt_icon_url}\"}"
    local default_webhook_payload="{\"username\":\"\${opt_username}\",\"pretext\":\"\${opt_pretext}\",\"text\":\"\${opt_text}\",\"color\":\"\${opt_color}\",\"recipient\":\"\${opt_recipient}\",\"icon_url\":\"\${opt_icon_url}\"}"
    local default_payload=""

    # set up type-unique options
    case "$r_mastername" in
      "Slack"|"slackKey" )
        default_payload="$default_slack_payload"
        if [ -z "$opt_recipient" ]; then
          recipients_list=($(jq -r ".version.propertyBag.recipients[]" $meta/version.json))
        fi
        ;;
      "webhook"|"webhookV2" )
        local r_authorization=$(get_integration_resource_field "$r_name" authorization)
        if [ -n "$r_authorization" ]; then
          curl_auth="-H authorization:'$r_authorization'"
        fi
        default_payload="$default_webhook_payload"
        ;;
      *)
        echo "Error: unsupported notification type: $r_mastername"
        exit 99
        ;;
    esac

    local r_endpoint=$(get_integration_resource_field "$r_name" webhookUrl)
    if [ -z "$r_endpoint" ]; then
      echo "Error: no endpoint found in resource $r_name"
      exit 99
    fi

    if [ -n "$opt_payload" ]; then
      if [ ! -f $opt_payload ]; then
        echo "Error: file not found at path: $opt_payload"
        exit 99
      fi
      local isValid=$(jq type $opt_payload || true)
      if [ -z "$isValid" ]; then
        echo "Error: payload is not valid JSON"
        exit 99
      fi
      _send_curl "$opt_payload" "$curl_auth" "$r_endpoint"
    else
      if [ ${#recipients_list[@]} -gt 0 ]; then
        for recipient in ${recipients_list[@]};
        do
          opt_recipient="$recipient"
          echo $default_payload > /tmp/payload.json
          opt_payload=/tmp/payload.json
          shipctl replace $opt_payload

          local isValid=$(jq type $opt_payload || true)
          if [ -z "$isValid" ]; then
            echo "Error: payload is not valid JSON"
            exit 99
          fi
          echo "sending notification to $opt_recipient"
          _send_curl "$opt_payload" "$curl_auth" "$r_endpoint"
        done
      else
        echo $default_payload > /tmp/payload.json
        opt_payload=/tmp/payload.json
        shipctl replace $opt_payload

        local isValid=$(jq type $opt_payload || true)
        if [ -z "$isValid" ]; then
          echo "Error: payload is not valid JSON"
          exit 99
        fi
        if [ -n "$opt_recipient" ]; then
          echo "sending notification to \"$opt_recipient\""
        fi
        _send_curl "$opt_payload" "$curl_auth" "$r_endpoint"
      fi
    fi
  fi
}

_send_curl() {
  local payload=$1
  local auth=$2
  local endpoint=$3

  local curl_cmd="curl -XPOST -sS -H content-type:'application/json' $auth $endpoint -d @$payload"
  eval $curl_cmd
  echo ""
}
