#!/bin/bash

# Dependencies:
# - secureString.txt (Master password encrypted using OpenSSL):
#   echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:Secret@Bitwarden#99 > secureString.txt
#
# - secureString_secret.txt (Org secret key encrypted using OpenSSL):
#   echo 'YOUR_ORG_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:Secret@Bitwarden#99 > secureString_secret.txt
#
# - curl, jq, bw, and openssl are required in $PATH
#   jq: https://stedolan.github.io/jq/download/
#   bw: https://bitwarden.com/help/cli/
#   openssl: https://www.openssl.org/

# Configuration
organization_id="12345678-1234-1234-1234-123456789012"  # Set your Org ID
api_url="https://api.bitwarden.eu"                      # Set your API URL
identity_url="https://identity.bitwarden.eu"            # Set your Identity URL

# Secret files
secure_password_file="secureString.txt"                 # Local encrypted master password file
secure_secret_file="secureString_secret.txt"            # Local encrypted org client secret file

# Retrieve and decrypt the org secret key and master password
org_client_secret_key=$(cat "$secure_secret_file" | openssl enc -aes-256-cbc \
  -md sha512 -a -d -pbkdf2 -iter 600001 -salt -pass pass:Secret@Bitwarden#99)

password=$(cat "$secure_password_file" | openssl enc -aes-256-cbc -md sha512 \
  -a -d -pbkdf2 -iter 600001 -salt -pass pass:Secret@Bitwarden#99)

# Unlock Bitwarden CLI and obtain session key
session_key=$(printf "%s" "$password" | bw unlock --raw)

# Obtain bearer token from the identity service
bearer_token=$(curl -sX POST "$identity_url/connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials&scope=api.organization&client_id=organization.$organization_id&client_secret=$org_client_secret_key" \
  | cut -d '"' -f4)

# Fetch organization members with status == 2 (active members)
org_members=$(curl -sX GET "$api_url/public/members" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $bearer_token" \
  | jq -r '.data[] | select(.status == 2) | .name')

# Loop through each member and create a collection if none exists
IFS=$'\n'
for member in ${org_members[@]}; do
  if bw --session "$session_key" list org-collections \
     --organizationid "$organization_id" | jq -r '.[].name' | grep -x "$member"; then
    echo "ℹ️ '$member' already has a Collection, skipping."
  else
    # Fetch all organization members data
    allorgmembers=$(curl -sX GET "$api_url/public/members" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $bearer_token" | jq 'del(.object)')

    # Get member ID and original member body
    memberid=$(echo "$allorgmembers" | jq -r -c --arg n "$member" \
      '.data[] | select(.name==$n) | .id')

    origmemberbody=$(curl -sX GET "$api_url/public/members/$memberid" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $bearer_token" | jq -r -c 'del(.object)')

    # Create a new collection for the member
    collectionid=$(bw --session "$session_key" get template org-collection \
      | jq -c --arg n "$member" --arg c "$organization_id" \
      '.name=$n | .organizationId=$c | del(.groups[1])' | bw encode \
      | bw --session "$session_key" create org-collection \
      --organizationid "$organization_id" | jq -r '.id')

    # Update member with the new collection
    newmemberbody=$(echo "$origmemberbody" | jq -r -c --arg newcol "$collectionid" \
      --arg i "$memberid" \
      '.collections += [{"id": $newcol, "readOnly": false, "hidePasswords": false, "manage": true}] | select(.id == $i)')

    # Update the member with the new collection via the API
    curl -sX PUT "$api_url/public/members/$memberid" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $bearer_token" \
      -d "$newmemberbody" >/dev/null

    echo "✅ Created Collection for '$member'."
  fi
done
