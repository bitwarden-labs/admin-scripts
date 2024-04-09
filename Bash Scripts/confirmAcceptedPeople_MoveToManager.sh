#!/bin/bash
# Depends on file "secureString.txt" which can be created by first running:
# echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:Secret@Bitwarden#69 > secureString.txt
# Depends on file "secureString_secret.txt" which can be created by first running:
# echo 'YOUR_ORG_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:Secret@Bitwarden#69 > secureString_secret.txt
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# openssl is required in $PATH https://www.openssl.org/

organization_id="YOUR_ORG_ID" # Set your Org ID

cloud_flag=1 # Self-hosted Bitwarden or Cloud?
if [ $cloud_flag == 1 ]; then
    api_url="https://api.bitwarden.com"
    identity_url="https://identity.bitwarden.com"
else
    api_url="https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    identity_url="https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
fi

# Set up CLI and API auth

org_client_secret_key=$(cat secureString_secret.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 \
 -salt -pass pass:Secret@Bitwarden#69)
org_client_id=("organization.$organization_id")

# Get Access Token

bearer_token="$(curl -X POST $identity_url/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d  'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret_key'' | cut -d '"' -f4)"

# Perform CLI and API auth

password=$(cat secureString.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 \
 -salt -pass pass:Secret@Bitwarden#69)

session_key="$(printf $password | bw unlock --raw)"
org_members="$(bw list --session "$session_key" org-members --organizationid $organization_id | jq -c '.[] | select( .status == 1 )' | jq -c '.id' | tr -d '"')"

for member_id in ${org_members[@]} ; do
            bw confirm --session $session_key org-member $member_id --organizationid $organization_id
            member_data="$(curl -X GET "$api_url/public/members/$member_id" -H 'Authorization: Bearer '$bearer_token'')"
            access_all=$(echo "$member_data" | jq -r .accessAll)
            external_id=$(echo "$member_data" | jq -r .externalId)
            reset_password_enrolled=$(echo "$member_data" | jq -r .resetPasswordEnrolled)
            collections=$(echo "$member_data" | jq -r .collections)
            curl -X PUT "$api_url/public/members/$member_id" -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer_token'' -d "{\"type\":3, \"accessAll\":$access_all, \"externalId\": \"$external_id\", \"resetPasswordEnrolled\":$reset_password_enrolled, \"collections\":$collections}"
done