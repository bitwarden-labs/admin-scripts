$sessionKey = powershell -c 'bw login --raw'
$itemFiles = @(Get-ChildItem .\*.json)
foreach ($itemFile in $itemFiles) {
    $itemText = Get-Content $itemFile | Out-String
    $itemText | bw encode | bw create --session $sessionKey item
}
# Optional
bw sync --session $sessionKey
bw list --session $sessionKey items
#
#
# Example Item File Syntax
#
#
# {
#   "id": "RANDOM GUID",
#   "organizationId": "YOUR ORGANIZATION ID",
#   "folderId": null,
#   "type": 1,
#   "reprompt": 0,
#   "name": "ITEM NAME",
#   "notes": null,
#   "favorite": true,
#   "login": {
#     "uris": [
#        {
#         "match": null,
#         "uri": "YOUR URI"
#       }
#     ],
#     "username": "YOUR USERNAME",
#     "password": "YOUR PASSWORD",
#     "totp": null
#    },
#    "collectionIds": [
#     "YOUR COLLECTION ID"
#   ]
# }
