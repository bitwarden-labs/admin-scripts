# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# bw is required in $PATH and logged in but you do not have to unlock it https://bitwarden.com/help/cli/

$organization_id = "" # Set your Org ID

# Perform CLI auth

$password = Get-Content "secureString.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $password
$session_key = , $cred.GetNetworkCredential().password | powershell -c 'bw unlock --raw'

bw --session $session_key sync | Out-Null

# Fetch the list of Collections

$collections_response = (bw --session $session_key list org-collections --organizationid $organization_id) | ConvertFrom-Json

# Loop through each Collection and delete it

if ($collections_response) {

  foreach ($collection_object in $collections_response) {

    $collection_id = $collection_object.id
    $collection_name = $collection_object.name
    Write-Host "Deleting $collection_name"
    bw --session $session_key delete org-collection $collection_id --organizationid $organization_id
  }
}

# Error handling

else {
  Write-Host "No Collections found"
}
