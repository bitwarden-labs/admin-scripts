
client_id='organization.17fac31c-f515-44cb-b88e-af4900f6d531'
client_secret='WNZaEmgfcg11OlPrNIuWAYCeghA8Je'
scope='api.organization'
grant_type='client_credentials'
vault_uri='https://bitwardengrafana.atjb.link'

  #!/bin/bash

echo $client_id
echo $client_credentials
echo $scope
echo $grant_type
echo $vault_uri

ACCESS_TOKEN="$(curl -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id=organization.17fac31c-f515-44cb-b88e-af4900f6d531&client_secret=WNZaEmgfcg11OlPrNIuWAYCeghA8Je' | jq -cr '.access_token')"

echo $ACCESS_TOKEN

curl -X GET $vault_uri/api/public/events/ -H 'Authorization: Bearer '$ACCESS_TOKEN'' | jq -r '.data[] | join (",")' > /home/adam/bwEventLogs/event_logs.csv