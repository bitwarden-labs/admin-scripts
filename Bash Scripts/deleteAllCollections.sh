#!/bin/bash

#User must be logged out for the script to work

if ! command -v jq &> /dev/null
then
        echo 'Please install jq'
        exit
fi

set -e
session_key="$(bw login --raw)"
read -p "Organization ID: " organizationID

bw --session $session_key sync

organizations="$(bw --session $session_key list org-collections --organizationid $organizationID)"

echo "You are going to delete the following collections: "
echo $organizations | jq ".[].name"

read -p "Are you sure? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]
then
        echo $organizations | jq ".[].id" | \
        xargs -n 1 -t bw --session $session_key delete --organizationid $organizationID org-collection
fi
