# Prompt for input

$cloud_flag = 1 # Self-hosted Bitwarden or Cloud?
if ($cloud_flag -eq 1) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
}
else {
    $api_url = "https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    $identity_url = "https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
}

$org_client_id = Read-Host 'Organization Client ID'
$org_client_secret_hidden = Read-Host 'Organization Client Secret (Hidden)' -AsSecureString
# Convert the secure string to plain text (for simplicity)
$org_client_secret = [System.Net.NetworkCredential]::new('', $org_client_secret_hidden).Password


$response = Invoke-RestMethod -Method Post -Uri "$identity_url/connect/token" -Headers @{ 'Content-Type' = 'application/x-www-form-urlencoded' } -Body "grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$org_client_secret"


$ACCESS_TOKEN = $response.access_token

# Querying the groups and saving the 'id' and 'name' in a JSON file for reference later
$groups = Invoke-RestMethod -Uri "$api_url/public/groups" -Headers @{ "Authorization" = "Bearer $ACCESS_TOKEN" }
$groups.data | Select-Object id, name | ConvertTo-Json | Set-Content -Path "groups.json"

# Function to get group name by ID
function Get-GroupNameById {
    param (
        [string]$group_id
    )

    $allGroups = Get-Content -Path "groups.json" | ConvertFrom-Json
    return ($allGroups | Where-Object { $_.id -eq $group_id }).name
}

# Get the org_members
$org_members = Invoke-RestMethod -Method Get -Uri "$api_url/public/members/" -Headers @{ 'Authorization' = "Bearer $ACCESS_TOKEN" }

# Output
Write-Output "email,role,status,groups"
foreach ($member in $org_members.data) {
    $userid = $member.id
	$email = $member.email
    $role = $member.type
    $status = $member.status

    # Map status
    switch ($status) {
        '0'  { $status = "invited" }
        '1'  { $status = "accepted" }
        '2'  { $status = "confirmed" }
        '-1' { $status = "revoked" }
        default { $status = "unknown" }
    }

    # Map role
    switch ($role) {
        '0' { $role = "Owner" }
        '1' { $role = "Admin" }
        '2' { $role = "User" }
        '3' { $role = "Manager" }
        '4' { $role = "Custom Admin" }
        default { $role = "unknown" }
    }

	$group_ids = Invoke-RestMethod -Uri "$api_url/public/members/$userid/group-ids" -Headers @{ 'Authorization' = "Bearer $ACCESS_TOKEN" }

	# Construct the semicolon-separated group names
	$group_names = @()
	foreach ($group_id in $group_ids) {
		$group_name = Get-GroupNameById -group_id $group_id
		if ($group_name) {
			$group_names += $group_name
		}
	}

	# Join the group names with semicolon
	$semicolon_separated_names = ($group_names -join ";")


    Write-Output "$email,$role,$status,$semicolon_separated_names"
}

Remove-Item -Path "groups.json" -Force