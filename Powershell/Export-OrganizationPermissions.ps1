<#
.SYNOPSIS
    Exports organization permissions from the Public API to a CSV or JSON file, or displays them in the terminal.

.DESCRIPTION
    This script configures and starts the Bitwarden server, logs in with a specified master password,
    unlocks the vault, retrieves all collections and their user/group permissions for a specific organization, 
    and exports the data to a CSV or JSON file, or displays it in a table format in the terminal. It also retrieves groups
    and users from the Public API using client credentials. Once the script finishes, the server shuts down.

.PARAMETER ORGANIZATION_ID
    The organization ID for which to retrieve collections and permissions (required).

.PARAMETER CLIENT_ID
    The Client ID for accessing the Bitwarden Public API (required for user and group retrieval).

.PARAMETER CLIENT_SECRET
    The Client Secret for accessing the Bitwarden Public API (required for user and group retrieval).

.PARAMETER MASTER_PASSWORD
    The master password for the Bitwarden account used to unlock the vault.

.PARAMETER EMAIL
    The email of the Bitwarden user account used for CLI login. 

.PARAMETER SERVER_URI
    The URI of the Bitwarden server (default: "https://vault.bitwarden.eu").

.PARAMETER PORT
    The port on which to run the local API server (default: 8087).

.PARAMETER OUTPUT_PATH
    Optional path to the directory for the export file. The filename will be automatically generated as bitwarden_org_permissions_export_YYYYMMDDHHMMSS with the appropriate extension.

.PARAMETER EXPORT_FORMAT
    The format for the export file, either "csv" or "json". If not specified, defaults to "csv".

.PARAMETER LOG_FILE
    The path for the log file. If specified, all debug and error messages will be directed to this file, which is useful for troubleshooting.

.EXAMPLE
    # To run the script and export the data to a CSV file:
    .\Export-OrganizationPermissions.ps1 -ORGANIZATION_ID "your-org-id" -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -OUTPUT_PATH "C:\Exports" -EXPORT_FORMAT "csv" -LOG_FILE "script.log"

    # To run the script and display the data in the terminal:
    $DebugPreference = 'Continue' ; bw logout ; .\Export-OrganizationPermissions.ps1 -ORGANIZATION_ID "your-org-id" -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret"

    .\Export-OrganizationPermissions.ps1 `
        -ORGANIZATION_ID "your-org-id" `
        -CLIENT_ID "your-client-id" `
        -CLIENT_SECRET (ConvertTo-SecureString "your-client-secret" -AsPlainText -Force) `
        -EMAIL "youremail@domain.com" `
        -MASTER_PASSWORD (ConvertTo-SecureString "your-master-password" -AsPlainText -Force) `
        -OUTPUT_PATH "C:\Exports" `
        -EXPORT_FORMAT "json" `
        -LOG_FILE "C:\Logs\script.log"
#>

param (
    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [string]$ORGANIZATION_ID,

    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [string]$CLIENT_ID,

    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [SecureString]$CLIENT_SECRET,

    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [string]$EMAIL,

    [Parameter(Mandatory=$true)] 
    [ValidateNotNullOrEmpty()] 
    [SecureString]$MASTER_PASSWORD,
    
    [ValidateNotNullOrEmpty()] 
    [string]$SERVER_URI = "https://vault.bitwarden.eu",

    [ValidateNotNullOrEmpty()] 
    [string]$API_URI = "https://api.bitwarden.eu",
    
    [ValidateNotNullOrEmpty()] 
    [int]$PORT = 8087,

    [string]$OUTPUT_PATH,
    
    [string]$EXPORT_FORMAT = "csv",
    
    [string]$LOG_FILE
)

# Helper function for logging
function Write-Log {
    param (
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$Type] - $Message"

    # Output to console
    if ($Type -eq "ERROR") {
        Write-Host $logEntry -ForegroundColor Red
    } else {
        Write-Host $logEntry
    }

    # Output to log file if specified
    if ($LOG_FILE) {
        Add-Content -Path $LOG_FILE -Value $logEntry
    }
}

# Ensure Bitwarden CLI is available
$BW_EXEC = "./bw"  # Adjust this if needed for your environment
if (-not (Get-Command $BW_EXEC -ErrorAction SilentlyContinue)) {
    Write-Log "❌ Bitwarden CLI ($BW_EXEC) is not available. Please install it and try again." "ERROR"
    exit 1
}

