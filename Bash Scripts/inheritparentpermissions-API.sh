#!/bin/bash
# Depends on file "secureString.txt" which can be created as an encrypted file by replacing all references in this script to:
# replacewithyoursupersecretstring
# With your own encryption phrase, and then running:
# echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:replacewithyoursupersecretstring > secureString.txt
# echo 'ORG API KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:replacewithyoursupersecretstring > secureSecretString.txt
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# openssl is required in $PATH https://www.openssl.org/
# Usage: ./inheritparentpermissions-API.sh ["Parent Collection Name"]
# If parent name is provided, only processes that specific parent collection

organization_id="REPLACE_WITH_YOUR_ORG_ID" # Set your Org ID
org_client_id="organization.$organization_id" # Auto-generated from organization_id
BW_IDENTITY_HOST="https://identity.bitwarden.com"
BW_API_HOST="https://api.bitwarden.com"
debug=0

# Optional parameter: specific parent collection name
specific_parent="$1"

# org_client_secret will be read from secureSecretString.txt

# Perform CLI auth

password=$(cat secureString.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600001 \
 -salt -pass pass:replacewithyoursupersecretstring)

session_key="$(printf $password | bw unlock --raw)"
export BW_SESSION="$session_key"

# Read client secret from secureSecretString.txt
org_client_secret=$(cat secureSecretString.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600001 \
 -salt -pass pass:replacewithyoursupersecretstring)

# Get API access token
api_token=$(curl -s -X POST "$BW_IDENTITY_HOST/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=$org_client_id" \
  -d "client_secret=$org_client_secret" \
  -d "scope=api.organization" | jq -r '.access_token')

if [ "$api_token" = "null" ] || [ -z "$api_token" ]; then
    echo "Failed to get API token. Please check your org_client_id and org_client_secret."
    exit 1
fi

# Get all groups with their collection permissions via API
groups_data=$(curl -s -X GET "$BW_API_HOST/public/groups" \
  -H "Authorization: Bearer $api_token" \
  -H "Content-Type: application/json")

if [ $? -ne 0 ]; then
    echo "Failed to fetch groups from API. Falling back to CLI method."
    groups_data=""
fi

# Transform groups data to be searchable by collection ID
# This creates a mapping of collection ID -> array of group permissions
if [ -n "$groups_data" ]; then
    collections_data=$(echo "$groups_data" | jq -c '
        .data | map(
            . as $group | 
            .collections | map(
                . + {groupId: $group.id, groupName: $group.name}
            )
        ) | flatten | group_by(.id) | map({
            id: .[0].id,
            groups: map({
                id: .groupId,
                name: .groupName,
                readOnly: .readOnly,
                hidePasswords: .hidePasswords,
                manage: .manage
            })
        })
    ')
    
    if [ "$collections_data" = "null" ] || [ -z "$collections_data" ]; then
        echo "Failed to transform groups data. Falling back to CLI method."
        collections_data=""
    else
        echo "Successfully transformed groups data for API lookup"
		if [ "$debug" -eq 1 ]; then
			echo $collections_data
		fi
    fi
fi
# Build a list of parents

parentcollections=$(bw list org-collections --organizationid $organization_id | jq -r '.[].name' | grep \/ | uniq | cut -f1 -d \/ | uniq)

# Collection names can contain spaces, we don't want the loop separating on those
IFS=$'\n'
for parent in $parentcollections; do

    # Skip this parent if a specific parent was provided and this isn't it
    if [ -n "$specific_parent" ] && [ "$parent" != "$specific_parent" ]; then
        continue
    fi

    # Get the Parent's Collection ID
    parentid=$(bw list org-collections --organizationid $organization_id | jq --arg p "$parent" -r '.[] | select(.name == $p) | .id')
	if [ -n "$parentid" ]; then
		echo "I found parent $parent"

		# Try to get permissions from API first, fall back to CLI if API fails
		if [ -n "$collections_data" ]; then
			parentspermissions=$(echo "$collections_data" | jq --arg parentid "$parentid" -c '.[] | select(.id == $parentid) | .groups')
			if [ "$parentspermissions" = "null" ] || [ -z "$parentspermissions" ]; then
				echo "Parent collection not found in API response, using CLI fallback"
				parentspermissions=$(bw get org-collection $parentid --organizationid $organization_id | jq -c '.groups')
			else
				echo "Retrieved permissions from API for parent collection $parent"
			fi
		else
			echo "Using CLI method for parent collection $parent"
			parentspermissions=$(bw get org-collection $parentid --organizationid $organization_id | jq -c '.groups')
		fi
	
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
				
				# Try to get child collection data from API first, fall back to CLI if API fails
				if [ -n "$collections_data" ]; then
					child_collection_data=$(echo "$collections_data" | jq --arg childid "$childid" -c '.[] | select(.id == $childid)')
					if [ "$child_collection_data" = "null" ] || [ -z "$child_collection_data" ]; then
						echo "Child collection not found in API response, using CLI fallback"
						child_collection_data=$(bw get org-collection $childid --organizationid $organization_id)
					else
						echo "Retrieved child collection data from API for $child"
					fi
				else
					echo "Using CLI method for child collection $child"
					child_collection_data=$(bw get org-collection $childid --organizationid $organization_id)
				fi
				if [ "$debug" -eq 1 ]; then
					echo "Child collection data:"
					echo $child_collection_data
					echo "Parents permissions:"
					echo $parentspermissions
				fi

				# Extract child groups
				child_groups=$(echo "$child_collection_data" | jq '.groups')

				# Merge parent and child groups, child takes precedence
				merged_groups=$(jq -n --argjson parent "$parentspermissions" --argjson child "$child_groups" '
				  ($child + $parent)
				  | group_by(.id)
				  | map(.[-1])
				')

				# Prepare the payload for the API call
				update_payload=$(jq -n --argjson groups "$merged_groups" '{groups: $groups}')

				# Use API call to update the collection's groups
				curl -s -o /dev/null -X PUT "$BW_API_HOST/public/collections/$childid" \
				    -H "Authorization: Bearer $api_token" \
				    -H "Content-Type: application/json" \
				    -d "$update_payload"

			done
			# Reset IFS to its default value
			unset IFS

			childiters=$(($childiters-1))
		done
	
	fi

done
