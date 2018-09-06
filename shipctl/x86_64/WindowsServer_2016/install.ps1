$currentDir = $PSScriptRoot
$destinationDir = "$env:ProgramFiles\Shippable"

if (!(Test-Path -PathType Container $destinationDir)) {
    New-Item -ItemType directory -Path $destinationDir
}

Write-Output "Installing shipctl"
Copy-Item -Force $currentDir\shipctl.ps1 $destinationDir\shipctl.ps1
Copy-Item -Force $currentDir\utility.ps1 $destinationDir\utility.ps1

Write-Output "Installing shippable_retry"
Copy-Item -Force $currentDir\shippable_retry.ps1 $destinationDir\shippable_retry.ps1

Write-Output "Installing shippable_replace"
Copy-Item -Force $currentDir\shippable_replace.ps1 $destinationDir\shippable_replace.ps1

if (!($env:PATH.Contains($destinationDir))) {
    Write-Output "Updating machine PATH environment variable"
    $env:PATH="$env:PATH;$destinationDir"
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine);
}
