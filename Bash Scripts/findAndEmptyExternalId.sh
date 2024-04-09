#!/bin/bash

read -p 'Bitwarden Vault URI: ' vault_uri
read -p 'Organization Client ID: ' org_client_id
read -sp 'Organization Client Secret (Hidden): ' org_client_secret
read -p 'External ID to query: ' user_external_id

#if you want to hardcode the values
#vault_uri="https://bitwarden.example.com"
#org_client_id="organization.999999-999-4a23-a0a4-af91000f50d0"
#org_client_secret="Mxd999999999999PSqxwDb90ON"

ACCESS_TOKEN="$(curl -s -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret'' | cut -d '"' -f4)"

org_members="$(curl -s -X GET $vault_uri/api/public/members/ -H 'Authorization: Bearer '$ACCESS_TOKEN'' | jq -c '.data[] | select( .externalId == "'$user_external_id'" )' | jq -c '"\(.id),\(.email)"' | tr -d '"')"

echo ""
echo "Members with that External ID:"
echo $org_members
echo ""

member_id="${org_members%,*}"
email="${org_members#*,}"
read -p "Do you want to empty the external ID of $email? (Y/N): " answer


case "$answer" in
  [Yy]* )
    echo "You chose YES. Performing the action..."
	echo "Emptying externalID of $email"
	member_data="$(curl -s -X GET $vault_uri/api/public/members/$member_id -H 'Authorization: Bearer '$ACCESS_TOKEN'' | jq '.externalId = null' | sed '1,8d' | sed '1 i\
{
' | jq -c)"
	curl -s -kX PUT $vault_uri/api/public/members/$member_id -H 'Authorization: Bearer '$ACCESS_TOKEN'' -H "accept: application/json" -H "Content-Type: application/json" -d ''$member_data''
    ;;
  [Nn]* )
    echo "You chose NO. Exiting..."
    # Optional: Place code for an alternative action here
    exit 1
    ;;
  * )
    echo "Invalid response. Please answer with Y or N."
    exit 1
    ;;
esac

