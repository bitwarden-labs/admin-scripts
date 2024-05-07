#!/bin/bash

# Print help instructions
print_help() {
    echo ""
    echo $0
    echo ""
    echo "The script automates permission inheritance for child collections in Bitwarden, using encrypted master password and organization ID inputs, and requires jq, bw, and openssl to be installed."
    echo ""
    echo "Generate secureString.txt:"
    echo "1. Choose a secure passphrase."
    echo "2. Run the following command, replacing YOUR_MASTER_PASSWORD with your Bitwarden master password"
    echo "   and YOUR_PASSPHRASE with your chosen passphrase:"
    echo "   echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 100000 -salt -pass pass:YOUR_PASSPHRASE > secureString.txt"
    echo ""
    echo "Usage: $0 <organization_id> <secure_string_path> <passphrase>"
    echo "Example: $0 \"YOUR-ORG-ID\" \"secureString.txt\" \"your_passphrase\""
    echo ""
}

# Check if required commands are installed
check_command() {
    if ! type "$1" > /dev/null 2>&1; then
        echo "Error: $1 is not installed or not found in PATH." >&2
        exit 1
    fi
}

# Decrypt master password
get_pwd() {
    openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 \
        -salt -pass pass:"$passphrase" -in "$secure_string_path"
}

# Check dependencies: jq, Bitwarden CLI (bw), openssl
check_command jq
check_command openssl
check_command bw

# Arguments
organization_id="$1"
secure_string_path="$2"
passphrase="$3"

# Validate arguments
if [ -z "$organization_id" ] || [ -z "$secure_string_path" ] || [ -z "$passphrase" ]; then
    print_help
    exit 1
fi

# Unlock Bitwarden and get session key
session=$(get_pwd | bw unlock --raw)

# Get parent collections
parents=$(bw --session "$session" list org-collections \
    --organizationid "$organization_id" | jq -r '.[].name' | grep \/ | cut -f1 -d\/ | uniq)

# Loop through parents
for p in "${parents[@]}"; do
    echo "Processing parent: $p"

    # Get Parent ID and permissions
    p_id=$(bw --session "$session" list org-collections \
        --organizationid "$organization_id" | jq -r --arg p "$p" '.[] | select(.name == $p) | .id')
    p_perms=$(bw --session "$session" get org-collection "$p_id" \
        --organizationid "$organization_id" | jq -c '.groups')

    # Depth of nesting
    depth=$(bw --session "$session" list org-collections \
        --organizationid "$organization_id" | jq -r '.[].name' | grep \/ | grep "$p" | \
        awk -F'/' '{print NF-1}' | sort -rn | head -n1)

    # Loop through depths
    for (( d=1; d<=$depth; d++ )); do
        children=$(bw --session "$session" list org-collections \
            --organizationid "$organization_id" | jq -r '.[].name' | grep "$p/" | \
            cut -f$((d+1)) -d\/ | uniq)

        # Process children
        for c in $children; do
            echo "Updating child: $c under $p"
            c_id=$(bw --session "$session" list org-collections \
                --organizationid "$organization_id" | jq -r --arg p "$p" '.[] | select(.name | contains($p)) | {name, id}' | \
                jq -r --arg c "$c" 'select(.name | contains($c)) | .id' | uniq | head -n1)
            bw --session "$session" get org-collection "$c_id" \
                --organizationid "$organization_id" | jq --argjson g "$p_perms" -c '.groups=$g' | \
                bw encode | bw --quiet --session "$session" edit org-collection "$c_id" \
                --organizationid "$organization_id"
        done
    done
done
