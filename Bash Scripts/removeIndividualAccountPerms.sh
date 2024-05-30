#!/bin/bash
# Depends on file "secureString_secret.txt" which can be created by first running:
# echo 'YOUR_ORG_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:Secret@Bitwarden#69 > secureString_secret.txt
# jq is required in $PATH https://stedolan.github.io/jq/download/
# openssl is required in $PATH https://www.openssl.org/

organization_id="REPLACE-WITH-ORG-ID" # Set your Org ID 

cloud_flag=1 # Self-hosted Bitwarden or Cloud?
if [ $cloud_flag == 1 ]; then
    api_url="https://api.bitwarden.com"
    identity_url="https://identity.bitwarden.com"
elif [ $cloud_flag == 2 ]; then
    api_url="https://api.bitwarden.eu"
    identity_url="https://identity.bitwarden.eu"
else
    api_url="https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    identity_url="https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
fi

# Set up CLI and API auth

org_client_secret_key=$(cat secureString_secret.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 \
 -salt -pass pass:Secret@Bitwarden#69)
org_client_id=("organization.$organization_id")

# Get Access Token

bearer_token="$(curl -s -X POST $identity_url/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d  'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret_key'' | cut -d '"' -f4)"

org_members="$(curl -sX GET $api_url/public/members -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer_token'' | jq -r '.data[] | .id')"

for member_id in ${org_members[@]} ; do
            member_data="$(curl -s -X GET "$api_url/public/members/$member_id" -H 'Authorization: Bearer '$bearer_token'')"
            member_email=$(echo "$member_data" | jq -r .email)
            new_member_data=$(echo $member_data | jq ".collections = []")
            curl -sX PUT $api_url/public/members/$member_id -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer_token'' -d "$new_member_data" > /dev/null
            echo "$member_email is updated"
done
