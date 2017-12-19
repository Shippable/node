$ErrorActionPreference = "Stop"

$shipctl_command = $args[0]
$len = $args.Length - 1
$copy = $args[1..$len]

. ./utility.ps1

function execute_shiptctl_command() {
    if (Get-Command $shipctl_command -CommandType Function) {
        # Splat `copy` so it's passed as individual arguments to the function
        Invoke-Expression "$shipctl_command @copy"
    } else {
        Write-Output "The command $shipctl_command is not supported on this image."
        return 99
    }
}

execute_shiptctl_command $shipctl_command