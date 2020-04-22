#!/bin/bash

set -e

index=0
while true; do
  (python manage-servers.py is_install_ready)
  exit_code=$?

  if [[ $index -gt 59 ]]; then
    echo "60 minutes has passed"
    echo "Launching the wait task again"
    bash .circleci/launch-wait.sh
    break
  elif [[ exit_code -eq 0 ]]; then
    echo "Install ready!"
    bash .circleci/launch-further-steps.sh
    break
  elif [[ exit_code -eq 50 ]]; then
    echo "Install not ready yet"
  else
    echo "Unexpected error when running is_install_ready"
    exit $exit_code
  fi

  echo "$(date '+%Y-%m-%d %H:%M:%S') Sleeping 1 minute .."
  sleep 60
  index=$((index+1))
done
