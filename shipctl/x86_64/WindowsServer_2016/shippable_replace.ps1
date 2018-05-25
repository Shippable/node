
function replace() {
    $allEnvs = Get-ChildItem env:*
    foreach ($fileName in $args) {
        $fileContent = Get-Content "$fileName"
        foreach ($env in $allEnvs) {
            # Support ${NAME} and $NAME, in that order of preference
            $fileContent = $fileContent.Replace("$" + "{" + $env.Key + "}", $env.Value).Replace("$" + $env.Key, $env.Value)
        }
        # Use IO.File instead of Out-File to prevent UTF-8 BOM
        [IO.File]::WriteAllLines(($fileName | Resolve-Path), $fileContent)
    }
}

replace @args
