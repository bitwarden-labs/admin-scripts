#!/usr/bin/env python3

"""
Prerequisite: run BW CLI serve (https://bitwarden.com/help/cli/#serve) and unlock your vault
"""

import json
import urllib.request
import datetime
import os

affected_collections = os.environ.get("BW_COLLECTIONS")
if not affected_collections:
    affected_collections = input(
        "Enter affected collections (separated by commas): ").split(",")
# datetime(year, month, day, hour, minute, second, microsecond,timezone)
date = datetime.datetime(2022, 11, 10, 11, 45, 59, 776, datetime.timezone.utc)
base_url = os.environ.get("BW_BASE_URL")
if not base_url:
    base_url = input(
        "Enter vault URL (default is: https://vault.bitwarden.com): ") or "https://vault.bitwarden.com"
serve = os.environ.get("BW_SERVE_URL")
if not serve:
    serve = input(
        "Enter serve URL (default is: http://localhost:8087): ") or "http://localhost:8087"

def shared_elements(collection1, collection2):
    for item in collection1:
        if item in collection2:
            return True
    return False

request = urllib.request.Request(serve + "/list/object/items")
response = urllib.request.urlopen(request)
text = response.read().decode('utf8')
list = json.loads(text)
data = list.get("data").get("data")

for item in data:
    if item.get("type") != 1:  # type 1 = logins
        continue
    if not shared_elements(item.get("collectionIds"), affected_collections):
        continue
    revision_date = item.get("login").get("passwordRevisionDate")
    if revision_date and datetime.datetime.fromisoformat(revision_date) > date:
        continue
    print("----------")
    print("Account: " + item.get("name"))
    print("Revision date: " + str(revision_date))
    print("Link: " + base_url + "/#/organizations/" + item.get("organizationId") +
          "/vault?collectionId=" + item.get("collectionIds")[0] + "&itemId=" + item.get("id"))
