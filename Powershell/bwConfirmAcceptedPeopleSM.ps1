param (
    [Parameter(Mandatory=$true)]
    [string]$access_token
)

try {
	$command = Get-Command -Name bw -ErrorAction Stop
}
catch {
	Write-Host "Bitwarden CLI bw is not available on the system." -ForegroundColor Red
	Write-Host "Ensure the program's location is added to the %PATH% variable in Windows." -ForegroundColor Red
	exit 1
}
    
try {
	$command = Get-Command -Name bws -ErrorAction Stop
}
catch {
	Write-Host "Bitwarden Secret Manager CLI bws is not available on the system." -ForegroundColor Red
	Write-Host "Ensure the program's location is added to the %PATH% variable in Windows." -ForegroundColor Red
	exit 1
}

try {
	$command = Get-Command -Name jq -ErrorAction Stop
}
catch {
	Write-Host "JSON Processor jq is not available on the system." -ForegroundColor Red
	Write-Host "Ensure the program's location is added to the %PATH% variable in Windows." -ForegroundColor Red
	exit 1
}
    
$organization_id = "1f0c58c3-a3d8-48b2-bb3a-ac8c0075bcc6"

$masterpass = bws list secrets -t $access_token | jq '.[] | select(.key == \"masterpassword\")' | jq '.value' 
$masterpass = $masterpass -replace  '"', ''

$client_id = bws list secrets -t $access_token | jq '.[] | select(.key == \"client_id\")' | jq '.value' 
$env:BW_CLIENTID = $client_id -replace  '"', ''


$client_secret = bws list secrets -t $access_token | jq '.[] | select(.key == \"client_secret\")' | jq '.value' 
$env:BW_CLIENTSECRET = $client_secret -replace  '"', ''

bw logout --raw
bw login --apikey --raw

$session_key = , $masterpass | powershell -c 'bw unlock --raw'
$org_members_object = bw list --session $session_key org-members --organizationid $organization_id | ConvertFrom-Json
$org_members = $org_members_object |  Where-Object { $_.status -eq 1 } | Select-Object -ExpandProperty id

if ($org_members -eq $null) {
  write-host "Nothing to do here"
}

else {
ForEach ($member_id in $org_members.trim('"')) {
    .\bw confirm --session $session_key org-member $member_id --organizationid $organization_id
}

}

