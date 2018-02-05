$ErrorActionPreference = "Stop"

function sanitize_shippable_string([string] $in) {
    if (-not $in) {
        throw "Usage: shipctl sanitize_shippable_string STRING"
    }
    return ($in -replace "[^a-zA-Z_0-9]", "")
}

function to_uppercase([string] $in) {
    if (-not $in) {
        throw "Usage: shipctl to_uppercase STRING"
    }
    return $in.ToUpper()
}

function _get_env_value([string] $key) {
    if (-not $key) {
        throw "Usage: shipctl _get_env_value KEY"
    }
    return (Get-Item "env:$key").Value
}

function _get_key_name([string] $resource, [string] $qualifier) {
    if (-not $resource -or -not $qualifier) {
        throw "Usage: shipctl _get_key_name RESOURCE QUALIFIER"
    }
    return (get_resource_name $resource) + "_" + $qualifier
}

function _sanitize_upper([string] $in) {
    if (-not $in) {
        throw "Usage: shipctl _sanitize_upper STRING"
    }
    $up = to_uppercase $in
    return sanitize_shippable_string $up
}

function get_resource_name([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_name RESOURCE"
    }
    $up = to_uppercase $resource
    return sanitize_shippable_string $up
}

function get_resource_id([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_id RESOURCE"
    }
    $key = _get_key_name $resource "ID"
    return _get_env_value $key
}

function get_resource_meta([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_meta RESOURCE"
    }
    $key = _get_key_name $resource "META"
    return _get_env_value $key
}

function get_resource_state([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_state RESOURCE"
    }
    $key = _get_key_name $resource "STATE"
    return _get_env_value $key
}

function get_resource_path([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_path RESOURCE"
    }
    return get_resource_state $resource
}

function get_resource_operation([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_operation RESOURCE"
    }
    $key = _get_key_name $resource "OPERATION"
    return _get_env_value $key
}

function get_resource_type([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_type RESOURCE"
    }
    $key = _get_key_name $resource "TYPE"
    return _get_env_value $key
}

function get_resource_env([string] $resource, [string] $envName) {
    if (-not $resource -or -not $envName) {
        throw "Usage: shipctl get_resource_env RESOURCE ENV_NAME"
    }

    $resourceName = get_resource_name $resource
    $envUp = to_uppercase $envName
    $key = $resourceName + "_" + $envUp
    return _get_env_value $key
}

function get_params_resource([string] $resource, [string] $param) {
    if (-not $resource -or -not $param) {
        throw "Usage: shipctl get_params_resource RESOURCE PARAM"
    }
    $up = get_resource_name $resource
    $paramName = _sanitize_upper $param
    $key = $up + "_PARAMS_" + $paramName
    return _get_env_value $key;
}

function get_integration_resource_keys([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_integration_resource_keys RESOURCE"
    }
    $up = get_resource_name $resource
    $resMetaDirectory = get_resource_meta $resource
    if (!(Test-Path "$resMetaDirectory")) {
        throw "IN directory not present for resource: $resource"
    }
    $resIntegrationEnvFile = Join-Path "$resMetaDirectory" "integration.env"
    if (!(Test-Path "$resIntegrationEnvFile")) {
        throw "integration.env not present for resource: $resource"
    }
    Get-Content $resIntegrationEnvFile | %{ $_.Split('=')[0] }
}

function get_integration_resource_field([string] $resource, [string] $field) {
    if (-not $resource -or -not $field) {
        throw "Usage: shipctl get_integration_resource_field RESOURCE FIELD"
    }
    $up = get_resource_name $resource
    $intKeyName = _sanitize_upper $field
    $key = $up + "_INTEGRATION_" + $intKeyName
    return _get_env_value $key
}

function get_resource_version_name([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_version_name RESOURCE"
    }
    $key = _get_key_name $resource "VERSIONNAME"
    return _get_env_value $key
}

function get_resource_version_id([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_version_id RESOURCE"
    }
    $key = _get_key_name $resource "VERSIONID"
    return _get_env_value $key
}

function get_resource_version_number([string] $resource) {
    if (-not $resource) {
        throw "Usage: shipctl get_resource_version_number RESOURCE"
    }
    $key = _get_key_name $resource "VERSIONNUMBER"
    return _get_env_value $key
}

