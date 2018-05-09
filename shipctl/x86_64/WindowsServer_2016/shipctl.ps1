$ErrorActionPreference = "Stop"

$shipctl_command = $args[0]
$len = $args.Length - 1
if ($len -eq 0) {
    $len = 1
}
$copy = $args[1..$len]

. $PSScriptRoot/utility.ps1


function execute_shiptctl_command() {
    if (Get-Command $shipctl_command -CommandType Function -ErrorAction SilentlyContinue) {
        # Splat `copy` so it's passed as individual arguments to the function
        try {
            Invoke-Expression "$shipctl_command @copy"
        } catch {
            Write-Error $_
            exit 99
        }
    } else {
        Write-Error "The command $shipctl_command is not supported on this image."
        exit 99
    }
}

function execute_command($command) {
    &$command @args
    exit $LASTEXITCODE
}

if ($shipctl_command -eq "jdk") {
    Write-Error "shipctl jdk is not yet supported on this image"
} elseif ($shipctl_command -eq "decrypt") {
    Write-Error "shipctl decrypt is not yet supported on this image"
} elseif ($shipctl_command -eq "service") {
    Write-Error "shipctl service is not yet supported on this image"
} elseif ($shipctl_command -eq "replace") {
    execute_command shippable_replace @copy
} elseif ($shipctl_command -eq "retry") {
    execute_command shippable_retry @copy
} else {
    execute_shiptctl_command $shipctl_command
}