# Configure the Bitwarden server
Write-Log "🔧 Configuring Bitwarden CLI with server URI: $SERVER_URI"
& $BW_EXEC config server $SERVER_URI | Out-Null

# Log in with the master password
$plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($MASTER_PASSWORD)
)

Write-Log "🔑 Logging in to Bitwarden CLI with email: $EMAIL"
$loginResult = & $BW_EXEC login $EMAIL $plainTextPassword --raw

if (-not $loginResult) {
    Write-Log "❌ Failed to log in. Check your email and password and try again." "ERROR"
    exit 1
}

Write-Log "✅ Successfully logged in."

# Start the local server
Write-Log "🚀 Starting Bitwarden local API server on port $PORT..."
Start-Process -NoNewWindow -FilePath $BW_EXEC -ArgumentList "serve --port $PORT"
Start-Sleep -Seconds 5  # Allow time for server to start

# Unlock the vault using the API
Write-Log "🔓 Unlocking the vault..."
$unlockResponse = Invoke-RestMethod -Uri "http://localhost:$PORT/unlock" -Method Post -Body (@{ password = $plainTextPassword } | ConvertTo-Json) -ContentType "application/json"

if ($unlockResponse.success -eq $false) {
    Write-Log "❌ Failed to unlock the vault. Message: $($unlockResponse.message)" "ERROR"
    Stop-Process -Name bw
    exit 1
}

Write-Log "🔓 Vault unlocked successfully."

# Function to call Vault Management API with added error handling
function Invoke-VaultManagementAPI {
    param (
        [string]$endpoint,
        [string]$method = "GET",
        [object]$body = $null
    )

    $url = "http://localhost:$PORT/$endpoint"
    $headers = @{
        "Authorization" = "Bearer $unlockResponse.data.raw"
    }

    try {
        if ($method -eq "GET") {
            return Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ContentType 'application/json'
        } elseif ($method -eq "POST") {
            return Invoke-RestMethod -Uri $url -Headers $headers -Method Post -Body ($body | ConvertTo-Json) -ContentType 'application/json'
        }
    }
    catch {
        Write-Log "❌ API call failed for endpoint: $endpoint" "ERROR"
        Write-Log "Error details: $_" "ERROR"
    }
}

# Fetch access token for Public API
Write-Log "🔑 Fetching access token for Public API..."
$plainTextClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CLIENT_SECRET)
)
$authResponse = Invoke-RestMethod -Uri "$SERVER_URI/identity/connect/token" -Method Post -ContentType "application/x-www-form-urlencoded" -Body @{
    client_id = $CLIENT_ID
    client_secret = $plainTextClientSecret
    grant_type = "client_credentials"
    scope = "api.organization"
}

$access_token = $authResponse.access_token

if (-not $access_token) {
    Write-Log "❌ Failed to retrieve access token for Public API." "ERROR"
    exit 1
}

# Fetch all users and groups for the organization from Public API
Write-Log "📋 Fetching users and groups for organization ID: $ORGANIZATION_ID..."

# Public API headers
$publicAPIHeaders = @{
    "Authorization" = "Bearer ${access_token}"
    "Content-Type" = "application/json"
}

# Fetch users from the Public API
Write-Log "📋 Fetching organization users from Public API..."
$usersResponse = Invoke-RestMethod -Uri "$API_URI/public/members" -Headers $publicAPIHeaders -Method Get
# Create a hashtable to map user IDs to emails and external IDs
$userDetails = @{}
foreach ($user in $usersResponse.data) {
    $userDetails[$user.id] = @{
        email = $user.email
        externalId = $user.externalId
    }
}

# Fetch groups from the Public API
Write-Log "📋 Fetching organization groups from Public API..."
$groupsResponse = Invoke-RestMethod -Uri "$API_URI/public/groups" -Headers $publicAPIHeaders -Method Get
# Create a hashtable to map group IDs to names and external IDs
$groupDetails = @{}
foreach ($group in $groupsResponse.data) {
    $groupDetails[$group.id] = @{
        name = $group.name
        externalId = $group.externalId
    }
}

