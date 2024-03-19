# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in but you do not have to unlock it https://bitwarden.com/help/cli/

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

# Fetch the list of Groups

$org_groups = (Invoke-RestMethod -Method GET -Uri $api_url/public/groups -Headers $headers) | Select-Object data
$group_values = $org_groups.psobject.Properties.Value | Select-Object name,id

# Fetch the list of Collections

$org_collections = (Invoke-RestMethod -Method GET -Uri $api_url/public/collections -Headers $headers) | Select-Object data
$collection_values = $org_collections.psobject.Properties.Value | Select-Object name,id

# For each Group, list its assigned Collections

	ForEach ($groupvalues in $group_values) {

	$groupname = $groupvalues.name
	$groupid = $groupvalues.id
	$retrievegroup = (Invoke-RestMethod -Method GET -Uri $api_url/public/groups/$groupid -Headers $headers) | Select-Object collections

	# Iterate over the Collection IDs and fetch the Collection Name
	$collection_name = @()
	ForEach ($collection_for_group in $retrievegroup.psobject.Properties.Value) {

		$collection_id_for_lookup = $collection_for_group | Select-Object id | ConvertTo-Json | jq -r '.id'
		$collection_name += (bw --session $session_key get org-collection $collection_id_for_lookup --organizationid $organization_id | jq -r '.name')

	}

	Write-Host "`n`n $groupname Group has Collection access to:"
	Write-Host $collection_name -Separator ([environment]::NewLine)

}
