#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <access_token>"
  exit 1
fi

access_token="$1"


if ! command -v bw > /dev/null 2>&1; then
  echo "Bitwarden CLI (bw) is not available on your system. Exiting..."
  echo "Ensure the directory location is set in the \$PATH variable."
  exit 2
fi

if ! command -v bws > /dev/null 2>&1; then
  echo "Bitwarden Secret Manager CLI (bws) is not available on your system. Exiting..."
  echo "Ensure the directory location is set in the \$PATH variable."
  exit 2
fi

if ! command -v jq > /dev/null 2>&1; then
  echo "Command Line JSON processor (jq) is not available on your system. Exiting..."
  echo "Ensure the directory location is set in the \$PATH variable."
  exit 2
fi

#get values from Secret Manager with keys masterpassword, client_id, and client_secret

masterpass=$(bws list secrets -t $access_token | jq '.[] | select(.key == "masterpassword")' | jq '.value' | tr -d '"')
export BW_CLIENTID=$(bws list secrets -t $access_token | jq '.[] | select(.key == "client_id")' | jq '.value' | tr -d '"')
export BW_CLIENTSECRET=$(bws list secrets -t $access_token | jq '.[] | select(.key == "client_secret")' | jq '.value' | tr -d '"')


organization_id="1f0c58c3-a3d8-48b2-bb3a-ac8c0075bcc6"

bw logout --raw
bw login --apikey --raw


session_key="$(printf $masterpass | bw unlock --raw)"
org_members="$(bw list --session "$session_key" org-members --organizationid $organization_id | jq -c '.[] | select( .status == 1 )' | jq -c '.id' | tr -d '"')"
for member_id in ${org_members[@]} ; do
	bw confirm --session $session_key org-member $member_id --organizationid $organization_id
done
