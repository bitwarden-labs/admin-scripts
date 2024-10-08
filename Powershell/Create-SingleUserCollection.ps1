<#
.SYNOPSIS
    Creates a single Bitwarden collection for a specified user.

.DESCRIPTION
    This script authenticates with the Bitwarden CLI, retrieves the organization member, 
    and creates a collection for the specified user. If `secureString.txt` is not found, 
    the script will prompt for the master password and save it as an encrypted file 
    for future use. Otherwise, it will use the existing file.

.PARAMETER ORG_ID
    The UUID format organization ID for Bitwarden (e.g., "9d3210e3-385c-4c76-ad72-b1f5013a8cc2").

.PARAMETER USER_EMAIL
    The email of the Bitwarden user account used for CLI login.

.PARAMETER USER_PRINCIPAL_NAME
    The email address of the user for whom the collection will be created.

.PARAMETER NAME
    The name to use for the user in the collection name.

.PARAMETER PARENT_COLLECTION_NAME
    The base name of the collection (e.g., "Personal Vaults").

.PARAMETER VAULT_URI
    The URI of the Bitwarden vault (default: "https://vault.bitwarden.com").

.EXAMPLE
    .\Create-SingleUserCollection.ps1 -ORG_ID "your-org-id" -USER_EMAIL "your-email" -USER_PRINCIPAL_NAME "johndoe@domain.com" -NAME "John Doe" -PARENT_COLLECTION_NAME "Personal Vaults"
    Creates a collection for the user "johndoe@domain.com" within the specified Bitwarden organization under the "Personal Vaults/John Doe" collection.
#>

param(
    [string]$ORG_ID,
    [string]$USER_EMAIL,
    [string]$USER_PRINCIPAL_NAME,
    [string]$NAME,
    [string]$PARENT_COLLECTION_NAME = "Personal Vaults",
    [string]$VAULT_URI = "https://vault.bitwarden.com"
)

# Check if required parameters are provided
$missingParams = @()
if (-not $ORG_ID)              { $missingParams += 'ORG_ID: The UUID format organization ID for Bitwarden.' }
if (-not $USER_EMAIL)          { $missingParams += 'USER_EMAIL: The email of the Bitwarden user account used for CLI login.' }
if (-not $USER_PRINCIPAL_NAME) { $missingParams += 'USER_PRINCIPAL_NAME: The email address of the user for whom the collection will be created.' }
if (-not $NAME)                { $missingParams += 'NAME: The name to use for the user in the collection name.' }

# If any required parameters are missing, show help and usage example
if ($missingParams.Count -gt 0) {
    Write-Host 'The following required parameters are missing:' -ForegroundColor DarkGray
    $missingParams | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    Write-Host "`nDescription:" -ForegroundColor DarkGray
    Write-Host 'This script creates a single Bitwarden collection for a specified user.' -ForegroundColor White
    Write-Host "`nUsage example:" -ForegroundColor DarkGray
    Write-Host '  .\Create-SingleUserCollection.ps1 -ORG_ID "your-org-id" -USER_EMAIL "your-email" -USER_PRINCIPAL_NAME "johndoe@domain.com" -NAME "John Doe" -PARENT_COLLECTION_NAME "Personal Vaults"' -ForegroundColor Green
    exit 1
}

# Define the path to the Bitwarden CLI executable and the secure password file
$BW_EXEC = './bw'
$secureStringPath = './secureString.txt'

# Check if secureString.txt exists
if (Test-Path $secureStringPath) {
    # Load encrypted master password from file
    $MASTER_PASSWORD = Get-Content $secureStringPath | ConvertTo-SecureString
    Write-Host " Loaded master password from secureString.txt" -ForegroundColor Green
} else {
    # Prompt for the master password and save it as SecureString to file
    Write-Host "Please enter your master password:" -ForegroundColor Yellow
    $MASTER_PASSWORD = Read-Host -AsSecureString
    $MASTER_PASSWORD | ConvertFrom-SecureString | Out-File $secureStringPath
    Write-Host " Master password saved to secureString.txt for future use." -ForegroundColor Green
}

