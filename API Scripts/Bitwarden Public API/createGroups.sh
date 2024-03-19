## Script downloads Bitwarden Vault Event Logs
org_client_id='organization.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
org_client_secret='xxxxxxxxxxxxxxxxxxxxxx'
scope='api.organization'
grant_type='client_credentials'
vault_uri='https://vault.bitwarden.com'

  #!/bin/bash

ACCESS_TOKEN="$(curl -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret'' | cut -d '"' -f4)"
curl -X POST $vault_uri/api/public/groups/ -H 'Authorization: Bearer '$ACCESS_TOKEN'' -H "Content-Type: application/json" -d '{"name": "myGroup", "accessAll": true, "exernalId": "external_id_123456", "collections": [{"id":"aa1f6cf8-178b-4ea1-896a-b00700b13a69","readOnly":true}]}'
curl -X POST $vault_uri/api/public/members/ -H 'Authorization: Bearer '$ACCESS_TOKEN'' -H "Content-Type: application/json" -d '{"type": 0, "accessAll": true, "externalId": "external_id_123456", "resetPasswordEnrolled": false, "collections": [{"id":"aa1f6cf8-178b-4ea1-896a-b00700b13a69","readOnly":true}], "email": "abramley+api@bitwaden.com"}'

