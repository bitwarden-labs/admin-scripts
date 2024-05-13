import os
import subprocess
import json
import requests
from requests.exceptions import Timeout

def login_on_cli(f_bw_path, f_bw_vault_uri, f_bw_acc_client_id, f_bw_acc_client_secret, f_bw_acc_password):
    # Uses Bitwarden CLI
    # Logging in to the CLI and returning the CLI Session

    f_cli_session = ""

    os.environ["BW_CLIENTID"] = f_bw_acc_client_id
    os.environ["BW_CLIENTSECRET"] = f_bw_acc_client_secret
    os.environ["BW_PASSWORD"] = f_bw_acc_password
    output = subprocess.check_output([f_bw_path, 'status'])
    output_str = output.decode('utf-8')
    data = json.loads(output_str)

    if not data["status"] == "unauthenticated":
        subprocess.run([f_bw_path, 'logout', '--raw'])
    if f_bw_vault_uri == "https://vault.bitwarden.com/":
        subprocess.run([f_bw_path, 'config', 'server', 'null', '--raw'])
    else:
        subprocess.run([f_bw_path, 'config', 'server', f_bw_vault_uri, '--raw'])

    os.environ["BW_CLIENTID"] = f_bw_acc_client_id
    os.environ["BW_CLIENTSECRET"] = f_bw_acc_client_secret
    try:        
        subprocess.run([f_bw_path, 'login', '--apikey', '--raw'])
    except subprocess.CalledProcessError as e:
        print(f"There is an issue logging in to your origin server. Exit code: {e.returncode}\nError: {e.stderr}")
        exit(1)

    try:
        output = subprocess.check_output([f_bw_path, 'unlock', '--passwordenv', 'BW_PASSWORD', '--raw'])
        output_str = output.decode('utf-8')
    except subprocess.CalledProcessError as e:
        print(f"There is an issue unlocking your vault with client id {f_bw_acc_client_id}. Make sure you entered the correct password. Exit code: {e.returncode}\nError: {e.stderr}")
        exit(1)

    f_cli_session = output_str
    os.environ["BW_PASSWORD"] = ""
    os.environ["BW_CLIENTSECRET"] = ""

    return f_cli_session

def load_items_list(bw_path, f_bw_cli_session, bw_org_id):
    # Uses Bitwarden CLI
    # Listing all items and returning the data

    command = [bw_path, "list", "items", "--organizationid", bw_org_id, "--session", f_bw_cli_session]
    output = subprocess.check_output(command)

    output_str = output.decode('utf-8')
    data_items = json.loads(output_str)
    return data_items

def load_collection_list_cli(f_bw_path, f_bw_org_id, f_bw_cli_session):
    # Uses Bitwarden CLI
    # Loading list of collections within the organization

    output = subprocess.check_output([f_bw_path, 'list', 'org-collections', '--organizationid', f_bw_org_id, '--session', f_bw_cli_session])

    output_str = output.decode('utf-8')
    data = json.loads(output_str)

    return data

def login_to_bw_public_api(f_bw_identity_endpoint, f_bw_org_client_id, f_bw_org_client_secret, debug=False):
    #Function to log in to BW Public API and get access token

    if (debug):
        print(f"Logging in to public api. URL: {f_bw_identity_endpoint}, client id: {f_bw_org_client_id}")

    f_access_token = ""
    body = {"client_id":f_bw_org_client_id,"client_secret":f_bw_org_client_secret,"grant_type":"client_credentials","scope":"api.organization"}
    http_headers = {'Content-type': 'application/x-www-form-urlencoded'}

    try:
        response = requests.post(f_bw_identity_endpoint+"connect/token", data=body, headers=http_headers, timeout = 10)
    except Timeout:
        print("The request timed out during authentication")
        print("Identity endpoint: ", f_bw_identity_endpoint)
        exit(1)
    except Exception as e:
        print("An error occurred during auth to public API: ", e)
        print("Identity endpoint: ", f_bw_identity_endpoint)
        exit(1)

    if (response.status_code == 200):
        response_json = response.json()
        f_access_token = response_json["access_token"]
        if (debug):
            print("Login to API is successful")
    else:
        f_access_token = ""
        if (debug): print(response.content )
        print("Auth to BW Public API failed, Status Code: ",response.status_code, " Endpoint: ", f_bw_identity_endpoint)


    return f_access_token

def load_collection_details_cli(f_bw_path, f_bw_org_id, f_bw_col_id, f_bw_cli_session):

    output = subprocess.check_output([f_bw_path, 'get', 'org-collection', f_bw_col_id,'--organizationid', f_bw_org_id, '--session', f_bw_cli_session])

    output_str = output.decode('utf-8')
    data = json.loads(output_str)

    return data

def load_groups_api(f_bw_api_endpoint,f_access_token, debug=False):
    # Function to get all groups from public API to a dictionary
    
    http_headers = {'Authorization': 'Bearer '+f_access_token}
    response = requests.get(f_bw_api_endpoint+"public/groups", headers=http_headers)
    
    group_data = {}
    if (response.status_code == 200):
        group_json = response.json()
        if "data" in group_json:
            group_data = group_json["data"]
        else:
            print(f"JSON Response does not contain data. Response: {response}")
    else:
        print(f"Failed loading groups list. Response: {response.status_code}")

    if (debug):
        print("** Load groups via API")
        print("** API End Point: ", f_bw_api_endpoint)
        print("** HTTP Response Code: ", response)
        print("** Group data: ", group_data)
        print("")

    return group_data

def get_members_list(f_bw_api_endpoint,f_access_token, debug = False):
    # Function to load all groups from public API to a dictionary
    http_headers = {'Authorization': 'Bearer '+f_access_token}
    response = requests.get(f_bw_api_endpoint+"public/members", headers=http_headers)
    
    f_member_list = []
    if (response.status_code == 200):
        resp_dict = response.json()
        f_member_list = resp_dict["data"]
    else:
        print(f"Failed getting member list. Response Code: {response.status_code}")

    if (debug):
        print("Load members debug")
        print("API")
        print(f_bw_api_endpoint)
        print("Response")
        print(response)
        print("BW Member List")
        print(f_member_list)
        print("")

    return f_member_list

def load_member_details_api(f_bw_api_endpoint,f_access_token, member_id, debug=False):
    # Function to load all groups from public API to a dictionary
    http_headers = {'Authorization': 'Bearer '+f_access_token}
    response = requests.get(f_bw_api_endpoint+"public/members/"+member_id, headers=http_headers)
    
    member_data = {}
    if (response.status_code == 200):
        member_json = response.json()
        if len(member_json) > 0:
            member_data = member_json
        else:
            if (debug):
                print(f"JSON Response does not contain data. load_group_details_api. Response: {response}. Group ID:{member_id}")
    else:
        if (debug):
            print(f"Failed loading group details. Response: {response.status_code} Group ID:{member_id}")

    return member_data

def convert_perms_to_text(manage = False, readonly = False, hidepasswords = False):
    perms_txt = ""
    if manage:
        perms_txt = "Can Manage"
    elif not readonly and not hidepasswords:
        perms_txt = "Can Edit"
    elif readonly and not hidepasswords:
        perms_txt = "Can View"
    elif readonly and hidepasswords:
        perms_txt = "Can View - Except Passwords"
    elif not readonly and hidepasswords:
        perms_txt = "Can Edit - Except Passwords"

    return perms_txt