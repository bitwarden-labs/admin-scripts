#!/bin/bash

## REQUIREMENTS ##
# before running the script:
# download jq JSON tool
# Log in to Bitwarden CLI first


# Get the directory of the current script
script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Check if 'bw' exists in the same directory as the script
if [[ -f "$script_dir/bw" ]]; then
    bw_path="$script_dir/bw"
else
    # If not found, check in the directories listed in $PATH
    bw_path=$(which bw)
    if [[ -z $bw_path ]]; then
        echo "'bw' not found in the script directory or in \$PATH"
        exit 1
    fi
fi

# Check if 'jq' exists in the same directory as the script
if [[ -f "$script_dir/jq" ]]; then
    jq_path="$script_dir/jq"
else
    # If not found, check in the directories listed in $PATH
    jq_path=$(which jq)
    if [[ -z $jq_path ]]; then
        echo "'jq' not found in the script directory or in \$PATH"
        exit 1
    fi
fi

#ask for org id

read -p 'Organization ID: ' org_id

#ask for master password to unlock the CLI

read -sp 'Enter Master Password for the account (Hidden): ' acc_master_pass
echo ""

session_key=$($bw_path unlock $acc_master_pass --raw)
#$bw_path sync --session $session_key

json_data="$($bw_path list items --organizationid $org_id --session $session_key)"

# Process JSON and update uris.match to "Host" if null
updated_json=$(echo "$json_data" | jq -c '
  map(
    if .login.uris != null then
      .login.uris |= map(.match = 1)
    else
      .
    end
  )
')

echo "$updated_json" | jq -c '.[]' | while read -r item; do
  # Get the item id
  id=$(echo "$item" | jq -r '.id')
  item_name=$(echo "$item" | jq -r '.name')
  # Encode the item and run the bw command
  echo "$item" | bw encode | bw edit item "$id" --session $session_key --quiet
  echo "$item_name updated"
done
