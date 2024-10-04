#!/bin/bash

# Dependencies:
#
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
organization_id=""  # Set your Org ID
api_url="https://api.bitwarden.eu"                      # Set your API URL
identity_url="https://identity.bitwarden.eu"            # Set your Identity URL

# Secret files and settings
num_iterations=600001
secure_password_file="secureString.txt"                 # Local encrypted master password file
secure_secret_file="secureString_secret.txt"            # Local encrypted org client secret file

# Function to handle errors
handle_error() {
  echo "❌ Error: $1"
  exit 1
}

# Retrieve and decrypt secret
decrypt_secret() {
  local file=$1
  openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter $num_iterations -salt \
    -pass pass:Secret@Bitwarden#99 < "$file" || handle_error "Failed to decrypt $file"
}

# Retrieve and decrypt the org secret key and master password
org_client_secret_key=$(decrypt_secret "$secure_secret_file")
password=$(decrypt_secret "$secure_password_file")

# Check if Bitwarden is already unlocked
if ! bw status | grep -q "unlocked"; then
  echo "ℹ️  Unlocking Bitwarden CLI..."
  session_key=$(printf "%s" "$password" | bw unlock --raw) || handle_error "Failed to unlock Bitwarden CLI"
else
  session_key=$(bw unlock --raw)
  echo "ℹ️ Bitwarden CLI already unlocked."
fi

# Obtain bearer token from the identity service
bearer_token=$(curl -sX POST "$identity_url/connect/token" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -d "grant_type=client_credentials&scope=api.organization&client_id=organization.$organization_id&client_secret=$org_client_secret_key" \
  | cut -d '"' -f4) || handle_error "Failed to obtain bearer token"

# Fetch organization members with status == 2 (active members)
org_members=$(curl -sX GET "$api_url/public/members" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $bearer_token" \
  | jq -r '.data[] | select(.status == 2) | .name') || handle_error "Failed to fetch organization members"

# Loop through each member and create a collection if none exists
IFS=$'\n'
for member in ${org_members[@]}; do
  echo "ℹ️ Processing member: $member"
  
  if bw --session "$session_key" list org-collections \
     --organizationid "$organization_id" | jq -r '.[].name' | grep -x "$member"; then
    echo "ℹ️ '$member' already has a Collection, skipping."
  else
    # Fetch all organization members data
    allorgmembers=$(curl -sX GET "$api_url/public/members" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $bearer_token" | jq 'del(.object)') || handle_error "Failed to fetch all members"

    # Get member ID
    memberid=$(echo "$allorgmembers" | jq -r -c --arg n "$member" \
      '.data[] | select(.name==$n) | .id') || handle_error "Failed to get member ID for $member"

    # Get original member body
    origmemberbody=$(curl -sX GET "$api_url/public/members/$memberid" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $bearer_token" | jq -r -c 'del(.object)') || handle_error "Failed to get member body for $memberid"

    # Create a new collection for the member
    collectionid=$(bw --session "$session_key" get template org-collection \
      | jq -c --arg n "$member" --arg c "$organization_id" \
      '.name=$n | .organizationId=$c | del(.groups[1])' | bw encode \
      | bw --session "$session_key" create org-collection \
      --organizationid "$organization_id" | jq -r '.id') || handle_error "Failed to create collection for $member"

    # Update member with the new collection
    newmemberbody=$(echo "$origmemberbody" | jq -r -c --arg newcol "$collectionid" \
      --arg i "$memberid" \
      '.collections += [{"id": $newcol, "readOnly": false, "hidePasswords": false, "manage": true}] | select(.id == $i)') || handle_error "Failed to update member body for $member"

    # Update the member with the new collection via the API
    curl -sX PUT "$api_url/public/members/$memberid" \
      -H 'Content-Type: application/json' \
      -H "Authorization: Bearer $bearer_token" \
      -d "$newmemberbody" >/dev/null || handle_error "Failed to update member via API for $member"

    echo "✅ Created Collection for '$member'."
  fi
done
