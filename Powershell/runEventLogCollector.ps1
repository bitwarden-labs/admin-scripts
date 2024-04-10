# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter Org client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
# Depends on file "secureString_user.txt" which can be created by first running:
# Read-Host "Enter user client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_user.txt"
# Depends on requests, logzero which can be installed by running:
# pip install requests logzero

$organization_id = "" # Set your Org ID
$admin_account_email = "email@domain.com" # Set the login for the BW CLI
$Env:BW_CLIENTID = "" # Obtain from My Account->Security->View API Key
$user_secret = Get-Content "secureString_user.txt" | ConvertTo-SecureString
$user_creds = New-Object System.Management.Automation.PSCredential "null", $user_secret
$Env:BW_CLIENTSECRET =  , $user_creds.GetNetworkCredential().password
$org_client_secret = Get-Content "secureString_secret.txt" | ConvertTo-SecureString
$client_creds = New-Object System.Management.Automation.PSCredential "null", $org_client_secret
$org_client_secret_key =  , $client_creds.GetNetworkCredential().password
$org_client_id = "organization." + $organization_id

$password = Get-Content "secureString.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $password

bw login --apikey

$password = Get-Content "secureString.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $password
$Env:BW_SESSION = , $cred.GetNetworkCredential().password | powershell -c '.\bw unlock --raw'

python .\bw-event-collector.py --user $org_client_id --secret $org_client_secret_key
