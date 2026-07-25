<#
.SYNOPSIS
Creates collection for new users, assigns Administrator group to all collections, moves collections created 
    at the root to nest under the first user with permissions, and archives collections belonging to revoked users
    Optimizes functionality compared to original scripts by reducing calls to bw for each user

.PARAMETER ORG_ID
    Required, The UUID format organization ID for Bitwarden (e.g., "9d3210e3-385c-4c76-ad72-b1f5013a8cc2").
	
.PARAMETER CLIENT_ID
    Required, The UUID format client ID for the user performing CLI actions (e.g., "9d3210e3-385c-4c76-ad72-b1f5013a8cc2").

.PARAMETER ADMIN_GROUP_ID
    Optional, The UUID of the Bitwarden Administrator group to apply to all collections.

.PARAMETER USER_COLLECTION_BASE_PATH
    Optional, The collection to nest all user collections within (default: "Users").

.PARAMETER ARCHIVE_COLLECTION_BASE_PATH
    Optional, The collection to nest all user collections within (default: "Archived Accounts").

.PARAMETER USER_SKIP_LIST
    Optional, List of users to skip when creating default collections. Used when default collection name does not match the username (default: "Admin").
	
.PARAMETER COLLECTION_SKIP_LIST
    Optional, List of collections to skip when evaluating base level collections for nesting (default: "Archived Accounts,Company,Default collection,Unassigned,Users").
	
.PARAMETER LOG_FILE
    Optional, Log file for storing script actions.
	
.PARAMETER SELF_HOSTED_DOMAIN
    Optional, The base URI of the Bitwarden instance.

.EXAMPLE
	.\Maintain-BitwardenOrganization.ps1 -ORG_ID "9d3210e3-385c-4c76-ad72-b1f5013a8cc2" -CLIENT_ID "your-client-id" -ADMIN_GROUP_ID "your-admin-group-uuid" -LOG_FILE "LOG_Maintain-BitwardenOrganization.txt"
	Creates new personal collections for members under the "Users" collection, checks that the admin group can manage all collections, moves collections
	that aren't in the default list of base collections to skip, and archives personal collections for revoked members.

.EXAMPLE
	.\Maintain-BitwardenOrganization.ps1 -ORG_ID "your-org-uuid" -CLIENT_ID "your-client-id" -ADMIN_GROUP_ID "your-admin-group-uuid" -USER_COLLECTION_BASE_PATH "Members" -ARCHIVE_COLLECTION_BASE_PATH "Boneyard"
	Sets the base path for personal collections to "Members" and the archive path to "Boneyard"

.EXAMPLE
	.\Maintain-BitwardenOrganization.ps1 -ORG_ID "your-org-uuid" -CLIENT_ID "your-client-id" -ADMIN_GROUP_ID "your-admin-group-uuid" -ARCHIVE_COLLECTION_BASE_PATH "Boneyard" -USER_SKIP_LIST "Peregrine,Meriadoc"
	Sets the archive path to "Boneyard" and skips creating a personal collection for the users "Peregrine" and "Meriadoc"

.EXAMPLE
	.\Maintain-BitwardenOrganization.ps1 -ORG_ID "your-org-uuid" -CLIENT_ID "your-client-id" -ADMIN_GROUP_ID "your-admin-group-uuid" -USER_SKIP_LIST "Peregrine,Meriadoc" -$COLLECTION_SKIP_LIST "Boneyard,Company,Default collection,Unassigned,Members"
	Sets the archive path to "Boneyard" and skips creating a personal collection for the users "Peregrine" and "Meriadoc"

