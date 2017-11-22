$NODE_DATA_LOCATION="$env:USERPROFILE\node"
$NODE_ENV="$NODE_DATA_LOCATION\_node.env.ps1"
$NODE_INIT_SCRIPT_FULL_PATH="$NODE_SCRIPTS_LOCATION\initScripts\$NODE_INIT_SCRIPT"

Write-Output "Sourcing $NODE_ENV"
. "$NODE_ENV"

$REQUIRED_ENVS = @(
    "EXEC_IMAGE",
    "LISTEN_QUEUE",
    "NODE_ARCHITECTURE",
    "NODE_DOCKER_VERSION",
    "NODE_ID",
    "NODE_INIT_SCRIPT",
    "NODE_OPERATING_SYSTEM",
    "NODE_TYPE_CODE",
    "RUN_MODE",
    "SHIPPABLE_AMQP_DEFAULT_EXCHANGE",
    "SHIPPABLE_AMQP_URL",
    "SHIPPABLE_API_URL",
    "SHIPPABLE_RELEASE_VERSION",
    "SUBSCRIPTION_ID")

# Helper functions

Function checkRequiredEnvs($requiredEnvs) {
    Write-Output "Verifying environment variables"
    foreach ($reqEnv in $requiredEnvs) {
        if (!($reqEnv)) {
            Write-Error "$reqEnv is not defined"
            exit -1;
        }
    }
}

# End helper functions

Function initializeNode() {
    Write-Output "Beginning node initialization"
    & "$NODE_INIT_SCRIPT_FULL_PATH"
    Write-Output "Node initialization complete"
}

checkRequiredEnvs($REQUIRED_ENVS);
initializeNode;