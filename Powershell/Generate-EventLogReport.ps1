<#
.SYNOPSIS
Fetches Bitwarden event logs within a date range and displays them in a table or saves them to a CSV file.

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

.PARAMETER OutputCSV
(Optional) Path to a CSV file where the logs should be saved.

.PARAMETER Columns
(Optional) Array of columns to display (e.g., date, type, device). By default, it shows date, type, and device.

.EXAMPLE
.\Generate-EventLogReport.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -start_date "2024-06-01" -end_date "2024-08-31"
Fetches and displays logs between June 1, 2024, and August 31, 2024.

.EXAMPLE
.\Generate-EventLogReport.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -start_date "2024-06-01" -end_date "2024-08-31" -OutputCSV "logs.csv"
Fetches logs and saves them to "logs.csv" in CSV format.

.EXAMPLE
.\Generate-EventLogReport.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret"
Fetches and displays logs from the last month up to today.

.EXAMPLE
.\Generate-EventLogReport.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -OutputCSV "logs.csv"
Fetches logs from the last month up to today and saves them to "logs.csv" in CSV format.

.EXAMPLE
.\Generate-EventLogReport.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -Columns date,type,device
Fetches logs and displays only the date, type, and device columns.

.EXAMPLE
.\Generate-EventLogReport.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -Columns date,type,device -OutputCSV "filtered_logs.csv"
Fetches logs, displays only the date, type, and device columns, and saves them to "filtered_logs.csv" in CSV format.
#>

param (
    [string]$CLIENT_ID,
    [string]$CLIENT_SECRET,
    [string]$VAULT_URI = "https://vault.bitwarden.com",
    [string]$API_URL = "https://api.bitwarden.com",
    [datetime]$start_date = (Get-Date).AddMonths(-1),
    [datetime]$end_date = (Get-Date),
    [string]$OutputCSV,
    [string[]]$Columns = @("date", "type", "device")  # Default columns
)

function Update-Type {
    param ([int]$type)
    switch ($type) {
        1000 { return "(1000) Logged In." }
        1001 { return "(1001) Changed account password." }
        1002 { return "(1002) Enabled/updated two-step login." }
        1003 { return "(1003) Disabled two-step login." }
        1004 { return "(1004) Recovered account from two-step login." }
        1005 { return "(1005) Login attempted failed with incorrect password." }
        1006 { return "(1006) Login attempt failed with incorrect two-step login." }
        1007 { return "(1007) User exported their individual vault items." }
        1008 { return "(1008) User updated a password issued through account recovery." }
        1009 { return "(1009) User migrated their decryption key with Key Connector." }
        1010 { return "(1010) User requested device approval." }
        1100 { return "(1100) Created item." }
        1101 { return "(1101) Edited item." }
        1102 { return "(1102) Permanently Deleted item." }
        1103 { return "(1103) Created attachment for item." }
        1104 { return "(1104) Deleted attachment for item." }
        1105 { return "(1105) Moved item to an organization." }
        1106 { return "(1106) Edited collections for item." }
        1107 { return "(1107) Viewed item." }
        1108 { return "(1108) Viewed password for item." }
        1109 { return "(1109) Viewed hidden field for item." }
        1110 { return "(1110) Viewed security code for item." }
        1111 { return "(1111) Copied password for item." }
        1112 { return "(1112) Copied hidden field for item." }
        1113 { return "(1113) Copied security code for item." }
        1114 { return "(1114) Autofilled item." }
        1115 { return "(1115) Sent item to trash." }
        1116 { return "(1116) Restored item." }
        1117 { return "(1117) Viewed Card Number for item." }
        1300 { return "(1300) Created collection." }
        1301 { return "(1301) Edited collection." }
        1302 { return "(1302) Deleted collection." }
        1400 { return "(1400) Created group." }
        1401 { return "(1401) Edited group." }
        1402 { return "(1402) Deleted group." }
        1500 { return "(1500) Invited user." }
        1501 { return "(1501) Confirmed user." }
        1502 { return "(1502) Edited user." }
        1503 { return "(1503) Removed user." }
        1504 { return "(1504) Edited groups for user." }
        1505 { return "(1505) Unlinked SSO for user." }
        1506 { return "(1506) User enrolled in account recovery." }
        1507 { return "(1507) User withdrew from account recovery." }
        1508 { return "(1508) Master Password reset for user." }
        1509 { return "(1509) Reset SSO link for user." }
        1510 { return "(1510) User logged in using SSO for the first time." }
        1511 { return "(1511) Revoked organization access for user." }
        1512 { return "(1512) Restored organization access for user." }
        1513 { return "(1513) Approved device for user." }
        1514 { return "(1514) Denied device for user." }
        1600 { return "(1600) Edited organization settings." }
        1601 { return "(1601) Purged organization vault." }
        1602 { return "(1602) Exported organization vault." }
        1603 { return "(1603) Organization Vault access by a managing Provider." }
        1604 { return "(1604) Organization enabled SSO." }
        1605 { return "(1605) Organization disabled SSO." }
        1606 { return "(1606) Organization enabled Key Connector." }
        1607 { return "(1607) Organization disabled Key Connector." }
        1608 { return "(1608) Families Sponsorships synced." }
        1609 { return "(1609) Modified collection management setting." }
        1700 { return "(1700) Modified policy." }
        2000 { return "(2000) Added domain." }
        2001 { return "(2001) Removed domain." }
        2002 { return "(2002) Domain verified." }
        2003 { return "(2003) Domain not verified." }
        default { return "(default) Unknown event type ($type)." }
    }
}

