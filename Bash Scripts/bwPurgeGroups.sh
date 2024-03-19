#!/bin/bash

#read -p 'Bitwarden Vault URI: ' vault_uri
vault_uri="https://vault.bitwarden.com/"
read -p 'Organization Client ID: ' org_client_id
read -sp 'Organization Client Secret (Hidden): ' org_client_secret


ACCESS_TOKEN="$(curl -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret'' | jq -cr '.access_token')"

org_groups="$(curl -X GET $vault_uri/api/public/groups/ -H 'Authorization: Bearer '$ACCESS_TOKEN''  | jq -cr '.data[] | .id')"

for group_id in ${org_groups[@]} ; do
  curl -X DELETE "$vault_uri/api/public/groups/$group_id" -H "Content-Length: 0" -H 'Authorization: Bearer '$ACCESS_TOKEN''
  echo "$group_id deleted"
done
