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
(Optional) Array of columns to display (e.g., date, type, device). By default, it shows date, type, device, and memberEmail.

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
.\Generate-EventLogReport.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -Columns date,type,device,memberEmail
Fetches logs and displays only the date, type, device, and memberEmail columns.
#>

param (
    [string]$CLIENT_ID,
    [string]$CLIENT_SECRET,
    [string]$VAULT_URI = "https://vault.bitwarden.com",
    [string]$API_URL = "https://api.bitwarden.com",
    [datetime]$start_date = (Get-Date).AddMonths(-1),
    [datetime]$end_date = (Get-Date),
    [string]$OutputCSV,
    [string[]]$Columns = @("typeText", "device", "date", "userName", "userEmail", "ipAddress")

)
function Get-AccessToken {
    param (
        [string]$client_id,
        [string]$client_secret,
        [string]$vault_uri
    )
    $auth_response = Invoke-RestMethod -Uri "$vault_uri/identity/connect/token" -Method Post -ContentType 'application/x-www-form-urlencoded' -Body @{
        grant_type    = "client_credentials"
        client_id     = $client_id
        client_secret = $client_secret
        scope         = "api.organization"
    }
    return $auth_response.access_token
}

function Update-Type {
    param ([int]$type)
    switch ($type) {
        1000 { return [PSCustomObject]@{ code = 1000; text = "Logged In." } }
        1001 { return [PSCustomObject]@{ code = 1001; text = "Changed account password." } }
        1002 { return [PSCustomObject]@{ code = 1002; text = "Enabled/updated two-step login." } }
        1003 { return [PSCustomObject]@{ code = 1003; text = "Disabled two-step login." } }
        1004 { return [PSCustomObject]@{ code = 1004; text = "Recovered account from two-step login." } }
        1005 { return [PSCustomObject]@{ code = 1005; text = "Login attempted failed with incorrect password." } }
        1006 { return [PSCustomObject]@{ code = 1006; text = "Login attempt failed with incorrect two-step login." } }
        1007 { return [PSCustomObject]@{ code = 1007; text = "User exported their individual vault items." } }
        1008 { return [PSCustomObject]@{ code = 1008; text = "User updated a password issued through account recovery." } }
        1009 { return [PSCustomObject]@{ code = 1009; text = "User migrated their decryption key with Key Connector." } }
        1010 { return [PSCustomObject]@{ code = 1010; text = "User requested device approval." } }
        1100 { return [PSCustomObject]@{ code = 1100; text = "Created item." } }
        1101 { return [PSCustomObject]@{ code = 1101; text = "Edited item." } }
        1102 { return [PSCustomObject]@{ code = 1102; text = "Permanently Deleted item." } }
        1103 { return [PSCustomObject]@{ code = 1103; text = "Created attachment for item." } }
        1104 { return [PSCustomObject]@{ code = 1104; text = "Deleted attachment for item." } }
        1105 { return [PSCustomObject]@{ code = 1105; text = "Moved item to an organization." } }
        1106 { return [PSCustomObject]@{ code = 1106; text = "Edited collections for item." } }
        1107 { return [PSCustomObject]@{ code = 1107; text = "Viewed item." } }
        1108 { return [PSCustomObject]@{ code = 1108; text = "Viewed password for item." } }
        1109 { return [PSCustomObject]@{ code = 1109; text = "Viewed hidden field for item." } }
        1110 { return [PSCustomObject]@{ code = 1110; text = "Viewed security code for item." } }
        1111 { return [PSCustomObject]@{ code = 1111; text = "Copied password for item." } }
        1112 { return [PSCustomObject]@{ code = 1112; text = "Copied hidden field for item." } }
        1113 { return [PSCustomObject]@{ code = 1113; text = "Copied security code for item." } }
        1114 { return [PSCustomObject]@{ code = 1114; text = "Autofilled item." } }
        1115 { return [PSCustomObject]@{ code = 1115; text = "Sent item to trash." } }
        1116 { return [PSCustomObject]@{ code = 1116; text = "Restored item." } }
        1117 { return [PSCustomObject]@{ code = 1117; text = "Viewed Card Number for item." } }
        1300 { return [PSCustomObject]@{ code = 1300; text = "Created collection." } }
        1301 { return [PSCustomObject]@{ code = 1301; text = "Edited collection." } }
        1302 { return [PSCustomObject]@{ code = 1302; text = "Deleted collection." } }
        1400 { return [PSCustomObject]@{ code = 1400; text = "Created group." } }
        1401 { return [PSCustomObject]@{ code = 1401; text = "Edited group." } }
        1402 { return [PSCustomObject]@{ code = 1402; text = "Deleted group." } }
        1500 { return [PSCustomObject]@{ code = 1500; text = "Invited user." } }
        1501 { return [PSCustomObject]@{ code = 1501; text = "Confirmed user." } }
        1502 { return [PSCustomObject]@{ code = 1502; text = "Edited user." } }
        1503 { return [PSCustomObject]@{ code = 1503; text = "Removed user." } }
        1504 { return [PSCustomObject]@{ code = 1504; text = "Edited groups for user." } }
        1505 { return [PSCustomObject]@{ code = 1505; text = "Unlinked SSO for user." } }
        1506 { return [PSCustomObject]@{ code = 1506; text = "User enrolled in account recovery." } }
        1507 { return [PSCustomObject]@{ code = 1507; text = "User withdrew from account recovery." } }
        1508 { return [PSCustomObject]@{ code = 1508; text = "Master Password reset for user." } }
        1509 { return [PSCustomObject]@{ code = 1509; text = "Reset SSO link for user." } }
        1510 { return [PSCustomObject]@{ code = 1510; text = "User logged in using SSO for the first time." } }
        1511 { return [PSCustomObject]@{ code = 1511; text = "Revoked organization access for user." } }
        1512 { return [PSCustomObject]@{ code = 1512; text = "Restored organization access for user." } }
        1513 { return [PSCustomObject]@{ code = 1513; text = "Approved device for user." } }
        1514 { return [PSCustomObject]@{ code = 1514; text = "Denied device for user." } }
        1600 { return [PSCustomObject]@{ code = 1600; text = "Edited organization settings." } }
        1601 { return [PSCustomObject]@{ code = 1601; text = "Purged organization vault." } }
        1602 { return [PSCustomObject]@{ code = 1602; text = "Exported organization vault." } }
        1603 { return [PSCustomObject]@{ code = 1603; text = "Organization Vault access by a managing Provider." } }
        1604 { return [PSCustomObject]@{ code = 1604; text = "Organization enabled SSO." } }
        1605 { return [PSCustomObject]@{ code = 1605; text = "Organization disabled SSO." } }
        1606 { return [PSCustomObject]@{ code = 1606; text = "Organization enabled Key Connector." } }
        1607 { return [PSCustomObject]@{ code = 1607; text = "Organization disabled Key Connector." } }
        1608 { return [PSCustomObject]@{ code = 1608; text = "Families Sponsorships synced." } }
        1609 { return [PSCustomObject]@{ code = 1609; text = "Modified collection management setting." } }
        1700 { return [PSCustomObject]@{ code = 1700; text = "Modified policy." } }
        2000 { return [PSCustomObject]@{ code = 2000; text = "Added domain." } }
        2001 { return [PSCustomObject]@{ code = 2001; text = "Removed domain." } }
        2002 { return [PSCustomObject]@{ code = 2002; text = "Domain verified." } }
        2003 { return [PSCustomObject]@{ code = 2003; text = "Domain not verified." } }
        default { return [PSCustomObject]@{ code = $type; text = "Unknown event type." } }
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

function Get-Members {
    param ([string]$api_url, [string]$access_token)
    $headers = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type"  = "application/json"
    }
    $uri = "$api_url/public/members"
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    return $response
}

function Get-EventLog {
    param (
        [string]$start,
        [string]$end,
        [string]$continuation_token = "",
        [string]$api_url,
        [string]$access_token
    )

    $headers = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type"  = "application/json"
    }

    $uri = "$api_url/public/events?start=$start&end=$end"
    if ($continuation_token -ne "") {
        $uri = "$uri&continuationToken=$continuation_token"
    }

    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    return $response
}

