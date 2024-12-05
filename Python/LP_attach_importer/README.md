A Script to download attachments from LastPass and import it to Bitwarden.
This script makes use for LastPass CLI and Bitwarden CLI.

This script will upload the attachment to items on Bitwarden with the same name. This script WILL NOT import your items from LastPass. You are expected to perform export-import of items prior to running this script.

https://bitwarden.com/help/import-from-lastpass/

Things to do before running the script:
1. Download or Install LastPass CLI

https://github.com/lastpass/lastpass-cli

Login to your LastPass account

2. Download Bitwarden CLI

https://bitwarden.com/download/#downloads-command-line-interface

Log in to your Bitwarden Account

https://bitwarden.com/help/cli/#log-in

Export the session as environment variable

export BW_SESSION="5PBYGU+5yt3Rxxxxxxxxx/wByU34vokGRZjXpSH7Ylo8w=="

3. Fill in the config.cfg

FQDN of your web vault e.g. https://bitwarden.example.com/ if your are self-hosted or https://vault.bitwarden.com/ if you are using the Bitwarden cloud

bw_org_client_id= bw_org_client_secret=

To obtain client_id and client_secret for public API, see: https://bitwarden.com/help/public-api/#authentication

run the script:

python3 bwLPmigration.py -d -c importattall -f config.cfg
