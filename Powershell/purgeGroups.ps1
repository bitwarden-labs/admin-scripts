$vault_uri = "https://vault.bitwarden.com"

$body = @{
    grant_type = "client_credentials"
    client_id = "ENTER_CLIENT_ID_HERE"
    client_secret = "ENTER_CLIENT_SECRET_HERE"
    scope = "api.organization"
}


$headers = @{
    'Content-Type' = 'application/x-www-form-urlencoded'
}

$auth = Invoke-RestMethod -Method Post -Uri $vault_uri/identity/connect/token -Headers $headers -Body $body

$access_token = ("$auth").substring(15,"$auth".length-76) 

$auth_headers = @{ Authorization = "Bearer $access_token" }

$org_groups = Invoke-RestMethod -Method Get -Uri $vault_uri/api/public/groups/ -Headers $auth_headers | ConvertTo-Json | .\jq.exe -c '.data[] | .id'

if ($org_groups)
{
	foreach ($groupid in $org_groups.trim('"'))
	{
		Invoke-RestMethod -Method DELETE -Uri $vault_uri/api/public/groups/$groupid -Headers $auth_headers 
		write-host "$($groupid) deleted"
	}
} else { echo "no groups" }

