# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"

# Set your bw serve / Vault Management API URL

$vaultapiurl = "http://localhost:3000"

# Make sure we're in sync right away, outside of any loops

Invoke-RestMethod -Method Post -Uri $vaultapiurl/sync | Out-Null

# Handle API URLs

$organization_id = "" # Set your Org ID
$cloud_flag = 1 # Self-hosted Bitwarden or Cloud?
if ($cloud_flag -eq 1) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
}
else {
    $api_url = "https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    $identity_url = "https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
}

# Set up Public API auth

$org_client_secret = Get-Content "secureString_secret.txt" | ConvertTo-SecureString
$client_creds = New-Object System.Management.Automation.PSCredential "null", $org_client_secret
$org_client_secret_key =  , $client_creds.GetNetworkCredential().password
$org_client_id = "organization." + $organization_id

# Get Access Token

$publicApibody = "grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$org_client_secret_key"
$publicApibearer_token = (Invoke-RestMethod -Method POST -Uri $identity_url/connect/token -Body $publicApibody).access_token

$publicApiheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$publicApiheaders.Add('Authorization',('Bearer {0}' -f $publicApibearer_token))
$publicApiheaders.Add('Accept','application/json')
$publicApiheaders.Add('Content-Type','application/json')

# Fetch the list of Groups

$org_groups = (Invoke-RestMethod -Method GET -Uri $api_url/public/groups -Headers $publicApiheaders) | Select-Object data
$group_values = $org_groups.psobject.Properties.Value | Select-Object name,id

# Fetch the list of Collections

$org_collections = (Invoke-RestMethod -Method GET -Uri $api_url/public/collections -Headers $publicApiheaders) | Select-Object data
$collection_values = $org_collections.psobject.Properties.Value | Select-Object name,id

# For each Group, list its assigned Collections

ForEach ($groupvalues in $group_values) {

	$groupname = $groupvalues.name
	$groupid = $groupvalues.id
	$retrievegroup = (Invoke-RestMethod -Method GET -Uri $api_url/public/groups/$groupid -Headers $publicApiheaders) | Select-Object collections

	Write-Host "`n${groupname} Group has Collection access to:"

	if ($retrievegroup.psobject.Properties.Value -ne $null) {

	# Iterate over the Collection IDs and fetch the Collection Name

		ForEach ($collection_for_group in $retrievegroup.psobject.Properties.Value) {

			$this_collection_id = $collection_for_group.id
			$collection_name_lookup = (Invoke-RestMethod -Method Get -Uri "${vaultapiurl}/object/org-collection/${this_collection_id}?organizationId=${organization_id}")
			$collection_object = @{name=$collection_name_lookup.psobject.Properties.Value.name;readOnly=$collection_name_lookup.psobject.Properties.Value.groups.readOnly;hidePasswords=$collection_name_lookup.psobject.Properties.Value.groups.hidePasswords}
			$collection_name = $collection_object.name
			$collection_read_only = $collection_object.readOnly
			$collection_hide_passwords = $collection_object.hidePasswords

			Write-Host "`n `t ${collection_name}, Read Only: ${collection_read_only}, Hide Passwords: ${collection_hide_passwords}"
		}
	}

	# Handle Groups with no Collections

	else {

		Write-Host "`n `t No Collections for $groupname"

	}
}
