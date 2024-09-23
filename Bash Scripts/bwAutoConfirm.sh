#!/bin/bash

BW_PATH=""
JQ_PATH=""
SECURE_STR="Secret@Bitwarden#88"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_FILE="user_config.yml"

# Mode for the setup. 
# For future developemt
# API : API Only
# CLI : CLI Only
# BOTH : Both API and CLI Only
#mode="API"

# Function to get the full path of bw
get_bw_path() {
  # Check if bw is in the PATH
  if command -v bw &> /dev/null; then
    # If bw is found in the PATH, store the full path in the global variable
    BW_PATH=$(command -v bw)
  else
    # If bw is not found in the PATH, check if it's in the same directory as the script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    if [ -f "$SCRIPT_DIR/bw" ]; then
      # If bw is found in the same directory as the script, store the full path in the global variable
      BW_PATH="$SCRIPT_DIR/bw"
    else
      # If bw is not found, print an error message
      echo "bw not found in PATH or in the same directory as the script."
      exit 1
    fi
  fi
}

# Function to get the full path of bw
get_jq_path() {
  # Check if bw is in the PATH
  if command -v jq &> /dev/null; then
    # If bw is found in the PATH, store the full path in the global variable
    JQ_PATH=$(command -v jq)
  else
    # If bw is not found in the PATH, check if it's in the same directory as the script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
    if [ -f "$SCRIPT_DIR/jq" ]; then
      # If bw is found in the same directory as the script, store the full path in the global variable
      JQ_PATH="$SCRIPT_DIR/jq"
    else
      # If bw is not found, print an error message
      echo "jq not found in PATH or in the same directory as the script."
      exit 1
    fi
  fi
}

# Function to get the full path of openssl
check_openssl() {
  # Check if bw is in the PATH
  if ! command -v openssl &> /dev/null; then
    echo "OpenSSL is not installed."
    exit 1
  fi
}

encrypt_text() {
  local plaintext="$1"

  if [ -z "$plaintext" ]; then
    echo "Error: No text provided for encryption."
    return 1
  fi

  echo "$plaintext" | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:"$SECURE_STR"
}

decrypt_text() {
  local encrypted_text="$1"

  if [ -z "$encrypted_text" ]; then
    echo "Error: No encrypted text provided for decryption."
    return 1
  fi

  if [ -z "$SECURE_STR" ]; then
    echo "Error: SECURE_STR is not set."
    return 1
  fi

  echo "$encrypted_text" | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -d -salt -pass pass:"$SECURE_STR"
}

server_url_menu() {
  echo "Please select your Region:"
  echo "1) US"
  echo "2) EU"
  echo "3) Self-hosted"

  read -p "Enter your choice: " choice
  
  case $choice in
    1)
      server_url="https://vault.bitwarden.com/"
      ;;
    2)
      server_url="https://vault.bitwarden.eu/"
      ;;
    3)
      read -p "Please enter your self-hosted address (https://webapp.domain.com): " custom_region
      server_url=$custom_region
      ;;
    *)
      echo "Invalid option. Please try again."
      show_menu
      ;;
  esac
}


# Function to write user-provided configs to a YAML file
write_configs() {
  local config_file="$1"
  server_url_menu

  # Prompt the user for input
  read -p "Enter your user client ID e.g. user.xxx-xxx-xx: " user_client_id
  read -sp "Enter your user API secret: " user_client_secret
  echo  # Newline for better formatting
  read -sp "Enter the account Master Password: " user_master_password
  echo  # Newline for better formatting
  read -p "Enter your organization ID e.g. xxx-xxx-xx: " org_id

  encrypted_client_secret=$(encrypt_text $user_client_secret)
  encrypted_master_pass=$(encrypt_text $user_master_password)

  # Write the input to the YAML file
  cat > "$config_file" <<EOL
server: $server_url  
user_client_id: $user_client_id
user_client_secret: $encrypted_client_secret
user_master_pass: $encrypted_master_pass
org_id: $org_id
EOL

  echo "Configurations written to $config_file."
}

# Function to read configs from a YAML file and store them into variables
read_configs() {
  local config_file="$1"

  if [ ! -f "$config_file" ]; then
    echo "Configuration file '$config_file' does not exist."
    return 1
  fi

  while IFS=":" read -r key value; do
    # Skip empty lines and comments
    if [[ -z "$key" || "$key" =~ ^\s*# ]]; then
      continue
    fi

    # Remove leading/trailing whitespaces and quotes
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs | sed -e 's/^"//' -e 's/"$//')

    # Dynamically export variables
    export "$key"="$value"
  done < "$config_file"

}

get_bw_path
get_jq_path
check_openssl


if [ ! -f "$SCRIPT_DIR/$CONFIG_FILE" ]; then
  # Config File is not found. Write user-provided configs to the YAML file
  write_configs "$CONFIG_FILE"
fi


# Read and assign configs to variables
read_configs "$CONFIG_FILE"

plain_user_secret=$(decrypt_text $user_client_secret)
plain_user_pass=$(decrypt_text $user_master_pass)

$BW_PATH --quiet logout
$BW_PATH --quiet config server $server
export BW_CLIENTID=$user_client_id
export BW_CLIENTSECRET=$plain_user_secret
export BW_PASSWORD=$plain_user_pass
$BW_PATH --quiet login --apikey
BW_SESSION=""
BW_SESSION=$($BW_PATH unlock --passwordenv BW_PASSWORD --raw)

if [ -z "$BW_SESSION" ]; then
  echo "Login failed. Session is still empty"
  return 1
fi

#empty env vars that are not needed
export BW_CLIENTID=""
export BW_CLIENTSECRET=""
export BW_PASSWORD=""

export BW_SESSION=$BW_SESSION

org_members="$($BW_PATH list org-members --organizationid $org_id | $JQ_PATH -c '.[] | select( .status == 1 )' | $JQ_PATH -c '.id' | tr -d '"')"
for member_id in ${org_members[@]} ; do
	$BW_PATH confirm  org-member $member_id --organizationid $org_id
done

$BW_PATH --quiet logout

export BW_SESSION=""
