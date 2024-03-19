# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
# jq is required in $PATH https://stedolan.github.io/jq/download/

$organization_id = "c4cb0c6d-d84e-4a6c-a748-aeda0142df3a" # Set your Org ID
$cloud_flag = 0 # Self-hosted Bitwarden or Cloud?
if ($cloud_flag -eq 1) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
}
else {
    $api_url = "https://demo.b7n.dog/api" # Set your Self-Hosted API URL
    $identity_url = "https://demo.b7n.dog/identity" # Set your Self-Hosted Identity URL
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

$org_members = (Invoke-RestMethod -Method GET -Uri $api_url/public/members -Headers $headers) | ConvertTo-Json | jq -c '.data[] | select( .status == 0 )' | jq -c '.id'

ForEach ($member_id in $org_members.trim('"')) {
 Invoke-RestMethod -Method DELETE -Uri $api_url/public/members/$member_id -Headers $headers
}
