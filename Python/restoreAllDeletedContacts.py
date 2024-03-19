import requests as r
from decouple import config

desk = 'https://bitwarden.freshdesk.com'

def get_all_contacts_from_page(page):
    params = {'page': page, 'state': 'deleted', 'per_page':'100'}
    deleted_contacts = r.get(desk + '/api/v2/contacts',
                            auth=(config('API_KEY'), 'X'), params=params)

    return deleted_contacts.json()

def get_all_contacts():
    done = False
    all_contacts = []
    page = 1
    while(not done):
        contact_list = get_all_contacts_from_page(page)
        if contact_list:
            all_contacts.extend(contact_list)
            page = page + 1
        else:
            done = True
    print("trying to restore: " + str(len(all_contacts)))    
    return all_contacts

def restore(contact):
    id = str(contact["id"])
    response = r.put(desk + '/api/v2/contacts/' + id + '/restore', auth=(config('API_KEY'), 'X'))
    if not response.ok:
        print(id + ' could not be restored') 

all_contacts = get_all_contacts()

for contact in all_contacts:
    restore(contact)

print("done")