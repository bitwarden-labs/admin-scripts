#!/bin/bash

read -p 'Secure Note Name: ' name
read -p ''"$name"' Body: ' body
read -p 'Organization ID: ' organizationID
read -p 'Collection ID: ' collectionID

session_key="$(bw unlock --raw)"

bw --session $session_key sync

objectID="$(echo '{"type":2,"name":"'$name'","notes":"'$body'","secureNote":{"type":0}}' | bw encode | bw --session $session_key create item | cut -d '"' -f8)"

echo '["'"$collectionID"'"]' | bw encode | bw --session $session_key share $objectID $organizationID