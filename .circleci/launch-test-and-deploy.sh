#!/bin/bash

set -e


if [ -z "$1" ]; then
  echo "Missing required argument: server_env!"
  exit 2
fi

server_env="$1"
body_prod='{
  "parameters": {
    "test_and_deploy": true,
    "server_env": "%s"
  }
}'
body_qa='{
  "parameters": {
    "test_and_deploy_qa": true,
    "server_env": "%s"
  }
}'

body_template="$body_qa"

if [ "$server_env" == "reserve" ]; then
  body_template="$body_prod"
fi
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
