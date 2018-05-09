# Retries commands up to $maxRetries times if an error occurs
$maxRetries = 3

# PowerShell commands MUST be invoked with "-ErrorAction stop" if you 
# want this to work. We will not force any arguments.

# The last known exit code from the command
$ret = 0

function retry($command) {
    foreach ($i in 1..$maxRetries) {
        $LASTEXITCODE = 0
        try {
            &$command @args
            $isSuccess = $?
            $script:ret = $LASTEXITCODE
        } catch {
            Write-Error $_ -ErrorAction Continue
            $isSuccess = $false
            $script:ret = 99
        }       

        if ($isSuccess) {
            break;
        }
        Write-Output "retrying $i of $maxRetries times..."
        Write-Output ""
    }
}

# Convert args to "command" and "everything else"
$len = $args.Length - 1
if ($len -eq 0) {
    $len = 1
}
$copy = $args[1..$len]

# Splat copy so it can be passed to the command invocation operator
retry $args[0] @copy

# Always exit with $ret
exit $ret