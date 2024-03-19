#Depends on file "secureString.txt" which can be created by first running `Read-Host "Enter Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"`
#Use this to store your API client_secret
#Depends on file "secureString2.txt" which can be created by first running `Read-Host "Enter Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString2.txt"`
#Use this to store your Master Password to unlock your Vault

$organization_id = "b9c70d44-2615-4c84-9913-ac330139c9eb"
$user = "admin-or-manage-users-privileged-account@yourdomain.com"
$BW_CLIENTID = "account settings -> security -> keys -> view api key -> client_id"

$secret = Get-Content "secureString.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $secret

$password = Get-Content "secureString2.txt" | ConvertTo-SecureString
$cred2 = New-Object System.Management.Automation.PSCredential "null", $password
$status = .\bw status | ConvertFrom-Json | Select-Object -ExpandProperty status

if ($status -eq "unauthenticated") {
$env:BW_CLIENTSECRET=$cred.GetNetworkCredential().password
.\bw login --apikey | Out-Null
}

$session_key = , $cred2.GetNetworkCredential().password | powershell -c '.\bw unlock --raw'
$org_members_object = .\bw list --session $session_key org-members --organizationid $organization_id | ConvertFrom-Json
$org_members = $org_members_object |  Where-Object { $_.status -eq 1 } | Select-Object -ExpandProperty id

if ($org_members -eq $null) {
  write-host "Nothing to do here"
}

else {
ForEach ($member_id in $org_members.trim('"')) {
    .\bw confirm --session $session_key org-member $member_id --organizationid $organization_id
}

}
