$DOCKER_VERSION="17.06.0"
$docker_restart=$false
$SHIPPABLE_RUNTIME_DIR="c:\shippable"
$BASE_UUID=New-Guid
$BASE_DIR="$SHIPPABLE_RUNTIME_DIR\$BASE_UUID"
$REQPROC_DIR="$BASE_DIR\reqProc"
$REQEXEC_DIR="$BASE_DIR\reqExec"
$REQEXEC_BIN_DIR="$BASE_DIR\reqExec\bin"
$REQEXEC_BIN_PATH="$REQEXEC_BIN_DIR\dist\main\main"
$REQKICK_DIR="$BASE_DIR\reqKick"
$REQKICK_SERVICE_DIR="$REQKICK_DIR\init\$NODE_ARCHITECTURE\$NODE_OPERATING_SYSTEM"
$REQKICK_CONFIG_DIR="c:\shippable\config\reqKick"
$BUILD_DIR="$BASE_DIR\build"
$STATUS_DIR="$BUILD_DIR\status"
$SCRIPTS_DIR="$BUILD_DIR\scripts"
$REQPROC_MOUNTS=""
$REQPROC_ENVS=""
$REQPROC_OPTS=""
$REQPROC_CONTAINER_NAME_PATTERN="reqProc"
$REQPROC_CONTAINER_NAME="$REQPROC_CONTAINER_NAME_PATTERN-$BASE_UUID"
$REQKICK_SERVICE_NAME_PATTERN="shippable-reqKick@"
$SHIPPABLE_AMQP_URL=""
$SHIPPABLE_API_URL="https://api.shippable.com"
$LISTEN_QUEUE="58b5dd45ddd8e8070045dab1.exec"
$NODE_ID="5a04a3542ff69c0700fabe0b"
$RUN_MODE="production"
$COMPONENT="genExec"
$SHIPPABLE_AMQP_DEFAULT_EXCHANGE="shippableEx"
$SUBSCRIPTION_ID="58b5dd45ddd8e8070045dab1"
$NODE_TYPE_CODE="7000"
$DOCKER_CLIENT_LATEST=""
$EXEC_IMAGE="drydock/genexec:v5.10.4"
$DOCKER_VERSION="17.09.0-ce"
$NODE_ARCHITECTURE="x86_64"

Function install_nodejs {
	echo "Installing node"
	$install_node_js_cmd = "choco install -y nodejs.install"
	iex $install_node_js_cmd
	iex "RefreshEnv"

	#$check_node_version_cmd = '"$env:ProgramW6432\nodejs\node.exe" "-v"'
	$check_node_version_cmd = "node -v"
	# iex "& $check_node_version_cmd"
	iex $check_node_version_cmd
}

Function install_nodepackages {
	echo "Installing prerequisite packages"
	$install_pm2_package_cmd = "npm install pm2 -g"
	iex $install_pm2_package_cmd
	iex "pm2 update"

	# pm2-windows-startup
	$install_pm2_startup_package_cmd = "npm install pm2-windows-startup -g"
	iex $install_pm2_startup_package_cmd
	$run_pm2_startup_cmd = "pm2-startup install"
	iex $run_pm2_startup_cmd
}

