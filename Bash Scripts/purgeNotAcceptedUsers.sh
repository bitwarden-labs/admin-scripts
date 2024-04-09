#!/bin/bash

read -p 'Bitwarden Vault URI: ' vault_uri
read -p 'Organization Client ID: ' org_client_id
read -sp 'Organization Client Secret (Hidden): ' org_client_secret

ACCESS_TOKEN="$(curl -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret'' | cut -d '"' -f4)"

org_members="$(curl -X GET $vault_uri/api/public/members/ -H 'Authorization: Bearer '$ACCESS_TOKEN'' | jq -c '.data[] | select( .status == 0 )' | jq -c '.id' | tr -d '"')"
for member_id in ${org_members[@]} ; do
	curl -X DELETE "$vault_uri/api/public/members/$member_id" -H "Content-Length: 0" -H 'Authorization: Bearer '$ACCESS_TOKEN''
done
