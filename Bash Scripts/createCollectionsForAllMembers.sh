#!/bin/bash
#
# Bitwarden Collection Creation (Sequential Execution)
#

set -e  # Exit on error

# Usage Information
show_help() {
  echo "Usage: $0 <organization_id> <secure_password_file> <secure_secret_file> <parent_collection_name>"
  exit 0
}

# Check arguments
if [[ $# -lt 4 ]]; then
  show_help
fi

# Parameters
organization_id=$1
secure_password_file=$2
secure_secret_file=$3
parent_collection_name=$4
num_iterations=600001
log_file="bitwarden_script.log"

# Logging function
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') $1" | tee -a "$log_file"
}

handle_error() {
  log "❌ Error: $1"
  exit 1
}

decrypt_secret() {
  local file=$1
  openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter $num_iterations -salt \
    -pass pass:"$BITWARDEN_PASS" < "$file" || handle_error "Failed to decrypt $file"
}

# Check dependencies
for cmd in jq curl bw openssl; do
  command -v "$cmd" >/dev/null 2>&1 || handle_error "$cmd is required but not installed."
done

# Ensure BITWARDEN_PASS is set
if [[ -z "$BITWARDEN_PASS" ]]; then
  handle_error "BITWARDEN_PASS environment variable is not set. Exiting."
fi

# Decrypt Credentials
org_client_secret_key=$(decrypt_secret "$secure_secret_file")
password=$(decrypt_secret "$secure_password_file")

# Unlock Bitwarden CLI session
if ! bw status | grep -q "unlocked"; then
  log "ℹ️  Unlocking Bitwarden CLI..."
  session_key=$(printf "%s" "$password" | bw unlock --raw 2>/dev/null) || handle_error "Failed to unlock Bitwarden CLI"
else
  session_key=$(bw unlock --raw)
  log "ℹ️  Bitwarden CLI already unlocked."
fi

# Check if Parent Collection Exists & Get ID
log "📡 Checking if parent collection '$parent_collection_name' exists..."
parent_collection_id=$(bw --session "$session_key" list org-collections --organizationid "$organization_id" | jq -r ".[] | select(.name == \"$parent_collection_name\") | .id")

if [[ -z "$parent_collection_id" ]]; then
  log "📂 Creating parent collection: $parent_collection_name"
  parent_collection_id=$(bw --session "$session_key" get template org-collection \
    | jq -c --arg n "$parent_collection_name" --arg c "$organization_id" '.name=$n | .organizationId=$c' \
    | bw encode \
    | bw --session "$session_key" create org-collection --organizationid "$organization_id" \
    | jq -r '.id') || handle_error "Failed to create parent collection"
  log "✅ Created parent collection '$parent_collection_name'"
else
  log "⏭️  Parent collection '$parent_collection_name' already exists, using ID: $parent_collection_id"
fi

# Fetch organization members
log "📡 Retrieving organization members..."
org_members=$(bw --session "$session_key" list org-members --organizationid "$organization_id" | jq -c '.[] | select(.status == 2) | {id: .id, name: (.name // .email), email: .email}')

if [[ -z "$org_members" ]]; then
  handle_error "No active organization members found."
fi

# Process each member **sequentially**
echo "$org_members" | jq -c '.' | while read -r member; do
  member_id=$(echo "$member" | jq -r '.id')
  member_name=$(echo "$member" | jq -r '.name // .email')

  # If name is empty, use email prefix
  member_name=$(echo "$member_name" | sed 's/#EXT#.*//; s/@.*//')

  # Trim long names (50 char limit)
  member_name=$(echo "$member_name" | cut -c1-50)

  log "ℹ️  Processing member: $member_name"

  collection_name="$parent_collection_name/$member_name"

  # Check if collection already exists
  existing_collection_id=$(bw --session "$session_key" list org-collections --organizationid "$organization_id" | jq -r ".[] | select(.name == \"$collection_name\") | .id")

  if [[ -z "$existing_collection_id" ]]; then
    log "📂 Creating collection: $collection_name"
    
    collection_id=$(bw --session "$session_key" get template org-collection \
      | jq -c --arg n "$collection_name" --arg c "$organization_id" --arg uid "$member_id" \
          '.name=$n | .organizationId=$c | .groups |= map(.readOnly=false | .hidePasswords=false | .manage=true) | .users=[{"id":$uid, "readOnly":false, "hidePasswords":false, "manage":true}]' \
      | bw encode \
      | bw --session "$session_key" create org-collection --organizationid "$organization_id" \
      | jq -r '.id') || handle_error "Failed to create collection for $member_name"
    
    log "✅ Created Collection '$collection_name' for member '$member_name'."
  else
    log "⏭️  Collection '$collection_name' already exists, skipping."
    collection_id=$existing_collection_id
  fi

  # Assign the user explicitly to the collection
  log "🔑 Assigning user '$member_name' (ID: $member_id) to collection '$collection_name'"

  # Fetch the current collection data
  collection_data=$(bw --session "$session_key" get org-collection "$collection_id" --organizationid "$organization_id") || handle_error "Failed to retrieve collection data for $collection_name"

  # Add the user to the 'users' array with correct permissions
  updated_collection=$(echo "$collection_data" | jq -c --arg uid "$member_id" \
    '.users += [{"id": $uid, "readOnly": false, "hidePasswords": false, "manage": true}]')

  # Update the collection with the new user assignment (suppress output)
  echo "$updated_collection" | bw encode \
    | bw --session "$session_key" edit org-collection "$collection_id" --organizationid "$organization_id" > /dev/null \
    || handle_error "Failed to assign user $member_name to collection $collection_name"

  log "✅ User '$member_name' assigned to collection '$collection_name'"

done

log "🎉 Collection creation and user assignment completed!"