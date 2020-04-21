NEW_WAIT_INDEX=$((WAIT_INDEX+1))
body_template='{
  "parameters": {
    "start": false,
    "wait": true,
    "wait-index": "0"
  }
}'
body=$(printf "$body_template" "$NEW_WAIT_INDEX")

echo "Sending body: $body"
http_code=$(curl -o out -w '%{http_code}' -v -u ${CIRCLECI_TOKEN}: -X POST --header "Content-Type: application/json" -d "$body" https://circleci.com/api/v2/project/github/alvarcarto/alvarcarto-map-server/pipeline)

echo -e "\nResponse:"
cat out

if [[ $http_code -ne 201 ]]; then
  echo -e "\n\nCurl response status code was $http_code"
  exit 1
fi