# Script to create a report of when passwords were last revised in the vault
import csv
import json
import os
import subprocess
from utils.create_env import main as create_env
from utils.decrypt_env import decrypt_secrets
from utils.get_session_key import get_session_key

# setup
create_env()
decrypt_secrets()
client_id = os.environ['client_id']
org_id = client_id.split('.', 1)[1]
bw = ['/Users/adambramley/.nvm/versions/node/v19.9.0/bin/bw']

# Obtain BW CLI Session key
session_key = get_session_key()

with open('changedPasswordsReport.csv', 'w', newline='') as csvfile:
  reportWriter = csv.writer(csvfile, delimiter = ',', quotechar='"', quoting=csv.QUOTE_MINIMAL)

  # get items using BW list items
  items = json.loads(subprocess.run(bw + ['list', 'items', '--organizationid', org_id, '--session', session_key], stdout=subprocess.PIPE).stdout.decode("utf-8"))

  # write csv headers
  reportWriter.writerow(['Item_Name', 'Item_ID', 'Password_Revision_Date', 'Password_Creation_Date'])

  # write each item with password revision dates
  for item in items:
    id = str(item['id'])
    name = str(item['name'])
    revisionDate = item.get('login', {}).get('passwordRevisionDate')
    if revisionDate is not None:
      revisionDate = str(revisionDate)
    else:
      revisionDate = "N/A"
    creationDate = str(item['creationDate'])
    rowData = [ name, id, revisionDate, creationDate]
    reportWriter.writerow(rowData)