if (-not $CLIENT_ID -or -not $CLIENT_SECRET) {
    Write-Host "Error: CLIENT_ID and CLIENT_SECRET must be provided."
    exit 1
}

if (-not $CLIENT_ID -or -not $CLIENT_SECRET) {
    Write-Host "Error: CLIENT_ID and CLIENT_SECRET must be provided."
    exit 1
}

$date_format = "yyyy-MM-dd"
$start_date_iso = $start_date.ToString($date_format) + "T00:00:01.000Z"
$end_date_iso = $end_date.ToString($date_format) + "T23:59:59.999Z"

Write-Host "Fetching access token..."
$access_token = Get-AccessToken -client_id $CLIENT_ID -client_secret $CLIENT_SECRET -vault_uri $VAULT_URI

Write-Host "Fetching members..."
$members = Get-Members -api_url $API_URL -access_token $access_token
$all_event_logs = @()
$has_more_logs = $true
$continuation_token = ""

Write-Host "Fetching event logs..."
while ($has_more_logs) {
    $event_logs = Get-EventLog -start $start_date_iso -end $end_date_iso -continuation_token $continuation_token -api_url $API_URL -access_token $access_token
    $all_event_logs += $event_logs.data

    if ($event_logs.continuationToken) {
        $continuation_token = $event_logs.continuationToken
    } else {
        $has_more_logs = $false
    }
}

$all_event_logs = $all_event_logs | ForEach-Object {
    # Determine the userId by merging memberId and actingUserId
    $userId = if ($_.memberId) { $_.memberId } elseif ($_.actingUserId) { $_.actingUserId } else { "" }

    # Lookup the user information in the members' data by checking both 'id' and 'userId'
    $userInfo = $members.data | Where-Object { $_.id -eq $userId -or $_.userId -eq $userId }
    $userName = if ($userInfo) { $userInfo.name } else { "Unknown" }
    $userEmail = if ($userInfo) { $userInfo.email } else { "Unknown" }

    # Add the userId, userName, userEmail, event type, and device information
    $_ | Add-Member -NotePropertyName userId -NotePropertyValue $userId -Force
    $_ | Add-Member -NotePropertyName userName -NotePropertyValue $userName -Force
    $_ | Add-Member -NotePropertyName userEmail -NotePropertyValue $userEmail -Force

    $eventType = Update-Type -type $_.type
    $_ | Add-Member -NotePropertyName typeText -NotePropertyValue $eventType.text -Force
    $_ | Add-Member -NotePropertyName device -NotePropertyValue (Update-Device -device $_.device) -Force

    $_
}

if ($OutputCSV) {
    $all_event_logs | Select-Object -Property $Columns | Export-Csv -Path $OutputCSV -NoTypeInformation
    Write-Host "Logs saved to $OutputCSV"
} else {
    $all_event_logs | Format-Table -Property $Columns -AutoSize
}

$total_logs_fetched = ($all_event_logs | Measure-Object).Count
Write-Host "Total logs '$total_logs_fetched' from $start_date_iso to $end_date_iso"
