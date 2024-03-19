# Script to create a report of when passwords were last revised in the vault
import csv
import json
import subprocess

# setup
session_key = input('Input session key: ') # bw session key
org_id = input('Input Org ID: ') # org ID
bw = ['./bw', '--session', session_key]

with open('changedPasswordsReport.csv', 'w', newline='') as csvfile:
  reportWriter = csv.writer(csvfile, delimiter = ',', quotechar='"', quoting=csv.QUOTE_MINIMAL)
  items = json.loads(subprocess.run(bw + ['list', 'items', '--organizationid', org_id], stdout=subprocess.PIPE).stdout.decode("utf-8"))

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
