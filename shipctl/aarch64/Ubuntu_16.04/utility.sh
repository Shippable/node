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
  UP=$(get_resource_name "$1")
  INTKEYNAME=$(sanitize_shippable_string "$(to_uppercase "$2")")
  eval echo "$""$UP"_INTEGRATION_"$INTKEYNAME"
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
  UP=$(sanitize_shippable_string "$(to_uppercase "$1")")
  INTKEYNAME=$(sanitize_shippable_string "$(to_uppercase "$2")")
  eval echo "$""$UP"_INTEGRATION_"$INTKEYNAME"
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

replicate() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl replicate FROM_resource_name TO_resource_name"
    exit 99
  fi
  local resFrom=$1
  local resTo=$2
  local typeFrom="$(shipctl get_resource_type $resFrom)"
  local typeTo="$(shipctl get_resource_type $resTo)"

  # declare options
  local opt_files_only=""
  local opt_metadata_only=""
  local opt_webhook_data_only=""
  local opt_to_current_job=""
  local opt_match_settings=""
  local canMatchSettings=""

  for arg in "$@"
  do
    case $arg in
      --files-only )
        opt_files_only="true"
        shift
        ;;
      --metadata-only )
        opt_metadata_only="true"
        shift
        ;;
      --webhook-data-only )
        opt_webhook_data_only="true"
        shift
        ;;
      --match-settings )
        opt_match_settings="true"
        shift
        ;;
      --* )
        echo "Warning: Unrecognized flag \"$arg\""
        shift
        ;;
    esac
  done
  if [ "$resFrom" == "$JOB_NAME" ]; then
    echo "Error: current job cannot be the FROM argument"
    exit 99
  fi
  if [ "$typeTo" = "ciRepo" ]; then
    echo "Error: cannot replicate to ciRepo"
    exit 99
  fi
  if [[ "$typeFrom" =~ ^gitRepo|ciRepo|syncRepo$ ]] && [[ "$typeTo" =~ ^gitRepo|syncRepo$ ]]; then
    opt_metadata_only="true"
    canMatchSettings="true"
  elif [ "$resTo" == "$JOB_NAME" ]; then
    opt_to_current_job="true"
  elif [ "$typeFrom" != "$typeTo" ]; then
    echo "Error: resources must be the same type."
    exit 99
  fi

  if [ -n "$opt_match_settings" ] && [ -z "$canMatchSettings" ]; then
    echo "Error: --match-settings flag not supported for the specified resources."
    exit 99
  fi

  if [ -n "$opt_match_settings" ] && [ -n "$canMatchSettings" ]; then
    opt_webhook_data_only="true"
    local fromVersionFile="$JOB_PATH/IN/$resFrom/version.json"
    local toVersionFile="$JOB_PATH/OUT/$resTo/version.json"
    local fromShaData=$(jq '.version.propertyBag.shaData' $fromVersionFile)
    local shouldReplicate="true"
    if [ -z "$fromShaData" ]; then
      echo "Error: FROM resource does not contain shaData."
      exit 99
    fi
    # check for tag-based types.
    local isGitTag=$(jq '.version.propertyBag.shaData.isGitTag' $fromVersionFile)
    local isRelease=$(jq '.version.propertyBag.shaData.isRelease' $fromVersionFile)
    if [ "$isGitTag" == "true" ]; then
      local gitTagName=$(jq -r '.version.propertyBag.shaData.gitTagName' $fromVersionFile)
      # check if TO has a tags only/except section. Will be empty string otherwise.
      local toTagsOnly=$(jq -r '.version.propertyBag | select(.tags.only) | .tags.only[]' $toVersionFile)
      local toTagsExcept=$(jq -r '.version.propertyBag | select(.tags.except) | .tags.except[]' $toVersionFile)
      if [ -n "$toTagsOnly" ]; then
        local matchedTag=""
        if [ ${#toTagsOnly[@]} -gt 0 ]; then
          for tag in ${toTagsOnly[@]};
          do
            if [[ $gitTagName = $tag ]]; then
              matchedTag="true"
            fi
          done
          if [ "$matchedTag" != "true" ]; then
            shouldReplicate=""
          fi
        fi
      fi
      if [ -n "$toTagsExcept" ]; then
        local matchedTag=""
        if [ ${#toTagsExcept[@]} -gt 0 ]; then
          for tag in ${toTagsExcept[@]};
          do
            if [[ $gitTagName = $tag ]]; then
              matchedTag="true"
            fi
          done
          if [ "$matchedTag" == "true" ]; then
            shouldReplicate=""
          fi
        fi
      fi
    elif [ "$isRelease" != "true" ]; then
      # if it's not a tag, and it's not a release, treat it as a branch.
      local branchName=$(jq -r '.version.propertyBag.shaData | select(.branchName) | .branchName' $fromVersionFile)
      if [ -z "$branchName" ]; then
        echo "Error: no branch name in FROM resource shaData. Cannot replicate."
        return 0
      fi
      local toBranch=$(jq -r '.version.propertyBag | select(.branch) | .branch' $toVersionFile)
      local toBranchesOnly=$(jq -r '.version.propertyBag | select(.branches.only) | .branches.only[]' $toVersionFile)
      local toBranchesExcept=$(jq -r '.version.propertyBag | select(.branches.except) | .branches.except[]' $toVersionFile)
      if [ -n "$toBranch" ]; then
        # this is the case where the TO repo is configured for a single branch.
        if [ "$toBranch" != "$branchName" ]; then
          shouldReplicate=""
        fi
      else
        # if not configured for a single branch, then check the only/except sections
        if [ -n "$toBranchesOnly" ]; then
          local matchedBranch=""
          if [ ${#toBranchesOnly[@]} -gt 0 ]; then
            for branch in ${toBranchesOnly[@]};
            do
              if [[ $branchName = $branch ]]; then
                matchedBranch="true"
              fi
            done
            if [ "$matchedBranch" != "true" ]; then
              shouldReplicate=""
            fi
          fi
        fi
        if [ -n "$toBranchesExcept" ]; then
          local matchedBranch=""
          if [ ${#toBranchesExcept[@]} -gt 0 ]; then
            for branch in ${toBranchesExcept[@]};
            do
              if [[ $branchName = $branch ]]; then
                matchedBranch="true"
              fi
            done
            if [ "$matchedBranch" == "true" ]; then
              shouldReplicate=""
            fi
          fi
        fi
      fi
    fi

    if [ -z "$shouldReplicate" ]; then
      echo "FROM shaData does not match TO settings. skipping replicate"
      return 0
    fi
  fi

  # copy files
  if [ -z "$opt_metadata_only" ]; then
    local pathFrom="$JOB_PATH/IN/$resFrom/$typeFrom"
    local pathTo=""
    if [ -z "$opt_to_current_job" ]; then
      pathTo="$JOB_PATH/OUT/$resTo/$typeTo"
    else
      pathTo="$JOB_STATE"
    fi
    if [ -d "$pathFrom" ] && [ -n "$(ls -A $pathFrom)" ]; then
      # files exist. copy them.
      rm -rf $pathTo/*
      cp -r $pathFrom/* $pathTo
    fi
  fi

  # copy values
  if [ -z "$opt_files_only" ]; then
    local mdFilePathFrom="$JOB_PATH/IN/$resFrom/version.json"
    local mdFilePathTo=""
    if [ -z "$opt_to_current_job" ]; then
      mdFilePathTo="$JOB_PATH/OUT/$resTo/version.json"
    else
      mdFilePathTo="$JOB_STATE/outputVersion.json"
      if [ ! -f "$mdFilePathTo" ]; then
        echo "{}" > $mdFilePathTo
      fi
    fi
    if [ -f "$mdFilePathFrom" ] && [ -f "$mdFilePathTo" ]; then
      if [ -z "$(which jq)" ]; then
        echo "Error: jq is required for metadata copy"
        exit 99
      fi
      if [ -z "$opt_webhook_data_only" ]; then
        local fromVersion=$(jq '.version.propertyBag' $mdFilePathFrom)
        local tmpFilePath=""
        if [ -n "$opt_to_current_job" ]; then
          tmpFilePath="$JOB_STATE/copyTmp.json"
          cp $mdFilePathTo  $tmpFilePath
          jq ".propertyBag = $fromVersion" $tmpFilePath > $mdFilePathTo
        else
          tmpFilePath="$JOB_PATH/OUT/$resTo/copyTmp.json"
          cp $mdFilePathTo  $tmpFilePath
          jq ".version.propertyBag = $fromVersion" $tmpFilePath > $mdFilePathTo
        fi
        rm $tmpFilePath
      else
        # store only the 3 fields that count as webhook data
        local fromShaData=$(jq '.version.propertyBag.shaData' $mdFilePathFrom)
        local fromWebhookRequestHeaders=$(jq '.version.propertyBag.webhookRequestHeaders' $mdFilePathFrom)
        local fromWebhookRequestBody=$(jq '.version.propertyBag.webhookRequestBody' $mdFilePathFrom)
        local tmpFilePath=""
        if [ -n "$opt_to_current_job" ]; then
          tmpFilePath="$JOB_STATE/copyTmp.json"
        else
          tmpFilePath="$JOB_PATH/OUT/$resTo/copyTmp.json"
        fi

        if [ "$fromShaData" != "null" ]; then
          cp $mdFilePathTo  $tmpFilePath
          jq ".version.propertyBag.shaData = $fromShaData" $tmpFilePath > $mdFilePathTo
        fi
        if [ "$fromWebhookRequestHeaders" != "null" ]; then
          cp $mdFilePathTo  $tmpFilePath
          jq ".version.propertyBag.webhookRequestHeaders = $fromWebhookRequestHeaders" $tmpFilePath > $mdFilePathTo
        fi
        if [ "$fromWebhookRequestBody" != "null" ]; then
          cp $mdFilePathTo  $tmpFilePath
          jq ".version.propertyBag.webhookRequestBody = $fromWebhookRequestBody" $tmpFilePath > $mdFilePathTo
        fi

        if [ -n "$opt_to_current_job" ]; then
          local propertyBag=$(jq '.version.propertyBag' $mdFilePathTo)
          echo "{\"propertyBag\":$propertyBag}" > $mdFilePathTo
        fi

        if [ -f "$tmpFilePath" ]; then
          rm $tmpFilePath
        fi
      fi
    fi
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
  FULL_PATH="$JOB_PATH/IN/$RES_NAME/$RES_TYPE/$FILE_NAME"

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
  RES_OUT_PATH="$JOB_PATH/OUT/$RES_NAME/state"
  RES_IN_PATH="$JOB_PATH/IN/$RES_NAME/state"

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

split_tests() {
  local test_path=$1
  local test_files_name_regex=$2
  local test_reports_path=$3

  if [ "$test_path" == "" ] || [ "$test_files_name_regex" == "" ] || [ "$test_reports_path" == "" ]; then
    echo "Usage: shipctl split_tests TEST_PATH TEST_FILES_NAME_REGEX TEST_REPORTS_PATH"
    exit 99
  fi

  # delete tmp files
  rm -rf /tmp/current_tests.txt
  rm -rf /tmp/cached_test_timings.txt
  rm -rf /tmp/sorted_cached_test_timings.txt
  rm -rf /tmp/sorted_cached_tests.txt

  # create tmp files
  touch /tmp/current_tests.txt
  touch /tmp/cached_test_timings.txt
  touch /tmp/sorted_cached_test_timings.txt
  touch /tmp/sorted_cached_tests.txt

  for current_test_file in "$(find $test_path -name $test_files_name_regex)";
  do
    echo -e "$current_test_file\n" >> /tmp/current_tests.txt;
  done

  find $test_reports_path -name \*.xml | while read cached_test_report_file;
  do
    echo $(xq .testsuites.testsuite $cached_test_report_file | jq -cr '.["@filepath"]," ", .["@time"]') >> /tmp/cached_test_timings.txt
  done

  sort -k 2n /tmp/cached_test_timings.txt > /tmp/sorted_cached_test_timings.txt
  awk -F " " '{print $1}' /tmp/sorted_cached_test_timings.txt > /tmp/sorted_cached_tests.txt
  IFS=$'\r\n' GLOBIGNORE='*' command eval  'sorted_cached_tests=($(cat /tmp/sorted_cached_tests.txt))'
  IFS=$'\r\n' GLOBIGNORE='*' command eval  'current_tests=($(cat /tmp/current_tests.txt))'
  all_tests=()
  current_job_tests=()
  # iterate through past tests(cached),
  # put the once which are in current tests list in the beginning of all_tests
  # so that sorted tests are distributed across jobs
  for sorted_cached_test in "${sorted_cached_tests[@]}";
  do
    skip=
    for current_test in "${current_tests[@]}";
    do
      [[ $sorted_cached_test == *$current_test ]] && { skip=1; break; }
    done
    [[ -n $skip ]] && all_tests+=($sorted_cached_test)
  done

  # iterate through current tests, put the remaining(unsorted) tests in the end all_tests
  for current_test in "${current_tests[@]}";
  do
    skip=
    for sorted_cached_test in "${sorted_cached_tests[@]}";
    do
      [[ $sorted_cached_test == *$current_test ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || all_tests+=($current_test)
  done

  tLen=${#all_tests[@]}
  for (( count=${SHIPPABLE_JOB_NUMBER}-1; count<${tLen}; count=count+${SHIPPABLE_JOB_COUNT} ));
  do
    current_job_tests+=(${all_tests[$count]})
  done

  for file in "${current_job_tests[@]}"
  do
    eval echo "$file"
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
  local r_mastername=$(get_integration_resource "$r_name" masterName)

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

  export opt_type="$NOTIFY_TYPE"
  if [ -z "$opt_type" ]; then
    opt_type=""
  fi

  export opt_revision="$NOTIFY_REVISION"
  if [ -z "$opt_revision" ]; then
    opt_revision=""
  fi

  export opt_description="$NOTIFY_DESCRIPTION"
  if [ -z "$opt_description" ]; then
    opt_description=""
  fi

  export opt_changelog="$NOTIFY_CHANGELOG"
  if [ -z "$opt_changelog" ]; then
    opt_changelog=""
  fi

  export opt_project_id="$NOTIFY_PROJECT_ID"
  if [ -z "$opt_project_id" ]; then
    opt_project_id=""
  fi

  export opt_environment="$NOTIFY_ENVIRONMENT"
  if [ -z "$opt_environment" ]; then
    opt_environment=""
  fi

  export opt_email="$NOTIFY_EMAIL"
  if [ -z "$opt_email" ]; then
    opt_email=""
  fi

  export opt_repository="$NOTIFY_REPOSITORY"
  if [ -z "$opt_repository" ]; then
    opt_repository=""
  fi

  export opt_version="$NOTIFY_VERSION"
  if [ -z "$opt_version" ]; then
    opt_version=""
  fi

  export opt_summary="$NOTIFY_SUMMARY"
  if [ -z "$opt_summary" ]; then
    opt_summary=""
  fi

  export opt_attach_file="$NOTIFY_ATTACH_FILE"
  if [ -z "$opt_attach_file" ]; then
    opt_attach_file=""
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
      --type=*)
        opt_type="${arg#*=}"
        shift
        ;;
      --revision=*)
        opt_revision="${arg#*=}"
        shift
        ;;
      --description=*)
        opt_description="${arg#*=}"
        shift
        ;;
      --changelog=*)
        opt_changelog="${arg#*=}"
        shift
        ;;
      --appId=*)
        opt_appId="${arg#*=}"
        shift
        ;;
      --appName=*)
        opt_appName="${arg#*=}"
        shift
        ;;
      --project-id=*)
        opt_project_id="${arg#*=}"
        shift
        ;;
      --environment=*)
        opt_environment="${arg#*=}"
        shift
        ;;
      --email=*)
        opt_email="${arg#*=}"
        shift
        ;;
      --repository=*)
        opt_repository="${arg#*=}"
        shift
        ;;
      --version=*)
        opt_version="${arg#*=}"
        shift
        ;;
      --summary=*)
        opt_summary="${arg#*=}"
        shift
        ;;
      --attach-file=*)
        opt_attach_file="${arg#*=}"
        shift
        ;;
    esac
  done

  local recipients_list=()

  if [ "$r_method" == "irc" ]; then

    local irc_command=""

    if type nc &> /dev/null && true; then
      irc_command=nc
    elif type ncat &> /dev/null && true; then
      irc_command=ncat
    elif type telnet &> /dev/null && true; then
      irc_command=telnet
    else
      echo "Error: no command found to send IRC messages"
      echo "Error: nc, ncat, or telnet must be installed"
      exit 99
    fi

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
        } | ${irc_command} ${irc_recipient[0]} 6667
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
      } | ${irc_command} ${irc_recipient[0]} 6667
    fi
  elif [ "$r_mastername" == "newRelicKey" ]; then
    _notify_newrelic
  elif [ "$r_mastername" == "airBrakeKey" ]; then
    _notify_airbrake
  elif [ "$r_mastername" == "jira" ]; then
    _notify_jira
  else
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
      _post_curl "$opt_payload" "$curl_auth" "$r_endpoint"
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
          _post_curl "$opt_payload" "$curl_auth" "$r_endpoint"
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
        _post_curl "$opt_payload" "$curl_auth" "$r_endpoint"
      fi
    fi
  fi
}

_notify_newrelic() {
  local curl_auth=""
  local appId=""
  local r_endpoint=""
  local default_post_deployment_payload="{\"\${opt_type}\":{\"revision\":\"\${opt_revision}\",\"description\":\"\${opt_description}\",\"user\":\"\${opt_username}\",\"changelog\":\"\${opt_changelog}\"}}"
  local default_get_appid_payload="--data-urlencode 'filter[name]=$opt_appName' -d 'exclude_links=true'"
  local default_get_payload=""
  local default_post_payload=""
  local r_authorization=$(get_integration_resource_field "$r_name" token)

  if [ -n "$r_authorization" ]; then
    curl_auth="-H X-Api-Key:'$r_authorization'"
  fi

  local r_url=$(get_integration_resource_field "$r_name" url)
  if [ -z "$r_url" ]; then
    echo "Error: no url found in resource $r_name"
    exit 99
  fi

  if [ -z "$opt_appId" ] && [ -z "$opt_appName" ]; then
    echo "Error: --appId or --appName should be present in shipctl notify"
    exit 99
  fi
  # get the appId from the appName by making a get request to newrelic, if appId is not present
  appId="$opt_appId"
  if [ -z "$appId" ]; then
    r_endpoint="$r_url/applications.json"
    default_get_payload="$default_get_appid_payload"
    local applications=$(_get_curl "$default_get_payload" "$curl_auth" "$r_endpoint")
    appId=$(echo $applications | jq ".applications[0].id // empty")
  fi

  # record the deployment
  if [ -z "$appId" ]; then
    echo "Error: Unable to find an application on NewRelic"
    exit 99
  fi
  r_endpoint="$r_url/applications/$appId/deployments.json"
  default_post_payload="$default_post_deployment_payload"

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
    echo "Recording deployments on NewRelic for appID: $appId"
    local deployment=$(_post_curl "$opt_payload" "$curl_auth" "$r_endpoint")
    local deploymentId=$(echo $deployment | jq ".deployment.id")
    if [ -z "$deploymentId" ]; then
      echo "Error: $deployment"
      exit 99
    else
      echo "Deployment Id: $deploymentId"
    fi
  else
    if [ -z "$opt_type" ]; then
      echo "Error: --type is missing in shipctl notify"
      exit 99
    fi
    if [ -z "$opt_revision" ]; then
      echo "Error: --revision is missing in shipctl notify"
      exit 99
    fi
    echo $default_post_payload > /tmp/payload.json
    opt_payload=/tmp/payload.json
    shipctl replace $opt_payload
    local isValid=$(jq type $opt_payload || true)
    if [ -z "$isValid" ]; then
      echo "Error: payload is not valid JSON"
      exit 99
    fi
    echo "Recording deployments on NewRelic for appID: $appId"
    local deployment=$(_post_curl "$opt_payload" "$curl_auth" "$r_endpoint")
    local deploymentId=$(echo $deployment | jq ".deployment.id")
    if [ -z "$deploymentId" ]; then
      echo "Error: $deployment"
      exit 99
    else
      echo "Deployment Id: $deploymentId"
    fi
  fi
}

_notify_airbrake() {
  local curl_auth=""
  local r_obj_type=""
  local r_project_id="${opt_project_id}"
  local r_endpoint=$(get_integration_resource_field "$r_name" url)
  local r_token=$(get_integration_resource_field "$r_name" token)
  local default_airbrake_payload="{\"environment\":\"\${opt_environment}\",\"username\":\"\${opt_username}\",\"email\":\"\${opt_email}\",\"repository\":\"\${opt_repository}\",\"revision\":\"\${opt_revision}\",\"version\":\"\${opt_version}\"}"

  if [ -z "$opt_type" ]; then
    echo "Error: --type is missing in shipctl notify"
    exit 99
  fi
  if [ "$opt_type" == "deploy" ]; then
    r_obj_type="deploys"
  else
    echo "Error: unsupported type value $opt_type"
    exit 99
  fi

  if [ -z "$r_project_id" ]; then
    recipients_list=($(jq -r ".version.propertyBag.recipients[]" $meta/version.json))
    r_project_id=${recipients_list[0]}
  fi
  if [ -z "$r_project_id" ]; then
    echo "Error: missing project ID, try passing --project-id"
    exit 99
  fi

  r_endpoint="${r_endpoint%/}"
  r_endpoint="${r_endpoint}/projects/${r_project_id}/${r_obj_type}?key=${r_token}"

  if [ -n "$opt_payload" ]; then
    if [ ! -f $opt_payload ]; then
      echo "Error: file not found at path: $opt_payload"
      exit 99
    fi
  else
    echo $default_airbrake_payload > /tmp/payload.json
    opt_payload=/tmp/payload.json
    shipctl replace $opt_payload
  fi

  local isValid=$(jq type $opt_payload || true)
  if [ -z "$isValid" ]; then
    echo "Error: payload is not valid JSON"
    exit 99
  fi

  echo "Requesting Airbrake project: $r_project_id"

  _post_curl "$opt_payload" "$curl_auth" "$r_endpoint"
}

_notify_jira() {
  local r_username=$(get_integration_resource_field "$r_name" username)
  local r_endpoint=$(get_integration_resource_field "$r_name" url)
  local r_token=$(get_integration_resource_field "$r_name" token)
  local default_jira_payload="{\"fields\":{\"project\":{\"key\":\"\${opt_project_id}\"},\"summary\":\"\${opt_summary}\",\"description\":\"\${opt_description}\",\"issuetype\":{\"name\":\"\${opt_type}\"}}}"

  if [ -z "$(which base64)" ]; then
    echo "Error: base64 utility is not present, but is required for Jira authorization"
    exit 99
  fi
  if [ -z "$r_endpoint" ]; then
    echo "Error: missing endpoint. Please check your integration."
    exit 99
  fi
  if [ -z "$r_token" ]; then
    echo "Error: missing token. Please check your integration."
    exit 99
  fi
  if [ -z "$r_username" ]; then
    echo "Error: missing username. Please check your integration."
    exit 99
  fi
  if [ -z "$opt_project_id" ]; then
    echo "Error: missing project identifier. Please use --project-id."
    exit 99
  fi
  if [ -z "$opt_type" ]; then
    echo "Error: missing issue type. Please use --type."
    exit 99
  fi
  if [ -z "$opt_summary" ]; then
    echo "Error: missing summary. Please use --summary."
    exit 99
  fi

  local encoded_auth=$(echo -n "$r_username:$r_token" | base64)

  echo $default_jira_payload > /tmp/payload.json
  opt_payload=/tmp/payload.json
  shipctl replace $opt_payload

  local isValid=$(jq type $opt_payload || true)
  if [ -z "$isValid" ]; then
    echo "Error: payload is not valid JSON"
    exit 99
  fi

  result=$(curl -XPOST -sS \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $encoded_auth" \
    "$r_endpoint/issue" \
    -d @$opt_payload)
  echo $result

  if [ -n "$opt_attach_file" ]; then
    if [ -f "$opt_attach_file" ]; then

      issueKey=$(jq -r '.key' <<< $result)
      curl -sS -XPOST \
        -H "X-Atlassian-Token: nocheck" \
        -H "Authorization: Basic $encoded_auth" \
        -F "file=@$opt_attach_file" \
        "$r_endpoint/issue/$issueKey/attachments"
    else
      echo "Error: --attach-file option refers to a file that doesn't exist"
      exit 99
    fi
  fi
}

_post_curl() {
  local payload=$1
  local auth=$2
  local endpoint=$3

  local curl_cmd="curl -XPOST -sS -H content-type:'application/json' $auth $endpoint -d @$payload"
  eval $curl_cmd
  echo ""
}

_get_curl() {
  local payload=$1
  local auth=$2
  local endpoint=$3

  local curl_cmd="curl -s $auth $endpoint $payload"
  eval $curl_cmd
  echo ""
}
