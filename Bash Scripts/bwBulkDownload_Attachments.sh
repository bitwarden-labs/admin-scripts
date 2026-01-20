#!/bin/bash

################################################################################
# Bitwarden Vault Attachment Downloader
################################################################################
#
# DESCRIPTION:
#   Downloads all attachments from a Bitwarden vault to your local machine.
#   This script can retrieve attachments from either your personal vault OR
#   an organization vault. Files are prefixed with the item name to prevent
#   filename conflicts and provide better organization.
#
# PREREQUISITES:
#   1. Bitwarden CLI installed (brew install bitwarden-cli)
#   2. jq installed for JSON processing (brew install jq)
#   3. bc installed for calculations (usually pre-installed on macOS)
#   4. Already logged in to Bitwarden:
#      - For US Cloud:    bw login
#      - For EU Cloud:    bw config server https://vault.bitwarden.eu && bw login
#      - For Self-hosted: bw config server https://your-server.com && bw login
#   5. Vault unlocked with: bw unlock
#
# FEATURES:
#   - Downloads attachments from PERSONAL or ORGANIZATION vaults
#   - Prefixes files with item names to prevent duplicates
#   - Sanitizes filenames for filesystem compatibility
#   - Shows download progress with file sizes
#   - Provides detailed summary of successful/failed downloads
#   - Supports interactive mode or command-line arguments
#   - Auto-selects organization if you only have one (org mode only)
#   - Works with US Cloud, EU Cloud, and Self-hosted instances
#
# PARAMETERS:
#   -s, --session SESSION    Bitwarden session token (alternative to BW_SESSION env var)
#                           If not provided, will prompt for unlock or use BW_SESSION
#
#   -t, --type TYPE         Vault type: "personal" or "org" (organization)
#                           Default: prompts for selection if not specified
#
#   -o, --org-id ORG_ID     Organization ID (required if type is "org", ignored if "personal")
#                           If not provided in org mode, will show interactive selection
#                           Use --list-orgs to find your organization ID
#
#   -d, --directory DIR     Download directory path (supports ~ for home directory)
#                           Default personal: ~/Downloads/bitwarden-personal-attachments
#                           Default org: ~/Downloads/bitwarden-org-attachments/<OrgName>
#
#   -l, --list-orgs         List all available organizations with their IDs and exit
#                           Useful for finding the organization ID you need
#
#   -h, --help              Display help message with usage examples
#
# USAGE EXAMPLES:
#   # Download from personal vault
#   ./download_bw_attachments.sh --type personal
#
#   # Download from personal vault with custom directory
#   ./download_bw_attachments.sh --type personal --directory ~/Documents/my-files
#
#   # List all organizations
#   ./download_bw_attachments.sh --list-orgs
#
#   # Interactive mode (prompts for personal or org selection)
#   ./download_bw_attachments.sh
#
#   # Download from specific organization
#   ./download_bw_attachments.sh --type org --org-id abc123def456
#
#   # Download from org with custom directory
#   ./download_bw_attachments.sh --type org --org-id abc123 --directory ~/Documents/company-files
#
#   # With session token (if BW_SESSION not set)
#   ./download_bw_attachments.sh --type personal --session YOUR_SESSION_TOKEN
#
#   # Using environment variable for session
#   export BW_SESSION=$(bw unlock --raw)
#   ./download_bw_attachments.sh --type org --org-id abc123
#
# FILE NAMING:
#   Files are prefixed with the vault item name to prevent conflicts:
#   - Original: document.pdf
#   - Saved as: MyVaultItem_document.pdf
#   
#   Special characters in item names are replaced with underscores for
#   filesystem compatibility.
#
# OUTPUT:
#   The script provides colored output showing:
#   - Login and session verification status
#   - Vault type selection (personal or organization)
#   - Organization selection/confirmation (if org mode)
#   - Progress for each item with attachments
#   - Individual file download status
#   - Final summary with success/failure counts
#
# EXIT CODES:
#   0 - Success
#   1 - Error (not logged in, invalid session, missing dependencies, etc.)
#
# AUTHOR:
#   Created for managing Bitwarden vault attachments
#
# VERSION:
#   2.0.0
#
################################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -s, --session SESSION      Bitwarden session token (or set BW_SESSION env var)"
    echo "  -t, --type TYPE            Vault type: 'personal' or 'org' (organization)"
    echo "  -o, --org-id ORG_ID        Organization ID (required if type is 'org')"
    echo "  -d, --directory DIR        Download directory"
    echo "  -l, --list-orgs            List available organizations and exit"
    echo "  -h, --help                 Display this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - Log in to Bitwarden first: bw login"
    echo "  - For self-hosted: bw config server https://your-server.com"
    echo "  - Then unlock: bw unlock"
    echo ""
    echo "Examples:"
    echo "  $0 --type personal                          # Download from personal vault"
    echo "  $0 --list-orgs                              # List all organizations"
    echo "  $0 --type org --org-id abc123               # Download from specific org"
    echo "  $0 --type personal -d ~/Documents/my-files  # Custom directory"
    exit 1
}

