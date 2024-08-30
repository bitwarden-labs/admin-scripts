#!/bin/bash

# Depends on file "secureString.txt" and "secureString_secret.txt" which can be created by first running:
# echo 'YOUR_MASTER_PASSWORD' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:Secret@Bitwarden#99 > secureString.txt
# Depends on file "secureString_secret.txt" which can be created by first running:
# echo 'YOUR_PERSONAL_SECRET_KEY' | openssl enc -aes-256-cbc -md sha512 -a -pbkdf2 -iter 600001 -salt -pass pass:Secret@Bitwarden#99 > secureString_secret.txt
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/
# openssl is required in $PATH https://www.openssl.org/


# !!!!!!!!!!!!!!!!!!!!!!!!
# FILL IN THESE VARIABLES

bw_clientid="user.0263352c-8d55-4cad-ae38-aff7017deee4" #fill this with your Personal API client id. it starts with user.
organization_id="1f0c58c3-a3d8-48b2-bb3a-ac8c0075bcc6" # Set your Org ID
exformat="json" #format of the export
expath="./bw_export.json" #FULL path to save the export


if ! command -v bw > /dev/null 2>&1; then
  echo "Bitwarden CLI (bw) is not available on your system. Exiting..."
  echo "Ensure the directory location is set in the \$PATH variable."
  exit 2
fi


if ! command -v jq > /dev/null 2>&1; then
  echo "Command Line JSON processor (jq) is not available on your system. Exiting..."
  echo "Ensure the directory location is set in the \$PATH variable."
  exit 2
fi

if [[ ! -e "./secureString.txt" ]]; then
    echo "Password file does not exist."
    exit 1
fi

if [[ ! -e "./secureString_secret.txt" ]]; then
    echo "Secret Password file does not exist."
    exit 1
fi



personal_client_secret=$(cat secureString_secret.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600001 \
 -salt -pass pass:Secret@Bitwarden#99)

password=$(cat secureString.txt | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 600001 \
 -salt -pass pass:Secret@Bitwarden#99)
 


#export API id and secret
export BW_CLIENTID=$bw_clientid
export BW_CLIENTSECRET=$personal_client_secret

output=$(bw status)  # Run the command and store the output

if [[ $output == *"unauthenticated"* ]]; then  # Check if the output contains the word "locked"
  bw login --apikey --raw
fi


session_key=$(bw unlock $password --raw)
bw export $user_pass --output $expath --format $exformat --organizationid $organization_id --session $session_key

bw logout
