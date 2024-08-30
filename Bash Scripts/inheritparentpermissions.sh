#!/bin/bash
# Depends on file "secureString.txt" which can be created as an encrypted file by replacing all references in this script to:
# replacewithyoursupersecretstring
# With your own encryption phrase, and then running:
# echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:replacewithyoursupersecretstring > secureString.txt
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# openssl is required in $PATH https://www.openssl.org/

organization_id="Change-With-Your-Org-ID" # Set your Org ID

# Perform CLI auth

password=$(cat secureString.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600001 \
 -salt -pass pass:replacewithyoursupersecretstring)

session_key="$(printf $password | bw unlock --raw)"
export BW_SESSION="$session_key"

# Build a list of parents

parentcollections=$(bw list org-collections --organizationid $organization_id | jq -r '.[].name' | grep \/ | uniq | cut -f1 -d \/ | uniq)

# Collection names can contain spaces, we don't want the loop separating on those
IFS=$'\n'
for parent in $parentcollections; do

    echo "I found parent $parent"
    # Get the Parent's Collection ID
    parentid=$(bw list org-collections --organizationid $organization_id | jq --arg p "$parent" -r '.[] | select(.name == $p) | .id')

	if [ -n "$parentid" ]; then

		parentspermissions=$(bw get org-collection $parentid --organizationid $organization_id | jq -c '.groups')
	
		# How deep does the nesting go?
	
		childiters=$(bw list org-collections --organizationid $organization_id | jq -r '.[].name' | grep \/ | grep -F "$parent" | awk '{print gsub(/\//,"")}' | sort -rn | head -n1)

		# Loop through each layer of nesting
		while [ "$childiters" -ge 1 ]; do

			# Get a list of Collections under this Parent
			IFS=$'\n' read -r -d '' -a childcollections < <(bw list org-collections --organizationid $organization_id | jq -r '.[].name' | grep \/ | grep -F "$parent" | cut -f$((childiters+1)) -d \/ | uniq && printf '\0')

			# Loop through each Child
			for child in "${childcollections[@]}"; do

				echo "I found $child in $parent"
				childid=$(bw list org-collections --organizationid $organization_id | jq --arg p "$parent" '.[] | select(.name | contains($p)) | {name, id}' | jq --arg c "$child" -r '. | select(.name | contains($c)) | .id' | uniq | head -n1)
				bw get org-collection $childid --organizationid $organization_id | jq --argjson g "$parentspermissions" -c '.groups=$g' | bw encode | bw --quiet   edit org-collection $childid --organizationid $organization_id

			done
			# Reset IFS to its default value
			unset IFS

			childiters=$(($childiters-1))
		done
	
	fi

done

bw logout