# Parse command line arguments
SESSION=""
DOWNLOAD_DIR=""
ORG_ID=""
VAULT_TYPE=""
LIST_ORGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--session)
            SESSION="$2"
            shift 2
            ;;
        -t|--type)
            VAULT_TYPE="$2"
            shift 2
            ;;
        -o|--org-id)
            ORG_ID="$2"
            shift 2
            ;;
        -d|--directory)
            DOWNLOAD_DIR="$2"
            shift 2
            ;;
        -l|--list-orgs)
            LIST_ORGS=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install it with: brew install jq"
    exit 1
fi

# Check if bc is installed (for file size calculations)
if ! command -v bc &> /dev/null; then
    echo -e "${YELLOW}Warning: bc is not installed. File sizes will not be displayed.${NC}"
    echo "Install it with: brew install bc"
    BC_AVAILABLE=false
else
    BC_AVAILABLE=true
fi

# Function to sanitize filename
sanitize_filename() {
    local filename="$1"
    # Replace problematic characters with underscores
    echo "$filename" | sed 's/[\/\\:*?"<>|]/_/g' | sed 's/[[:space:]]/_/g'
}

# Check if bw is installed
if ! command -v bw &> /dev/null; then
    echo -e "${RED}Error: Bitwarden CLI (bw) is required but not installed.${NC}"
    echo "Install it with: brew install bitwarden-cli"
    exit 1
fi

# Check if user is logged in to Bitwarden
echo -e "${BLUE}Checking Bitwarden login status...${NC}"
login_status=$(bw login --check 2>&1 || true)

if echo "$login_status" | grep -q "You are not logged in"; then
    echo -e "${RED}Error: You are not logged in to Bitwarden.${NC}"
    echo ""
    echo "Please log in first:"
    echo "  For US Cloud:      bw login"
    echo "  For EU Cloud:      bw config server https://vault.bitwarden.eu && bw login"
    echo "  For Self-hosted:   bw config server https://your-server.com && bw login"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Logged in to Bitwarden${NC}"

# Check session token
if [ -z "$SESSION" ]; then
    if [ -z "$BW_SESSION" ]; then
        echo -e "${YELLOW}No session token provided.${NC}"
        echo "Please unlock your vault or provide a session token:"
        read -sp "Enter session token (or press Enter to unlock now): " SESSION
        echo ""
        
        if [ -z "$SESSION" ]; then
            echo -e "${BLUE}Unlocking vault...${NC}"
            SESSION=$(bw unlock --raw)
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to unlock vault${NC}"
                exit 1
            fi
        fi
    else
        SESSION="$BW_SESSION"
    fi
fi

export BW_SESSION="$SESSION"

# Test session validity
echo -e "${BLUE}Verifying session...${NC}"
if ! bw sync &> /dev/null; then
    echo -e "${RED}Error: Invalid session token or vault is locked${NC}"
    echo "Please unlock your vault with: bw unlock"
    exit 1
fi
echo -e "${GREEN}✓ Session verified${NC}"

# Function to list organizations
list_organizations() {
    echo -e "${BLUE}Fetching organizations...${NC}"
    orgs=$(bw list organizations)
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to fetch organizations${NC}"
        exit 1
    fi
    
    org_count=$(echo "$orgs" | jq 'length')
    
    if [ "$org_count" -eq 0 ]; then
        echo -e "${YELLOW}No organizations found in your account${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${GREEN}Available Organizations:${NC}"
    echo "=================================================="
    echo "$orgs" | jq -r '.[] | "\(.id) - \(.name)"' | while IFS= read -r line; do
        echo "  $line"
    done
    echo "=================================================="
    echo ""
    echo "Total organizations: $org_count"
    echo ""
    echo "To download attachments, use:"
    echo "  $0 --org-id <ORG_ID>"
}

