#!/bin/bash

read -p 'Bitwarden Vault URI: ' vault_uri
read -p 'Organization Client ID: ' org_client_id
read -sp 'Organization Client Secret (Hidden): ' org_client_secret

ACCESS_TOKEN="$(curl -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret'' | cut -d '"' -f4)"

read -p 'Current Role Type Number (Owner=0, Admin=1, User=2, Manager=3) [Change From]: ' current_role
read -p 'New Role Type Number (Owner=0, Admin=1, User=2, Manager=3) [Change To]: ' new_role

org_members="$(curl -X GET $vault_uri/api/public/members/ -H 'Authorization: Bearer '$ACCESS_TOKEN'' | jq -c '.data[] | select( .type == '$current_role' )' | jq -c '.id' | tr -d '"')"

for member_id in ${org_members[@]} ; do
	member_data="$(curl -X GET $vault_uri/api/public/members/$member_id -H 'Authorization: Bearer '$ACCESS_TOKEN'' | jq '.type = '$new_role'' | sed '1,8d' | sed '1 i {' | jq -c)"
	curl -kX PUT $vault_uri/api/public/members/$member_id -H 'Authorization: Bearer '$ACCESS_TOKEN'' -H "accept: application/json" -H "Content-Type: application/json" -d ''$member_data''
done