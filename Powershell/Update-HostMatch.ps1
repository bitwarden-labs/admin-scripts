<#
.SYNOPSIS
    Updates all items in a given organization's Bitwarden vault to ensure each login URI is set to a specified `URI` and `MATCH` value.

.DESCRIPTION
    This script updates the URIs of all items in the specified Bitwarden organization's vault. It replaces or sets the `uri` field, and sets the `match` field to control how Bitwarden detects URIs for autofill.

    Bitwarden URI Match Options (from Bitwarden documentation):
    - Domain (0): The top-level domain and second-level domain of the URI match the detected resource.
    - Host (1): The hostname and (if specified) port of the URI matches the detected resource.
    - StartsWith (2): The detected resource starts with the URI, regardless of what follows it.
    - Exact (3): The URI matches the detected resource exactly.
    - RegularExpression (4): The detected resource matches a specified regular expression.
    - Never (5): Never offer auto-fill for the item.

.PARAMETER EMAIL
    The email for the Bitwarden CLI login.

.PARAMETER MASTER_PASSWORD
    The master password for the CLI login, passed securely.

.PARAMETER ORGANIZATION_ID
    The organization ID for which items should be updated.

.PARAMETER URI
    The URI value to set for all items' login URIs.

.PARAMETER MATCH
    The match value to set for all items' login URIs (integer 0-5 corresponding to Domain, Host, etc.)

.PARAMETER LOG_FILE
    Optional log file for storing script logs.

.EXAMPLE
    bw config server https://vault.bitwarden.eu
    bw logout
    .\Update-HostMatch.ps1 `
        -EMAIL "user@example.com" `
        -MASTER_PASSWORD (ConvertTo-SecureString "YourPassword" -AsPlainText -Force) `
        -ORGANIZATION_ID "your-organization-id" `
        -URI "https://example.com" `
        -MATCH 1

    Sets all login URIs to "https://example.com" and match mode to "Host" (1).
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$EMAIL,

    [Parameter(Mandatory=$true)]
    [SecureString]$MASTER_PASSWORD,

    [Parameter(Mandatory=$true)]
    [string]$ORGANIZATION_ID,

    [Parameter(Mandatory=$true)]
    [string]$URI,

    [Parameter(Mandatory=$true)]
    [int]$MATCH,

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
    Write-Host "$logEntry"

    if ($LOG_FILE) {
        Add-Content -Path $LOG_FILE -Value $logEntry
    }
}

# Convert SecureString to plain text
function ConvertFrom-SecureStringPlain {
    param ([SecureString]$SecureString)
    return [System.Runtime.InteropServices.Marshal]::PtrToStringUni(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    )
}

# Authenticate and unlock Bitwarden vault
function Authenticate-Bitwarden {
    Write-Log "🔑 Authenticating with Bitwarden CLI..."
    $password = ConvertFrom-SecureStringPlain -SecureString $MASTER_PASSWORD
    $loginResult = & bw login $EMAIL $password --raw

    if (-not $loginResult) {
        Write-Log "❌ Failed to authenticate with Bitwarden CLI." "ERROR"
        exit 1
    }

    Write-Log "🔓 Unlocking Bitwarden vault..."
    $sessionKey = & bw unlock $password --raw

    if (-not $sessionKey) {
        Write-Log "❌ Failed to unlock Bitwarden vault." "ERROR"
        exit 1
    }

    Write-Log "✅ Successfully unlocked Bitwarden vault."
    $env:BW_SESSION = $sessionKey
}

# Main function
function Main {
    Write-Log "🚀 Starting item URI and match value update process..."

    # Authenticate with Bitwarden
    Authenticate-Bitwarden

    # Fetch all items for the given organization
    Write-Log "📦 Fetching items for organization ID: $ORGANIZATION_ID"
    $itemsJson = & bw list items --organizationid $ORGANIZATION_ID --session $env:BW_SESSION
    $items = $itemsJson | ConvertFrom-Json

    if (-not $items) {
        Write-Log "❌ No items returned or failed to fetch items." "ERROR"
        exit 1
    }

    foreach ($item in $items) {
        if (-not $item.login) {
            Write-Log "$($item.name) does not have a login object, skipping."
            continue
        }

        if ($item.login.uris) {
            # Update existing URIs
            foreach ($uriObj in $item.login.uris) {
                $uriObj.uri = $URI
                $uriObj.match = $MATCH
            }
        } else {
            # Create a new URI object if none exist
            $item.login.uris = @(
                [PSCustomObject]@{
                    uri   = $URI
                    match = $MATCH
                }
            )
        }

        # Convert the item back to JSON and encode it
        $updatedItemJson = $item | ConvertTo-Json -Depth 10
        $encodedItem = $updatedItemJson | bw encode

        # Apply changes to Bitwarden
        try {
            & bw edit item $item.id --session $env:BW_SESSION --quiet $encodedItem | Out-Null
            Write-Log "$($item.name) updated with URI=$URI and MATCH=$MATCH"
        } catch {
            Write-Log "❌ Failed to update item: $($item.name) - $_" "ERROR"
        }
    }

    Write-Log "🎉 All applicable items have been updated with the specified URI and match value."
}

# Execute main
Main