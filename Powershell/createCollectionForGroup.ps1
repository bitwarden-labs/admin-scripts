# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in https://bitwarden.com/help/cli/


# Set our command-line arguments; -group_name is the text name of the Group you synced
# -new_collection_name is the Collection you want to create and assign to that Group

param($group_name, $new_collection_name)

# Handle API URLs

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

# Perform CLI auth

$password = Get-Content "secureString.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $password
$session_key = , $cred.GetNetworkCredential().password | powershell -c 'bw unlock --raw'

# Fetch the list of Groups and get the ID of the one we want to modify

$org_groups = (Invoke-RestMethod -Method GET -Uri $api_url/public/groups -Headers $headers) | ConvertTo-Json
$my_group_id = $org_groups | jq -r --arg g "$group_name" '.data[] | select(.name == $g) | .id'

# Create the new Collection and associate the Group

bw --session $session_key get template org-collection | jq --arg n "$new_collection_name" --arg c "$organization_id" --arg g "$my_group_id" '.name="$n" | .organizationId="$c" | .groups[0].id="$g" | del(.groups[1])' | bw encode | bw --session $session_key create org-collection --organizationid $organization_id