.NOTES
	jq is required in $PATH https://stedolan.github.io/jq/download/
	bw is required in $PATH and logged in and unlocked https://bitwarden.com/help/cli/
	
	Depends on file "secureString_masterPassword.txt" which can be created by first running:
	Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_masterPassword.txt"
	
	Depends on file "secureString_orgSecret.txt" which can be created by first running:
	Read-Host "Enter org_client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_orgSecret.txt"
	
	Depends on file "secureString_userSecret.txt" which can be created by first running:
	Read-Host "Enter user_client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_userSecret.txt"
	
	If changing USER_COLLECTION_BASE_PATH or ARCHIVE_COLLECTION_BASE_PATH, it may be better to change the script default values
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$ORG_ID,
	
	[Parameter(Mandatory=$true)]
	[string]$CLIENT_ID,
	
	[Parameter(Mandatory=$true)]
	[string]$ADMIN_GROUP_ID,
	
	[string]$USER_COLLECTION_BASE_PATH = "Users",
	
	[string]$ARCHIVE_COLLECTION_BASE_PATH = "Archived Accounts",
	
	[string]$USER_SKIP_LIST = "Admin",
	
	[string]$COLLECTION_SKIP_LIST = "Archived Accounts,Company,Default collection,Unassigned,Users",
	
	[string]$LOG_FILE,
		
	[string]$SELF_HOSTED_DOMAIN
)

# Convert secure strings to plain text
function ConvertFrom-SecureStringPlain {
    param ([SecureString]$SecureString)
    return [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    )
}

# API/CLI authentication and session setup
function Authenticate-Bitwarden {
    param (
        [string]$OrgId
    )
	
    Write-Output "`n Authenticating with Bitwarden API..."
	
    # Set up API auth
	$orgClientSecret = Get-Content "secureString_orgSecret.txt" | ConvertTo-SecureString
	$orgClientSecretKey = ConvertFrom-SecureStringPlain($orgClientSecret)
	
	If ($OrgId -like "organization.*") {
		$orgClientId = $OrgId
	} Else {
		$orgClientId = "organization.$OrgId"
	}

	# Get API Access Token
	$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
	$headers.Add('Content-Type','application/x-www-form-urlencoded')
	$body = "grant_type=client_credentials&scope=api.organization&client_id=$orgClientId&client_secret=$orgClientSecretKey"
	
	$bearerToken = (Invoke-RestMethod -Method POST -Uri $identity_url/connect/token -Headers $headers -Body $body).access_token

	If ($bearerToken) { 
		$env:BW_TOKEN = $bearerToken
		Write-Output "`n API Bearer Token: Success"
	} Else { 
		Write-Output "`n API Bearer Token: Failure"
		exit 1
	}

    Write-Output "`n Authenticating with Bitwarden CLI..."
	
	# Perform CLI auth 
	$userClientSecret = Get-Content "secureString_userSecret.txt" | ConvertTo-SecureString
	$env:BW_CLIENTSECRET = ConvertFrom-SecureStringPlain($userClientSecret) # service account client secret
	$bwMasterPass = Get-Content "secureString_masterPassword.txt" | ConvertTo-SecureString # service account master password
	$bwMasterPassPlain = ConvertFrom-SecureStringPlain($bwMasterPass)
	$bwStatus = (& .\bw status | ConvertFrom-Json).status
	Switch ($bwStatus) {
		"unauthenticated" {
			Write-Output "`n Logging in and unlocking Bitwarden vault..."
			$loginResult = & .\bw login --apikey
			$sessionKey = & .\bw unlock $bwMasterPassPlain --raw
		}
		"locked" {
			Write-Output "`n Already logged in, unlocking Bitwarden vault..."
			$sessionKey = & .\bw unlock $bwMasterPassPlain --raw
		}
	}
	
	# Clear secrets from variables
	$env:BW_CLIENTSECRET = ''
	$bwMasterPassPlain = ''
	$orgClientSecretKey = ''
	$orgClientSecret = ''
	$userClientSecret = ''
	$bwMasterPass = ''
	$env:BW_CLIENTID = ''

	If (!$sessionKey) { Write-Output "`n CLI Session Key: Failure"; exit 1 }
    
    Write-Output "`n Successfully unlocked Bitwarden vault."
    $env:BW_SESSION = $sessionKey
	
	#clear variable
	$sessionKey = ''
}

