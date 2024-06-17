$cloud_flag = 1  # Self-hosted Bitwarden or Cloud?

if ($cloud_flag -eq 1) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
} else {
    $api_url = "https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    $identity_url = "https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
}

$org_client_id = Read-Host 'Organization Client ID: '
$org_client_secret = Read-Host 'Organization Client Secret (Hidden): ' -AsSecureString

# Convert secure string to plain text
$org_client_secret_plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($org_client_secret))

# Get access token
$access_token_response = Invoke-RestMethod -Uri "$identity_url/connect/token" -Method Post -ContentType 'application/x-www-form-urlencoded' -Body "grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$org_client_secret_plain"
$access_token = $access_token_response.access_token

Invoke-RestMethod -Uri "$api_url/public/groups" -Headers @{ Authorization = "Bearer $access_token" } | Select-Object -ExpandProperty data | ForEach-Object { [PSCustomObject]@{ id = $_.id; name = $_.name } } | ConvertTo-Json | Out-File -FilePath groups.json

function Get-GroupNameById {
    param(
        [string]$group_id
    )
    $group_name = (Get-Content -Path groups.json | ConvertFrom-Json | Where-Object { $_.id -eq $group_id }).name
    return $group_name
}

$org_members_response = Invoke-RestMethod -Uri "$api_url/public/members/" -Headers @{ Authorization = "Bearer $access_token" }
$org_members = $org_members_response.data | ForEach-Object { "$($_.id),$($_.email),$($_.type),$($_.status),$($_.twoFactorEnabled)" }

Write-Host "email,role,status,2FA,groups"
foreach ($member in $org_members) {
    $member_info = $member -split ','
    $userid = $member_info[0]
    $email = $member_info[1]
    $role = switch ($member_info[2]) {
        0 { "Owner" }
        1 { "Admin" }
        2 { "User" }
        3 { "Manager" }
        4 { "Custom Admin" }
        default { "unknown" }
    }
    $status = switch ($member_info[3]) {
        0 { "invited" }
        1 { "accepted" }
        2 { "confirmed" }
        -1 { "revoked" }
        default { "unknown" }
    }
    $twofa_status = $member_info[4]

    $group_ids = (Invoke-RestMethod -Uri "$api_url/public/members/$userid/group-ids" -Headers @{ Authorization = "Bearer $access_token" }).id
    $group_names = $group_ids | ForEach-Object { Get-GroupNameById $_ }

    Write-Host "$email,$role,$status,$twofa_status,$group_names"
    Start-Sleep -Milliseconds 200
}

Remove-Item -Path groups.json
