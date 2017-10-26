# Accepts an array of ENVs and exit with error status 1 if any of them are missing
check_envs() {
  expected_envs=$1
  for env in "${expected_envs[@]}"
  do
    env_value=$(eval "echo \$$env")
    if [ -z "$env_value" ]; then
      echo "Missing ENV: $env"
      exit 1
    fi
  done
}
