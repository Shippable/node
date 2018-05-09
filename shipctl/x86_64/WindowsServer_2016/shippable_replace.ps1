
function replace() {
    mkdir -Force $env:TEMP\shippable_replace

    $allEnvs = Get-ChildItem env:*
    foreach ($fileName in $args) {
        $fileContent = Get-Content "$fileName"
        foreach ($env in $allEnvs) {
            $fileContent = $fileContent.Replace("$" + $env.Key, $env.Value)
            $fileContent | Out-File -Encoding utf8 -FilePath "$fileName"
        }
    }
}

replace @args
