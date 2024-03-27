# Script to tag each vault item with its Collection Name to aid vault searchability
# The Bitwarden CLI tool should be available, and its location defined below (https://bitwarden.com/help/cli/)
# Run 'bw unlock' from the same terminal used to run this script in order to obtain a session key before starting

import json
import subprocess

# setup
session_key = input(
    "Input session key: "
)  # bw session key - https://bitwarden.com/help/cli/#using-a-session-key
# 1e0e131d-f610-4798-86cc-aed10109190e
# The org_id can be obtained with `bw list organizations --pretty` run from the bw CLI tool (https://bitwarden.com/help/cli/#list)
# org_id = "" # For use with a hardcoded Org ID
org_id = input("Input Org ID: ")  # To input the Org ID interactively
bw = ["/Users/adambramley/.nvm/versions/node/v19.9.0/bin/bw", "--session", session_key]


# Obtain collection data
def get_collection_data():
    collections = subprocess.run(
        bw + ["list", "collections"], capture_output=True, text=True
    )

    if collections.returncode == 0:

        try:
            collections = json.loads(collections.stdout)

            org_collections = [
                {"id": item["id"], "name": item["name"]} for item in collections
            ]
            return org_collections

        except json.JSONDecodeError:
            print("Error: Unable to decode Org Collections data")
            return None

    else:
        print("Error: Unable to obtain item list from vault")
        return None


# Add each collection item is present in to item notes field
def update_items_notes(org_collections):
    # Get all Vault Items
    items_output = subprocess.run(
        bw + ["list", "items"], capture_output=True, text=True
    )

    if items_output.returncode == 0:
        try:
            items_data = json.loads(items_output.stdout)

            for item in items_data:

                item_id = item.get("id")
                item_collections = item.get("collectionIds", [])
                collection_names = []

                # Map Collection Names against IDs
                for collection_id in item_collections:
                    for org_collection in org_collections:
                        if org_collection["id"] == collection_id:
                            collection_names.append(org_collection["name"])

                # Append collections if notes exist, write collections if notes are empty
                item_notes = item.get("notes", "")
                if item_notes is not None:
                    item_notes += "\nCollections:\n" + "\n".join(collection_names)

                else:
                    item_notes = "Collections:\n" + "\n".join(collection_names)

                # Write new notes to item
                item["notes"] = item_notes
                item_json = json.dumps(item)

                # Produce encoded json of modified item
                encodedJson = subprocess.run(
                    bw + ["encode"], input=item_json, capture_output=True, text=True
                )
                if encodedJson.returncode == 0:
                    encodedJson = encodedJson.stdout.strip()
                else:
                    print("Error encoding JSON:", encodedJson.stderr)

                # Write modified item back to vault
                edit_item = subprocess.run(
                    bw + ["edit", "item", item_id, encodedJson],
                    capture_output=True,
                    text=True,
                )
                if edit_item.returncode == 0:
                    print(f"Updated {item['name']}")
                else:
                    print(f"Error editing {item['name']}:", edit_item.stderr)

        except json.JSONDecodeError:
            print("Error: Unable to process items data")
            return None

    else:
        print("Error: Unable to decode items data")
        return None


org_collections = get_collection_data()
org_items_processed = update_items_notes(org_collections)
