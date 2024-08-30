#!/bin/bash
# Depends on file "secureString.txt" which can be created as an encrypted file by replacing all references in this script to:
# replacewithyoursupersecretstring
# With your own encryption phrase, and then running:
# echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:replacewithyoursupersecretstring > secureString.txt
# Assumes a list of Collections in a file named collections.csv in the current directory
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# openssl is required in $PATH https://www.openssl.org/

organization_id="YOUR-ORGANIZATION-ID" # Set your Org ID

# Perform CLI auth

password=$(cat secureString.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600001 \
 -salt -pass pass:replacewithyoursupersecretstring)

session_key="$(printf $password | bw unlock --raw)"

# Check for the Collection list and create any missing Collections in a loop

IFS=$'\n'
for collectionname in $(cat collections.csv); do

# Check if the Group already exists

existingcollection=$(bw --session "$session_key" list org-collections --organizationid $organization_id | jq -r '.[].name' | grep -x "$collectionname")

if [[ $existingcollection == $collectionname ]]; then

echo "$collectionname already exists, skipping"

else

bw --session "$session_key" get template org-collection | jq --arg n "$collectionname" --arg c "$organization_id" '.name=$n | .organizationId=$c | del(.groups)' | bw encode | bw --quiet --session "$session_key" create org-collection --organizationid $organization_id
echo "Created Collection for $collectionname"

fi

done
