#!/bin/bash
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# sessionKey will prompt the user with the bw interactive login, and then extract the session key
# organizationID must be set by the user manually (found in GUI or via 'bw list organizations' in the CLI)
# organizationID ex: organizationID="4ce1432b-c57f-4594-93dd-b25e023141f3"
# NOTE: Please ensure that the CSV imported into BW has been cleaned to use "/" instead of "\" (ex: Keeper uses "\" for nested folders).

# Get Bitwarden CLI status JSON
bwStatus=$(bw status 2>/dev/null)

# Extract the "status" field
status=$(echo "$bwStatus" | jq -r '.status' 2>/dev/null)

# Ensure status is not empty
if [[ -z "$status" ]]; then
    echo "Error: Unable to retrieve Bitwarden status."
    exit 1
fi

# Determine if we need to log in or unlock
if [[ "$status" == "unauthenticated" ]]; then
    echo "Not logged in, attempting login..."
    sessionKey=$(bw login | sed -n 's/.*\$env:BW_SESSION="\([^"]*\)".*/\1/p') # Prompt user for login and extract session key
else
    echo "Logged in, grabbing session key..."
    sessionKey=$(bw unlock | sed -n 's/.*\$env:BW_SESSION="\([^"]*\)".*/\1/p') # Unlock vault and extract session key
fi

organizationID=$(bw list organizations --session "$sessionKey" | jq -r '.[].id') #grab the first organization ID

# Check for the Collection list and create any missing Collections in a loop
listCollections=$(bw list org-collections --organizationid $organizationID --session "$sessionKey" | jq -r '.[].name')

# Split the response into an array
IFS=$'\n' read -r -d '' -a collections <<< "$listCollections"

# Separate nested Collections for Parent collections
nestedCollections=()
parentCollections=()
for collection in "${collections[@]}"; do
    if [[ "$collection" == *"/"* ]]; then
        nestedCollections+=("$collection")
    else
        parentCollections+=("$collection")
    fi
done

# Output nested collections
echo "NESTED COLLECTIONS:"
for collection in "${nestedCollections[@]}"; do
    echo "$collection"
done

echo "" #output spacing

# Output parent collections
echo "PARENT COLLECTIONS:"
for collection in "${parentCollections[@]}"; do
    echo "$collection"
done

echo "" #output spacing

#create a list for collections that need to be created (ie, missing parent collections) and a placeholder for unique results
missingParents=()
uniqueMissingParents=()

# Function to check recursively if a collection exists or needs to be created
check_and_create_collection() {
    local path="$1"
    local parentPath=""

    # Split the path into individual parts
    IFS='/' read -r -a pathParts <<< "$path"

    # Iterate over the parts but stop at the second-to-last part (exclude the item itself)
    for (( i=0; i<${#pathParts[@]}-1; i++ )); do
        part="${pathParts[$i]}"
        
        # Update the full parent path
        if [ -z "$parentPath" ]; then
            parentPath="$part"
        else
            parentPath="$parentPath/$part"
        fi

        # Check if the collection exists, if not, add it to missingParents
        match=false
        for parent in "${parentCollections[@]}"; do
            if [[ "$parent" == "$parentPath" ]]; then
                match=true
                break
            fi
        done

        if ! $match; then
            # Add the missing collection to the list, if it's not already present
            if [[ ! " ${missingParents[@]} " =~ " ${parentPath} " ]]; then
                missingParents+=("$parentPath")
            fi
        fi
    done
}

# Check each nested collection path recursively
for nestedItem in "${nestedCollections[@]}"; do
    check_and_create_collection "$nestedItem"
done

# Remove duplicates and ensure no missing collection is a part of the existing nested collections
for item in "${missingParents[@]}"; do
    # Ensure that the missing parent is not already part of the nested collections
    match=false
    for nested in "${nestedCollections[@]}"; do
        if [[ "$nested" == "$item" ]]; then
            match=true
            break
        fi
    done

    # Add to uniqueMissingParents only if it's not already in nested collections
    if ! $match; then
        uniqueMissingParents+=("$item")
    fi
done

# Output the uniqueMissingParents array
echo "Unique Missing Parents:"
for item in "${uniqueMissingParents[@]}"; do
    echo "$item"
done

echo "" #output spacing
read -p "Do you want to continue? (y/any other input): " user_input

# Check if the input is "y". If it is, create the collection
if [[ "$user_input" == "y" || "$user_input" == "Y" ]]; then
    for collectionname in "${uniqueMissingParents[@]}"; do
        bw --session "$sessionKey" get template org-collection | jq --arg n "$collectionname" --arg c "$organizationID" '.name=$n | .organizationId=$c | del(.groups) | del(.users)' | bw encode | bw --session "$sessionKey" create org-collection --organizationid $organizationID
        echo "Created Collection for $collectionname"
    done
else
    echo "Exiting..."
    exit 0
fi