# Convert SecureString to PlainText
function Convert-SecureStringToPlainText {
    param ([SecureString]$secureString)
    $marshalPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
    try {
        return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($marshalPtr)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($marshalPtr)
    }
}

# Function to initialize the Bitwarden CLI session
function Initialize-BitwardenCLI {
    param (
        [string]$vault_uri,
        [string]$user_email,
        [SecureString]$master_password
    )

    Write-Host '🔧 Configuring Bitwarden CLI...'
    & $BW_EXEC logout | Out-Null  # Log out to avoid conflicts with existing sessions
    & $BW_EXEC config server $vault_uri

    $plainTextPassword = Convert-SecureStringToPlainText -secureString $master_password
    Write-Host "🔐 Attempting login for user: $user_email" -ForegroundColor Yellow

    # Try to log in
    $loginOutput = & $BW_EXEC login $user_email $plainTextPassword
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to login. Error: $loginOutput" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ Successfully logged in as $user_email" -ForegroundColor Green
    }

    # Attempt to unlock and set session key
    Write-Host ' Unlocking the vault...'
    $session_key = & $BW_EXEC unlock $plainTextPassword --raw
    if (!$session_key) {
        Write-Host '❌ Failed to unlock Bitwarden CLI with the master password.' -ForegroundColor Red
        exit 1
    }

    # Set the session key as an environment variable for use in subsequent commands
    $env:BW_SESSION = $session_key    

    # Retry loop to confirm Bitwarden session is fully unlocked
    for ($i = 0; $i -lt 5; $i++) {
        $bwStatus = & $BW_EXEC status | ConvertFrom-Json
        if ($bwStatus.status -eq "unlocked") {
            Write-Host '✅ Bitwarden session is fully unlocked.' -ForegroundColor Green
            return $session_key
        }
        else {
            Start-Sleep -Seconds 2
            Write-Host "😮 Waiting for Bitwarden session to unlock... Attempt $($i+1)/5" -ForegroundColor Yellow
        }
    }

    Write-Host "❌ Bitwarden session is not unlocked. Please verify your login credentials and two-step login setup." -ForegroundColor Red
    exit 1
}

# Function to create a Bitwarden collection for a single user
function Create-UserCollection {
    param (
        [string]$user_principal_name,
        [string]$name,
        [string]$organization_id,
        [string]$session_key,
        [string]$parent_collection_name
    )

    # Retrieve the Bitwarden member ID
    Write-Host '🧑‍🤝‍🧑 Retrieving organization members...'
    $org_members = & $BW_EXEC list org-members --organizationid $organization_id | ConvertFrom-Json
    $member = $org_members | Where-Object { $_.email -eq $user_principal_name }

    if (-not $member) {
        Write-Host "❌ Error: User with email $user_principal_name does not exist in the Bitwarden organization." -ForegroundColor Red
        exit 1
    }

    # Create a collection template and configure it with the desired values
    Write-Host "🥤 Creating a collection for user $user_principal_name..."
    $template = & $BW_EXEC get template collection --organizationid $organization_id | ConvertFrom-Json
    $template.name = "$parent_collection_name/$name - ($($member.id))"
    $template.organizationId = $organization_id        

    $newCollection = $template | ConvertTo-Json | & $BW_EXEC encode | & $BW_EXEC create org-collection --organizationid $organization_id | ConvertFrom-Json

    Write-Host "✅ Collection '$($newCollection.name)' created successfully for user '$user_principal_name'." -ForegroundColor Green
}

# Main Script Execution
Write-Host '⚙️ Initializing Bitwarden CLI session...'
$session_key = Initialize-BitwardenCLI -vault_uri $VAULT_URI -user_email $USER_EMAIL -master_password $MASTER_PASSWORD
if (!$session_key) {
    Write-Host '❌ Failed to retrieve session key.' -ForegroundColor Red
    exit 1
}
Write-Host '🔑 Session key retrieved successfully.' -ForegroundColor Green

# Create collection for specified user
Create-UserCollection -user_principal_name $USER_PRINCIPAL_NAME -name $NAME -organization_id $ORG_ID -session_key $session_key -parent_collection_name $PARENT_COLLECTION_NAME