# For each Member, ensure a personal Collection exists
function Create-DefaultUserCollections {
    param (
        [string]$UserPath,
        [string]$OrgCollections,
        [psobject]$OrgMembers,
        [string]$GroupId,
        [string]$OrgId,
        [string]$UserSkipList
    )
	
	Write-Output "`n Checking for users without a personal collection..."
	
	# Regex to use when filtering the collections
	$query = "^" + $UserPath + ".*$" 
	
	# Filter orgCollections to those nested under the base user path
	$userCollections = $OrgCollections | .\jq -c --arg q "$query" '.[] | select(.name|test("$q"))'
	
	# Convert the skip list to regex
	$memberSkipRegEx = $UserSkipList -replace ",","|" 

	ForEach ($member in $OrgMembers) {
		$memberName = ($member.email -split "@")[0] #ignore the name field, standardizing on the first part of the email address
		$memberId = $member.id
		$memberStatus = $member.status
		$memberEmail = $member.email
		$existingCollection = ""

		# Check If the Collection already exists
		$query = $userPath + $memberName
		$existingCollection = $userCollections -cmatch $query
		
		#skip If the user exists or it is the Admin account, or the user is revoked
		If ($existingCollection -or ($memberName -cmatch $memberSkipRegEx) -or ($memberStatus -eq -1)) {
			Write-Output "`n Skipping: $memberName"
		} Else {

		#create the collection and add Administrators group to it
			#jq is inserting the values into the template
				#Get the template: 				(.\bw get template org-collection)
				#Set the jq variables: 			.\jq --arg n "$query" --arg c "$OrgId" --arg g "$$GroupId" --arg u "$memberId"
				#Insert into the json string: 	'.name="$n" | .organizationId="$c" | .groups[0].id="$g" | .groups[0].manage="true" | del(.groups[1]) | .users=[{"id":$u, "readOnly":false, "hidePasswords":false, "manage":true}]' 
				#Encode the json: 				| .\bw encode 
				#Create the collection:			| .\bw create org-collection --organizationid $OrgId
				#Filter to new collection Id:	| .\jq -r '.id'
			$newCollectionId = (.\bw get template org-collection) | .\jq --arg n "$query" --arg c "$OrgId" --arg g "$GroupId" --arg u "$memberId" '.name="$n" | .organizationId="$c" | .groups[0].id="$g" | .groups[0].manage="true" | del(.groups[1]) | .users=[{"id":$u, "readOnly":false, "hidePasswords":false, "manage":true}]' | .\bw encode | .\bw create org-collection --organizationid $OrgId | .\jq -r '.id'
			Write-Output "`n +++ Created Collection: $memberName"
			
		}
	}
}

# Confirm unconfirmed users - note this is not recommended
function Confirm-Users {
    param (
        [psobject]$OrgMembers
    )
	
	Write-Output "`n Confirming users..."
	$pendingMembers = $OrgMembers | where {$_.status -eq 1}
	
	ForEach ($member in $pendingMembers) {
		.\bw confirm org-member $member.id --organizationid $ORG_ID
		Write-Output "`n +++ Confirmed user:	$membername"
	}
}

