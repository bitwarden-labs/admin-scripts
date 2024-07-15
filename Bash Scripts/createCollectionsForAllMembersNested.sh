#!/bin/bash

# Depends on file "secureString.txt" which can be created by first running:
# echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:Secret@Bitwarden#99 > secureString.txt
# Depends on file "secureString_secret.txt" which can be created by first running:
# echo 'YOUR_ORG_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:Secret@Bitwarden#99 > secureString_secret.txt
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# openssl is required in $PATH https://www.openssl.org/

organization_id="YOUR-ORG-ID" # Set your Org ID

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
 -salt -pass pass:Secret@Bitwarden#99)

password=$(cat secureString.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 \
 -salt -pass pass:Secret@Bitwarden#99)

session_key="$(printf $password | bw unlock --raw)"
export BW_SESSION="$session_key"
bearer_token="$(curl -sX POST $identity_url/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id='organization.$organization_id'&client_secret='$org_client_secret_key'' | cut -d '"' -f4)"
org_members="$(curl -sX GET $api_url/public/members -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer_token'' | jq -r '.data[] | select(.status == 2) | .name')"

IFS=$'\n'

for member in ${org_members[@]}; do

if (bw list org-collections --organizationid $organization_id | jq -r '.[].name' | grep -x "Personal Collections/$member" > /dev/null); then
echo "$member already has a Collection, skipping"

else

allorgmembers="$(curl -sX GET $api_url/public/members -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer_token'' | jq 'del(.object)')"
memberid="$(jq -r -c --arg n "$member" '.data[] | select(.name==$n) | .id' <<< "$allorgmembers")"
origmemberbody="$(curl -sX GET $api_url/public/members/$memberid -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer_token''| jq -r -c 'del(.object)')"
collectionid="$(bw get template org-collection | jq -c --arg n "$member" --arg c "$organization_id" '.name="Personal Collections/" + $n | .organizationId=$c | del(.groups[1])' | bw encode | bw create org-collection --organizationid $organization_id | jq -r '.id')"
newmemberbody=$(jq -r -c --arg newcol "$collectionid" --arg i "$memberid" 'select(.id==$i) | .collections += [{"id": $newcol, "readOnly": false, "hidePasswords": false, "manage": true}]' <<< "$origmemberbody")
curl -sX PUT $api_url/public/members/$memberid -H 'Content-Type: application/json' -H 'Authorization: Bearer '$bearer_token'' -d $newmemberbody > /dev/null
echo "Created Collection for $member"
fi

done
