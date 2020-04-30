#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Missing required argument: server_env!"
  exit 2
fi

server_env="$1"

index=0
while true; do
  output=$(python manage-servers.py is_install_ready_to_continue $server_env)
  output_trim=$(echo "$output" | xargs)

  if [[ $index -gt 59 ]]; then
    echo "60 minutes has passed"
    echo "Launching the wait task again"
    bash .circleci/launch-wait-for-install.sh $server_env
    break
  elif [[ "$output_trim" = "true" ]]; then
    echo "Install ready!"
    bash .circleci/launch-finish-install.sh $server_env
    break
  elif [[ "$output_trim" = "false" ]]; then
    echo "Install not ready yet"
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') Sleeping 1 minute .."
  sleep 60
  index=$((index+1))
done
