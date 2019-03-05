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

function get_integration_keys([string] $integration) {
    if (-not $integration) {
        throw "Usage: shipctl get_integration_keys INTEGRATION_NAME"
    }
    $integrationEnvFile = Join-Path "$env:JOB_INTEGRATIONS" "$integration\integration.env"
    if (!(Test-Path "$integrationEnvFile")) {
        throw "integration.env not present for integration: $integration"
    }
    Get-Content $integrationEnvFile | %{ $_.Split('=')[0] }
}

function get_integration_field([string] $integration, [string] $field) {
    if (-not $integration -or -not $field) {
        throw "Usage: shipctl get_integration_field INTEGRATION_NAME FIELD"
    }
    $integrationJsonFile = Join-Path "$env:JOB_INTEGRATIONS" "$integration\integration.json"
    if (!(Test-Path "$integrationJsonFile")) {
        throw "integration.json not present for integration: $integration"
    }
    $up = _sanitize_upper $integration
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
        return get_json_value "$resVersionFile" "version.$versionKey"
    } else {
        return get_json_value "$resVersionFile" "version.propertyBag.$versionKey"
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
        throw "Usage: shipctl put_resource_state RESOURCE KEY VALUE"
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
    if (-not $filePath -or -not $restorePath) {
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

function replicate() {

    param(
    [string]$resourceFrom,
    [string]$resourceTo,
    [switch]$files_only,
    [switch]$metadata_only,
    [switch]$webhook_data_only,
    [switch]$match_settings
  )

  if ($PSBoundParameters.Count -lt 2) {
    throw "Usage: shipctl replicate FROM_resource TO_resource [-files_only|-metadata_only|-webhook_data_only]"
  }
  $toCurrentJob = $false
  $typeFrom = $(get_resource_type "$resourceFrom")
  $typeTo = $(get_resource_type "$resourceTo")

  if ($resourceFrom -eq $env:JOB_NAME) {
    throw "Error: current job cannot be the FROM argument"
  }
  if ($typeTo -eq "ciRepo") {
    throw "Error: cannot replicate to ciRepo"
  }
  if (($typeFrom -match "^gitRepo|ciRepo|syncRepo$") -and ($typeTo -match "^gitRepo|syncRepo$")) {
    $metadata_only = $true
    $canMatchSettings = $true
  } elseif ("$resourceTo" -eq "$env:JOB_NAME") {
    $toCurrentJob = $true
  } elseif ("$typeFrom" -ne "$typeTo") {
    throw "Error: resources must be the same type"
  }

  if ($match_settings -and !$canMatchSettings) {
    throw "Error: -match_settings flag not supported for the specified resources."
  }

  # match branch/tag settings
  if ($match_settings -and $canMatchSettings) {
    $webhook_data_only = $true
    $fromVersionData = Get-Content -Raw -Path "$env:JOB_PATH/IN/$resourceFrom/version.json" | ConvertFrom-Json
    $toVersionData = Get-Content -Raw -Path "$env:JOB_PATH/OUT/$resourceTo/version.json" | ConvertFrom-Json
    $shouldReplicate = $true

    $fromShaData = $fromVersionData.version.propertyBag.shaData
    if (!$fromShaData) {
      throw "Error: FROM resource does not contain shaData."
    }
    $isGitTag = $fromVersionData.version.propertyBag.shaData.isGitTag
    $isRelease = $fromVersionData.version.propertyBag.shaData.isRelease
    if ($isGitTag -eq "true") {
      $gitTagName = $fromVersionData.version.propertyBag.shaData.gitTagName
      $toTagsOnly = $toVersionData.version.propertyBag.tags.only
      $toTagsExcept = $toVersionData.version.propertyBag.tags.except
      if ($toTagsOnly -and $toTagsOnly.Count -gt 0 ) {
        $matchingTags = $toTagsOnly.Where({$gitTagName -like $_}).Count
        if ($matchingTags -eq 0) {
          $shouldReplicate = $false
        }
      }
      if ($toTagsExcept -and ($toTagsExcept.Count -gt 0 )) {
        $matchingTags = $toTagsExcept.Where({$gitTagName -like $_}).Count
        if ($matchingTags -gt 0) {
          $shouldReplicate = $false
        }
      }
    } elseif ($isRelease -ne "true") {
      # branches
      $branchName = $fromVersionData.version.propertyBag.shaData.branchName
      if (!$branchName) {
        throw "Error: No branch name in FROM resource shaData. Cannot replicate"
      }
      $toBranch = $toVersionData.version.propertyBag.branch
      $toBranchesOnly = $toVersionData.version.propertyBag.branches.only
      $toBranchesExcept = $toVersionData.version.propertyBag.branches.except
      if ($toBranch) {
        if ($toBranch -ne $branchName) {
          $shouldReplicate = $false
        }
      } else {
        if ($toBranchesOnly.Count -gt 0) {
          $matchingBranches = $toBranchesOnly.Where({$branchName -like $_}).Count
          if ($matchingBranches -eq 0) {
            $shouldReplicate = $false
          }
        }
        if ($toBranchesExcept.Count -gt 0) {
          $matchingBranches = $toBranchesExcept.Where({$branchName -like $_}).Count
          if ($matchingBranches -gt 0) {
            $shouldReplicate = $false
          }
        }
      }
    }
    if (!$shouldReplicate) {
      Write-Output "FROM shaData does not match TO settings. Skipping replicate."
      exit 0
    }
  }

  # copy files
  if (!$metadata_only) {
    $pathFrom = "$env:JOB_PATH/IN/$resourceFrom/$typeFrom"
    $pathTo = ""
    if (!$toCurrentJob) {
      $pathTo = "$env:JOB_PATH/OUT/$resourceTo/$typeTo"
    } else {
      $pathTo = "$env:JOB_STATE"
    }
    $resultTo = test-path "$pathTo"
    $resultFrom = test-path "$pathFrom"
    if ((Test-Path "$pathFrom") -and (Test-Path "$pathTo")) {
      $directory = Get-ChildItem $pathFrom | Measure-Object
      if ($directory.count -gt 0) {
        Copy-Item -Path $pathFrom/* -Destination $pathTo -recurse -Force
      }
    }
  }
  # copy metadata
  if (!$files_only) {
    $metadataFromContents = Get-Content -Raw -Path "$env:JOB_PATH/IN/$resourceFrom/version.json" | ConvertFrom-Json
    $mdFilePathTo = ""
    if ($toCurrentJob) {
      $mdFilePathTo = "$env:JOB_STATE/outputVersion.json"
    } else {
      $mdFilePathTo = "$env:JOB_PATH/OUT/$resourceTo/version.json"
    }
    if (!$webhook_data_only) {
      $fromVersion = $metadataFromContents.version.propertyBag #read json at mdFilePathFrom.version.propertyBag

      if ($toCurrentJob) {
        $outputVersion = @{
          "propertyBag" = $fromVersion
        }
        (ConvertTo-Json $outputVersion -depth 100) | Out-File -filepath "$mdFilePathTo" -Encoding UTF8

      } else {
        $toVersionJson = Get-Content -Raw -Path $mdFilePathTo | ConvertFrom-Json
        $toVersionJson.version.propertyBag = $fromVersion
        (ConvertTo-Json $toVersionJson -depth 100) | Out-File -filepath "$mdFilePathTo" -Encoding UTF8
      }
    } else {
      $fromShaData = $metadataFromContents.version.propertyBag.shaData
      $fromWebhookRequestHeaders = $metadataFromContents.version.propertyBag.webhookRequestHeaders
      $fromWebhookRequestBody = $metadataFromContents.version.propertyBag.webhookRequestBody
      if ($toCurrentJob) {
        $bag = [PSCustomObject]@{}
        $toVersionJson = [PSCustomObject]@{propertyBag=$bag}
        $jsonSource = $toVersionJson
      } else {
        $jsonSource = Get-Content -Raw -Path $mdFilePathTo | ConvertFrom-Json
        $toVersionJson = $jsonSource.version
      }
      if ($fromShaData) {
        Add-Member -InputObject $toVersionJson.propertyBag -NotePropertyName 'shaData' -NotePropertyValue $fromShaData -Force
        $toVersionJson
      }
      if ($fromWebhookRequestHeaders) {
        Add-Member -InputObject $toVersionJson.propertyBag -NotePropertyName 'webhookRequestHeaders' -NotePropertyValue $fromWebhookRequestHeaders -Force
      }
      if ($fromWebhookRequestBody) {
        Add-Member -InputObject $toVersionJson.propertyBag -NotePropertyName 'webhookRequestBody' -NotePropertyValue $fromWebhookRequestBody -Force
      }
      (ConvertTo-Json $jsonSource -depth 100) | Out-File -filepath "$mdFilePathTo" -Encoding UTF8
    }
  }
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
    $onlyFileName = Split-Path "$fileName" -Leaf
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

function bump_version([string] $version_to_bump, [string] $action) {
    if (-not $version_to_bump -or -not $action) {
        throw "Usage: shipctl bump_version version_to_bump action"
    }
    $versionsAndPrerelease = $version_to_bump.Split("{-}")
    $versionParts = $versionsAndPrerelease[0].Split("{.}")
    $prerelease = $versionsAndPrerelease[1]
    $majorWithoutV = $versionParts[0].Replace("v", "")
    if (-not ($majorWithoutV -match "^[\d\.]+$" -and $versionParts[1] -match "^[\d\.]+$" -and
        $versionParts[2] -match "^[\d\.]+$")) {
        throw "error: Invalid semantics given in the argument."
    }
    if ($action -ne "major" -and $action -ne "minor" -and $action -ne "patch" -and
        $action -ne "rc" -and $action -ne "alpha" -and $action -ne "beta" -and $action -ne "final") {
        throw "error: Invalid action given in the argument."
    }
    $major = [int]$majorWithoutV
    $minor = [int]$versionParts[1]
    $patch = [int]$versionParts[2]
    if ( $versionParts[0] -eq $majorWithoutV) {
        $appendV = $false
    }
    else {
        $appendV = $true
    }
    if ($action -eq "major") {
        $major = $major + 1
        $minor = 0
        $patch = 0
    }
    ElseIf ($action -eq "minor") {
        $minor = $minor + 1
        $patch = 0
    }
    ElseIf ($action -eq "patch") {
        $patch = $patch + 1
    }
    ElseIf ($action -eq "alpha" -or $action -eq "beta" -or $action -eq "rc") {
       if (-not $prerelease) {
         $prereleaseText = $action
       }
       else {
         $prereleaseParts = $prerelease.Split("{.}")
         if ($prereleaseParts -Contains $action) {
           if ([regex]::match("$prerelease", "$action.[0-9]*").Success) {
             $count =  [regex]::match("$prerelease", "$action.[0-9]*").Value
             $prereleaseCount = $count.Split("{.}")
             $prereleaseCount = [int]$prereleaseCount[1] + 1
           }
           else {
             $prereleaseCount = 1
           }
           $prereleaseText = [string]$action + "." + [string]$prereleaseCount
         }
         else {
           $prereleaseText = [string]$action
         }
       }
    }
    $newVersion = [string]$major + "." + [string]$minor + "." + [string]$patch
    if ($prereleaseText -and $action -ne "final") {
        $newVersion = $newVersion + "-" + [string]$prereleaseText
    }
    if ($appendV) {
        $newVersion = "v" + $newVersion
    }
    Write-Output $newVersion
}

function get_git_changes() {
  param([string]$path, [string]$resource, [int]$depth, [alias("directories-only")][switch]$directories_only, [alias("commit-range")][string]$commit_range)

  if (!($path -or $resource)) {
    throw "Usage: shipctl get_git_changes [-path|-resource]"
  }

  $git_repo_path = $path
  if (!($path)) {
    $git_repo_path=$(get_resource_state "$resource")
  }

  if (!(Test-Path "$git_repo_path/.git" -PathType Container)) {
    throw "git repository not found at path: $git_repo_path"
  }

  $current_commit_range = ""

  # for runSh with IN: gitRepo
  if ($resource) {
    # for runSh with IN: gitRepo commits
    $current_commit_sha = $(shipctl get_resource_version_key $resource shaData.commitSha)
    $before_commit_sha = $(shipctl get_resource_version_key $resource shaData.beforeCommitSha)
    $current_commit_range = "${before_commit_sha}..${current_commit_sha}"

    # for runSh with IN: gitRepo pull requests
    $is_pull_request = $(shipctl get_resource_env $resource is_pull_request)
    if($is_pull_request -eq "true") {
      $current_commit_sha = $(shipctl get_resource_version_key $resource shaData.commitSha)
      $base_branch = $(shipctl get_resource_env $resource base_branch)
      $current_commit_range = "origin/${base_branch}...${current_commit_sha}"
    }
  }

  # Override commit range if present in options
  if ($commit_range) {
    $current_commit_range = $commit_range
  }

  if (!$current_commit_range) {
    throw "Unknown commit range. use --commit-range."
  }

  pushd $git_repo_path
    $result = @();

    if ($directories_only) {
      git diff --dirstat $current_commit_range | %{ $arr = $_.Split(" "); $result += $arr[$arr.length - 1]; }
    } else {
      git diff --name-only $current_commit_range | %{ $result += $_ ; }
    }

    if ($depth -gt 0) {
      if ($result.Count -gt 0) {
        $result = $result | %{ $_.Split('/')[$depth - 1]; }
      }
    }

    $result | select -uniq
  popd
}

function notify() {
  param(
    [string]$resource,
    [string]$payload,
    [string]$recipient,
    [string]$icon_url,
    [string]$color,
    [string]$pretext,
    [string]$text,
    [string]$username,
    [string]$password,
    [string]$type,
    [alias("project-id")][string]$project_id,
    [string]$environment,
    [string]$email,
    [string]$repository,
    [string]$revision,
    [string]$version,
    [string]$description,
    [string]$changelog,
    [string]$appId,
    [string]$appName
  )
  if ($PSBoundParameters.Count -lt 1) {
    throw "Usage: shipctl notify RESOURCE [-payload|-recipient|-pretext|-text|-username|-password|-color|-icon_url|-type|-project-id|-environment|-email|-repository|-revision|-version|-description|-changelog|-appId|-appName]"
  }

  $env:opt_resource = $resource

  $r_type=$(get_resource_type "$env:opt_resource")
  if (!$r_type) {
    throw "Error: resource data not found for $env:opt_resource"
  } elseif ($r_type -ne "notification") {
    throw "Error: resource $env:opt_resource is not of type 'notification'"
  }


  $r_method = $(get_resource_version_key "$env:opt_resource" method)
  if (!$r_method) {
    $r_mastername=$(get_integration_resource "$env:opt_resource" masterName)
  }

  $env:opt_recipient = $recipient
  if (!$env:opt_recipient) {
    $env:opt_recipient = $env:NOTIFY_RECIPIENT
    if (!$env:opt_recipient) {
      $env:opt_recipient=""
    }
  }

  $env:opt_icon_url = $icon_url
  if (!$env:opt_icon_url) {
    $env:opt_icon_url = $env:NOTIFY_ICON_URL
    if (!$env:opt_icon_url) {
      $env:opt_icon_url = "$env:SHIPPABLE_WWW_URL/images/slack-aye-aye-yoga.png"
    }
  }

  $env:opt_color = $color
  if (!$env:opt_color) {
    $env:opt_color = $env:NOTIFY_COLOR
    if (!$env:opt_color) {
      $env:opt_color = "#65cea7"
    }
  }

  $env:opt_pretext = $pretext
  if (!$env:opt_pretext) {
    $env:opt_pretext = $env:NOTIFY_PRETEXT
    if (!$env:opt_pretext) {
      $env:opt_pretext = Get-Date -UFormat "%c (UTC %Z)"
    }
  }

  $env:opt_text = $text
  if (!$env:opt_text) {
    $env:opt_text = $env:NOTIFY_TEXT
    if (!$env:opt_text) {
      if ($env:JOB_TYPE -eq "runCI") {
        if ($r_method -eq "irc") {
          $env:opt_text = "[$env:REPO_FULL_NAME:$env:BRANCH] Build $env:BUILD_NUMBER $env:BUILD_URL"
        } else {
          $env:opt_text = "[$env:REPO_FULL_NAME:$env:BRANCH] `<$env:BUILD_URL|Build#$env:BUILD_NUMBER`>"
        }
      } elseif ($env:JOB_TYPE -eq "runSh") {
        if ($r_method -eq "irc") {
          $env:opt_text="[$env:JOB_NAME] Build $env:BUILD_NUMBER $env:BUILD_URL"
        } else {
          $env:opt_text = "[$env:JOB_NAME] `<$env:BUILD_URL|Build#$env:BUILD_NUMBER`>"
        }
      } else {
        throw "Error: unsuported job type: $env:JOB_TYPE"
      }
    }
  }

  $env:opt_username = $username
  if (!$env:opt_username) {
    $env:opt_username = $env:NOTIFY_USERNAME
    if (!$env:opt_username) {
      $env:opt_username = ""
    }
  }

  $env:opt_password = $password
  if (!$env:opt_password) {
    $env:opt_password = $env:NOTIFY_PASSWORD
    if (!$env:opt_password) {
      $env:opt_password = ""
    }
  }

  $env:opt_payload = $payload
  if (!$env:opt_payload) {
      $env:opt_payload = $env:NOTIFY_PAYLOAD
      if (!$env:opt_payload) {
        $env:opt_payload = ""
      }
  }

  $env:opt_type = $type
  if (!$env:opt_type) {
    $env:opt_type = $env:NOTIFY_TYPE
    if (!$env:opt_type) {
      $env:opt_type = ""
    }
  }

  $env:opt_project_id = $project_id
  if (!$env:opt_project_id) {
    $env:opt_project_id = $env:NOTIFY_PROJECT_ID
    if (!$env:opt_project_id) {
      $env:opt_project_id = ""
    }
  }

  $env:opt_environment = $environment
  if (!$env:opt_environment) {
    $env:opt_environment = $env:NOTIFY_ENVIRONMENT
    if (!$env:opt_environment) {
      $env:opt_environment = ""
    }
  }

  $env:opt_email = $email
  if (!$env:opt_email) {
    $env:opt_email = $env:NOTIFY_EMAIL
    if (!$env:opt_email) {
      $env:opt_email = ""
    }
  }

  $env:opt_repository = $repository
  if (!$env:opt_repository) {
    $env:opt_repository = $env:NOTIFY_REPOSITORY
    if (!$env:opt_repository) {
      $env:opt_repository = ""
    }
  }

  $env:opt_revision = $revision
  if (!$env:opt_revision) {
    $env:opt_revision = $env:NOTIFY_REVISION
    if (!$env:opt_revision) {
      $env:opt_revision = ""
    }
  }

  $env:opt_version = $version
  if (!$env:opt_version) {
    $env:opt_version = $env:NOTIFY_VERSION
    if (!$env:opt_version) {
      $env:opt_version = ""
    }
  }

  $env:opt_description = $description
  if (!$env:opt_description) {
    $env:opt_description = $env:NOTIFY_DESCRIPTION
    if (!$env:opt_description) {
      $env:opt_description = ""
    }
  }

  $env:opt_changelog = $changelog
  if (!$env:opt_changelog) {
    $env:opt_changelog = $env:NOTIFY_CHANGELOG
    if (!$env:opt_changelog) {
      $env:opt_changelog = ""
    }
  }

  $env:opt_appId = $appId
  if (!$env:opt_appId) {
    $env:opt_appId = $env:NOTIFY_APPID
    if (!$env:opt_appId) {
      $env:opt_appId = ""
    }
  }

  $env:opt_appName = $appName
  if (!$env:opt_appName) {
    $env:opt_appName = $env:NOTIFY_APPNAME
    if (!$env:opt_appName) {
      $env:opt_appName = ""
    }
  }

  $default_slack_payload = '{"username":"$opt_username","attachments":[{"pretext":"$opt_pretext","text":"$opt_text","color":"$opt_color"}],"channel":"$opt_recipient","icon_url":"$opt_icon_url"}'
  $default_webhook_payload = '{"username":"$opt_username","pretext":"$opt_pretext","text":"$opt_text","color":"$opt_color","channel":"$opt_recipient","icon_url":"$opt_icon_url"}'
  $default_payload=""
  if ($r_method -eq "irc") {
    if (!$env:opt_username) {
      $env:opt_username = "Shippable-$env:BUILD_NUMBER"
    }
    if ($env:opt_recipient) {
      $recipients_list = @("$env:opt_recipient")
    } else {
      $recipients_list = $(get_resource_version_key "$env:opt_resource" "recipients")
    }
    if ($recipients_list.count -le 0) {
      throw "Error: no recipient provided."
    }
    foreach ($recipient in $recipients_list) {
      $server,$channel = $recipient.split('#')
      if (!$server) {
        throw "Error: no server specified in recipient $recipient"
      } elseif (!$channel) {
        throw "Error: no channel specified in recipient $recipient"
      }
      $channel = "#$channel"
      Write-Output "sending notification to $recipient"
      _send_irc_notification -server $server -channel $channel -nick $env:opt_username -pass $env:opt_password -payload $env:opt_text
    }
  } elseif ($r_mastername -eq "airBrakeKey") {
    _send_airbrake_notification
  } elseif ($r_mastername -eq "newRelicKey") {
    _send_newrelic_notification
  } else {
    $r_endpoint = $(get_integration_resource_field "$env:opt_resource" webhookUrl)
    if (!$env:opt_username) {
      $env:opt_username = "Shippable"
    }
    if ($r_mastername -eq "Slack" -or $r_mastername -eq "slackKey") {
      $default_payload = $default_slack_payload
      $recipients_list = $(get_resource_version_key "$env:opt_resource" "recipients")
    } elseif ($r_mastername -eq "webhook" -or $r_mastername -eq "webhookV2") {
      $authorization = $(get_integration_resource_field "$env:opt_resource" authorization)
      if (!$authorization) {
        $r_authorization = @{}
      } else {
        $r_authorization = @{ "Authorization" = "$authorization" }
      }
      $default_payload = $default_webhook_payload
    } else {
      throw "Error: unsupported notification type: $r_mastername"
    }
    if ($env:opt_payload) {
      if (!(Test-Path $env:opt_payload)) {
        throw "Error: file not found at path: $opt_payload"
      }
      try {
        $result = Get-Content $env:opt_payload -Raw | ConvertFrom-Json -ErrorAction Stop
      } catch {
        throw "Error: payload is not valid JSON"
      }

      Write-Output "sending notification"
      _send_web_notification -payload "$env:opt_payload" -auth $r_authorization -endpoint "$r_endpoint"

    } else {
      if ($($recipients_list.count) -gt 0 -and !$env:opt_recipient) {
        foreach ($recipient in $recipients_list) {
          $env:opt_recipient = $recipient

          Out-File -FilePath "$env:TEMP/payload.json" -InputObject $default_payload
          $env:opt_payload = "$env:TEMP/payload.json"
          shipctl replace $env:opt_payload

          try {
            $result = Get-Content $env:opt_payload -Raw | ConvertFrom-Json -ErrorAction Stop
          } catch {
            throw "Error: payload is not valid JSON"
          }

          Write-Output "sending notification to $env:opt_recipient"
          _send_web_notification -payload "$env:opt_payload" -auth $r_authorization -endpoint "$r_endpoint"
        }
      } else {

        Out-File -FilePath "$env:TEMP/payload.json" -InputObject $default_payload
        $env:opt_payload = "$env:TEMP/payload.json"
        shipctl replace $env:opt_payload

        $fileContent = Get-Content "$env:opt_payload"
        $fileContent = $fileContent.Replace("$" + "opt_recipient", "")
        # Use IO.File instead of Out-File to prevent UTF-8 BOM
        [IO.File]::WriteAllLines(($env:opt_payload | Resolve-Path), $fileContent)

        try {
          $result = Get-Content $env:opt_payload -Raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
          throw "Error: payload is not valid JSON"
        }
        if ($env:opt_recipient) {
          Write-Output "sending notification to $env:opt_recipient"
        } else {
          Write-Output "sending notification"
        }
        _send_web_notification -payload "$env:opt_payload" -auth $r_authorization -endpoint "$r_endpoint"
      }
    }
  }
  Write-Output "done"
  exit 0
}

function _send_web_notification() {
  param(
    [string]$payload,
    [hashtable]$auth,
    [string]$endpoint,
    [string]$security_protocol
  )
  if ($security_protocol) {
    [Net.ServicePointManager]::SecurityProtocol = $security_protocol
  }
  $json = Get-Content $payload -Raw | ConvertFrom-Json | ConvertTo-Json -Compress
  if ($auth.count -eq 0) {
    try {
      $result = Invoke-WebRequest -Method 'Post' -Uri "$endpoint" -ContentType "application/json" -Body $json -UseBasicParsing
    } catch {
      Write-Output $_.Exception|format-list -force
      throw "Error: exception in web request."
    }
  } else {
    try {
      $result = Invoke-WebRequest -Method 'Post' -Uri "$endpoint" -Headers $auth -ContentType "application/json" -Body $json -UseBasicParsing
    } catch {
      Write-Output $_.Exception|format-list -force
      throw "Error: exception in web request."
    }
  }
}

function _get_web_request() {
  param(
    [hashtable]$payload,
    [hashtable]$auth,
    [string]$endpoint
  )
  if ($auth.count -eq 0) {
    try {
      $result = Invoke-WebRequest -Method 'Get' -Uri "$endpoint" -Body $payload -UseBasicParsing
      return $result
    } catch {
      Write-Output $_.Exception|format-list -force
      throw "Error: exception in web request."
    }
  } else {
    try {
      $result = Invoke-WebRequest -Method 'Get' -Uri "$endpoint" -Headers $auth -Body $payload -UseBasicParsing
      return $result
    } catch {
      Write-Output $_.Exception|format-list -force
      throw "Error: exception in web request."
    }
  }
}

function _send_irc_notification() {
  param(
    [string]$server,
    [string]$channel,
    [string]$nick,
    [string]$password,
    [string]$payload
  )
  $port = 6667

  # make the connection
  $client = New-Object -TypeName Net.Sockets.TcpClient
  $client.Connect($server, $port)
  $netStream = $client.GetStream()
  $encoding = [System.Text.Encoding]::ASCII
  $streamWriter = New-Object -Type System.IO.StreamWriter -ArgumentList $netStream, $encoding
  $connection = "on"
  # send initial login commands
  if ($password) {
    $streamWriter.WriteLine("PASS $password")
    $streamWriter.Flush()
  }
  $streamWriter.WriteLine("NICK $nick")
  $streamWriter.WriteLine("USER $env:UserName 0 * :Shippable Assembly Lines")
  $streamWriter.Flush()

  # read data
  $maxWaitTime = 60 # seconds
  $message = ""
  $ready = $false
  while (($connection -eq "on") -and ($maxWaitTime -ge 0)) {

    if ($netStream.DataAvailable) {
      [char]$char = $netStream.ReadByte()
      if ($char -eq 13) {
        write-output "$message"
        $ready = _check_message $message
        $message = ""
      } elseif ($char -ne 10) {
        $message += $char
      }
    } else {
      if ($ready) {
        sleep 2
        write-output "Joining channel $channel"
        $streamWriter.WriteLine("JOIN $channel")
        $streamWriter.Flush()
        sleep 2
        $payload = $payload.TrimEnd()
        Write-Output "Sending notice"
        $streamWriter.WriteLine("NOTICE $channel :$payload")
        $streamWriter.Flush()
        $connection = "off"
      } else {
        write-output "waiting for $maxWaitTime more seconds..."
        sleep 2
        $maxWaitTime -= 2
      }
    }
  }
  if ($maxWaitTime -le 0) {
    Write-Output "Max wait time exceeded. Closing connection."
    $errorMessage = "Max wait time exceeded"
  }

  # disconnect
  write-output "disconnecting from server"
  $streamWriter.WriteLine("PART $channel")
  $streamWriter.WriteLine("QUIT")
  $streamWriter.Flush()
  $streamWriter.Close()
  $netStream.Close()
  $client.Close()
  if ($errorMessage) {
    throw $errorMessage
  }
}

function _send_airbrake_notification() {
  $r_authorization = @{}
  $r_obj_type = ""
  $r_project_id = "$env:opt_project_id"
  $r_endpoint = $(get_integration_resource_field "$env:opt_resource" url)
  $r_token = $(get_integration_resource_field "$env:opt_resource" token)
  $default_airbrake_payload = '{"environment":"$opt_environment","username":"$opt_username","email":"$opt_email","repository":"$opt_repository","revision":"$opt_revision","version":"$opt_version"}'

  if (!$env:opt_type) {
    throw "Error: --type is missing in shipctl notify"
  }
  if ($env:opt_type -eq "deploy") {
    $r_obj_type = "deploys"
  } else {
    throw "Error: unsupported type value $env:opt_type"
  }

  if (!$r_project_id) {
    $recipients_list = $(get_resource_version_key "$env:opt_resource" "recipients")
    $r_project_id = $recipients_list[0]
  }
  if (!$r_project_id) {
    throw "Error: missing project ID, try passing -project-id"
  }

  $r_endpoint = $r_endpoint.trim('/')
  $r_endpoint = "$r_endpoint/projects/${r_project_id}/${r_obj_type}?key=${r_token}"

  if ($env:opt_payload) {
    if (!(Test-Path $env:opt_payload)) {
      throw "Error: file not found at path: $env:opt_payload"
    }
    try {
      $result = Get-Content $env:opt_payload -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
      throw "Error: payload is not valid JSON"
    }
  } else {
    Out-File -FilePath "$env:TEMP/payload.json" -InputObject $default_airbrake_payload
    $env:opt_payload = "$env:TEMP/payload.json"
    shipctl replace $env:opt_payload
  }

  Write-Output "Requesting Airbrake project: $r_project_id"

  _send_web_notification -payload "$env:opt_payload" -auth $r_authorization -endpoint "$r_endpoint" -security_protocol "tls12"
}

function _send_newrelic_notification() {
  $appId = ""
  $r_endpoint = ""
  $default_post_deployment_payload = '{"$opt_type":{"revision":"$opt_revision","description":"$opt_description","user":"$opt_username","changelog":"$opt_changelog"}}'
  $default_get_appid_payload = @{ "filter[name]" = "$env:opt_appName" }
  $default_get_payload = ""
  $default_post_payload = ""
  $authorization = $(get_integration_resource_field "$env:opt_resource" token)

  if ($authorization) {
    $r_authorization = @{ "X-Api-Key" = "$authorization" }
  } else {
    $r_authorization = @{}
  }

  if (!$env:opt_username) {
    $env:opt_username = "Shippable"
  }

  $r_url=$(get_integration_resource_field "$env:opt_resource" url)
  if (!$r_url) {
    throw "Error: no url found in resource $env:opt_resource"
  }

  if (!$env:opt_appId -and !$env:opt_appName) {
    throw "Error: --appId or --appName should be present in shipctl notify"
  }

  $appId=$env:opt_appId
  if (!$appId) {
    $r_endpoint="$r_url/applications.json"
    $default_get_payload=$default_get_appid_payload
    $applications=$(_get_web_request -payload $default_get_payload -auth $r_authorization -endpoint "$r_endpoint") | ConvertFrom-Json
    $appId=$applications.applications[0].id
  }

  if (!$appId) {
    throw "Error: Unable to find an application on NewRelic"
  }
  $r_endpoint="$r_url/applications/$appId/deployments.json"
  $default_post_payload="$default_post_deployment_payload"

  if ($env:opt_payload) {
    if (!(Test-Path $env:opt_payload)) {
      throw "Error: file not found at path: $env:opt_payload"
    }
    try {
      $result = Get-Content $env:opt_payload -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
      throw "Error: payload is not valid JSON"
    }
  } else {
    if (!$env:opt_type) {
      throw "Error: --type is missing in shipctl notify"
    }
    if (!$env:opt_revision) {
      throw "Error: --revision is missing in shipctl notify"
    }
    Out-File -FilePath "$env:TEMP/payload.json" -InputObject $default_post_payload
    $env:opt_payload = "$env:TEMP/payload.json"
    shipctl replace $env:opt_payload
  }

   Write-Output "Recording deployments on NewRelic for appID: $appId"

  _send_web_notification -payload "$env:opt_payload" -auth $r_authorization -endpoint "$r_endpoint"
}

function _check_message() {

  param(
    [string]$message
  )

  if ($message -match "^:(.+?) +([0-9]{3}|[A-Z]+)") {
    $from = $matches[1]
    $code = $matches[2]
  }

  $ready = $false
  switch -regex ($code) {
    "376" { # means end of MOTD. Additional commands will be accepted now
      $ready = $true
      break
    }
  }
  return $ready
}
