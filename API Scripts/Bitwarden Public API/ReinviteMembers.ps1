param(
    [Parameter(Mandatory=$true)][string]$VaultUri,
    [Parameter(Mandatory=$true)][string]$OrgClientId,
    [Parameter(Mandatory=$true)][string]$OrgClientSecret
)

# Normalize vault URI
$VaultUri = $VaultUri.ToLower().TrimEnd('/')

# Determine identity and API URIs
switch ($VaultUri) {
    "https://vault.bitwarden.com" {
        $IdentityUri = "https://identity.bitwarden.com"
        $ApiUri      = "https://api.bitwarden.com"
    }
    "https://vault.bitwarden.eu" {
        $IdentityUri = "https://identity.bitwarden.eu"
        $ApiUri      = "https://api.bitwarden.eu"
    }
    default {
        $IdentityUri = "$VaultUri/identity"
        $ApiUri      = "$VaultUri/api"
    }
}

# Request an access token
Write-Host "Requesting access token..."
$tokenResponse = Invoke-RestMethod -Method Post -Uri "$IdentityUri/connect/token" `
    -ContentType "application/x-www-form-urlencoded" `
    -Body "grant_type=client_credentials&scope=api.organization&client_id=$OrgClientId&client_secret=$OrgClientSecret"

$accessToken = $tokenResponse.access_token

if (-not $accessToken -or $accessToken -eq "null") {
    Write-Error "Failed to retrieve access token. Please check your credentials and try again."
    exit 1
}
Write-Host "Access token retrieved successfully."

# Retrieve members with status 0 (invited but not accepted)
Write-Host "Retrieving members with pending invitations..."
$membersResponse = Invoke-RestMethod -Method Get -Uri "$ApiUri/public/members/" `
    -Headers @{ Authorization = "Bearer $accessToken" }

$pendingMembers = $membersResponse.data | Where-Object { $_.status -eq 0 } | Select-Object -ExpandProperty id

if (-not $pendingMembers) {
    Write-Host "No members found with status 0 (pending invitation)."
    exit 0
}

Write-Host "Members found. Attempting to re-invite..."

foreach ($memberId in $pendingMembers) {
    Write-Host "Re-inviting member: $memberId"

    try {
        $response = Invoke-WebRequest -Method Post -Uri "$ApiUri/public/members/$memberId/reinvite" `
            -Headers @{ Authorization = "Bearer $accessToken" } `
            -ContentType "application/json"

        if ($response.StatusCode -eq 200) {
            Write-Host "Successfully re-invited member: $memberId"
        } else {
            Write-Host "Failed to re-invite member: $memberId (HTTP Status: $($response.StatusCode))"
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        Write-Host "Failed to re-invite member: $memberId (HTTP Status: $statusCode)"
    }
}

Write-Host "Re-invitation process completed."
