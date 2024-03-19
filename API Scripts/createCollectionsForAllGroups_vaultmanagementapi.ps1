# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"

# Set your bw serve / Vault Management API URL

$vaultapiurl = "http://localhost:3000"

# Make sure we're in sync right away, outside of any loops

Invoke-RestMethod -Method Post -Uri $vaultapiurl/sync | Out-Null

# Handle Public API URLs

$organization_id = "YOUR-ORG-ID" # Set your Org ID
$cloud_flag = 1 # Self-hosted Bitwarden or Cloud?
if ($cloud_flag -eq 1) {
    $public_api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
}
else {
    $public_api_url = "https://YOUR-FQDN/api" # Set your Self-Hosted API URL
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

$org_groups = (Invoke-RestMethod -Method GET -Uri $public_api_url/public/groups -Headers $publicApiheaders) | Select-Object data
$values = $org_groups.psobject.Properties.Value | Select-Object name,id

# For each Group, create a Collection, and then assign that Group to it

ForEach ($groupvalues in $values) {

$groupname = $groupvalues.name
$groupid = $groupvalues.id

# Check if the Collection already exists

$org_collections = (Invoke-RestMethod -Method Get -Uri "$vaultapiurl/list/object/org-collections?organizationid=$organization_id&search=$groupname")
$org_collections_data = $org_collections.data | select-object -expandproperty data | select-object -expandproperty name

if ($org_collections_data -ne $null) {

Write-Host "`n`n $groupname already has a Collection, skipping"

}

else {

# It doesn't exist, so let's go ahead
# Set up the body for the Vault Management API request

$vaultApiGroupObject = @(@{id=$groupid;readOnly=$False;hidePasswords=$False})
$vaultApiBody = @{organizationId=$organization_id;name=$groupname;externalId=$null;groups=$vaultApiGroupObject} | ConvertTo-Json -Compress

# Create the Collection for the Group and assign it

Invoke-RestMethod -Method POST -ContentType "application/json" -Uri "$vaultapiurl/object/org-collection?organizationid=$organization_id" -Body $vaultApiBody | Out-Null
Write-Host "`n`n Created Collection for $groupname"

}
}
