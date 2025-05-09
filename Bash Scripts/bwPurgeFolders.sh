#!/bin/bash

# Ensure you're logged in and the session is unlocked
SESSION=$(bw unlock --raw)
if [ -z "$SESSION" ]; then
    echo "Failed to unlock Bitwarden. Make sure you are logged in."
    exit 1
fi

# Get the list of folder IDs
FOLDER_IDS=$(bw list folders --session "$SESSION" | jq -r '.[].id')

# Check if there are folders to delete
if [ -z "$FOLDER_IDS" ]; then
    echo "No folders found to delete."
    exit 0
fi

# Loop through each folder ID and delete it
for ID in $FOLDER_IDS; do
    echo "Deleting folder ID: $ID"
    bw delete folder "$ID" --session "$SESSION"
done

echo "All folders deleted."

bw logout --session "$SESSION"
