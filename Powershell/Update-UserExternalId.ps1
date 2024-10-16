<#
.SYNOPSIS
Fetches a Bitwarden member by email from the member list and updates their external ID in the EU region.

.PARAMETER CLIENT_ID
Bitwarden organization Client ID (required).

.PARAMETER CLIENT_SECRET
Bitwarden organization Client Secret (required).

.PARAMETER VAULT_URI
Bitwarden vault URI (default: "https://vault.bitwarden.eu").

.PARAMETER API_URL
Bitwarden API URL (default: "https://api.bitwarden.eu").

.PARAMETER Email
The email address of the member to fetch and update (required).

.PARAMETER NewExternalId
The new external ID to set for the member (required).

.EXAMPLE
.\Update-MemberExternalId.ps1 -CLIENT_ID "your-client-id" -CLIENT_SECRET "your-client-secret" -Email "user@example.com" -NewExternalId "new-id"
Fetches the member with the specified email from the member list and updates their external ID to "new-id" in the EU Bitwarden instance.
#>

param (
    [string]$CLIENT_ID,
    [string]$CLIENT_SECRET,
    [string]$VAULT_URI = "https://vault.bitwarden.eu",
    [string]$API_URL = "https://api.bitwarden.eu",
    [string]$Email,
    [string]$NewExternalId
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

function Get-Members {
    param (
        [string]$api_url,
        [string]$access_token
    )
    $headers = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type"  = "application/json"
    }
    $uri = "$api_url/public/members"
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
    return $response
}

function Update-MemberExternalId {
    param (
        [string]$api_url,
        [string]$access_token,
        [string]$member_id,
        [int]$member_type,        
        [string]$new_external_id
    )
    $headers = @{
        "Authorization" = "Bearer $access_token"
        "Content-Type"  = "application/json"
    }
    $body = @{
        externalId = $new_external_id
        type = $member_type
    } | ConvertTo-Json
    
    $uri = "$api_url/public/members/$member_id"
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $body    
    return $response
}

# Main script logic
if (-not $CLIENT_ID -or -not $CLIENT_SECRET -or -not $Email -or -not $NewExternalId) {
    Write-Host "❌ Error: CLIENT_ID, CLIENT_SECRET, Email, and NewExternalId must be provided."
    exit 1
}

Write-Host "🔑 Fetching access token..."
$access_token = Get-AccessToken -client_id $CLIENT_ID -client_secret $CLIENT_SECRET -vault_uri $VAULT_URI

Write-Host "🧑‍🤝‍🧑 Fetching organization members..."
$members_response = Get-Members -api_url $API_URL -access_token $access_token

# Find member by email in members list
$member = $members_response.data | Where-Object { $_.email -eq $Email }

if ($null -eq $member) {
    Write-Host "❌ Member not found with email $Email."
    exit 1
}

$member_id = $member.id
$member_email = $member.email
$member_type = [int]$member.type
Write-Host "😮 Member '$member_email' with type '$member_type' found with ID: $member_id. Updating external ID..."

$update_response = Update-MemberExternalId -api_url $API_URL -access_token $access_token -member_id $member_id -new_external_id $NewExternalId -member_type $member_type

Write-Host "✅ External ID updated successfully for member $Email with ID $member_id."
