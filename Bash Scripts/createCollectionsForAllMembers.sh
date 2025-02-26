#!/bin/bash
#
# This script automates the process of creating Bitwarden collections for
# all active members of a Bitwarden organization using the CLI.
#
# Usage: ./create_collections.sh <organization_id> <secure_password_file> <secure_secret_file> <parent_collection_name>
#
# Setup Instructions:
# 1. Configure Bitwarden CLI to use the correct server:
#    $ bw config server https://vault.bitwarden.eu
#
# 2. Log in to Bitwarden CLI:
#    $ bw login
#
# 3. Set and generate a random secure password for the environment variable 'BITWARDEN_PASS':
#    $ export BITWARDEN_PASS=$(openssl rand -base64 32)
#
# 4. Encrypt your Bitwarden master password and organization secret using the generated BITWARDEN_PASS:
#    $ echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:$BITWARDEN_PASS > secureString.txt
#    $ echo 'YOUR_ORG_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:$BITWARDEN_PASS > secureString_secret.txt
#


# Function to display help message
show_help() {
  echo "Usage: $0 <organization_id> <secure_password_file> <secure_secret_file> <parent_collection_name>"
  echo "\nThis script creates Bitwarden collections for all active members of a Bitwarden organization using the CLI."
  exit 0
}

# Check if parameters are provided
if [[ $# -lt 4 ]]; then
  show_help
fi

# Parameters
organization_id=$1
secure_password_file=$2
secure_secret_file=$3
parent_collection_name=$4

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

# Ensure BITWARDEN_PASS is set
if [[ -z "$BITWARDEN_PASS" ]]; then
  handle_error "BITWARDEN_PASS environment variable is not set. Exiting."
fi

# Decrypt secrets
org_client_secret_key=$(decrypt_secret "$secure_secret_file")
password=$(decrypt_secret "$secure_password_file")

# Unlock Bitwarden CLI session if necessary
if ! bw status | grep -q "unlocked"; then
  log "ℹ️  Unlocking Bitwarden CLI..."
  session_key=$(printf "%s" "$password" | bw unlock --raw 2>/dev/null) || handle_error "Failed to unlock Bitwarden CLI"
else
  session_key=$(bw unlock --raw)
  log "ℹ️  Bitwarden CLI already unlocked."
fi

# Ensure parent collection exists
log "📡 Checking if parent collection '$parent_collection_name' exists..."
if ! bw --session "$session_key" list org-collections --organizationid "$organization_id" | jq -r '.[].name' | grep -qx "$parent_collection_name"; then
  log "📂 Creating parent collection: $parent_collection_name"
  parent_collection_id=$(bw --session "$session_key" get template org-collection \
    | jq -c --arg n "$parent_collection_name" --arg c "$organization_id" '.name=$n | .organizationId=$c' | bw encode \
    | bw --session "$session_key" create org-collection --organizationid "$organization_id" | jq -r '.id') || handle_error "Failed to create parent collection"
  log "✅ Created parent collection '$parent_collection_name'"
else
  log "⏭️  Parent collection '$parent_collection_name' already exists, skipping."
fi

# Fetch organization members
log "📡 Retrieving organization members..."
org_members=$(bw --session "$session_key" list org-members --organizationid "$organization_id" | jq -c '.[] | select(.status == 2) | {id: .id, name: (.name // .email), email: .email}')

if [[ -z "$org_members" ]]; then
  handle_error "Organization members API returned an empty response. Check authentication and permissions."
fi

# Loop through each member and create a collection if none exists
echo "$org_members" | jq -c '.' | while read -r member; do
  member_id=$(echo "$member" | jq -r '.id')
  member_name=$(echo "$member" | jq -r '.name // .email')

  # If no name, extract the email prefix before '@' and remove Bitwarden-specific suffixes
  member_name=$(echo "$member_name" | sed 's/#EXT#.*//; s/@.*//')

  log "ℹ️  Processing member: $member_name"

  collection_name="$parent_collection_name/$member_name"

  # Check if collection already exists
  if bw --session "$session_key" list org-collections --organizationid "$organization_id" | jq -r '.[].name' | grep -qx "$collection_name"; then
    log "⏭️  Collection '$collection_name' already exists, skipping."
  else
    log "📂 Creating collection: $collection_name"
    
    collection_id=$(bw --session "$session_key" get template org-collection \
      | jq -c --arg n "$collection_name" --arg c "$organization_id" '.name=$n | .organizationId=$c' | bw encode \
      | bw --session "$session_key" create org-collection --organizationid "$organization_id" | jq -r '.id') || handle_error "Failed to create collection for $member_name"
    
    log "✅ Created Collection '$collection_name' for member '$member_name'."
  fi
done