function get_resource_version_key([string] $resource, [string] $versionKey) {
    if (-not $resource -or -not $versionKey) {
        throw "Usage: shipctl get_resource_version_key RESOURCE KEY"
    }
    $resMetaDirectory = get_resource_meta $resource
    if (!(Test-Path "$resMetaDirectory")) {
        throw "IN directory not present for resource: $resource"
    }

    $resVersionFile = Join-Path "$resMetaDirectory" "version.json"

    if (!(Test-Path "$resVersionFile")) {
        throw "version.json not present for resource: $resource"
    }

    $native_properties = "versionName", "versionId", "versionNumber"
    if ($native_properties.Contains($versionKey)) {
        return get_json_value "$resVersionFile" "$versionKey"
    } else {
        return get_json_value "$resVersionFile" "propertyBag.$versionKey"
    }
}

function get_integration_resource([string] $resource, [string] $integrationKey) {
    if (-not $resource) {
        throw "Usage: shipctl get_integration_resource RESOURCE [KEY]"
    }
    $resMetaDirectory = get_resource_meta $resource
    $resIntegrationFile = Join-Path "$resMetaDirectory" "integration.json"

    if (!(Test-Path "$resIntegrationFile")) {
        throw "The given resource is not of type integration. ${resIntegrationFile}: No such file or directory"
    }

    return get_json_value $resIntegrationFile $integrationKey
}

function get_json_value([string] $jsonFilePath, [string] $field) {
    if (-not $jsonFilePath) {
        throw "Usage: shipctl get_json_value FILE [FIELD]"
    }
    if (!(Test-Path "$jsonFilePath")) {
        throw "${jsonFilePath}: No such file present in this directory"
    }

    if ($field -eq $null) {
        return Get-Content -Raw $jsonFilePath
    } else {
        return Invoke-Expression "(Get-Content -Raw $jsonFilePath | ConvertFrom-Json).$field"
    }
}

function post_resource_state([string] $resource, [string] $stateName, [string] $stateValue) {
    if (-not $resource -or -not $stateName -or -not $stateValue) {
        throw "Usage: shipctl post_resource_state RESOURCE KEY VALUE"
    }
    "$stateName=$stateValue" | Out-File -Encoding utf8 -NoNewLine -File "$env:JOB_STATE/$resource.env"
}

function put_resource_state([string] $resource, [string] $stateName, [string] $stateValue) {
    if (-not $resource -or -not $stateName -or -not $stateValue) {
        throw "Usage: shipctl put_resource_stat RESOURCE KEY VALUE"
    }
    "$stateName=$stateValue" | Out-File -Encoding utf8 -NoNewLine -Append -File "$env:JOB_STATE/$resource.env"
}

function copy_file_to_state([string] $fileName) {
    if (-not $fileName) {
        throw "Usage: shipctl copy_file_to_state FILE"
    }
    copy-item -Recurse -Verbose "$fileName" "$env:JOB_STATE"
}

function copy_file_from_prev_state([string] $filePath, [string] $restorePath) {
    if (-not $fileName -or -not $restorePath) {
        throw "Usage: shipctl copy_file_from_prev_state FILE DESTINATION"
    }
    $previousStateFile = Join-Path "$env:JOB_PREVIOUS_STATE" "$filePath"

    if (!(Test-Path "$previousStateFile")) {
        Write-Output "------  File does not exist in previous state, skipping -----"
        return
    }

    Write-Output "---------------- Restoring file from state -------------------"
    Copy-Item -Recurse -Verbose "$previousStateFile" "$restorePath"
}

function refresh_file_to_state([string] $newStateFile) {
    if (-not $newStateFile) {
        throw "Usage: shipctl refresh_file_to_state FILE"
    }

    $onlyFileName = Split-Path $newStateFile -Leaf

    Write-Output "---------------- Copying file to state -------------------"

    if (Test-Path "$newStateFile") {
        Write-Output "---------------  New file exists, copying  ----------------"
        Copy-Item -Verbose -Recurse "$newStateFile" "$env:JOB_STATE"
    } else {
        Write-Output "---  New file does not exist, hence try to copy from prior state ---"
        $previousStateFileName = Join-Path "$env:JOB_PREVIOUS_STATE" "$newStateFile"
        if (Test-Path "$previousStateFileName") {
            Write-Output ""
            Write-Output "------  File exists in previous state, copying -----"
            Copy-Item -Verbose -Recurse "$previousStateFileName" "$env:JOB_STATE"
        } else {
            Write-Output "-------  No previous state file exists. Skipping  ---------"
        }
    }
}