# If list-orgs flag is set, list organizations and exit
if [ "$LIST_ORGS" = true ]; then
    list_organizations
    exit 0
fi

# If list-orgs flag is set, list organizations and exit
if [ "$LIST_ORGS" = true ]; then
    list_organizations
    exit 0
fi

# Get vault type if not provided
if [ -z "$VAULT_TYPE" ]; then
    echo ""
    echo -e "${BLUE}Select vault type:${NC}"
    echo "1) Personal vault"
    echo "2) Organization vault"
    read -p "Enter choice [1-2]: " vault_choice
    
    case $vault_choice in
        1) VAULT_TYPE="personal" ;;
        2) VAULT_TYPE="org" ;;
        *)
            echo -e "${RED}Invalid selection${NC}"
            exit 1
            ;;
    esac
fi

# Validate vault type
if [ "$VAULT_TYPE" != "personal" ] && [ "$VAULT_TYPE" != "org" ]; then
    echo -e "${RED}Error: Invalid vault type '$VAULT_TYPE'. Must be 'personal' or 'org'${NC}"
    exit 1
fi

echo -e "${GREEN}Vault type: $VAULT_TYPE${NC}"

# Handle organization vault setup
if [ "$VAULT_TYPE" = "org" ]; then
    # Get organization ID if not provided
    if [ -z "$ORG_ID" ]; then
        echo ""
        echo -e "${BLUE}Fetching organizations...${NC}"
        orgs=$(bw list organizations)
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}Error: Failed to fetch organizations${NC}"
            exit 1
        fi
        
        org_count=$(echo "$orgs" | jq 'length')
        
        if [ "$org_count" -eq 0 ]; then
            echo -e "${RED}Error: No organizations found in your account${NC}"
            exit 1
        fi
        
        echo ""
        echo -e "${GREEN}Available Organizations:${NC}"
        echo "=================================================="
        echo "$orgs" | jq -r 'to_entries[] | "\(.key + 1)) \(.value.name) (ID: \(.value.id))"'
        echo "=================================================="
        echo ""
        
        if [ "$org_count" -eq 1 ]; then
            # Auto-select if only one org
            ORG_ID=$(echo "$orgs" | jq -r '.[0].id')
            ORG_NAME=$(echo "$orgs" | jq -r '.[0].name')
            echo -e "${GREEN}Only one organization found, auto-selecting: $ORG_NAME${NC}"
        else
            # Prompt user to select
            read -p "Enter organization number [1-$org_count]: " org_choice
            
            if ! [[ "$org_choice" =~ ^[0-9]+$ ]] || [ "$org_choice" -lt 1 ] || [ "$org_choice" -gt "$org_count" ]; then
                echo -e "${RED}Invalid selection${NC}"
                exit 1
            fi
            
            ORG_ID=$(echo "$orgs" | jq -r ".[$((org_choice - 1))].id")
            ORG_NAME=$(echo "$orgs" | jq -r ".[$((org_choice - 1))].name")
            echo -e "${GREEN}Selected organization: $ORG_NAME${NC}"
        fi
    else
        # Validate provided org ID
        orgs=$(bw list organizations)
        ORG_NAME=$(echo "$orgs" | jq -r ".[] | select(.id == \"$ORG_ID\") | .name")
        
        if [ -z "$ORG_NAME" ] || [ "$ORG_NAME" = "null" ]; then
            echo -e "${RED}Error: Organization ID '$ORG_ID' not found${NC}"
            echo ""
            echo "Run with --list-orgs to see available organizations"
            exit 1
        fi
        
        echo -e "${GREEN}Using organization: $ORG_NAME${NC}"
    fi
    
    # Set default download directory for org
    if [ -z "$DOWNLOAD_DIR" ]; then
        default_dir="~/Downloads/bitwarden-org-attachments/$ORG_NAME"
        read -p "Enter download directory (default: $default_dir): " user_dir
        DOWNLOAD_DIR=${user_dir:-$default_dir}
    fi
