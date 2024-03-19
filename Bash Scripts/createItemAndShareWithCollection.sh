#!/bin/bash

read -p 'Login Item Name: ' name
read -p ''"$name"' Username: ' username
read -p ''"$name"' Password: ' password
read -p 'Organization ID: ' organizationID
read -p 'Collection ID: ' collectionID

session_key="$(bw unlock --raw)"

bw --session $session_key sync

objectID="$(bw --session $session_key get template item | jq '.name="'"$name"'" | .login.username="'$username'" | .login.password="'$password'"' | bw encode | bw --session $session_key create item | cut -d '"' -f8)"

echo '["'"$collectionID"'"]' | bw encode | bw --session $session_key share $objectID $organizationID