Function is_installed( $program ) {
	$x86 = ((Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    $x64 = ((Get-ChildItem "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") |
        Where-Object { $_.GetValue( "DisplayName" ) -like "*$program*" } ).Length -gt 0;

    return $x86 -or $x64;
}

Function docker_install() {
	echo "Installing docker"

	$url = "https://download.docker.com/win/stable/InstallDocker.msi"
	$output = "$PSScriptRoot/InstallDocker.msi"

	$wc = New-Object System.Net.WebClient
	$wc.DownloadFile($url, $output)

	$arguments= ' /qn /l*v .\install_docker.log'
	Start-Process `
		 -file  $output `
		 -arg $arguments `
		 -passthru | wait-process

	$docker = "$env:ProgramW6432\Docker\Docker\Docker for Windows.exe"
	$process = Start-Process -file  $docker -PassThru

	echo "Waiting for docker daemon to start"
	# wait for a few seconds for Docker to Start
	Do {
		Start-Sleep -s 1
		& "docker" ps > out.txt 2>&1
	}
	While ($LastExitCode -eq 1)

	# Output docker version
	& "docker" -v
}

Function setup_envs() {
  $REQPROC_ENVS="$REQPROC_ENVS `
    -e SHIPPABLE_AMQP_URL=$SHIPPABLE_AMQP_URL `
    -e SHIPPABLE_AMQP_DEFAULT_EXCHANGE=$SHIPPABLE_AMQP_DEFAULT_EXCHANGE `
    -e SHIPPABLE_API_URL=$SHIPPABLE_API_URL `
    -e LISTEN_QUEUE=$LISTEN_QUEUE `
    -e NODE_ID=$NODE_ID `
    -e RUN_MODE=$RUN_MODE `
    -e SUBSCRIPTION_ID=$SUBSCRIPTION_ID `
    -e NODE_TYPE_CODE=$NODE_TYPE_CODE `
    -e BASE_DIR=$BASE_DIR `
    -e REQPROC_DIR=$REQPROC_DIR `
    -e REQEXEC_DIR=$REQEXEC_DIR `
    -e REQEXEC_BIN_DIR=$REQEXEC_BIN_DIR `
    -e REQKICK_DIR=$REQKICK_DIR `
    -e BUILD_DIR=$BUILD_DIR `
    -e REQPROC_CONTAINER_NAME=$REQPROC_CONTAINER_NAME `
    -e DEFAULT_TASK_CONTAINER_OPTIONS='$DEFAULT_TASK_CONTAINER_OPTIONS' `
    -e EXEC_IMAGE=$EXEC_IMAGE `
    -e DOCKER_CLIENT_LATEST=$DOCKER_CLIENT_LATEST `
    -e SHIPPABLE_DOCKER_VERSION=$DOCKER_VERSION `
    -e IS_DOCKER_LEGACY=false `
    -e SHIPPABLE_NODE_ARCHITECTURE=$NODE_ARCHITECTURE"

	echo $REQPROC_ENVS
}

Function setup_directories() {
	Remove-Item $SHIPPABLE_RUNTIME_DIR -Force -Recurse
	iex "mkdir -p $BASE_DIR"
	iex "mkdir -p $REQPROC_DIR"
	iex "mkdir -p $REQEXEC_DIR"
	iex "mkdir -p $REQEXEC_BIN_DIR"
	iex "mkdir -p $REQKICK_DIR"
	iex "mkdir -p $BUILD_DIR"
 }

Function boot_reqKick() {
	echo "Booting up reqKick service..."

	iex "git clone https://github.com/Shippable/reqKick.git $REQKICK_DIR"
	iex "pushd $REQKICK_DIR"
	iex "npm install"

	[Environment]::SetEnvironmentVariable("STATUS_DIR", "$STATUS_DIR", "Machine")
	[Environment]::SetEnvironmentVariable("SCRIPTS_DIR", "$SCRIPTS_DIR", "Machine")
	[Environment]::SetEnvironmentVariable("REQEXEC_BIN_PATH", "c:\Users\ambarish\Desktop\shippable\reqExec\dist\main.exe", "Machine")
	iex "RefreshEnv"

	# We also need to set Environment variables for launching reqKick from within powershell
	# On Reboot the systemt Environment variables will take effect
	$env:STATUS_DIR="$STATUS_DIR"
	$env:SCRIPTS_DIR="$SCRIPTS_DIR"
	$env:REQEXEC_BIN_PATH="c:\Users\ambarish\Desktop\shippable\reqExec\dist\main.exe"

	iex "pm2 start reqKick.app.js"
	iex "pm2 list"
	iex "pm2 show 0"
	iex "pm2 save"

	iex "popd"
}

Function remove_reqKick() {
	$remove_reqKick_cmd = "pm2 delete all"
	iex $remove_reqKick_cmd
}


install_nodejs
install_nodepackages

$docker_installed = is_installed docker
If ($docker_installed -eq $False) {
	docker_install
}

setup_envs
setup_directories
remove_reqKick
boot_reqKick
