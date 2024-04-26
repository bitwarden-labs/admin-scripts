# Update client_id and client_secret to authenticate to Bitwarden public API
# Settings > View API Key > OAUTH 2.0 Client Credentials

client_id=your_client_id
client_secret=your_client_secret

# Globals
grant_type=client_credentials
scope=api.organization
vault_uri=https://vault.bitwarden.com

get_access_token() {
    local response=$(curl -s -X POST "$vault_uri/identity/connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "grant_type=$grant_type" \
        --data-urlencode "scope=$scope" \
        --data-urlencode "client_id=$client_id" \
        --data-urlencode "client_secret=$client_secret")
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to retrieve access token." >&2
        exit 1
    fi

    echo "$response" | jq -r '.access_token'
}

list_members() {
    if [[ -z "$vault_uri" || -z "$access_token" ]]; then
        echo "Error: 'vault_uri' and 'access_token' must be set as global variables."
        return 1
    fi

    local API_URL="$vault_uri/api"

    local org_members=$(curl -s "$API_URL/public/members/" \
        -H "Authorization: Bearer $access_token" | \
        jq -r '.data[] | [ .email, .externalId, .type, .status] | @csv')

    echo "email, externalId, role, status"
    echo "$org_members" | while IFS=, read -r name email externalId role status; do
        local status_text=("invited" "accepted" "confirmed" "revoked" "unknown")
        local role_text=("owner" "admin" "user" "manager" "custom" "unknown")

        [[ "$status" -eq -1 ]] && status="revoked" || status=${status_text[$status]:-"unknown"}
        role=${role_text[$role]:-unknown}

        echo "$name, $email, $externalId, $role, $status"
    done
}

access_token=`get_access_token`
list_members