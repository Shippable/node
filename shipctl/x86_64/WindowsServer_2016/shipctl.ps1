$ErrorActionPreference = "Stop"

$shipctl_command = $args[0]
$len = $args.Length - 1
#$copy = $args[1..$len]
if ($len -eq 0) {
    $len = 1
}
$copy = $args[1..$len]

. ./utility.ps1


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

execute_shiptctl_command $shipctl_command