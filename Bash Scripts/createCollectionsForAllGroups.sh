#!/bin/bash
# Depends on file "secureString.txt" which can be created as an encrypted file by replacing all references in this script to:
# replacewithyoursupersecretstring
# With your own encryption phrase, and then running:
# echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:replacewithyoursupersecretstring > secureString.txt
# Depends on file "secureString_secret.txt" which can be created by first running:
# echo 'YOUR_ORG_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:replacewithyoursupersecretstring > secureString_secret.txt
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# openssl is required in $PATH https://www.openssl.org/

organization_id="YOUR-ORGANIZATION-ID" # Set your Org ID

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
 -salt -pass pass:replacewithyoursupersecretstring)
org_client_id=("organization.$organization_id")

# Get Access Token

bearer_token="$(curl -sX POST $identity_url/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d  'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret_key'' | cut -d '"' -f4)"

# Perform CLI and API auth

password=$(cat secureString.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 \
 -salt -pass pass:replacewithyoursupersecretstring)

session_key="$(printf $password | bw unlock --raw)"

# Fetch the list of Groups

org_groups="$(curl -sX GET $api_url/public/groups -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer_token'')"
group_names="$(echo $org_groups | jq -r '.data[].name')"
group_ids="$(echo $org_groups | jq -r '.data[].id')"

# For each Group, create a Collection, and then assign that Group to it

for groupname in ${group_names[@]}; do

# Check if the Group already exists

#echo "Define existingcollection"

if existingcollection="$(bw --session "$session_key" list org-collections --organizationid $organization_id | jq -r '.[].name' | grep -x "$groupname")"; then

#echo "Start if loop on $existingcollection looking for $groupname"

#if [ $existingcollection == $groupname ]; then

echo "\n\n$groupname already has a Collection, skipping"

else

bw --session "$session_key" get template org-collection | jq --arg n "$groupname" --arg c "$organization_id" --arg g "$groupid" '.name=$n | .organizationId=$c | .groups[0].id=$g | del(.groups[1])' | bw encode | bw --session "$session_key" create org-collection --organizationid $organization_id
echo "\n\nCreated Collection for $groupname"

fi

done
