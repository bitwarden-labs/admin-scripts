<#
.SYNOPSIS
    Exports an organization vault from Bitwarden to a file using the Bitwarden CLI.

.DESCRIPTION
    This script authenticates to Bitwarden using API key credentials (Client ID and Client Secret),
    unlocks the vault with a master password, and exports the organization vault to a specified file
    in the requested format (JSON, CSV, or encrypted JSON). The master password is passed as a
    SecureString for secure handling in memory.

.PARAMETER CLIENT_ID
    The Personal API Client ID for Bitwarden authentication (starts with "user.").

.PARAMETER CLIENT_SECRET
    The Personal API Client Secret for Bitwarden authentication (SecureString).

.PARAMETER MASTER_PASSWORD
    The master password for unlocking the Bitwarden vault (SecureString).

.PARAMETER ORGANIZATION_ID
    The Organization ID whose vault will be exported.

.PARAMETER OUTPUT_FILE
    The full path to the output file where the vault export will be saved.

.PARAMETER EXPORT_FORMAT
    The format for the export file: "json", "csv", or "encrypted_json". Default is "json".

.PARAMETER SERVER_URI
    The URI of the Bitwarden server. Default is "https://vault.bitwarden.eu".

.PARAMETER LOG_FILE
    Optional path for the log file. If specified, all log messages will be written to this file.

.EXAMPLE
    .\Export-OrganizationVault.ps1 `
        -CLIENT_ID "user.0263352c-8d55-4cad-ae38-aff7017deee4" `
        -CLIENT_SECRET (ConvertTo-SecureString "your-client-secret" -AsPlainText -Force) `
        -MASTER_PASSWORD (ConvertTo-SecureString "your-master-password" -AsPlainText -Force) `
        -ORGANIZATION_ID "1f0c58c3-a3d8-48b2-bb3a-ac8c0075bcc6" `
        -OUTPUT_FILE "C:\Exports\bw_export.json" `
        -EXPORT_FORMAT "json"

.EXAMPLE
    .\Export-OrganizationVault.ps1 `
        -CLIENT_ID "user.0263352c-8d55-4cad-ae38-aff7017deee4" `
        -CLIENT_SECRET (ConvertTo-SecureString "your-client-secret" -AsPlainText -Force) `
        -MASTER_PASSWORD (ConvertTo-SecureString "your-master-password" -AsPlainText -Force) `
        -ORGANIZATION_ID "1f0c58c3-a3d8-48b2-bb3a-ac8c0075bcc6" `
        -OUTPUT_FILE "C:\Exports\bw_export.csv" `
        -EXPORT_FORMAT "csv" `
        -LOG_FILE "C:\Logs\export.log"

.NOTES
    - Requires Bitwarden CLI (bw) to be installed and available in PATH
    - Uses API key authentication (no email required)
    - Based on exportOrgVaultCronjob.sh bash script
#>

param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$CLIENT_ID,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$CLIENT_SECRET,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$MASTER_PASSWORD,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ORGANIZATION_ID,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OUTPUT_FILE,

    [ValidateSet("json", "csv", "encrypted_json")]
    [string]$EXPORT_FORMAT = "json",

    [ValidateNotNullOrEmpty()]
    [string]$SERVER_URI = "https://vault.bitwarden.com",

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
$BW_EXEC = "bw"
if (-not (Get-Command $BW_EXEC -ErrorAction SilentlyContinue)) {
    Write-Log "Bitwarden CLI (bw) is not available on your system. Exiting..." "ERROR"
    Write-Log "Ensure the directory location is set in the `$PATH variable." "ERROR"
    exit 2
}

Write-Log "Bitwarden CLI found: $((Get-Command $BW_EXEC).Source)"

# Configure the Bitwarden server
Write-Log "Configuring Bitwarden CLI with server URI: $SERVER_URI"
& $BW_EXEC config server $SERVER_URI | Out-Null

# Convert CLIENT_SECRET SecureString to plain text for environment variable
# Using NetworkCredential for cross-platform compatibility
$plainTextClientSecret = [System.Net.NetworkCredential]::new("", $CLIENT_SECRET).Password

# Set environment variables for API key authentication
Write-Log "Setting API key credentials as environment variables"
$env:BW_CLIENTID = $CLIENT_ID
$env:BW_CLIENTSECRET = $plainTextClientSecret

# Check authentication status
Write-Log "Checking authentication status..."
$statusOutput = & $BW_EXEC status | ConvertFrom-Json

if ($statusOutput.status -eq "unauthenticated") {
    Write-Log "Status: Unauthenticated. Logging in with API key..."
    $loginResult = & $BW_EXEC login --apikey --raw

    if ($LASTEXITCODE -ne 0) {
        Write-Log "Failed to log in with API key. Please check your CLIENT_ID and CLIENT_SECRET." "ERROR"
        exit 1
    }

    Write-Log "Successfully logged in with API key."
} else {
    Write-Log "Already authenticated. Status: $($statusOutput.status)"
}

# Convert SecureString to plain text for bw CLI
# Using NetworkCredential for cross-platform compatibility
$plainTextPassword = [System.Net.NetworkCredential]::new("", $MASTER_PASSWORD).Password

# Unlock the vault to get session key
Write-Log "Unlocking vault with master password..."
$sessionKey = & $BW_EXEC unlock $plainTextPassword --raw

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sessionKey)) {
    Write-Log "Failed to unlock vault. Please check your master password." "ERROR"
    & $BW_EXEC logout | Out-Null
    exit 1
}

Write-Log "Vault unlocked successfully."

# Export the organization vault
Write-Log "Exporting organization vault..."
Write-Log "Organization ID: $ORGANIZATION_ID"
Write-Log "Export Format: $EXPORT_FORMAT"
Write-Log "Output File: $OUTPUT_FILE"

& $BW_EXEC export `
    --output $OUTPUT_FILE `
    --format $EXPORT_FORMAT `
    --organizationid $ORGANIZATION_ID `
    --session $sessionKey

if ($LASTEXITCODE -ne 0) {
    Write-Log "Export failed. Please check the parameters and try again." "ERROR"
    & $BW_EXEC logout | Out-Null
    exit 1
}

Write-Log "Export completed successfully!"
Write-Log "File saved at: $OUTPUT_FILE"

# Logout
Write-Log "Logging out from Bitwarden CLI..."
& $BW_EXEC logout | Out-Null
Write-Log "Script completed successfully."
