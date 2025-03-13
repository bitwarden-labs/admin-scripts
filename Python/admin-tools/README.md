# Python Admin Tools

This script is to perform various admin tasks, written in Python

## External module required: 
```bash
pip3 install requests
```

## Requirements Before Running The Script
- Fill in the config file. See config-example.cfg
- For Lastpass: The data is already imported (collections created)

## Examples:

To print script usage:

`python3 bwAdminTools.py -h`

To migrate shared folder permissions from LastPass:

`python3 bwAdminTools.py -c migratelp -f myconfig.cfg`

To migrate attachments from & to Bitwarden servers:

`python3 bwAdminTools.py -c migrateattachments -f myconfig.cfg`


## Config File Description

### Basic Configuration

bw_vault_uri=

FQDN of your web vault e.g. https://bitwarden.example.com/ if your are self-hosted or https://vault.bitwarden.com/ if you are using the Bitwarden cloud

bw_org_client_id=
bw_org_client_secret=

To obtain client_id and client_secret for public API, see: https://bitwarden.com/help/public-api/#authentication

bw_org_id=

Fill in with your Bitwarden Organization's GUID. Take the "client_id" above and remove the "organization." text.

bw_acc_client_id=
bw_acc_client_secret=

How to obtain personal API key: https://bitwarden.com/help/personal-api-key/


### For Bitwarden-to-Bitwarden migration, the below configurations are required

dest_bw_vault_uri=

FQDN of your web vault e.g. https://bitwarden.example.com/ if your are self-hosted or https://vault.bitwarden.com/ if you are using the Bitwarden cloud

dest_bw_org_client_id=
dest_bw_org_client_secret=

To obtain client_id and client_secret for public API, see: https://bitwarden.com/help/public-api/#authentication

dest_bw_org_id=

Fill in with your Bitwarden Organization's GUID. Take the "client_id" above and remove the "organization." text.

dest_bw_acc_client_id=
dest_bw_acc_client_secret=

How to obtain personal API key: https://bitwarden.com/help/personal-api-key/


### For Lastpass-to-Bitwarden migration, the below configurations are required

lp_cid=

This is LastPass Customer ID. You can get this from the LastPass Admin Dashboard.

lp_api_secret=

LastPass API Secret. See: https://support.lastpass.com/help/use-the-lastpass-provisioning-api-lp010068

lp_api_uri=https://lastpass.com/enterpriseapi.php

Fixed value. No changes needed.
