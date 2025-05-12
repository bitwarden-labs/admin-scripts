#!/bin/bash

# --- Defaults ---
SILENT=false
LOGOUT_AFTER=false

# --- Help message ---
print_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -s, --silent         Run without confirmation prompt"
  echo "  -l, --logout         Log out from Bitwarden CLI after deletion"
  echo "  -h, --help           Show this help message and exit"
  echo ""
  echo "This script lists all folders in your Bitwarden vault, confirms deletion,"
  echo "and deletes them (excluding any with missing or null IDs)."
  exit 0
}

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--silent) SILENT=true ;;
    -l|--logout) LOGOUT_AFTER=true ;;
    -h|--help) print_help ;;
    *) echo "Unknown option: $1" && print_help ;;
  esac
  shift
done

# --- Unlock and Sync ---
export BW_SESSION=$(bw unlock --raw)
if [ -z "$BW_SESSION" ]; then
    echo "❌ Failed to unlock Bitwarden. Make sure you are logged in."
    exit 1
fi

echo "🔄 Syncing Bitwarden vault..."
bw sync --session "$BW_SESSION"

# --- List folders ---
FOLDERS_JSON=$(bw list folders --session "$BW_SESSION")
FOLDER_COUNT=$(echo "$FOLDERS_JSON" | jq '[.[] | select(.id != null and .id != "")] | length')

if [ "$FOLDER_COUNT" -eq 0 ]; then
    echo "ℹ️ No valid folders found to delete."
    exit 0
fi

# --- Show folders ---
echo "📂 The following folders will be deleted:"
echo "$FOLDERS_JSON" | jq -r '.[] | select(.id != null and .id != "") | "- \(.name) (\(.id))"'

# --- Confirmation ---
if [ "$SILENT" = false ]; then
    echo ""
    read -p "⚠️ Are you sure you want to delete ALL these folders? [y/N] " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "❌ Operation cancelled."
        exit 0
    fi
fi

# --- Delete folders ---
echo ""
echo "🗑 Deleting folders..."
echo "$FOLDERS_JSON" | jq -r '.[] | select(.id != null and .id != "") | .id' | while read -r ID; do
    echo "Deleting folder ID: $ID"
    bw delete folder "$ID" --session "$BW_SESSION"
done

# --- Optional logout ---
if [ "$LOGOUT_AFTER" = true ]; then
  echo ""
  echo "🚪 Logging out from Bitwarden CLI..."
  bw logout
fi

echo "✅ Folder deletion complete."