else
    # Personal vault mode
    echo -e "${GREEN}Using personal vault${NC}"
    
    # Set default download directory for personal
    if [ -z "$DOWNLOAD_DIR" ]; then
        default_dir="~/Downloads/bitwarden-personal-attachments"
        read -p "Enter download directory (default: $default_dir): " user_dir
        DOWNLOAD_DIR=${user_dir:-$default_dir}
    fi
fi

# Expand tilde
DOWNLOAD_DIR="${DOWNLOAD_DIR/#\~/$HOME}"

# Create directory
mkdir -p "$DOWNLOAD_DIR"
if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Could not create directory $DOWNLOAD_DIR${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=================================================="
echo "Bitwarden Vault Attachment Downloader"
echo "==================================================${NC}"
if [ "$VAULT_TYPE" = "org" ]; then
    echo "Vault type: Organization"
    echo "Organization: $ORG_NAME"
    echo "Organization ID: $ORG_ID"
else
    echo "Vault type: Personal"
fi
echo "Download directory: $DOWNLOAD_DIR"
echo ""

# Get all items based on vault type
if [ "$VAULT_TYPE" = "org" ]; then
    echo -e "${BLUE}Fetching items from organization vault...${NC}"
    items=$(bw list items --organizationid "$ORG_ID")
else
    echo -e "${BLUE}Fetching items from personal vault...${NC}"
    # For personal vault, we need to filter items where organizationId is null
    items=$(bw list items | jq '[.[] | select(.organizationId == null)]')
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to fetch items from vault${NC}"
    exit 1
fi

item_count=$(echo "$items" | jq 'length')
echo -e "${GREEN}✓ Found $item_count items in vault${NC}"
echo ""

# Loop through each item
total_attachments=0
downloaded_attachments=0
failed_attachments=0

while IFS= read -r item; do
    item_id=$(echo "$item" | jq -r '.id')
    item_name=$(echo "$item" | jq -r '.name')
    attachments=$(echo "$item" | jq -c '.attachments // []')
    
    # Check if item has attachments
    attachment_count=$(echo "$attachments" | jq 'length')
    
    if [ "$attachment_count" -gt 0 ]; then
        echo -e "${BLUE}Item: $item_name${NC}"
        echo "  Found $attachment_count attachment(s)"
        
        # Sanitize item name for use in filename
        sanitized_item_name=$(sanitize_filename "$item_name")
        
        # Loop through each attachment
        while IFS= read -r attachment; do
            att_id=$(echo "$attachment" | jq -r '.id')
            att_filename=$(echo "$attachment" | jq -r '.fileName')
            att_size=$(echo "$attachment" | jq -r '.size // "unknown"')
            
            # Create prefixed filename: ItemName_originalfilename.ext
            prefixed_filename="${sanitized_item_name}_${att_filename}"
            
            # Convert size to human readable
            if [ "$att_size" != "unknown" ] && [ "$att_size" != "null" ] && [ "$BC_AVAILABLE" = true ]; then
                att_size_mb=$(echo "scale=2; $att_size / 1048576" | bc)
                echo "  Downloading: $att_filename → $prefixed_filename (${att_size_mb} MB)"
            else
                echo "  Downloading: $att_filename → $prefixed_filename"
            fi
            
            # Download attachment with prefixed filename
            if bw get attachment "$att_id" --itemid "$item_id" --output "$DOWNLOAD_DIR/$prefixed_filename" 2>/dev/null; then
                echo -e "  ${GREEN}✓ Successfully downloaded: $prefixed_filename${NC}"
                ((downloaded_attachments++))
            else
                echo -e "  ${RED}✗ Failed to download: $prefixed_filename${NC}"
                ((failed_attachments++))
            fi
            
            ((total_attachments++))
        done < <(echo "$attachments" | jq -c '.[]')
        echo ""
    fi
done < <(echo "$items" | jq -c '.[]')

echo -e "${BLUE}==================================================${NC}"
echo -e "${GREEN}Download complete!${NC}"
if [ "$VAULT_TYPE" = "org" ]; then
    echo "Organization: $ORG_NAME"
else
    echo "Vault type: Personal"
fi
echo "Files saved to: $DOWNLOAD_DIR"
echo ""
echo "Summary:"
echo "  Total attachments found: $total_attachments"
echo "  Successfully downloaded: $downloaded_attachments"
if [ $failed_attachments -gt 0 ]; then
    echo -e "  ${RED}Failed: $failed_attachments${NC}"
fi
echo ""
