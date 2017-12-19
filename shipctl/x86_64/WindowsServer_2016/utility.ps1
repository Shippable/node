$ErrorActionPreference = "Stop"

function sanitize_shippable_string([string] $in) {
    return ($in -replace "[^a-zA-Z_0-9]", "")
}

function to_uppercase([string] $in) {
    return $in.ToUpper()
}

function _get_env_value([string] $key) {
    return (Get-Item "env:$key").Value
}

function _get_key_name([string] $resource, [string] $qualifier) {
    return (get_resource_name $resource) + "_" + $qualifier
}

function _sanitize_upper([string] $in) {
    $up = to_uppercase $in
    return sanitize_shippable_string $up
}

function get_resource_name([string] $resource) {
    $up = to_uppercase $resource
    return sanitize_shippable_string $up
}

function get_resource_id([string] $resource) {
    $key = _get_key_name $resource "ID"
    return _get_env_value $key
}

function get_resource_meta([string] $resource) {
    $key = _get_key_name $resource "META"
    return _get_env_value $key
}

function get_resource_state([string] $resource) {
    $key = _get_key_name $resource "STATE"
    return _get_env_value $key
}

function get_resource_path([string] $resource) {
    return get_resource_state $resource
}

function get_resource_operation([string] $resource) {
    $key = _get_key_name $resource "OPERATION"
    return _get_env_value $key
}

function get_resource_type([string] $resource) {
    $key = _get_key_name $resource "TYPE"
    return _get_env_value $key
}

function get_params_resource([string] $resource, [string] $param) {
    $up = get_resource_name $resource
    $paramName = _sanitize_upper $param
    $key = $up + "_PARAMS_" + $paramName
    return _get_env_value $key;
}

function get_integration_resource_field([string] $resource, [string] $int) {
    $up = get_resource_name $resource
    $intKeyName = _sanitize_upper $int
    $key = $up + "_INTEGRATION_" + $intKeyName
    return _get_env_value $key
}

function get_resource_version_name([string] $resource) {
    $key = _get_key_name $resource "_VERSIONNAME"
    return _get_env_value $key
}

function get_resource_version_id([string] $resource) {
    $key = _get_key_name $resource "_VERSIONID"
    return _get_env_value $key
}

function get_resource_version_number([string] $resource) {
    $key = _get_key_name $resource "_VERSIONNUMBER"
    return _get_env_value $key
}

function get_resource_version_key([string] $resource, [string] $versionKey) {
    $resMetaDirectory = get_resource_meta $resource
    if (!(Test-Path $resMetaDirectory)) {
        throw "IN directory not present for resource: $resource"
    }

    $resVersionFile = Join-Path $resMetaDirectory "version.json"

    if (!(Test-Path $resVersionFile)) {
        throw "version.json not present for resource: $resource"
    }

    $native_properties = "versionName", "versionId", "versionNumber"
    if ($native_properties.Contains($versionKey)) {
        return get_json_value $resVersionFile $versionKey
    } else {
        return get_json_value $resVersionFile "propertyBag.$versionKey"
    }
}

function get_integration_resource([string] $resource, [string] $integrationKey) {
    $resMetaDirectory = get_resource_meta $resource
    $resIntegrationFile = Join-Path $resMetaDirectory "integration.json"

    if (!(Test-Path $resIntegrationFile)) {
        throw "The given resource is not of type integration. ${resIntegrationFile}: No such file or directory"
    }

    return get_json_value $resIntegrationFile $integrationKey
}

function get_json_value([string] $jsonFilePath, [string] $field) {
    if (!(Test-Path $jsonFilePath)) {
        throw "${jsonFilePath}: No such file present in this directory"
    }

    if ($field -eq $null) {
        return Get-Content -Raw $jsonFilePath
    } else {
        return Invoke-Expression "(Get-Content -Raw $jsonFilePath | ConvertFrom-Json).$field"
    }
}

function post_resource_state([string] $resource, [string] $stateName, [string] $stateValue) {
    """$stateName""=""$stateValue""" | Out-File -File "$env:JOB_STATE/$resource.env"
}

function put_resource_state([string] $resource, [string] $stateName, [string] $stateValue) {
    """$stateName""=""$stateValue""" | Out-File -Append -File "$env:JOB_STATE/$resource.env"
}

function copy_file_to_state([string] $fileName) {
    copy-item -Recurse -Verbose "$fileName" "$env:JOB_STATE"
}

function copy_file_from_prev_state([string] $filePath, [string] $restorePath) {
    $previousStateFile = Join-Path $env:JOB_PREVIOUS_STATE $filePath

    if (!(Test-Path $previousStateFile)) {
        throw "------  File does not exist in previous state, skipping -----"
    }

    Write-Output "---------------- Restoring file from state -------------------"
    Copy-Item -Recurse -Verbose $previousStateFile $restorePath
}