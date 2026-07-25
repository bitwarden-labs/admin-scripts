#!/bin/bash
#
# This script automates the process of creating Bitwarden collections for
# all active members of a Bitwarden organization using the CLI.
#
# Usage: ./createCollectionsForAllMembers.sh <organization_id> <secure_password_file> <parent_collection_name>
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
# 4. Encrypt your Bitwarden master password using the generated BITWARDEN_PASS:
#    $ echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:$BITWARDEN_PASS > secureString.txt
#

set -e  # Exit on error

# Usage Information
show_help() {
  echo "Usage: $0 <organization_id> <secure_password_file> <parent_collection_name>"
  exit 0
}

# Check arguments
if [[ $# -lt 3 ]]; then
  show_help
fi

# Parameters
organization_id=$1
secure_password_file=$2
parent_collection_name=$3
num_iterations=600001
log_file="bitwarden_script.log"

# Logging function
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" | tee -a "$log_file"
}

handle_error() {
  log "Error: $1"
  exit 1
}

decrypt_secret() {
  local file=$1
  openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter $num_iterations -salt \
    -pass pass:"$BITWARDEN_PASS" < "$file" || handle_error "Failed to decrypt $file"
}

# Check dependencies
for cmd in jq bw openssl; do
  command -v "$cmd" > /dev/null 2>&1 || handle_error "$cmd is required but not installed."
done

# Ensure BITWARDEN_PASS is set
if [[ -z "$BITWARDEN_PASS" ]]; then
  handle_error "BITWARDEN_PASS environment variable is not set. Exiting."
fi

# Decrypt Credentials
password=$(decrypt_secret "$secure_password_file")

# Unlock Bitwarden CLI session (always supply password; bw unlock is idempotent)
log "Unlocking Bitwarden CLI..."
session_key=$(printf "%s" "$password" | bw unlock --raw 2>/dev/null) || handle_error "Failed to unlock Bitwarden CLI"

# Sync to ensure CLI cache is up to date before fetching members/collections
log "Syncing Bitwarden vault..."
bw --session "$session_key" sync > /dev/null 2>&1 || handle_error "Failed to sync Bitwarden vault"

# Check if Parent Collection Exists & Get ID
log "Checking if parent collection '$parent_collection_name' exists..."
parent_collection_id=$(bw --session "$session_key" list org-collections --organizationid "$organization_id" | jq -r ".[] | select(.name == \"$parent_collection_name\") | .id")

if [[ -z "$parent_collection_id" ]]; then
  log "Creating parent collection: $parent_collection_name"
  parent_collection_id=$(bw --session "$session_key" get template org-collection \
    | jq -c --arg n "$parent_collection_name" --arg c "$organization_id" '.name=$n | .organizationId=$c' \
    | bw encode \
    | bw --session "$session_key" create org-collection --organizationid "$organization_id" \
    | jq -r '.id') || handle_error "Failed to create parent collection"
  log "Created parent collection '$parent_collection_name'"
else
  log "Parent collection '$parent_collection_name' already exists, using ID: $parent_collection_id"
fi

# Fetch organization members
log "Retrieving organization members..."
org_members=$(bw --session "$session_key" list org-members --organizationid "$organization_id" | jq -c '.[] | select(.status == 2) | {id: .id, name: (.name // .email), email: .email}')

if [[ -z "$org_members" ]]; then
  handle_error "No active organization members found."
fi

# Fetch ALL existing collections once before the loop
log "Fetching existing collections (one-time)..."
all_collections=$(bw --session "$session_key" list org-collections --organizationid "$organization_id") \
  || handle_error "Failed to fetch collections list"

created=0
skipped=0

# Process each member sequentially using process substitution so the loop runs
# in the current shell
while read -r member; do
  member_id=$(echo "$member" | jq -r '.id')
  member_name=$(echo "$member" | jq -r '.name // .email')

  # If name contains guest suffixes, strip them; fall back to email prefix
  member_name=$(echo "$member_name" | sed 's/#EXT#.*//; s/@.*//')

  # Trim long names (50 char limit)
  member_name=$(echo "$member_name" | cut -c1-50)

  # Guard against a completely empty name after transformations
  [[ -z "$member_name" ]] && member_name="$member_id"

  log "Processing member: $member_name"

  collection_name="$parent_collection_name/$member_name"

  # In-memory check against the pre-fetched list
  existing_collection_id=$(echo "$all_collections" | jq -r ".[] | select(.name == \"$collection_name\") | .id")

  if [[ -n "$existing_collection_id" ]]; then
    log "Collection '$collection_name' already exists (ID: $existing_collection_id). Skipping member '$member_name'."
    ((skipped++))
    continue
  fi

  log "Creating collection: $collection_name"
  collection_id=$(bw --session "$session_key" get template org-collection \
    | jq -c --arg n "$collection_name" --arg c "$organization_id" --arg uid "$member_id" \
        '.name=$n | .organizationId=$c | .externalId=$uid | .users=[{"id":$uid, "readOnly":false, "hidePasswords":false, "manage":true}]' \
    | bw encode \
    | bw --session "$session_key" create org-collection --organizationid "$organization_id" \
    | jq -r '.id') || handle_error "Failed to create collection for $member_name"

  log "Created Collection '$collection_name' for member '$member_name'."
  ((created++))

done < <(echo "$org_members" | jq -c '.')

log "Collection processing complete. Created: $created | Skipped (already existed): $skipped."