import requests
import json

# Configuration — replace with your clientID and secret

CLIENT_ID = "YOUR_CLIENT_ID"
CLIENT_SECRET = "YOUR_CLIENT_SECRET"
API_BASE = "https://api.bitwarden.com"  # or your self-hosted public API base
IDENTITY_URL = "https://identity.bitwarden.com/connect/token"  # or your instance

def get_access_token():
    """Get OAuth token using client_credentials grant."""
    data = {
        "grant_type": "client_credentials",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        # Optionally, you may need a scope like "public.organization" or similar; check API docs.
    }
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    resp = requests.post(IDENTITY_URL, data=data, headers=headers)
    resp.raise_for_status()
    token_data = resp.json()
    return token_data["access_token"]

def get_org_members(token):
    """Fetch list of members in the organization."""
    url = f"{API_BASE}/public/members"  # endpoint path — check your API spec
    headers = {
        "Authorization": f"Bearer {token}"
    }
    resp = requests.get(url, headers=headers)
    resp.raise_for_status()
    
    
    return resp.json()

def remove_user(token, user_id):
    """Delete or disable a user by ID."""
    # The HTTP method / path depends on the API — this assumes DELETE /public/members/{id}
    url = f"{API_BASE}/public/members/{user_id}"
    headers = {
        "Authorization": f"Bearer {token}"
    }
    resp = requests.delete(url, headers=headers)
    # It might be “disable” or “deactivate” instead of delete in some APIs.
    if resp.status_code in (200, 204):
        print(f"Removed user {user_id}")
    else:
        print(f"Failed to remove user {user_id}: {resp.status_code} {resp.text}")

def main():
    token = get_access_token()
    members = get_org_members(token)

    members_resp = members.get("data", [])
    print(json.dumps(members_resp, indent=2))


    # The structure of each "member" object depends on the API; assume it has fields "id" and "status" 
    # as well as email which I will be displaying on the terminal to show which Items were deleted
    for m in members_resp:
        # for example:
        user_id = m.get("id")
        status = m.get("status")
        user_email = m.get("email") 
        
        if status == -1:
            print(f"Removing user {user_id} with email: {user_email}  (status = {status})")
            remove_user(token, user_id)

if __name__ == "__main__":
    main()
