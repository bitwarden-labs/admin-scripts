# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/

# Set our command-line argument, we're looking for a -collection_name

param($collection_name)

# Setup: Fill in your Organization ID (in the Web App, navigate to Organizations and it's between
# /organizations/ and /vault in the address bar
# Specify whether you are Cloud or self-hosted
# TODO: EU
# Specify where you would like to save the Bitwarden JSON import file

$organization_id = "YOUR-ORG-ID" # Set your Org ID
$cloud_flag = 1 # Self-hosted Bitwarden or Cloud?
if ($cloud_flag -eq 1) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
}
else {
    $api_url = "https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    $identity_url = "https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
}

$json_path = "C:\temp\collection.json"

# Set up CLI and API auth

$org_client_secret = Get-Content "secureString_secret.txt" | ConvertTo-SecureString
$client_creds = New-Object System.Management.Automation.PSCredential "null", $org_client_secret
$org_client_secret_key =  , $client_creds.GetNetworkCredential().password
$org_client_id = "organization." + $organization_id

# Get Access Token

$body = "grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$org_client_secret_key"
$bearer_token = (Invoke-RestMethod -Method POST -Uri $identity_url/connect/token -Body $body).access_token

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Authorization',('Bearer {0}' -f $bearer_token))
$headers.Add('Accept','application/json')
$headers.Add('Content-Type','application/json')

# Perform CLI and API auth

$password = Get-Content "secureString.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $password
$session_key = , $cred.GetNetworkCredential().password | powershell -c 'bw unlock --raw'

# Get the Collection ID

$collection_id = bw --session $session_key list org-collections --organizationid $organization_id | jq -r --arg c "$collection_name" '.[] | select(.name == $c) | .id'

# Fetch and write the data

Write-Host "Creating backup file for $collection_name in $json_path"
$item_data = "{`"encrypted`":false,`"collections`":["
$item_data += bw --session $session_key export --format json --raw --organizationid $organization_id | jq -c --arg c "$collection_id" '.collections[] | select(.id == $c)'
$item_data += "], `"items`": ["
$item_data += bw --session $session_key list items | jq -c --arg c "$collection_id" '.[] | select(.collectionIds[] == $c)'
$item_data += "]}"

$item_data | Out-File -FilePath $json_path
