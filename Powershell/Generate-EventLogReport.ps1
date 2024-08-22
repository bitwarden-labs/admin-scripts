<#
.SYNOPSIS
Fetches Bitwarden event logs within a date range and displays them in a table.

.PARAMETER CLIENT_ID
Bitwarden organization Client ID (required).

.PARAMETER CLIENT_SECRET
Bitwarden organization Client Secret (required).

.PARAMETER VAULT_URI
Bitwarden vault URI (default: "https://vault.bitwarden.com").

.PARAMETER API_URL
Bitwarden API URL (default: "https://api.bitwarden.com").

.PARAMETER start_date
Start date for logs (default: 1 month ago).

.PARAMETER end_date
End date for logs (default: today).

.EXAMPLE
.\Generate-EventLogReport.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -start_date "2024-06-01" -end_date "2024-08-31"
Fetches and displays logs between June 1, 2024, and August 31, 2024.
#>

param (
    [string]$CLIENT_ID,
    [string]$CLIENT_SECRET,
    [string]$VAULT_URI = "https://vault.bitwarden.com",
    [string]$API_URL = "https://api.bitwarden.com",
    [datetime]$start_date = (Get-Date).AddMonths(-1),
    [datetime]$end_date = (Get-Date)
)

# Validate required parameters
if (-not $CLIENT_ID -or -not $CLIENT_SECRET) {
    Write-Host "Error: CLIENT_ID and CLIENT_SECRET must be provided."
    exit 1
}

# Convert dates to ISO 8601 format
$date_format = "yyyy-MM-ddTHH:mm:ss.fffZ"
$start_date_iso = $start_date.ToString($date_format)
$end_date_iso = $end_date.ToString($date_format)

Write-Host "Fetching logs from $start_date_iso to $end_date_iso"

# Get access token from Bitwarden
$auth_response = Invoke-RestMethod -Uri "$VAULT_URI/identity/connect/token" -Method Post -ContentType 'application/x-www-form-urlencoded' -Body @{
    grant_type    = "client_credentials"
    client_id     = $CLIENT_ID
    client_secret = $CLIENT_SECRET
    scope         = "api.organization"
}

$access_token = $auth_response.access_token

# Function to fetch event logs
function Get-EventLogs {
    param (
        [string]$start,
        [string]$end,
        [string]$continuation_token = ""
    )

    $headers = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type"  = "application/json"
    }

    $uri = "$API_URL/public/events?start=$start&end=$end"
    if ($continuation_token) {
        $uri = "$uri&continuationToken=$continuation_token"
    }

    return Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
}

# Fetch and store all event logs
$all_event_logs = @()
$has_more_logs = $true
$continuation_token = ""

while ($has_more_logs) {
    $event_logs = Get-EventLogs -start $start_date_iso -end $end_date_iso -continuation_token $continuation_token
    $all_event_logs += $event_logs.data

    if ($event_logs.continuationToken) {
        $continuation_token = $event_logs.continuationToken
    } else {
        $has_more_logs = $false
    }
}

# Display logs in a table
$all_event_logs | Format-Table -AutoSize

# Display summary statistics
$total_logs_fetched = $all_event_logs.Count
Write-Host "`nSummary:"
Write-Host "Total logs: $total_logs_fetched"
Write-Host "Date range: $start_date_iso to $end_date_iso"
