#!/bin/bash

# Script Name: ListMembers.sh
# Description: Fetches and displays Bitwarden organization members.
# Usage: ./ListMembers.sh ORG_CLIENT_ID ORG_CLIENT_SECRET

# Validate dependencies
for dep in curl jq; do
    if ! command -v $dep &> /dev/null; then
        echo "Error: $dep is not installed. Please install $dep to continue."
        exit 1
    fi
done

# Validate arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 ORG_CLIENT_ID ORG_CLIENT_SECRET"
    exit 1
fi

API_URL="https://api.bitwarden.com"
IDENTITY_URL="https://identity.bitwarden.com/connect/token"
ORG_CLIENT_ID="$1"
ORG_CLIENT_SECRET="$2"

# Fetch the ACCESS_TOKEN
response=$(curl -s -X POST "$IDENTITY_URL" -H 'Content-Type: application/x-www-form-urlencoded' \
           -d "grant_type=client_credentials&scope=api.organization&client_id=$ORG_CLIENT_ID&client_secret=$ORG_CLIENT_SECRET")
ACCESS_TOKEN=$(echo $response | jq -r '.access_token')

if [[ $ACCESS_TOKEN == "null" || -z $ACCESS_TOKEN ]]; then
    echo "Error: Invalid Access Token. Response was: $response"
    exit 1
fi

# Fetch groups and store in a variable
GROUPS_JSON=$(curl -s "$API_URL/public/groups" -H "Authorization: Bearer $ACCESS_TOKEN" | jq '[.data[] | {id, name}]')

get_group_name_by_id() {
    local group_id="$1"
    echo "$GROUPS_JSON" | jq -r --arg group_id "$group_id" '.[] | select(.id == $group_id) | .name'
}

# Fetch organization members
ORG_MEMBERS=$(curl -s "$API_URL/public/members/" -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.data[] | [.id, .email, .type, .status, .twoFactorEnabled] | @csv')

echo "email,role,2FA Enabled,status,groups"
echo "$ORG_MEMBERS" | while IFS=, read -r userid email role status twoFactorEnabled; do
    # Convert role and status to text
    status_text=("invited" "accepted" "confirmed" "revoked" "unknown")
    role_text=("Owner" "Admin" "User" "Manager" "Custom" "unknown")

    # Check for special status value -1 and handle accordingly
    if [ "$status" -eq -1 ]; then
        status="revoked"
    else
        # Attempt to map status using the array, defaulting to "unknown" if out of range
        status=${status_text[$status]:-"unknown"}
    fi

    role=${role_text[$role]:-unknown}

    # Fetch group IDs for the member and construct group names string
    group_ids=$(curl -s "$API_URL/public/members/${userid//\"/}/group-ids" -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.[]')

    group_names=""
    for group_id in $group_ids; do
        group_name=$(get_group_name_by_id "$group_id")
        [[ ! -z "$group_name" ]] && group_names+="${group_name};"
    done
    group_names=${group_names%;} # Remove trailing semicolon

    echo "$email,$role,$status,$twoFactorEnabled,${group_names:-None}"
done