# Verify admin group has permissions to all member created collections
function Verify-CollectionGroupPermissions {
    param (
        [string]$UserPath,
        [string]$OrgCollections,
        [string]$GroupId,
        [string]$OrgId
    )
	
	Write-Output "`n Checking nested collection permissions..."
	$query = "^" + $UserPath + ".*"
	$nestedCollections = $OrgCollections | .\jq -c --arg q "$query" '.[] | select(.name|test("$q"))' | .\jq -r '.id'
	$orgGroups = (Invoke-RestMethod -Method GET -Uri $api_url/public/groups -Headers $headers) | Select-Object data
	$adminGroupCollections = ($orgGroups.data | where {$_.id -eq $GroupId}).collections
	$adminPermissionsWrong = $adminGroupCollections | where {($_.manage -eq $false) -or ($_.readOnly -eq $true) -or ($_.hidePasswords -eq $true)}

	ForEach ($nestedCollection in $nestedCollections) {
		If ((!($adminGroupCollections -match $nestedCollection)) -or ($adminPermissionsWrong -match $nestedCollection)) {
			$updateCollection = (.\bw get org-collection "$nestedCollection" --organizationid $OrgId) | .\jq --arg i $groupId  '.groups+=[{"id": $i,"readOnly": "false","hidePasswords": "false","manage": "true"}]' | .\bw encode | .\bw edit org-collection "$nestedCollection" --organizationid $OrgId | .\jq -r '.name'
			Write-Output "`n +++ Updated permissions on Collection: $updateCollection"
		}
	}
}

# Move member created base collections to nest under a user collection
function Move-UnauthorizedBaseCollections {
    param (
        [string]$UserPath,
        [string]$OrgCollections,
        [psobject]$OrgMembers,
        [string]$GroupId,
        [string]$OrgId,
		[string]$CollectionSkipList
    )
	
	Write-Output "`n Checking for unauthorized base collections..."
	$query = "^($CollectionSkipList)"
	$unnestedCollections = $orgCollections | .\jq -c --arg t "$query" '.[] | select(.name|test("$t")|not)' | ConvertFrom-Json

	ForEach ($collection in $unnestedCollections) {
		$colId = $collection.id
		$colName = $collection.name
		$item = (.\bw get org-collection "$colId" --organizationid $OrgId) | ConvertFrom-Json
		$itemGroups = $item.groups
		$itemId = $item.id
		$userId = $item.users[0].id
		$user = (($OrgMembers | where {$_.id -eq $userId}).email -split "@")[0]
		$newName = $UserPath + $user + "/$colName"
		
		If (!($itemGroups -match $groupId)) {
			$updateCollection = (.\bw get org-collection "$colId" --organizationid $OrgId) | .\jq --arg i $groupId --arg n $newName  '.groups+=[{"id": $i,"readOnly": "false","hidePasswords": "false","manage": "true"}] | .name=$n ' | .\bw encode | .\bw edit org-collection "$colId" --organizationid $OrgId
			Write-Output "`n +++ Moved $colName to $newName and added Admin group."
		} Else {
			$updateCollection = (.\bw get org-collection "$colId" --organizationid $OrgId) | .\jq --arg n $newName  '.name=$n ' | .\bw encode | .\bw edit org-collection $itemId  --organizationid $OrgId
			Write-Output "`n +++ Moved $colName to $newName."
		}
	}
}

# Archive the personal collection and all collections nested under it when member is revoked
function Archive-RevokedUserCollections {
    param (
        [string]$UserPath,
        [string]$OrgCollections,
        [psobject]$OrgMembers,
        [string]$OrgId,
        [string]$ArchivePath
    )
	
	Write-Output "`n Checking for revoked member collections to archive..."
	$revokedUsers = $OrgMembers | where {$_.status -eq -1}

	ForEach ($user in $revokedUsers) {
		$username = ($user.email -split "@")[0]
		$t = $UserPath + $username + ".*$"
		$userCollections = $orgCollections | .\jq -c --arg t "$t" '.[] | select(.name|test("$t"))' | convertfrom-json
		
		ForEach ($collection in $userCollections) {
			$colName = $collection.name
			$newName =  $colName.Replace($UserPath,$ArchivePath)
			$itemId = $collection.id
			$updateCollection = (.\bw get org-collection "$itemId" --organizationid $OrgId) | .\jq --arg n $newName  '.name=$n | .users=[]' | .\bw encode | .\bw edit org-collection "$itemId" --organizationid $OrgId
			Write-Output "`n +++ Archived $colName as $newName"
		}
	}
}

