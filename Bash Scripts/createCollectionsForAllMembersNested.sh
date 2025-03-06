#!/bin/bash

# Depends on file "secureString.txt" which can be created by first running:
# echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:Secret@Bitwarden#99 > secureString.txt
# Depends on file "secureString_secret.txt" which can be created by first running:
# echo 'YOUR_ORG_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:Secret@Bitwarden#99 > secureString_secret.txt
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# openssl is required in $PATH https://www.openssl.org/

organization_id="<ORG ID>" # Set your Org ID (ex: "1de1001b-d10f-1001-01dd-b10e010011f1")
parentCollection="<PARENT COLLECTION NAME>" # Set your Parent Collection name (ex: "Personal Collections")

cloud_flag=1 # Self-hosted Bitwarden or Cloud?
if [ $cloud_flag == 1 ]; then
    api_url="https://api.bitwarden.com"
    identity_url="https://identity.bitwarden.com"
else
    api_url="https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    identity_url="https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
fi

# Set up CLI and API auth
org_client_secret_key=$(cat secureString_secret.txt \
	| openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600001 \
	 -salt -pass pass:Secret@Bitwarden#99)

password=$(cat secureString.txt \
	| openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600001 \
	 -salt -pass pass:Secret@Bitwarden#99)

session_key="$(printf $password | bw unlock --raw)"
export BW_SESSION="$session_key"

IFS=$'\n'
bearer_token="$(curl -sX POST $identity_url/connect/token \
	-H 'Content-Type: application/x-www-form-urlencoded' \
	-d 'grant_type=client_credentials&scope=api.organization&client_id='organization.$organization_id'&client_secret='$org_client_secret_key'' \
	| cut -d '"' -f4)"

all_collections="$(bw list org-collections --organizationid $organization_id)"
collection_template="$(bw get template org-collection)"

allorgmembers="$(curl -sX GET $api_url/public/members \
	-H 'Content-Type: application/json' \
	-H 'Authorization: Bearer '$bearer_token'' \
	| jq 'del(.object)')"

org_members="$(jq -r '.data[] | select(.status == 2) | .email' <<< "$allorgmembers")"

#check if Parent collection exists
parentExists=0
listCollections=$(bw list org-collections --organizationid $organization_id | jq -r '.[].name')
IFS=$'\n' read -r -d '' -a collections <<< "$listCollections"
for collection in "${collections[@]}"; do
    if [[ "$collection" == $parentCollection ]]; then
        parentExists=1
		break
    fi
done

#create Parent Collection if it does not exist
if [ $parentExists == 0 ]; then
	echo "Parent Collection does not exist...creating $parentCollection"
	bw get template org-collection | jq --arg n "$parentCollection" --arg c "$organization_id" '.name=$n | .organizationId=$c | del(.groups) | del(.users)' | bw encode | bw create org-collection --organizationid $organization_id
fi

#Loop over all users and create a collection with their e-mail
for member in ${org_members[@]}; do

    if (echo $all_collections | jq -r '.[].name' | grep -x "Personal Collections/$member" > /dev/null); then
    echo "$member already has a Collection, skipping"

else

    memberid="$(jq -r -c --arg n "$member" '.data[] | select(.email==$n) | .id' <<< "$allorgmembers")"

    collectionid="$(echo $collection_template \
	| jq -c --arg n "$member" --arg c "$organization_id" --arg m "$memberid" \
	'.name="Personal Collections/" + $n | .organizationId=$c | del(.groups[1]) | del(.groups[0]) | del(.users[1]) | .users[0].id=$m | .users[0].manage=true' \
	| bw encode \
	| bw create org-collection --organizationid $organization_id \
	| jq -r '.id')"

    echo "Created Collection for $member"
fi

done
