#	Script:			bwUpdateOrganization.ps1
#	Date:			20250604
#	Description: 	Adapted from scripts found here - https://github.com/bitwarden-labs/admin-scripts/tree/main/Powershell
#					Creates collection for new users, assigns Administrator group to all collections, moves collections created
#					at the root to nest under the first user with permissions
#					Optimizes functionality compared to original scripts by reducing calls to bw for each user
#
# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in and unlocked https://bitwarden.com/help/cli/

#log the script notices
Start-Transcript "" #set your transcript location

#####################################
#									#
#	Script setup section			#
#									#
#####################################

# Handle API URLs
$organization_id = "" # Set your Org ID
$cloud_flag = 1 # Self-hosted Bitwarden or Cloud?
if ($cloud_flag -eq 1) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
} else {
    $api_url = "https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    $identity_url = "https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
}

# Set up CLI and API auth
$org_client_secret = Get-Content "secureString_secret.txt" | ConvertTo-SecureString
$client_creds = New-Object System.Management.Automation.PSCredential "null", $org_client_secret
$org_client_secret_key =  , $client_creds.GetNetworkCredential().password
$org_client_id = "organization." + $organization_id

# Get Access Token
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Content-Type','application/x-www-form-urlencoded')
$body = "grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$org_client_secret_key"
$bearer_token = (Invoke-RestMethod -Method POST -Uri $identity_url/connect/token -Headers $headers -Body $body).access_token

if($bearer_token) { Write-Output "`n Bearer Token: Success"} else {Write-Output "Bearer Token: Failure"}

# update headers to use the bearer token
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Authorization',('Bearer {0}' -f $bearer_token))
$headers.Add('Accept','application/json')
$headers.Add('Content-Type','application/json')

# Perform CLI auth 
$env:BW_CLIENTID = "user.eb7998e6-ab5f-4027-8d0a-b2f0011b2af9" # service account client id
$password = Get-Content "secureString_UserSecret.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $password
$env:BW_CLIENTSECRET = , $cred.GetNetworkCredential().password # service account client secret
.\bw login --apikey

$password = Get-Content "secureString.txt" | ConvertTo-SecureString # service account master password
$cred = New-Object System.Management.Automation.PSCredential "null", $password
$session_key = , $cred.GetNetworkCredential().password | powershell -c '.\bw unlock --raw'

if($session_key) { Write-Output "`n Session Key: Success"} else {Write-Output "Session Key: Failure"}

# Fetch the list of Members and collections
$org_members = (Invoke-RestMethod -Method GET -Uri $api_url/public/members -Headers $headers) | Select-Object data
$values = $org_members.psobject.Properties.Value | Select-Object name,id,status,email
$orgCollections = (.\bw --session $session_key list org-collections --organizationid $organization_id)

#####################################
#									#
#	Configure new users				#
#									#
#####################################
# For each Member, create a Collection, and then assign that Member to it

$groupId = "" #set the Administrators group guid
$t = "^Users/.*$" # regex to use when filtering the collections, I tried renaming this one to $query and jq breaks, so it is staying $t
#filter to the base user collections
$userCollections = $orgCollections | .\jq -c --arg t "$t" '.[] | select(.name|test("$t"))'

