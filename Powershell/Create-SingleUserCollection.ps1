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
    The UUID format organization ID for Bitwarden (e.g., "your-org-id").

.PARAMETER USER_EMAIL
    The email of the Bitwarden user account used for CLI login.

.PARAMETER MASTER_PASSWORD
    The master password for the Bitwarden user account.

.PARAMETER USER_PRINCIPAL_NAME
    The email address of the user for whom the collection will be created. 
    **Note**: This user must already exist in the Bitwarden organization.

.PARAMETER NAME
    The name to use for the user in the collection name.

.PARAMETER PARENT_COLLECTION_NAME
    The base name of the collection (e.g., "Personal Vaults").

.PARAMETER VAULT_URI
    The URI of the Bitwarden vault (default: "https://vault.bitwarden.eu").

.EXAMPLE
    .\Create-SingleUserCollection.ps1 -ORG_ID "your-org-id" -USER_EMAIL "your-email" -MASTER_PASSWORD "your-master-password" -USER_PRINCIPAL_NAME "johndoe@domain.com" -NAME "John Doe" -PARENT_COLLECTION_NAME "Personal Vaults"
    Creates a collection for the user "johndoe@domain.com" within the specified Bitwarden organization under the "Personal Vaults/John Doe" collection.
#>

param(
    [string]$ORG_ID,
    [string]$USER_EMAIL,
    [string]$MASTER_PASSWORD,
    [string]$USER_PRINCIPAL_NAME,
    [string]$NAME,
    [string]$PARENT_COLLECTION_NAME = "Personal Vaults",
    [string]$VAULT_URI = "https://vault.bitwarden.eu",
    [switch]$Help
)

# Display help message if the -Help switch is used
if ($Help) {
    Get-Help -Full $MyInvocation.MyCommand.Path
    exit 0
}

# Check if required parameters are provided
if (-not $ORG_ID -or -not $USER_EMAIL -or -not $MASTER_PASSWORD -or -not $USER_PRINCIPAL_NAME -or -not $NAME) {
    Write-Host "Missing required parameters. Use -Help for detailed usage information." -ForegroundColor Yellow
    Write-Host "`nUsage example:"
    Write-Host "  .\Create-SingleUserCollection.ps1 -ORG_ID 'your-org-id' -USER_EMAIL 'your-email' -MASTER_PASSWORD 'your-master-password' -USER_PRINCIPAL_NAME 'johndoe@domain.com' -NAME 'John Doe'"
    exit 1
}

# Define the path to the Bitwarden CLI executable
$BW_EXEC = "./bw"

# Function to configure the Bitwarden CLI for the specified server and log in with the master password
function Configure-BitwardenCLI {
    param (
        [string]$vault_uri,
        [string]$user_email,
        [string]$master_password
    )
    & $BW_EXEC logout | Out-Null  # Log out to avoid conflicts with existing sessions
    & $BW_EXEC config server $vault_uri

    # Log in and unlock using the master password
    Write-Host "🔐 Logging into Bitwarden CLI..."
    & $BW_EXEC login $user_email $master_password
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to login with the provided master password." -ForegroundColor Red
        exit 1
    }

    $session_key = & $BW_EXEC unlock $master_password --raw
    if (!$session_key) {
        Write-Host "❌ Failed to unlock Bitwarden CLI with the master password." -ForegroundColor Red
        exit 1
    }

    # Set the session key as an environment variable for use in subsequent commands
    $env:BW_SESSION = $session_key
    Write-Host "🔑 Session key retrieved and set as BW_SESSION."

    return $session_key
}

# Function to create a Bitwarden collection for a single user
function Create-UserCollection {
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
Write-Host "🔧 Configuring Bitwarden CLI session..."
$session_key = Configure-BitwardenCLI -vault_uri $VAULT_URI -user_email $USER_EMAIL -master_password $MASTER_PASSWORD
if (!$session_key) {
    Write-Host "❌ Failed to retrieve session key." -ForegroundColor Red
    exit 1
}

# Use $ORG_ID directly as the organization identifier
Create-UserCollection -user_principal_name $USER_PRINCIPAL_NAME -name $NAME -organization_id $ORG_ID -parent_collection_name $PARENT_COLLECTION_NAME