# Fetch collections from the Public API
Write-Log "📚 Fetching collections for organization ID: $ORGANIZATION_ID from Public API..."
$collectionsResponse = Invoke-RestMethod -Uri "$API_URI/public/collections" -Headers $publicAPIHeaders -Method Get

# Initialize an array to store permissions data
$permissionsData = @()

# Loop through each collection to fetch permissions, using Write-Progress to display progress
$collectionCount = $collectionsResponse.data.Count
$counter = 0

foreach ($collection in $collectionsResponse.data) {
    $collection_id = $collection.id
    $collection_externalId = $collection.externalId
    $counter++

    # Update the progress bar
    $percentComplete = ($counter / $collectionCount) * 100
    Write-Progress -Activity "Fetching permissions for Collection ID: $collection_id" `
                   -Status "Processing collection $counter of $collectionCount" `
                   -PercentComplete $percentComplete

    # Retrieve collection details including permissions
    Write-Log "👥 Fetching permissions for collection: ${collection_id}..."
    $collectionDetails = Invoke-VaultManagementAPI -endpoint "object/org-collection/${collection_id}?organizationId=${ORGANIZATION_ID}"
    $collection_name = $collectionDetails.data.name

    # Process User Permissions
    foreach ($user in $collectionDetails.data.users) {
        $userID = $user.id
        $userInfo = $userDetails[$userID]
        $username = $userInfo.email
        $userExternalId = $userInfo.externalId

        # Add data to permissions array with "Type" as "member"
        $permissionsData += [PSCustomObject]@{
            "Collection ID"        = $collection_id
            "Collection Name"      = $collection_name
            "Collection externalId" = $collection_externalId
            "User/Group"           = $username
            "User/Group ID"        = $userID
            "Type"                 = "member"
            "External ID"          = $userExternalId
            "readOnly"             = $user.readOnly
            "hidePasswords"        = $user.hidePasswords
            "manage"               = $user.manage
        }
    }

    # Process Group Permissions
    foreach ($group in $collectionDetails.data.groups) {
        $groupID = $group.id
        $groupInfo = $groupDetails[$groupID]
        $groupName = $groupInfo.name
        $groupExternalId = $groupInfo.externalId

        # Add data to permissions array with "Type" as "group"
        $permissionsData += [PSCustomObject]@{
            "Collection ID"        = $collection_id
            "Collection Name"      = $collection_name
            "Collection externalId" = $collection_externalId
            "User/Group"           = $groupName
            "User/Group ID"        = $groupID
            "Type"                 = "group"
            "External ID"          = $groupExternalId
            "readOnly"             = $group.readOnly
            "hidePasswords"        = $group.hidePasswords
            "manage"               = $group.manage
        }
    }
}

# Clear the progress bar
Write-Progress -Activity "Fetching permissions complete" -Completed

# Output permissions data
if ($permissionsData.Count -eq 0) {
    Write-Log "⚠️ No permissions data was retrieved." "WARNING"
}
elseif ($OUTPUT_PATH) {
    # Generate the timestamped filename and export to CSV or JSON in the specified directory
    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $fileName = "bitwarden_org_permissions_export_${timestamp}.$EXPORT_FORMAT"
    $outputFilePath = Join-Path -Path $OUTPUT_PATH -ChildPath $fileName

    if ($EXPORT_FORMAT -eq "csv") {
        Write-Log "💾 Exporting permissions data to $outputFilePath as CSV..."
        $permissionsData | Export-Csv -Path $outputFilePath -NoTypeInformation -Encoding UTF8
    } elseif ($EXPORT_FORMAT -eq "json") {
        Write-Log "💾 Exporting permissions data to $outputFilePath as JSON..."
        $permissionsData | ConvertTo-Json -Depth 4 | Out-File -FilePath $outputFilePath -Encoding UTF8
    }

    Write-Log "✅ Export complete! File saved at $outputFilePath."
} else {
    # Display permissions data in table format if no output file is specified
    Write-Log "📋 Displaying permissions data in terminal:"
    $permissionsData | Format-Table -AutoSize
}

# Stop the local server
Write-Log "🛑 Stopping the local API server..."
Stop-Process -Name bw -Force
Write-Log "🚀 Server stopped and script completed."
