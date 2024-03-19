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

# Fetch the list of Members

$org_members = (Invoke-RestMethod -Method GET -Uri $api_url/public/members -Headers $headers) | Select-Object data
$values = $org_members.psobject.Properties.Value | Select-Object name,id,status,email

# For each Member, create a Collection, and then assign that Member to it

ForEach ($membervalues in $values) {

$membername = $membervalues.name
$memberid = $membervalues.id
$memberstatus = $membervalues.status
$memberemail = $membervalues.email

# Use the email address if there is no Name field

if ([string]::IsNullOrEmpty($membername)) {

$membername = $memberemail

}

# Check if the Collection already exists

$existingcollection = (bw --session $session_key list org-collections --organizationid $organization_id | jq -c --arg n "$membername" '.[] | select(.name == "$n")' | jq -r '.name')

if ($existingcollection -eq $membername) {

Write-Host "`n`n $membername already has a Collection, skipping"

}

else {

# Only create collections for Confirmed Members

if ($memberstatus -eq 2) {

$collectionid = (bw --session $session_key get template org-collection | jq --arg n "$membername" --arg c "$organization_id" '.name="$n" | .organizationId="$c" | del(.groups[1])' | bw encode | bw --session $session_key create org-collection --organizationid $organization_id | jq -r '.id')
$origmemberbody = Invoke-RestMethod -Method GET -Uri $api_url/public/members/$memberid -Headers $headers | ConvertTo-Json | jq 'del(.object)'
$newmemberbody = ($origmemberbody | jq --arg newcol "$collectionid" '.collections += [{"id": "$newcol", "readOnly": false, "hidePasswords": false, "manage": true}]')
$newmemberput = Invoke-RestMethod -Method PUT -Uri $api_url/public/members/$memberid -Headers $headers -Body $newmemberbody
Write-Host "`n`n Created Collection for $membername"

}

# If the Member is not Confirmed, restart the loop

else {

Write-Host "`n`n $memberemail is not Confirmed, skipping"

}

}

}
