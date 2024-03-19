#!/bin/bash
# ----------------------------------------------------------------------------------
# Script Name: bw-list-collections-by-group.sh
# Description: This script lists Bitwarden collections by group using the Bitwarden CLI, `jq`, and `curl`.
#
# Prerequisites & Usage:
#
# Step 1: Login into Bitwarden CLI and export your session key:
#         bw login
#         # Follow login prompts.
#         export BW_SESSION="$(bw unlock --raw)"
#         # Enter your master password and copy the output session key.
#
# Step 2: Export your organization ID and client secret with your actual data:
#         export BW_ORG_ID="your_organization_id_here"
#         export BW_ORG_CLIENT_SECRET="your_client_secret_here"
#
# Step 3: Ensure `bw` (Bitwarden CLI), `jq` (JSON processor), and `curl` are installed on your system.
#         # You can typically install these tools with your package manager, for example:
#         sudo apt-get install jq curl
#         # For bw, follow the official Bitwarden CLI installation guide.
#
# Step 4: Execute the script:
#         ./bw-list-collections-by-group.sh
#
# Note: This script assumes you have already installed and configured the necessary tools
#       and exported the required environment variables.
# ----------------------------------------------------------------------------------

check_command() {
    command -v $1 >/dev/null 2>&1 || { echo >&2 "$1 is required but not installed. Aborting."; exit 1; }
}

check_env_var() {
    if [ -z "$(eval echo \$$1)" ]; then
        echo "Environment variable $1 is not set. Please set it to proceed."
        exit 1
    fi
}

# Check if bw, jq, curl are available on the system
check_command bw
check_command jq
check_command curl

# # Check if BW_SESSION, BW_ORG_ID, BW_ORG_CLIENT_SECRET are set
check_env_var BW_SESSION
check_env_var BW_ORG_ID
check_env_var BW_ORG_CLIENT_SECRET

api_url="https://api.bitwarden.com"
identity_url="https://identity.bitwarden.com"
org_client_id="organization.$BW_ORG_ID"
body="grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$BW_ORG_CLIENT_SECRET"
bearer_token=$(curl -s -X POST $identity_url/connect/token -d $body | jq -r '.access_token')

# Setup headers for API requests
auth_header="Authorization: Bearer $bearer_token"
accept_header="Accept: application/json"
content_type_header="Content-Type: application/json"

# Fetch list of Groups
org_groups=$(curl -s -H "$auth_header" -H "$accept_header" -H "$content_type_header" -X GET "$api_url/public/groups")
group_values=$(echo $org_groups | jq -c '.data[] | {name, id}')

# Fetch list of Collections
org_collections=$(curl -s -H "$auth_header" -H "$accept_header" -H "$content_type_header" -X GET "$api_url/public/collections")
collection_values=$(echo $org_collections | jq -c '.data[] | {name, id}')

# For each Group, list its assigned Collections
echo "$group_values" | while read -r group; do
    groupname=$(echo $group | jq -r '.name')
    groupid=$(echo $group | jq -r '.id')
    retrievegroup=$(curl -s -H "$auth_header" -H "$accept_header" -H "$content_type_header" -X GET "$api_url/public/groups/$groupid")
    collections=$(echo $retrievegroup | jq -c '.collections[] | {id}')

    echo "=> '$groupname' Group ($groupid) has Collection access to:"
    echo "$collections" | while read -r collection; do
        collection_id_for_lookup=$(echo $collection | jq -r '.id')
        collection_name=$(bw --session $BW_SESSION get org-collection $collection_id_for_lookup --organizationid $BW_ORG_ID | jq -r '.name')
        echo "\t - $collection_name ($collection_id_for_lookup)"
    done
done
