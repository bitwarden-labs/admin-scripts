''' Script design to update the Group affiliation of certain users' tickets
To run this script, you will need a .env that contains your Freshdesk's API key
'''

import os
import sys
import time
import requests as r
from decouple import config
import pprint

desk = 'https://bitwarden.freshdesk.com'
group = 00000000000000

ticketIDs = []
total = None
done = []

def bulkUpdate():
    global done
    global ticketIDs

    if not ticketIDs:
        print("Nothing to update")
        sys.exit(os.EX_OK)

    toUpdate = ticketIDs[:100]
    ticketIDs = ticketIDs[100:]
    update = r.post(desk + '/api/v2/tickets/bulk_update', auth=(config('API_KEY'), 'X'),
                    json={'bulk_action': {'ids': toUpdate, "properties": {"group_id": group}}})
    done.extend(toUpdate)

    if(not update.ok):
        print("Could not bulk update:\n")
        pprint.pprint(update.json())
        sys.exit(os.EX_SOFTWARE)

while(True):
    # Get all the tickets possible
    print("Fetching tickets",  end='')
    for page in range(1, 10+1):
        print('.', end='', flush=True)
        params = {'page': page,
                  'query': '"(agent_id:00000000000000 OR agent_id:00000000000000 or agent_id:00000000000000) AND (group_id:null)"'}
        ticketsResponse = r.get(desk + '/api/v2/search/tickets',
                                auth=(config('API_KEY'), 'X'), params=params)

        body = ticketsResponse.json()
        if(not body['results']):
            bulkUpdate()
            print("Done.")
            sys.exit(os.EX_OK)

        if total is None:
            total = body["total"]

        '''From: https://developers.freshdesk.com/api/
        "Please note that the updates will take a few minutes to get indexed, after which it will be available through API."
        '''
        if body['results'][0]["id"] in done:
            print("The search API has not been updated yet. Waiting 60 seconds.", flush=True)
            time.sleep(60)
            page = 1
            continue

        for ticket in body['results']:
            ticketIDs.append(ticket['id'])

    print("")
    while(len(ticketIDs) > 0):
        bulkUpdate()
        print("{:7.2f}".format(len(done) /
                               total * 100) + "% (" + str(len(done)) + "/" + str(total) + ") updated", flush=True)

    print("")
