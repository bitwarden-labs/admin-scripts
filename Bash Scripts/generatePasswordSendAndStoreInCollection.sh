#!/bin/bash
# generatePasswordSendAndStoreInCollection.sh
#
# DESCRIPTION
#   Automates new-joiner credential provisioning using the Bitwarden CLI.
#   The script does three things in sequence:
#     1. Generates a strong random password via the Bitwarden password generator
#     2. Stores it as a Login item inside a specified organisation collection
#        so the team retains a permanent, auditable copy in the vault
#     3. Creates a Bitwarden Send (time-limited, view-capped text share) containing
#        the credentials, and prints the Send URL for delivery to the recipient
#
# PREREQUISITES
#   - Bitwarden CLI (bw) installed and available in PATH
#       Install: npm install -g @bitwarden/cli
#                or https://bitwarden.com/help/cli/#download-and-install
#   - jq installed
#       Install: sudo apt install jq  /  brew install jq
#
#   ONE-TIME SETUP (run once before using this script):
#   1. Point the CLI at your Bitwarden server:
#       bw config server https://your-bitwarden-instance.example.com
#   2. Log in:
#       bw login
#      (The script calls bw unlock at runtime - it does not handle login itself)
#
#   - The account running this script must:
#       * Have access to the target collection (Member role or above)
#       * Have a Master Password set (required by bw unlock)
#         Note: in SSO-enforced organisations only Admin-role accounts
#         can have a Master Password - a dedicated service account is recommended
#
# INPUTS (prompted interactively)
#   Item name       - display name for the vault item and Send (e.g. "Jane Doe - AD Account")
#   Username        - the username being provisioned
#   Organization ID - UUID of the Bitwarden organisation
#                     (Admin Console > Settings > Organisation Info)
#   Collection ID   - UUID of the target collection
#                     (Admin Console >  Vault >  Collections > select collection > URL)
#   Send expiry     - hours until the Send self-deletes (default: 72)
#
# OUTPUT
#   - A Login vault item created in the specified collection
#   - A Bitwarden Send URL (expires per the chosen hours, max 3 views)
#
# USAGE
#   chmod +x generatePasswordSendAndStoreInCollection.sh
#   ./generatePasswordSendAndStoreInCollection.sh

set -euo pipefail

# --- Inputs ---
read -p 'Item name: ' ITEM_NAME
read -p 'Username: ' USERNAME
read -p 'Organization ID: ' ORG_ID
read -p 'Collection ID: ' COLLECTION_ID
read -p 'Send expiry (hours, default 72): ' EXPIRY_HOURS
EXPIRY_HOURS=${EXPIRY_HOURS:-72}

# --- Unlock ---
# bw unlock prompts for the Master Password and returns a session token.
# All subsequent bw commands use --session to authenticate without re-prompting.
export BW_SESSION
BW_SESSION=$(bw unlock --raw)

# Sync pulls the latest vault state from the server before making changes.
bw sync --session "$BW_SESSION" --quiet

# --- Generate password ---
# 24-character password with uppercase, lowercase, numbers, and special characters.
PASSWORD=$(bw generate --uppercase --lowercase --number --special --length 24)

# --- Create login item in the collection ---
# Fetches the blank item template, fills in the fields with jq, encodes it,
# and posts it to the vault. The item is scoped to the org and collection from the start.
ITEM_JSON=$(bw --session "$BW_SESSION" get template item | jq \
  --arg name "$ITEM_NAME" \
  --arg user "$USERNAME" \
  --arg pw "$PASSWORD" \
  --arg orgId "$ORG_ID" \
  --arg collId "$COLLECTION_ID" \
  '.type = 1
  | .name = $name
  | .organizationId = $orgId
  | .collectionIds = [$collId]
  | .login.username = $user
  | .login.password = $pw
  | .login.uris = null
  | .login.totp = null')

ITEM_ID=$(echo "$ITEM_JSON" \
  | bw encode \
  | bw --session "$BW_SESSION" create item \
  | jq -r '.id')

echo "Vault item created: $ITEM_ID"

# --- Create Bitwarden Send wrapping the password ---
# The Send is a one-way, time-limited share. The recipient only sees the text;
# they do not need a Bitwarden account to access it.
# maxAccessCount = 3 ensures the link self-destructs after 3 views even if
# the expiry window has not yet elapsed.
EXPIRY_DATE=$(date -u -d "+${EXPIRY_HOURS} hours" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
  || date -u -v+"${EXPIRY_HOURS}H" +"%Y-%m-%dT%H:%M:%SZ")

SEND_TEXT="Username: ${USERNAME}
Password: ${PASSWORD}

This Send expires after ${EXPIRY_HOURS} hours or 3 views."

SEND_JSON=$(bw send template send.text | jq \
  --arg name "Credentials: $ITEM_NAME" \
  --arg text "$SEND_TEXT" \
  --arg expiry "$EXPIRY_DATE" \
  '.name = $name
  | .type = 0
  | .text.text = $text
  | .text.hidden = false
  | .deletionDate = $expiry
  | .maxAccessCount = 3')

SEND_URL=$(echo "$SEND_JSON" \
  | bw encode \
  | bw send create \
  | jq -r '.accessUrl')

# --- Output ---
echo ""
echo "=== Done ==="
echo "Item name:  $ITEM_NAME"
echo "Vault item: $ITEM_ID"
echo "Send link:  $SEND_URL"
echo "Send expires: $EXPIRY_DATE (max 3 views)"

# --- Cleanup ---
# Lock the vault and clear sensitive variables from the shell environment.
bw lock
unset BW_SESSION PASSWORD
