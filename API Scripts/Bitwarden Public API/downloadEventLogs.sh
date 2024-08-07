#!/bin/bash

## Script downloads Bitwarden Vault Event Logs
org_client_id='organization.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
org_client_secret='xxxxxxxxxxxxxxxxxxxxxx'
scope='api.organization'
grant_type='client_credentials'
vault_uri='https://vault.bitwarden.com'

ACCESS_TOKEN="$(curl -X POST $vault_uri/identity/connect/token -H 'Content-Type: application/x-www-form-urlencoded' -d 'grant_type=client_credentials&scope=api.organization&client_id='$org_client_id'&client_secret='$org_client_secret'' | cut -d '"' -f4)"
curl -X GET $vault_uri/api/public/events/ -H 'Authorization: Bearer '$ACCESS_TOKEN'' -H "Accept: application/json" # -o '/home/adam/bwEventLogs/eventLogs.txt'