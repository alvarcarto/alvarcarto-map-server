#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "Missing required argument: server_env!"
  exit 2
fi

body_template='{
  "parameters": {
    "wait_for_install": true,
    "server_env": "%s"
  }
}'
body=$(printf "$body_template" "$1")

echo "Sending body: $body"
http_code=$(curl -o out -w '%{http_code}' -u ${CIRCLECI_TOKEN}: -X POST --header "Content-Type: application/json" -d "$body" https://circleci.com/api/v2/project/github/alvarcarto/alvarcarto-map-server/pipeline)

echo -e "\nResponse:"
cat out
rm out

if [[ $http_code -ne 201 ]] && [[ $http_code -ne 200 ]]; then
  echo -e "\n\nCurl response status code was $http_code"
  exit 1
fi
