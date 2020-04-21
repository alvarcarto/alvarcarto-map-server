body='{
  "parameters": {
    "start": false,
    "deploy": true
  }
}'

echo "Sending body: $body"
http_code=$(curl -o out -w '%{http_code}' -v -u ${CIRCLECI_TOKEN}: -X POST --header "Content-Type: application/json" -d "$body" https://circleci.com/api/v2/project/github/alvarcarto/alvarcarto-map-server/pipeline)

echo -e "\nResponse:"
cat out

if [[ $http_code -ne 201 ]]; then
  echo -e "\n\nCurl response status code was $http_code"
  exit 1
fi