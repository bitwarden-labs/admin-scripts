from dotenv import load_dotenv
import os

load_dotenv()

serverURL = str(os.getenv("serverURL"))
apiURL = str(os.getenv("apiURL"))
identityURL = str(os.getenv("identityURL"))
organisation_id = os.getenv("organisation_id")

authData = {
    "grant_type": "client_credentials",
    "scope": "api.organization",
    "client_id": os.getenv("client_id"),
    "client_secret": os.getenv("client_secret"),
}

eventsURL = serverURL + "api/public/events"
membersURL = serverURL + "api/public/members"
groupsURL = serverURL + "api/public/groups"
collectionsURL = serverURL + "api/public/collections"
