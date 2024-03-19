$vault_uri = "https://vault.bitwarden.com"

$body = @{
    grant_type = "client_credentials"
    client_id = "organization.00000000-0000-0000-0000-000000000000"
    client_secret = "SECRET"
    scope = "api.organization"
}
$headers = @{
    'Content-Type' = 'application/x-www-form-urlencoded'
}

$auth = Invoke-RestMethod -Method Post -Uri $vault_uri/identity/connect/token -Headers $headers -Body $body

$access_token = ("$auth").substring(15,"$auth".length-76) 

$auth_headers = @{ Authorization = "Bearer $access_token" }

$org_members = Invoke-RestMethod -Method Get -Uri $vault_uri/api/public/members/ -Headers $auth_headers | ConvertTo-Json | jq -c '.data[] | select( .status == 1 )' | jq -c '.email'

if ($org_members)
{
    $user = "SMTP_USERNAME"
    $pass = ConvertTo-SecureString -String "SMTP_PASSWORD" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential $user, $pass

    $mailParam = @{
        To = "owner.admin@example.com"
        From = "Bitwarden People Checker <no-reply@bitwarden.example.com>"
        Subject = "New People Need Confirmation"
        Body = "$org_members"
        SmtpServer = "smtp.sparkpostmail.com"
        Port = 587
        Credential = $cred
    }
    Send-MailMessage @mailParam -UseSsl
}