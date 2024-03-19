# Depends on file "secureString.txt" which can be created by first running:
# Read-Host "Enter Master Password" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString.txt"
# Depends on file "secureString_secret.txt" which can be created by first running:
# Read-Host "Enter client_secret" -AsSecureString | ConvertFrom-SecureString | Out-File "secureString_secret.txt"
# Depends on file "secureString.txt"
# Depends on file collections.json in the same directory of script. Example json:

<#

[
   {
      "collection_name":"CollectionParent",
      "sub_collections": 3,
       "groups": [
            "Nested",
            "Helpdesk"
        ]
   },
   {
      "collection_name":"CollectionExample",
      "sub_collections": 5,
      "groups": [
            "Engineering",
            "Beans"
        ]
   }
]

#>


# jq is required in $PATH https://stedolan.github.io/jq/download/
# bw is required in $PATH and logged in but you do not have to unlock it https://bitwarden.com/help/cli/

<# Usage

In collections.json:

Specify the name of the Parent Collection in collection_name
Specify the number of sub-collections to create in sub_collections
Specify the Groups that should have access to the Collections in groups

Example for Collections created with 3 sub Collections:

CollectionName/Collection1
CollectionName/Collection2
CollectionName/Collection3
...etc

# Note: This script requires that you've already created your Bitwarden Groups before running this script

#>

$json = Get-Content -Raw -Path 'collections.json' | ConvertFrom-Json

ForEach ($collection in $json){
    "CollectionName: {0}" -f $collection.collection_name
    "No of Sub Collections: {0}" -f $collection.sub_collections

    ForEach ($group in $collection.groups){
        "      Groups: {0}" -f $group
    }
}

# Handle API URLs

$organization_id = "" # Set your Org ID

$cloud_flag = 1 # Self-hosted Bitwarden or Cloud?
if ($cloud_flag -eq 1) {
    $api_url = "https://api.bitwarden.com"
    $identity_url = "https://identity.bitwarden.com"
}
else {
    $api_url = "https://YOUR-FQDN/api" # Set your Self-Hosted API URL
    $identity_url = "https://YOUR-FQDN/identity" # Set your Self-Hosted Identity URL
}

# Set up CLI and API auth

$org_client_secret = Get-Content "secureString_secret.txt" | ConvertTo-SecureString
$client_creds = New-Object System.Management.Automation.PSCredential "null", $org_client_secret
$org_client_secret_key =  , $client_creds.GetNetworkCredential().password
$org_client_id = "organization." + $organization_id

# Get Access Token

$body = "grant_type=client_credentials&scope=api.organization&client_id=$org_client_id&client_secret=$org_client_secret_key"
$bearer_token = (Invoke-RestMethod -Method POST -Uri $identity_url/connect/token -Body $body).access_token


$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add('Authorization',('Bearer {0}' -f $bearer_token))
$headers.Add('Accept','application/json')
$headers.Add('Content-Type','application/json')

# Perform CLI auth

$password = Get-Content "secureString.txt" | ConvertTo-SecureString
$cred = New-Object System.Management.Automation.PSCredential "null", $password
$session_key = , $cred.GetNetworkCredential().password | powershell -c 'bw unlock --raw'

# For each Group, create the Collection structure, and then assign the Group to each Collection in the tree
$group_data = (Invoke-RestMethod -Method GET -Uri $api_url/public/groups/ -Headers $headers) | Select-Object -ExpandProperty data

ForEach ($collection in $json) {
    ForEach ($group in $collection.groups) {
        $collection_name = $collection.collection_name
        $sub_count = $collection.sub_collections
        $item_group_id = $group_data | Where-Object { $_.name -eq $group } | Select-Object -ExpandProperty id
        while ($sub_count -gt 0){
            if ($sub_count -lt $collection.sub_collections){
                $item_collection = -join("$collection_name", "/", "Collection", "$sub_count")
            }
            else {
                $item_collection = -join("$collection_name")
            }
            Write-Output $item_collection
            bw --session "$session_key" get template org-collection | jq --arg n "$item_collection" --arg c "$organization_id" --arg g "$item_group_id" '.name=$n | .organizationId=$c | .groups[0].id=$g | del(.groups[1])' | bw encode | bw --session "$session_key" create org-collection --organizationid $organization_id
            "\n Created Collection" -f $item_collection
            $sub_count--
            }
    }
}