# Setup parameters
If ($CLIENT_ID -like "user.*") {
	$env:BW_CLIENTID = $CLIENT_ID # service account client id
} Else {
	$env:BW_CLIENTID = "user.$CLIENT_ID" # service account client id
}
$user_path = ($USER_COLLECTION_BASE_PATH + "/")
$archive_path = ($ARCHIVE_COLLECTION_BASE_PATH + "/")
# Ensure the member and archive paths are in the skip list
$collections_to_skip = $COLLECTION_SKIP_LIST
If ($COLLECTION_SKIP_LIST -notlike "*$USER_COLLECTION_BASE_PATH*") {
	$collections_to_skip += ",$USER_COLLECTION_BASE_PATH" 
}
If ($COLLECTION_SKIP_LIST -notlike "*$ARCHIVE_COLLECTION_BASE_PATH*") {
	$collections_to_skip += ",$ARCHIVE_COLLECTION_BASE_PATH"
}
# Convert to regex
$collections_to_skip = $collections_to_skip -Replace ",","|"

# Handle API URLs
If (!$SELF_HOSTED_DOMAIN) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
} Else {
    $api_url = "https://$SELF_HOSTED_DOMAIN/api" # Set your Self-Hosted API URL
    $identity_url = "https://$SELF_HOSTED_DOMAIN/identity" # Set your Self-Hosted Identity URL
	# configure bw client
	& .\bw config server "https://vault.$SELF_HOSTED_DOMAIN"
}

# Log the script progress
If ($LOG_FILE) {
	Start-Transcript $LOG_FILE #set your transcript location
}

# Setup the sessions
Authenticate-Bitwarden -OrgId $ORG_ID

Write-Output "`n Fetching all members for organization ID: $ORG_ID"

# Set headers to use the bearer token from environment
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Authorization',('Bearer {0}' -f $env:BW_TOKEN))
$headers.Add('Accept','application/json')
$headers.Add('Content-Type','application/json')

# Fetch the list of Members and collections to use throughout
$org_api_members = (Invoke-RestMethod -Method GET -Uri $api_url/public/members -Headers $headers) | Select-Object data
$org_members = $org_api_members.psobject.Properties.Value | Select-Object name,id,status,email

Write-Output "`n Fetching all collections for organization ID: $ORG_ID"
$org_collections = (.\bw list org-collections --organizationid $ORG_ID)

# For each Member, ensure a personal Collection exists
Create-DefaultUserCollections -UserPath $user_path -OrgCollections $org_collections -OrgMembers $org_members -GroupId $ADMIN_GROUP_ID -OrgId $ORG_ID -UserSkipList $USER_SKIP_LIST

# Confirm unconfirmed users - note this is not recommended, uncomment to use
#Confirm-Users -OrgMembers $org_members

# Check that the admin group has permissions to all collections
Verify-CollectionGroupPermissions -UserPath $user_path -OrgCollections $org_collections -GroupId $ADMIN_GROUP_ID -OrgId $ORG_ID

# Move unauthorized base collections to nest under the first user with permissions
Move-UnauthorizedBaseCollections -UserPath $user_path -OrgCollections $org_collections -OrgMembers $org_members -GroupId $ADMIN_GROUP_ID -OrgId $ORG_ID -CollectionSkipList $collections_to_skip

# Archive the personal collection and all collections nested under it when member is revoked
Archive-RevokedUserCollections -UserPath $user_path -OrgCollections $org_collections -OrgMembers $org_members -OrgId $ORG_ID -ArchivePath $archive_path

# Clear plaintext secrets
$env:BW_TOKEN = ''
$env:BW_SESSION = ''

# Logout session
.\bw logout

If ($LOG_FILE) { Stop-Transcript }
