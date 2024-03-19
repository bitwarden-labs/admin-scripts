
client_id='organization.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
client_secret='yourclientsecret'
scope='api.organization'
grant_type='client_credentials'
vault_uri='https://your.vault.uri'

  #!/bin/bash

echo $client_id
echo $client_credentials
echo $scope
echo $grant_type
echo $vault_uri

ACCESS_TOKEN="$(curl -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id=organization.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx&client_secret=yourclientsecret' | jq -cr '.access_token')"

echo $ACCESS_TOKEN

curl -X GET $vault_uri/api/public/events/ -H 'Authorization: Bearer '$ACCESS_TOKEN'' | jq -r '.data[] | join (",")' > /downloads/bwEventLogs/event_logs.csv
