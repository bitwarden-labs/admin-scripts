import json
import os
import subprocess
from authentication import session_key
from variables import bw_path, org_id

os.environ["BW_SESSION"] = session_key

# Obtain list of org collections
collections = json.loads(
  subprocess.run(
    bw_path + ["list", "org-collections", "--organizationid", org_id ],
    stdout=subprocess.PIPE,
    text=True
  ).stdout
)

# Store 2x collection IDs to add to item later
first_collection_id = collections[0]['id']
second_collection_id = collections[1]['id']

# ### View Collection IDs if necessary
# print(first_collection_id)
# print(second_collection_id)

# Obtain Bitwarden Item Template for 'item' and 'item.login' (https://bitwarden.com/help/cli/#get)
with open("item_template.json", "r") as file:
  item_template = json.load(file)

with open("item_template_login.json", "r") as file:
  item_template_login = json.load(file)

# Combine the two templates into a complete template
item_instance = item_template.copy()
item_instance["login"] = item_template_login

# ### Print combined template if required
# print(item_instance)

# Populate item with data
item_instance["name"] = "Example Item"
item_instance["organizationId"] = org_id
item_instance["collectionIds"] = [first_collection_id, second_collection_id]
item_instance["notes"] = "This item was created programatically."
item_instance["login"]["username"] = "dave"
item_instance["login"]["password"] = "password123"
item_instance["login"]["uris"] = ["https://bbc.co.uk", "https://bbc.com"]

# ### View item ready for encoding if required
# print(json.dumps(item_instance, indent=2))

# https://bitwarden.com/help/cli/#encode
encoded_item = subprocess.run(
  bw_path + ["encode"],
  input=json.dumps(item_instance),
  text=True,
  stdout=subprocess.PIPE
).stdout

# ### View encoded item if required
# print(encoded_item)

# https://bitwarden.com/help/cli/#create
subprocess.run(
  bw_path + ["create", "item"],
  input=encoded_item,
  text=True
)
