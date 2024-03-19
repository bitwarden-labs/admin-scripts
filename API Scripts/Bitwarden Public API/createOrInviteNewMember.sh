## Script downloads Bitwarden Vault Event Logs
org_client_id='organization.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
org_client_secret='xxxxxxxxxxxxxxxxxxxxxx'
scope='api.organization'
grant_type='client_credentials'
vault_uri='https://vault.bitwarden.com'

#!/bin/bash
ACCESS_TOKEN="$(curl -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret'' | cut -d '"' -f4)"
curl -X POST $vault_uri/public/members -H 'Authorization: Bearer '$ACCESS_TOKEN'' -H "Content-Type: application/json" -d '{"email":"user1@example.com","collections":[{"id":"2d66c744-b186-421b-951c-acc3005cf548","readOnly":false}],"type":0,"accessAll":true,"externalId":"null"}'