function Update-Device {
    param ([int]$device)
    switch ($device) {
        0  { return "Android" }
        1  { return "iOS" }
        2  { return "Chrome Extension" }
        3  { return "Firefox Extension" }
        4  { return "Opera Extension" }
        5  { return "Edge Extension" }
        6  { return "Windows" }
        7  { return "macOS" }
        8  { return "Linux" }
        9  { return "Chrome" }
        10 { return "Firefox" }
        11 { return "Opera" }
        12 { return "Edge" }
        13 { return "Internet Explorer" }
        14 { return "Unknown Browser" }
        15 { return "Android (Amazon)" }
        16 { return "UWP" }
        17 { return "Safari" }
        18 { return "Vivaldi" }
        19 { return "Vivaldi Extension" }
        20 { return "Safari Extension" }
        21 { return "SDK" }
        22 { return "Server" }
        23 { return "Windows CLI" }
        24 { return "MacOs CLI" }
        25 { return "Linux CLI" }
        default { return "Unknown Device Type ($device)" }
    }
}

if (-not $CLIENT_ID -or -not $CLIENT_SECRET) {
    Write-Host "Error: CLIENT_ID and CLIENT_SECRET must be provided."
    exit 1
}

$date_format = "yyyy-MM-dd"
$start_date_iso = $start_date.ToString($date_format) + "T00:00:01.000Z"
$end_date_iso = $end_date.ToString($date_format) + "T23:59:59.999Z"

Write-Host "Fetching logs from $start_date_iso to $end_date_iso"

$auth_response = Invoke-RestMethod -Uri "$VAULT_URI/identity/connect/token" -Method Post -ContentType 'application/x-www-form-urlencoded' -Body @{
    grant_type    = "client_credentials"
    client_id     = $CLIENT_ID
    client_secret = $CLIENT_SECRET
    scope         = "api.organization"
}

$access_token = $auth_response.access_token

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

    if ($continuation_token -ne "") {
        $uri = "$uri&continuationToken=$continuation_token"
    }

    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    return $response
}

$all_event_logs = @()
$has_more_logs = $true
$continuation_token = ""

while ($has_more_logs) {
    $event_logs = Get-EventLogs -start $start_date_iso -end $end_date_iso -continuation_token $continuation_token
    $all_event_logs += $event_logs.data | ForEach-Object {
        $_.type = Update-Type -type $_.type
        $_.device = Update-Device -device $_.device
        $_
    }

    if ($event_logs.continuationToken) {
        $continuation_token = $event_logs.continuationToken
    } else {
        $has_more_logs = $false
    }
}

if ($OutputCSV) {
    $all_event_logs | Select-Object -Property $Columns | Export-Csv -Path $OutputCSV -NoTypeInformation
    Write-Host "Logs saved to $OutputCSV"
} else {
    $all_event_logs | Format-Table -Property $Columns -AutoSize
}

Write-Host "`nSummary:"
$total_logs_fetched = ($all_event_logs | Measure-Object).Count
Write-Host "Total logs '$total_logs_fetched' from $start_date_iso to $end_date_iso"
