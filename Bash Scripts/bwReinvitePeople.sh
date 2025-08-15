#!/bin/sh

# Check if all required parameters are passed
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <Bitwarden Vault URI> <Organization Client ID> <Organization Client Secret>"
  exit 1
fi

# Assign parameters to variables
vault_uri="$1"
org_client_id="$2"
org_client_secret="$3"

# Normalize vault_uri to lowercase and remove trailing slash
vault_uri=$(printf "%s" "$vault_uri" | tr '[:upper:]' '[:lower:]')
vault_uri="${vault_uri%/}"

# Determine identity and API URIs
case "$vault_uri" in
  "https://vault.bitwarden.com")
    identity_uri="https://identity.bitwarden.com"
    api_uri="https://api.bitwarden.com"
    ;;
  "https://vault.bitwarden.eu")
    identity_uri="https://identity.bitwarden.eu"
    api_uri="https://api.bitwarden.eu"
    ;;
  *)
    identity_uri="$vault_uri/identity"
    api_uri="$vault_uri/api"
    ;;
esac

# Request an access token
echo "Requesting access token..."
ACCESS_TOKEN=$(curl -s -X POST "$identity_uri/connect/token" \
-H "Content-Type: application/x-www-form-urlencoded" \
-d "grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$org_client_secret" | jq -r '.access_token')

# Check if the access token was retrieved successfully
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" = "null" ]; then
  echo "Error: Failed to retrieve access token. Please check your credentials and try again."
  exit 1
fi

echo "Access token retrieved successfully."

# Retrieve organization members with status 0 (invited but not accepted)
echo "Retrieving members with pending invitations..."
org_members=$(curl -s -X GET "$api_uri/public/members/" \
-H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.data[] | select(.status == 0) | .id')

# Check if any members need to be re-invited
if [ -z "$org_members" ]; then
  echo "No members found with status 0 (pending invitation)."
  exit 0
fi

echo "Members found. Attempting to re-invite..."

# Loop through each member ID and re-invite them
for member_id in $org_members; do
  echo "Re-inviting member: $member_id"
  
  response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$api_uri/public/members/$member_id/reinvite" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json")
  
  if [ "$response" -eq 200 ]; then
    echo "Successfully re-invited member: $member_id"
  else
    echo "Failed to re-invite member: $member_id (HTTP Status: $response)"
  fi
done

echo "Re-invitation process completed."
