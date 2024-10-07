<#
.SYNOPSIS
    Creates a single Bitwarden collection for a specified user.

.DESCRIPTION
    This script authenticates with the Bitwarden CLI, retrieves the organization member, 
    and creates a collection for the specified user. The collection is created under a customizable 
    base name defined by the parameter `PARENT_COLLECTION_NAME`.

    Note: The `ORG_ID` is used for organization identification, while the `USER_EMAIL`
    and `MASTER_PASSWORD` are required for CLI login and unlock operations. 
    **Important**: The `USER_PRINCIPAL_NAME` must already exist as a member in the specified organization.

.PARAMETER ORG_ID
    The UUID format organization ID for Bitwarden (e.g., 'your-org-id').

.PARAMETER USER_EMAIL
    The email of the Bitwarden user account used for CLI login.

.PARAMETER MASTER_PASSWORD
    The master password for the Bitwarden user account, provided as a SecureString. 
    **Tip**: To enter the master password securely, run the following before the script:
    `$MasterPassword = Read-Host -Prompt 'Enter master password' -AsSecureString`

.PARAMETER USER_PRINCIPAL_NAME
    The email address of the user for whom the collection will be created. 
    **Note**: This user must already exist in the Bitwarden organization.

.PARAMETER NAME
    The name to use for the user in the collection name.

.PARAMETER PARENT_COLLECTION_NAME
    The base name of the collection (e.g., 'Personal Vaults').

.PARAMETER VAULT_URI
    The URI of the Bitwarden vault (default: 'https://vault.bitwarden.eu').

.EXAMPLE
    $SecurePassword = Read-Host -Prompt 'Enter master password' -AsSecureString
    .\New-UserCollection.ps1 -ORG_ID 'your-org-id' -USER_EMAIL 'your-email' -MASTER_PASSWORD $SecurePassword -USER_PRINCIPAL_NAME 'johndoe@domain.com' -NAME 'John Doe' -PARENT_COLLECTION_NAME 'Personal Vaults'

    Creates a collection for the user 'johndoe@domain.com' within the specified Bitwarden organization under the 'Personal Vaults/John Doe' collection.
#>

param(
    [string]$ORG_ID,
    [string]$USER_EMAIL,
    [SecureString]$MASTER_PASSWORD,
    [string]$USER_PRINCIPAL_NAME,
    [string]$NAME,
    [string]$PARENT_COLLECTION_NAME = 'Personal Vaults',
    [string]$VAULT_URI = 'https://vault.bitwarden.eu',
    [switch]$Help
)

# Display help message if the -Help switch is used
if ($Help) {
    Get-Help -Full $MyInvocation.MyCommand.Path
    exit 0
}

# Detailed error message for missing parameters
$missingParams = @()
if (-not $ORG_ID)           { $missingParams += 'ORG_ID: The UUID format organization ID for Bitwarden (e.g., ''your-org-id'').' }
if (-not $USER_EMAIL)       { $missingParams += 'USER_EMAIL: The email of the Bitwarden user account used for CLI login.' }
if (-not $MASTER_PASSWORD)  { $missingParams += 'MASTER_PASSWORD: The master password for the Bitwarden user account, provided as a SecureString.' }
if (-not $USER_PRINCIPAL_NAME) { $missingParams += 'USER_PRINCIPAL_NAME: The email address of the user for whom the collection will be created.' }
if (-not $NAME)             { $missingParams += 'NAME: The name to use for the user in the collection name.' }

# If any parameters are missing, output a detailed message and usage example
if ($missingParams.Count -gt 0) {
    Write-Host 'The following required parameters are missing:' -ForegroundColor DarkGray
    $missingParams | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    Write-Host "`nDescription:" -ForegroundColor DarkGray
    Write-Host 'This script creates a single Bitwarden collection for a specified user.' -ForegroundColor White
    Write-Host "`nUsage example:" -ForegroundColor DarkGray
    Write-Host '  $SecurePassword = Read-Host -Prompt "Enter master password" -AsSecureString' -ForegroundColor Green
    Write-Host '  .\Create-SingleUserCollection.ps1 -ORG_ID "your-org-id" -USER_EMAIL "your-email" -MASTER_PASSWORD `$SecurePassword -USER_PRINCIPAL_NAME "johndoe@domain.com" -NAME "John Doe"' -ForegroundColor Green
    exit 1
}

# Define the path to the Bitwarden CLI executable
$BW_EXEC = './bw'

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

# Function to initialize the Bitwarden CLI for the specified server and log in with the master password
function Initialize-BitwardenCLI {
    param (
        [string]$vault_uri,
        [string]$user_email,
        [SecureString]$master_password
    )
    & $BW_EXEC logout | Out-Null  # Log out to avoid conflicts with existing sessions
    & $BW_EXEC config server $vault_uri

    # Convert SecureString to plaintext only when needed for CLI login
    $plainTextPassword = Convert-SecureStringToPlainText -secureString $master_password

    # Log in and unlock using the master password
    Write-Host '🔐 Logging into Bitwarden CLI...'
    & $BW_EXEC login $user_email $plainTextPassword
    if ($LASTEXITCODE -ne 0) {
        Write-Host '❌ Failed to login with the provided master password.' -ForegroundColor Red
        exit 1
    }

    $session_key = & $BW_EXEC unlock $plainTextPassword --raw
    if (!$session_key) {
        Write-Host '❌ Failed to unlock Bitwarden CLI with the master password.' -ForegroundColor Red
        exit 1
    }

    # Set the session key as an environment variable for use in subsequent commands
    $env:BW_SESSION = $session_key
    Write-Host '🔑 Session key retrieved and set as BW_SESSION.'

    return $session_key
}

# Function to create a Bitwarden collection for a single user
function New-UserCollection {
    param (
        [string]$user_principal_name,
        [string]$name,
        [string]$organization_id,
        [string]$parent_collection_name
    )

    Write-Host "👤 Retrieving member information for user: $user_principal_name"
    $org_members = & $BW_EXEC list org-members --organizationid $organization_id | ConvertFrom-Json
    $member = $org_members | Where-Object { $_.email -eq $user_principal_name }

    if (-not $member) {
        Write-Host "❌ Error: User with email $user_principal_name does not exist in the Bitwarden organization." -ForegroundColor Red
        exit 1
    }

    Write-Host "📁 Creating collection for user $name..."
    $template = & $BW_EXEC get template collection --organizationid $organization_id | ConvertFrom-Json
    $template.name = "$parent_collection_name/$name - ($($member.id))"
    $template.organizationId = $organization_id        

    $newCollection = $template | ConvertTo-Json | & $BW_EXEC encode | & $BW_EXEC create org-collection --organizationid $organization_id | ConvertFrom-Json

    Write-Host "✅ Collection '$($newCollection.name)' created successfully for user '$user_principal_name'."
}

# Main Script Execution
Write-Host '🔧 Initializing Bitwarden CLI session...'
$session_key = Initialize-BitwardenCLI -vault_uri $VAULT_URI -user_email $USER_EMAIL -master_password $MASTER_PASSWORD
if (!$session_key) {
    Write-Host '❌ Failed to retrieve session key.' -ForegroundColor Red
    exit 1
}

# Use $ORG_ID directly as the organization identifier
New-UserCollection -user_principal_name $USER_PRINCIPAL_NAME -name $NAME -organization_id $ORG_ID -parent_collection_name $PARENT_COLLECTION_NAME
