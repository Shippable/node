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

get_integration_resource_field() {
  if [ "$1" == "" ] || [ "$2" == "" ]; then
    echo "Usage: shipctl get_integration_resource_field RESOURCE_NAME KEY_NAME"
    exit 99
  fi
  UP=$(get_resource_name "$1")
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
