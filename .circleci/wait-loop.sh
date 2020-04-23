#!/bin/bash

set -e

index=0
while true; do
  output=$(python manage-servers.py is_install_ready)
  output_trim=$(echo "$output" | xargs)

  if [[ $index -gt 59 ]]; then
    echo "60 minutes has passed"
    echo "Launching the wait task again"
    bash .circleci/launch-wait.sh
    break
  if [[ "$output_trim" = "true" ]] then
    echo "Install ready!"
    bash .circleci/launch-further-steps.sh
    break
  elif [[ "$output_trim" = "false" ]]; then
    echo "Install not ready yet"
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') Sleeping 1 minute .."
  sleep 60
  index=$((index+1))
done