function copy_resource_file_from_state([string] $resourceName, [string] $fileName, [string] $destinationPath) {
    if (-not $resourceName -or -not $fileName -or -not $destinationPath) {
        throw "Usage: shipctl copy_resource_file_from_state RESOURCE FILE DESTINATION"
    }
    $resourceType = get_resource_type $resourceName

    # Todo: Shouldn't this use get_resource_path?
    $fullPath = Join-Path "$env:JOB_PATH" "IN\$resourceName\$resourceType\$fileName"

    Write-Output "---------------- Restoring file from state -------------------"
    if (Test-Path "$fullPath") {
        Write-Output "----------------  File exists, copying -----------------------"
        Copy-Item -Recurse -Verbose "$fullPath" "$destinationPath"
    } else {
        Write-Output "------  File does not exist in $resourceName state, skipping -----"
    }
}

# alias of copy_resource_file_from_state
function copy_file_from_resource_state([string] $resourceName, [string] $fileName, [string] $destinationPath) {
    if (-not $resourceName -or -not $fileName -or -not $destinationPath) {
        throw "Usage: shipctl copy_resource_file_from_state RESOURCE FILE DESTINATION"
    }
    return copy_resource_file_from_state $resourceName $fileName $destinationPath
}

function refresh_file_to_out_path([string] $fileName, [string] $resourceName) {
    if (-not $fileName -or -not $resourceName) {
        throw "Usage: shipctl refresh_file_to_out_path FILE RESOURCE"
    }
    $onlyFileName = Split-Path "$newStateFile" -Leaf
    $resourceOutPath = Join-Path "$env:JOB_PATH" "OUT\$resourceName\state"
    $resourceInPath = Join-Path "$env:JOB_PATH" "IN\$resourceName\state"

    Write-Output "---------------- Copying file to state -------------------"
    if (Test-Path "$fileName") {
        Write-Output "---------------  New file exists, copying  ----------------"
        Copy-Item -Recurse -Verbose "$fileName" "$resourceOutPath"
    } else {
        echo "---  New file does not exist, hence try to copy from prior state ---"
        $previousStateFile = Join-Path "$resourceInPath" "$onlyFileName"
        if (Test-Path "$previousStateFile") {
            Write-Output "------  File exists in previous state, copying -----"
            Copy-Item -Recurse -Verbose "$previousStateFile" "$resourceOutPath"
        } else {
            Write-Output "------  File does not exist in previous state, skipping -----"
        }
    }
}

# alias of refresh_file_to_out_path
function copy_file_to_resource_state([string] $fileName, [string] $resourceName) {
    if (-not $fileName -or -not $resourceName) {
        throw "Usage: shipctl copy_file_to_resource_state FILE RESOURCE"
    }
    return refresh_file_to_out_path $fileName $resourceName
}

function get_resource_pointer_key([string] $resource, [string] $pointerKey) {
    if (-not $resource -or -not $pointerKey) {
        throw "Usage: shipctl get_resource_pointer_key RESOURCE KEY"
    }
    $resourceName = get_resource_name $resource
    $resourceMeta = get_resource_meta $resourceName
    if (!(Test-Path "$resourceMeta" -PathType Container)) {
        throw "IN directory not present for resource: $resource"
    }

    $resourceVersionFile = Join-Path "$resourceMeta" "version.json"
    if (!(Test-Path "$resourceVersionFile")) {
        throw "version.json not present for resource: $resourceName"
    }

    return get_json_value "$resourceVersionFile" "propertyBag.yml.pointer.$pointerKey"
}

function post_resource_state_multi([string] $resourceName) {
    if (-not $resourceName -or -not $args) {
        throw "Usage: shipctl post_resource_state_multi RESOURCE [STATE_ARRAY]"
    }
    $stateArray = $args
    $resourceEnvFile = Join-Path "$env:JOB_STATE" "$resourceName.env"

    Remove-Item -Force -Recurse "$resourceEnvFile" -ErrorAction SilentlyContinue

    foreach ($state in $stateArray) {
        "$state`n" | Out-File -Encoding utf8 -NoNewLine -Append -FilePath "$resourceEnvFile"
    }
}

function put_resource_state_multi([string] $resourceName) {
    if (-not $resourceName -or -not $args) {
        throw "Usage: shipctl put_resource_state_multi RESOURCE [STATE_ARRAY]"
    }
    $stateArray = $args
    $resourceEnvFile = Join-Path "$env:JOB_STATE" "$resourceName.env"

    foreach ($state in $stateArray) {
        "$state`n" | Out-File -Encoding utf8 -NoNewLine -Append -FilePath "$resourceEnvFile"
    }
}
