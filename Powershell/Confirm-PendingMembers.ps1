<#
.SYNOPSIS
    Automatically confirms all pending members in a specified Bitwarden organization.

.DESCRIPTION
    This script logs into the Bitwarden CLI, retrieves all pending members in a specified organization, 
    and confirms each one. It's designed to securely handle sensitive information and enable automation 
    by using SecureString for password handling.

.PARAMETER ORG_ID
    The UUID of the Bitwarden organization (e.g., 'b9c70d44-2615-4c84-9913-ac330139c9eb').

.PARAMETER USER_EMAIL
    The email of the Bitwarden user account with permissions to manage organization members.

.PARAMETER MASTER_PASSWORD
    The master password for the Bitwarden user account, provided as a SecureString.

.PARAMETER VAULT_URI
    The URI of the Bitwarden vault (default: 'https://vault.bitwarden.com').

.EXAMPLE
    $SecurePassword = Read-Host -Prompt 'Enter master password' -AsSecureString
    .\Confirm-PendingMembers.ps1 -ORG_ID 'your-org-id' -USER_EMAIL 'admin@example.com' -MASTER_PASSWORD $SecurePassword

    Automatically confirms all pending members in the specified Bitwarden organization.
#>

param(
    [string]$ORG_ID,
    [string]$USER_EMAIL,
    [SecureString]$MASTER_PASSWORD,
    [string]$VAULT_URI = 'https://vault.bitwarden.com',  # Default to main Bitwarden server
    [switch]$Help
)

# Display help message if the -Help switch is used
if ($Help) {
    Get-Help -Full $MyInvocation.MyCommand.Path
    exit 0
}

# Check if required parameters are provided
$missingParams = @()
if (-not $ORG_ID)          { $missingParams += 'ORG_ID: The UUID of the Bitwarden organization (e.g., ''b9c70d44-2615-4c84-9913-ac330139c9eb'').' }
if (-not $USER_EMAIL)      { $missingParams += 'USER_EMAIL: The email of the Bitwarden user account with permissions to manage organization members.' }
if (-not $MASTER_PASSWORD) { $missingParams += 'MASTER_PASSWORD: The master password for the Bitwarden user account, provided as a SecureString.' }

if ($missingParams.Count -gt 0) {
    Write-Host 'The following required parameters are missing:' -ForegroundColor DarkGray
    $missingParams | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    Write-Host "`nDescription:" -ForegroundColor DarkGray
    Write-Host 'This script confirms all pending members in the specified Bitwarden organization.' -ForegroundColor White
    Write-Host "`nUsage example:" -ForegroundColor DarkGray
    Write-Host '  $SecurePassword = Read-Host -Prompt "Enter master password" -AsSecureString' -ForegroundColor Green
    Write-Host '  .\Confirm-PendingMembers.ps1 -ORG_ID "your-org-id" -USER_EMAIL "your-email" -MASTER_PASSWORD `$SecurePassword' -ForegroundColor Green
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

# Function to initialize the Bitwarden CLI session
function Initialize-BitwardenCLI {
    param (
        [string]$vault_uri,
        [string]$user_email,
        [SecureString]$master_password
    )

    Write-Host '🔧 Logging out & Configuring Bitwarden CLI...'
    & $BW_EXEC logout | Out-Null  # Log out to avoid conflicts with existing sessions
    & $BW_EXEC config server $vault_uri

    $plainTextPassword = Convert-SecureStringToPlainText -secureString $master_password
    Write-Host "🔐 Logging '$user_email' into Bitwarden CLI..." -ForegroundColor Yellow

    # Try to log in
    $loginOutput = & $BW_EXEC login $user_email $plainTextPassword
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to login. Error: $loginOutput" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "✅ Successfully logged in as $user_email" -ForegroundColor Green
    }

    # Attempt to unlock and set session key
    Write-Host '🔐 Unlocking the vault...'
    $session_key = & $BW_EXEC unlock $plainTextPassword --raw
    if (!$session_key) {
        Write-Host '❌ Failed to unlock Bitwarden CLI with the master password.' -ForegroundColor Red
        exit 1
    }

    # Set the session key as an environment variable for use in subsequent commands
    $env:BW_SESSION = $session_key    

    # Retry loop to confirm Bitwarden session is fully unlocked
    for ($i = 0; $i -lt 5; $i++) {
        $bwStatus = & $BW_EXEC status --session $session_key | ConvertFrom-Json
        if ($bwStatus.status -eq "unlocked") {
            Write-Host '✅ Bitwarden session is fully unlocked.' -ForegroundColor Green
            return $session_key
        }
        else {
            Start-Sleep -Seconds 2
            Write-Host "Waiting for Bitwarden session to unlock... Attempt $($i+1)/5" -ForegroundColor Yellow
        }
    }

    Write-Host "❌ Bitwarden session is not unlocked. Please verify your login credentials and two-step login setup." -ForegroundColor Red
    exit 1
}

# Function to confirm pending organization members
function Confirm-PendingMembers {
    param (
        [string]$organization_id,
        [string]$session_key
    )

    Write-Host '👥 Retrieving pending members...'
    $org_members = & $BW_EXEC list org-members --organizationid $organization_id | ConvertFrom-Json
    $pending_members = $org_members | Where-Object { $_.status -eq 1 } | Select-Object -ExpandProperty id

    if (-not $pending_members) {
        Write-Host '✅ No pending members to confirm.' -ForegroundColor Green
        return
    }

    Write-Host "🆗 Confirming pending members..."
    foreach ($member_id in $pending_members) {
        try {
            & $BW_EXEC confirm org-member $member_id --organizationid $organization_id
            Write-Host "✅ Successfully confirmed member ID: $member_id" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Error confirming member ID: $member_id. Error details: $_" -ForegroundColor Red
        }
    }
}

# Main Script Execution
Write-Host ' Initializing Bitwarden CLI session...'
$session_key = Initialize-BitwardenCLI -vault_uri $VAULT_URI -user_email $USER_EMAIL -master_password $MASTER_PASSWORD
if (!$session_key) {
    Write-Host '❌ Failed to retrieve session key.' -ForegroundColor Red
    exit 1
}
Write-Host '🔧 Session key retrieved successfully.' -ForegroundColor Green

# Confirm pending members
Confirm-PendingMembers -organization_id $ORG_ID -session_key $session_key
