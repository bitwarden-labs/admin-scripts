#!/bin/bash

# Authentication

source_client_id=
source_client_secret=
dest_client_id=
dest_client_secret=

# Globals

grant_type=client_credentials
scope=api.organization
vault_uri=https://vault.bitwarden.com

# Placeholders

source_org_members=
dest_member_object=
source_access_token=
dest_access_token=

source_org_members=
dest_member_object=
source_access_token=
dest_access_token=

get_access_token() {
    local source_response=$(curl -s -X POST "$vault_uri/identity/connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "grant_type=$grant_type" \
        --data-urlencode "scope=$scope" \
        --data-urlencode "client_id=$source_client_id" \
        --data-urlencode "client_secret=$source_client_secret")
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to retrieve access token." >&2
        exit 1
    fi
    
    local dest_response=$(curl -s -X POST "$vault_uri/identity/connect/token" \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        --data-urlencode "grant_type=$grant_type" \
        --data-urlencode "scope=$scope" \
        --data-urlencode "client_id=$dest_client_id" \
        --data-urlencode "client_secret=$dest_client_secret")
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to retrieve access token." >&2
        exit 1
    fi

    source_access_token=$(echo "$source_response" | jq -r '.access_token')
    dest_access_token=$(echo "$dest_response" | jq -r '.access_token')
}

list_members() {
    if [[ -z "$vault_uri" || -z "$source_access_token" ]]; then
        echo "Error: 'vault_uri' and 'source_access_token' must be set as global variables."
        return 1
    fi

    local API_URL="$vault_uri/api"

    source_org_members=($(curl -s "$API_URL/public/members/" \
        -H "Authorization: Bearer $source_access_token" | \
        jq -r '.data[] | .email'))
        
}

package_member_object() {
    local member_object_header='{"groups": [], "members":['
    local member_object_footer='], "overwriteExisting": false, "largeImport": false}'
    local member_list=""
    for e in ${source_org_members[@]}; do
        member_list+='{"email": "'"$e"'","externalId":"'"$e"'"},'
    done
    member_list=$(echo "$member_list" | sed 's/,$//')
    dest_member_object=$member_object_header$member_list$member_object_footer
    echo $dest_member_object | jq
}

post_members() {
    if [[ -z "$vault_uri" || -z "$dest_access_token" ]]; then
        echo "Error: 'vault_uri' and 'dest_access_token' must be set as global variables."
        return 1
    fi

    local API_URL="$vault_uri/api"
    
    #echo $dest_member_object

    curl -s -X POST "$API_URL/public/organization/import" \
        -H "Authorization: Bearer $dest_access_token" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -d "$dest_member_object"
}

get_access_token
list_members
package_member_object
post_members