ForEach ($membervalues in $values) {
	$membername = ($membervalues.email -split "@")[0] #ignore the name field, standardizing on the first part of the email address
	$memberid = $membervalues.id
	$memberstatus = $membervalues.status
	$memberemail = $membervalues.email
	$existingcollection = ""

	# Check if the Collection already exists
	$query = "Users/" + $membername
	$existingcollection = $userCollections -match $query
	
	#skip if the user exists or it is the Admin account, or the user is revoked
	if ($existingcollection -or ($membername -eq "Admin") -or ($memberstatus -eq -1)) {

		Write-Output "`n $membername already has a Collection, skipping"

	}
	else {

		#create the collection and add Administrators group to it
		#jq is inserting the values into the template
			#Get the template: 				(.\bw --session $session_key get template org-collection)
			#Set the jq variables: 			.\jq --arg n "$query" --arg c "$organization_id" --arg g "$groupId" --arg u "$memberid"
			#Insert into the json string: 	'.name="$n" | .organizationId="$c" | .groups[0].id="$g" | .groups[0].manage="true" | del(.groups[1]) | .users=[{"id":$u, "readOnly":false, "hidePasswords":false, "manage":true}]' 
			#Encode the json: 				| .\bw encode 
			#Create the collection:			| .\bw --session $session_key create org-collection --organizationid $organization_id 
			#Filter to new collection Id:	| .\jq -r '.id'
		$collectionid = (.\bw --session $session_key get template org-collection) | .\jq --arg n "$query" --arg c "$organization_id" --arg g "$groupId" --arg u "$memberid" '.name="$n" | .organizationId="$c" | .groups[0].id="$g" | .groups[0].manage="true" | del(.groups[1]) | .users=[{"id":$u, "readOnly":false, "hidePasswords":false, "manage":true}]' | .\bw encode | .\bw --session $session_key create org-collection --organizationid $organization_id | .\jq -r '.id'
		Write-Output "`n Created Collection for $membername"

	}

	#Confirm unconfirmed users - note this is not recommended, uncomment to use
	#if ($memberstatus -eq 1) {
	#	
	#	.\bw --session $session_key confirm org-member $memberid --organizationid $organization_id
	#	Write-Output "`n Confirmed user:  $membername"
	#}

}

#####################################
#									#
#	Configure nested collection		#
#		permissions					#
#									#
#####################################

Write-Output "`n Checking nested collection permissions and adding the Administrators group"
$t = "^Users/.*/.*"
$nestedCollections = $orgCollections | .\jq -c --arg t "$t" '.[] | select(.name|test("$t"))' | .\jq -r '.id'
$org_groups = (Invoke-RestMethod -Method GET -Uri $api_url/public/groups -Headers $headers) | Select-Object data
$adminGroupCollections = ($org_groups.data | where {$_.id -eq $groupId}).collections
$adminPermissionsWrong = $adminGroupCollections | where {($_.manage -eq $false) -or ($_.readOnly -eq $true) -or ($_.hidePasswords -eq $true)}

ForEach ($nestedCollection in $nestedCollections) {
	
	if ((!($adminGroupCollections -match $nestedCollection)) -or ($adminPermissionsWrong -match $nestedCollection)) {
		$updateCollection = (.\bw --session $session_key get org-collection "$nestedCollection" --organizationid $organization_id) | .\jq --arg i $groupId  '.groups+=[{"id": $i,"readOnly": "false","hidePasswords": "false","manage": "true"}]' | .\bw encode | .\bw --session $session_key edit org-collection "$nestedCollection"  --organizationid $organization_id
	}
}

#####################################
#									#
#	Move unnested collections		#
#									#
#####################################

Write-Output "`n Checking for un-nested collections"
$t = "^(Users|Archived Accounts|Default collection|Unassigned)"
$unnestedCollections = $orgCollections | .\jq -c --arg t "$t" '.[] | select(.name|test("$t")|not)' 
$unnestedCollections = $unnestedCollections | convertfrom-json

ForEach ($collection in $unnestedCollections) {
	$colId = $collection.id
	$colName = $collection.name
	$item = (.\bw --session $session_key get org-collection "$colId" --organizationid $organization_id)
	$itemGroups = $item | .\jq -r '.groups'
	$itemId = $item | .\jq -r '.id'
	$userId = $item | .\jq -r '.users[0].id'
	$user = ($values | where {$_.id -eq $userId}).email -split "@"
	$newName = "Users/" + $user[0] + "/$colName"
	
	if (!($itemGroups -match $groupId)) {
		$updateCollection = (.\bw --session $session_key get org-collection "$colId" --organizationid $organization_id) | .\jq --arg i $groupId --arg n $newName  '.groups+=[{"id": $i,"readOnly": "false","hidePasswords": "false","manage": "true"}] | .name=$n ' | .\bw encode | .\bw --session $session_key edit org-collection $itemId  --organizationid $organization_id
	} else {
		$updateCollection = (.\bw --session $session_key get org-collection "$colId" --organizationid $organization_id) | .\jq --arg n $newName  '.name=$n ' | .\bw encode | .\bw --session $session_key edit org-collection $itemId  --organizationid $organization_id
	}
}

#clear plaintext secrets
$env:BW_CLIENTID = ''
$env:BW_CLIENTSECRET = ''
$org_client_secret_key = ''
.\bw logout
$session_key = ''

Stop-Transcript