#!/bin/bash
#
# This script automates the process of creating Bitwarden collections for
# all active members of a Bitwarden organization.
#
# Usage: ./create_collections.sh <organization_id> <secure_password_file> <secure_secret_file>
#
# If no parameters are passed, a brief help message will be displayed.
#

# Function to display help message
show_help() {
  echo "Usage: $0 <organization_id> <secure_password_file> <secure_secret_file>"
  echo
  echo "This script automates the creation of Bitwarden collections for all active members of a Bitwarden organization."
  echo
  echo "Parameters:"
  echo "  organization_id       The ID of your Bitwarden organization."
  echo "  secure_password_file  The encrypted master password file (secureString.txt)."
  echo "  secure_secret_file    The encrypted organization client secret file (secureString_secret.txt)."
  echo
  echo "Important: You must be logged in to Bitwarden CLI before running this script."
  echo "           Run 'bw login' to log in if you haven't already."
  echo
  echo "### Setup Instructions ###"
  echo
  echo "1. Configure Bitwarden CLI to use the correct server:"
  echo "   $ bw config server https://vault.bitwarden.eu"
  echo
  echo "2. Log in to Bitwarden CLI:"
  echo "   $ bw login"
  echo
  echo "3. Set and generate a random secure password for the environment variable 'BITWARDEN_PASS':"
  echo "   $ export BITWARDEN_PASS=\$(openssl rand -base64 32)"
  echo
  echo "4. Encrypt your Bitwarden master password and organization secret using the generated BITWARDEN_PASS:"
  echo "   $ echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:\$BITWARDEN_PASS > secureString.txt"
  echo "   $ echo 'YOUR_ORG_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:\$BITWARDEN_PASS > secureString_secret.txt"
  echo
  echo "5. Run the script to create collections for all active organization members:"
  echo "   $ ./create_collections.sh 9d3210e3-385c-4c76-ad72-b1f5013a8cc2 secureString.txt secureString_secret.txt"
  echo
  exit 0
}

# Check if parameters are provided
if [[ $# -lt 3 ]]; then
  show_help
fi

# Parameters
organization_id=$1
secure_password_file=$2
secure_secret_file=$3

# Configuration
num_iterations=600001

# Logging function
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1"
}

# Error handling
handle_error() {
  log "❌ Error: $1"
  exit 1
}

# Decrypt secret
decrypt_secret() {
  local file=$1
  openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter $num_iterations -salt \
    -pass pass:"$BITWARDEN_PASS" < "$file" || handle_error "Failed to decrypt $file"
}

# Check for dependencies
check_dependency() {
  command -v $1 >/dev/null 2>&1 || handle_error "$1 is required but not installed."
}

check_dependency jq
check_dependency curl
check_dependency bw
check_dependency openssl

# Decrypt secrets
org_client_secret_key=$(decrypt_secret "$secure_secret_file")
password=$(decrypt_secret "$secure_password_file")

# Function to perform API requests with retry logic
api_request() {
  local method=$1
  local url=$2
  local headers=$3
  local body=$4
  local retries=3
  local count=0
  local response

  until [ $count -ge $retries ]; do
    if [ -z "$body" ]; then
      response=$(curl -s -X "$method" "$url" -H "$headers")
    else
      response=$(curl -s -X "$method" "$url" -H "$headers" -d "$body")
    fi

    if [[ -n "$response" ]]; then
      echo "$response"
      return 0
    else
      count=$((count + 1))
      log "Retrying API request... ($count/$retries)"
      sleep 2
    fi
  done

  handle_error "API request to $url failed after $retries attempts."
}

# Unlock Bitwarden CLI session if necessary
if ! bw status | grep -q "unlocked"; then
  log "ℹ️  Unlocking Bitwarden CLI..."
  session_key=$(printf "%s" "$password" | bw unlock --raw 2>/dev/null) || handle_error "Failed to unlock Bitwarden CLI"
  echo "Session Key: $session_key"  # Debugging session key
  server_url=$(bw status | jq -r '.serverUrl')
  echo "Server URL: $server_url"  # Debugging server URL
  api_url=$(echo "$server_url" | sed 's/vault/api/')
  identity_url=$(echo "$server_url" | sed 's/vault/identity/')
else
  session_key=$(bw unlock --raw)
  log "ℹ️  Bitwarden CLI already unlocked."
fi

# Obtain bearer token from the identity service
bearer_token=$(api_request "POST" "$identity_url/connect/token" \
  "Content-Type: application/x-www-form-urlencoded" \
  "grant_type=client_credentials&scope=api.organization&client_id=organization.$organization_id&client_secret=$org_client_secret_key" \
  | cut -d '"' -f4) || handle_error "Failed to obtain bearer token"

echo "Bearer Token: $bearer_token"  # Debugging bearer token

# Fetch organization members with status == 2 (active)
org_members=$(api_request "GET" "$api_url/public/members" \
  "Content-Type: application/json; Authorization: Bearer $bearer_token")

echo "API Response: $org_members"  # Debugging API response for members

org_members=$(echo "$org_members" | jq -r '.data[] | select(.status == 2) | .name') || handle_error "Failed to fetch organization members"

# Loop through each member and create a collection if none exists
IFS=$'\n'
for member in ${org_members[@]}; do
  log "ℹ️  Processing member: $member"

  if bw --session "$session_key" list org-collections \
    --organizationid "$organization_id" | jq -r '.[].name' | grep -qx "$member"; then
    log "⏭️  '$member' already has a Collection, skipping."
  else
    # Fetch all organization members data
    allorgmembers=$(api_request "GET" "$api_url/public/members" \
      "Content-Type: application/json; Authorization: Bearer $bearer_token" | jq 'del(.object)') || handle_error "Failed to fetch all members"

    # Get member ID
    memberid=$(echo "$allorgmembers" | jq -r -c --arg n "$member" \
      '.data[] | select(.name==$n) | .id') || handle_error "Failed to get member ID for $member"

    # Get original member body
    origmemberbody=$(api_request "GET" "$api_url/public/members/$memberid" \
      "Content-Type: application/json; Authorization: Bearer $bearer_token" | jq -r -c 'del(.object)') || handle_error "Failed to get member body for $memberid"

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
    api_request "PUT" "$api_url/public/members/$memberid" \
      "Content-Type: application/json; Authorization: Bearer $bearer_token" \
      "$newmemberbody" >/dev/null || handle_error "Failed to update member via API for $member"

    log "✅ Created Collection for '$member'."
  fi
done