#!/usr/bin/env python3

# Python script for BW admin tools

# External module required: 
# pip3 install requests
# 
# Requirements Before Running The Script
# - Fill in the config file. See config-example.cfg


import json
import requests
from requests.exceptions import Timeout
import time
import sys
import getopt
import configparser
import os
import re
import subprocess
import getpass
import shutil
import uuid
import random

EXPORT_FILE_NAME="export.json"

bw_vault_uri = ""
bw_identity_endpoint = ""
bw_api_endpoint = ""
bw_org_client_id = ""
bw_org_client_secret = ""
bw_org_id=""
bw_acc_client_id = ""
bw_acc_client_secret = ""
bw_acc_password = ""

dest_bw_vault_uri = ""
dest_bw_org_client_id = ""
dest_bw_org_client_secret = ""
dest_bw_acc_client_id = ""
dest_bw_acc_client_secret = ""
dest_bw_org_id=""
dest_bw_identity_endpoint = ""
dest_bw_api_endpoint = ""
dest_bw_acc_password = ""

lp_cid = ""
lp_api_secret = ""
lp_api_uri = ""

access_token = ""
dest_access_token = ""
bw_path = ""
onep_path = ""

delay_after_api_call_secs = 1
debug = False
verbose = False
add_group_if_not_exists = True

script_location = os.path.dirname(os.path.abspath(__file__))


def create_guid():
    return str(uuid.uuid4())

def delete_all_collections(f_bw_identity_endpoint, f_bw_api_endpoint, f_bw_org_client_id, f_bw_org_client_secret):
    global access_token
    if access_token == "":
        access_token = login_to_bw_public_api(f_bw_identity_endpoint,f_bw_org_client_id,f_bw_org_client_secret)

    http_headers = {'Authorization': 'Bearer '+access_token}
    response = requests.get(bw_api_endpoint+"public/collections", headers=http_headers)
    

    if (response.status_code == 200):
        col_list = response.json()
        if len(col_list["data"]) > 0:
            for collection in col_list["data"]:
                response = requests.delete(f_bw_api_endpoint+"public/collections/"+collection["id"], headers=http_headers)
                if (response.status_code == 200):
                    if verbose: print("Collection ID: "+collection["id"]+" deleted")
                else:
                    if verbose: print("Collection ID: "+collection["id"]+" failed with status: ",response.status_code)
                time.sleep(delay_after_api_call_secs)
        else:
            if verbose: print("Empty Collection")
    else:
        if verbose: print("Getting Collections failed with status code: "+response.status_code )

def delete_all_groups(f_bw_identity_endpoint, f_bw_api_endpoint, f_bw_org_client_id, f_bw_org_client_secret):
    global access_token
    if access_token == "":
        access_token = login_to_bw_public_api(f_bw_identity_endpoint,f_bw_org_client_id,f_bw_org_client_secret)

    http_headers = {'Authorization': 'Bearer '+access_token}
    response = requests.get(f_bw_api_endpoint+"public/groups", headers=http_headers)
    

    if (response.status_code == 200):
        group_list = response.json()
        if len(group_list["data"]) > 0:
            for group in group_list["data"]:
                response = requests.delete(f_bw_api_endpoint+"public/groups/"+group["id"], headers=http_headers)
                if (response.status_code == 200):
                    if verbose: print("Group ID: "+group["id"]+" deleted")
                else:
                    if verbose: print("Group ID: "+group["id"]+" failed with status: ",response.status_code)
                time.sleep(delay_after_api_call_secs)
        else:
            if verbose: print("Empty Groups")
    else:
        if verbose: print("Getting Groups failed with status code: "+response.status_code )

def load_groups_api(f_bw_api_endpoint,f_access_token):
    # Function to load all groups from public API to a dictionary
    http_headers = {'Authorization': 'Bearer '+f_access_token}
    response = requests.get(f_bw_api_endpoint+"public/groups", headers=http_headers)
    
    group_data = {}
    if (response.status_code == 200):
        group_json = response.json()
        if "data" in group_json:
            group_data = group_json["data"]
        else:
            print(f"JSON Response does not contain data. Response: {response}")
            sys.exit(2)
    else:
        print(f"Failed loading groups list. Response: {response.status_code}")
        sys.exit(2)

    if (debug):
        print("** Load groups via API")
        print("** API End Point: ", f_bw_api_endpoint)
        print("** HTTP Response Code: ", response)
        print("** Group data: ", group_data)
        print("")

    return group_data

def load_group_details_api(f_bw_api_endpoint,f_access_token, group_id):
    # Function to load all groups from public API to a dictionary
    http_headers = {'Authorization': 'Bearer '+f_access_token}
    response = requests.get(f_bw_api_endpoint+"public/groups/"+group_id, headers=http_headers)
    
    group_data = {}
    if (response.status_code == 200):
        group_json = response.json()
        if len(group_json) > 0:
            group_data = group_json
        else:
            print(f"JSON Response does not contain data. load_group_details_api. Response: {response}. Group ID:{group_id}")
    else:
        print(f"Failed loading group details. Response: {response.status_code} Group ID:{group_id}")
        sys.exit(2)

    return group_data

def load_collections_api(f_bw_api_endpoint,f_access_token):
    # Function to load all collections from public API to a dictionary
    http_headers = {'Authorization': 'Bearer '+f_access_token}
    response = requests.get(f_bw_api_endpoint+"public/collections", headers=http_headers)
    
    f_coll_dict = {}
    if (response.status_code == 200):
        coll_list = response.json()
        if len(coll_list["data"]) > 0:
            f_coll_dict =  coll_list["data"]
    return f_coll_dict

def load_collection_list_cli(f_bw_org_id, f_bw_cli_session):

    output = subprocess.check_output([bw_path, 'list', 'org-collections', '--organizationid', f_bw_org_id, '--session', f_bw_cli_session])

    output_str = output.decode('utf-8')
    data = json.loads(output_str)

    if (debug):
        print("** Collection list from CLI:")
        print("** Collection data: ", data,"\n")
    return data

def load_collection_details_cli(f_bw_org_id, f_bw_col_id, f_bw_cli_session):

    output = subprocess.check_output([bw_path, 'get', 'org-collection', f_bw_col_id,'--organizationid', f_bw_org_id, '--session', f_bw_cli_session])

    output_str = output.decode('utf-8')
    data = json.loads(output_str)

    return data

def load_groups_members(f_bw_api_endpoint,f_access_token):
   # Function to load all groups from public API to a dictionary
 
    # Getting user list from source server...
    members_list = get_members_list( f_bw_api_endpoint, f_access_token)
    
    member_dict = {}
    #converting members list to dictionary
    if len(members_list) > 0:
        for each_member in members_list:
            member_dict[each_member["id"]] = each_member["email"]
    else:
        print("No members found. Terminating")
        exit(1)

    # Getting group list from source server...
    groups_list = load_groups_api( f_bw_api_endpoint, f_access_token)

    groups_members_dict = {}

    if len(groups_list) > 0:
        http_headers = {'Authorization': 'Bearer '+f_access_token}
        for each_group in groups_list:

            groups_members_dict[each_group["name"]] = []
            response = requests.get(f_bw_api_endpoint+"public/groups/"+each_group["id"]+"/member-ids", headers=http_headers)
            
            if (response.status_code == 200):
                response_list = response.json()
                # if there are any member, loop the membership list
                if len(response_list) > 0:
                    for each_member_id in response_list:
                        groups_members_dict[each_group["name"]].append(member_dict[each_member_id])
            else:
                print(f"Failed getting group membership list. Response Code: {response.status_code}")
            
            time.sleep(10)
    else:
        print("No group found. Terminating")
        exit(1)
    return groups_members_dict

def migrate_groups_members(f_bw_api_endpoint, f_access_token, f_groups_members_dict):

    members_list = get_members_list( f_bw_api_endpoint, f_access_token)
    
    member_dict = {}

    #converting members list to dictionary with email as the key
    if len(members_list) > 0:
        for each_member in members_list:
            member_dict[each_member["email"]] = each_member["id"]
    else:
        print("No members found. Terminating")
        exit(1)

    groups_list = load_groups_api( f_bw_api_endpoint, f_access_token )

    if len(groups_list) > 0:
        http_headers = {'Authorization': 'Bearer '+f_access_token}
        for each_group in groups_list:

            #get the current members
            response = requests.get(f_bw_api_endpoint+"public/groups/"+each_group["id"]+"/member-ids", headers=http_headers)
            response_list = []
            if (response.status_code == 200):
                response_list = response.json()
            else:
                print(f"Failed getting group membership list. Response Code: {response.status_code}")

            #update the current members
            if each_group["name"] in f_groups_members_dict:
                if len(f_groups_members_dict[each_group["name"]]) > 0:
                    there_is_update = False
                    for each_old_member in f_groups_members_dict[each_group["name"]]:
                        if each_old_member in member_dict and member_dict[each_old_member] not in response_list:
                            response_list.append(member_dict[each_old_member])
                            there_is_update = True
                    
                    #since there is new addition, update the group members
                    if there_is_update:
                        json_body = {
                                        "memberIds": response_list
                                    }
                        if debug:
                            print("member body")
                            print(json_body)
                        response = requests.put(f_bw_api_endpoint+"public/groups/"+each_group["id"]+"/member-ids", json=json_body, headers=http_headers)
                        if (response.status_code == 200):
                             if debug:
                                print(f"Updated group {each_group['name']}")
                        time.sleep(10)

def get_members_list(f_bw_api_endpoint,f_access_token):
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

def create_a_group(f_bw_api_endpoint, f_access_token, f_group_name, f_external_id):
    # Function to create a group via BW Public API

    json_body = { "name": f_group_name, "accessAll": False, "externalId": f_external_id }
    http_headers = {'Authorization': 'Bearer ' + f_access_token}
    response = requests.post(f_bw_api_endpoint+"public/groups", json=json_body, headers=http_headers)
    
    if (response.status_code == 200):
        json_resp = response.json()
    else:
        print("Error creating a group. Response Code: " + response.status_code)
        json_resp = {}
    return json_resp

def update_collection_cli(f_bw_cli_session, f_coll_name, f_coll_id, f_new_data_col, f_bw_org_id):
    # Updating a collection via CLI

    if (debug):
        print("** Updating a collection. Name: ",f_coll_name)
        print("Collection Data: ", f_new_data_col,"\n")

    try:
        cmd3 = [bw_path, 'encode']
        cmd4 = [bw_path, '--session', f_bw_cli_session, 'edit', 'org-collection', f_coll_id,'--organizationid', f_bw_org_id]

        p3 = subprocess.Popen(cmd3, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        output3 = p3.communicate(input=json.dumps(f_new_data_col).encode())[0]

        p4 = subprocess.Popen(cmd4, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        output, _ = p4.communicate(input=output3)

        output_str = output.decode('utf-8')
        data = json.loads(output_str)
        

    except subprocess.CalledProcessError as e:
        print(f"There is an issue when updating collection {f_coll_name}. Exit code: {e.returncode}\nError: {e.stderr}")
        print("Will continue processing next collection")

    return data

def login_to_bw_public_api(f_bw_identity_endpoint, f_bw_org_client_id, f_bw_org_client_secret):
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

    if f_access_token == "":
        sys.exit(2)
    return f_access_token

def get_lastpass_shared_folders(cid, provhash, lp_api_uri):
    # Function for getting list of shared folders from Lastpass

    body = {"cid":cid,"provhash":provhash,"cmd":"getsfdata","data":"all"}
    http_headers = {'Content-type': 'application/json', 'Accept': 'text/plain'}

    response = requests.post(lp_api_uri, json=body, headers=http_headers)
    if (response.status_code == 200):
        shared_folders = response.json()
        if (debug):
            print("LP API Success")
            print(shared_folders)
            print("")
    else:
        print("Failed getting Shared Folder data from Lastpass",response.status_code)
        shared_folders = []
    return shared_folders

def update_user_collection( f_bw_api_endpoint, f_access_token, f_user_id, f_data_dict ):

    http_headers = {'Authorization': 'Bearer ' + f_access_token}
    response = requests.put(f_bw_api_endpoint + "public/members/" + f_user_id, json=f_data_dict, headers=http_headers)
    
    if (response.status_code == 200):
        if(verbose): print("Updating collection for ",f_user_id," successful")
    else:
        if (verbose): print("Error updating user ",f_user_id," Status Code: ",response.status_code)
    time.sleep(delay_after_api_call_secs)

def update_user_collection_old_lastpass( user_id, user_name, user_type, user_accessAll, user_externalId, user_resetPasswordEnrolled, user_collections ):
    global access_token
    if access_token == "":
        access_token = login_to_bw_public_api(bw_identity_endpoint,bw_org_client_id,bw_org_client_secret)

    http_headers = {'Authorization': 'Bearer '+access_token}


    json_body = { "type": user_type, 'accessAll': user_accessAll, 'externalId': user_externalId, 'resetPasswordEnrolled': user_resetPasswordEnrolled, "collections": user_collections }
    http_headers = {'Authorization': 'Bearer ' + access_token}
    response = requests.put(bw_api_endpoint+"public/members/"+user_id, json=json_body, headers=http_headers)
    
    if (response.status_code == 200):
        json_resp = response.json()
        if(verbose): print("Updating collection for ",user_name," successful")
    else:
        if (verbose): print("Error updating user ",user_name," Status Code: ",response.status_code)
    time.sleep(delay_after_api_call_secs)

def update_all_individual_accounts(account_list):
    global access_token
    if access_token == "":
        access_token = login_to_bw_public_api(bw_identity_endpoint,bw_org_client_id,bw_org_client_secret)

    http_headers = {'Authorization': 'Bearer '+access_token}
    response = requests.get(bw_api_endpoint+"public/members", headers=http_headers)
    
    if (response.status_code == 200):
        json_resp = response.json()
        if (debug):
            print("All User Data:\n",json_resp)
        if len(json_resp['data']) > 0:
            for user in json_resp['data']:
                if user["email"] in account_list:
                    #this is not working because collections is always None from api/public/members
                    if user["collections"] is None:
                        user["collections"] = account_list[user["email"]]
                    else:
                        user["collections"].append(account_list[user["email"]])

                    update_user_collection_old_lastpass(user["id"], user["name"], user["type"], user["accessAll"], user["externalId"], user["resetPasswordEnrolled"], user["collections"])
        else:
            if (debug or verbose): print("User list is empty")
    else:
        if (debug): print("Error getting all users, status: ", response.status_code)
        json_resp = {}
    return True

def migrate_lastpass_permissions():
    global access_token, bw_acc_password, bw_cli_session

    if access_token == "":
        access_token = login_to_bw_public_api(bw_identity_endpoint,bw_org_client_id,bw_org_client_secret)

    initial_environment_check()

    bw_acc_password = get_account_password("destination")
    bw_cli_session = login_on_cli(bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password)

    cli_output = load_collection_list_cli(bw_org_id, bw_cli_session)

    collection_dict = {}
    if len(cli_output) > 0:
        for each_col in cli_output:
            collection_dict[each_col["name"]] = each_col["id"]

    if len(collection_dict) == 0:
        print("Collection Empty or Loading BW Collections failed, exiting program")
        sys.exit(2)


    group_list = load_groups_api(bw_api_endpoint,access_token)
    group_dict_name = {}
    for group in group_list:
        group_dict_name[group["name"]] = {"id" :group["id"], "name":group["name"], "externalId":group["externalId"]}

 
    if not add_group_if_not_exists and len(group_dict_name) == 0:
        print("Groups Empty or Loading BW Groups failed, exiting program")
        sys.exit(2)


    #Getting Shared Folders data from Lastpass
    #Enable this when trying real data
    
    shared_folders = get_lastpass_shared_folders(lp_cid, lp_api_secret, lp_api_uri)

    # with open("sample.json", "w") as outfile:
    #     outfile.write( json.dumps(shared_folders) )

    # read from file so I don't have to flood LP API during development and risk getting blocked
    # f = open('sample.json')
    # shared_folders = json.load(f)

    if (debug):
        print("Lastpass JSON\n",shared_folders)

    if len(shared_folders) == 0:
        print("No shared folders data. Exiting program")
        sys.exit(2)
    
    account_list = {}

    #loop every shared folders from lastpass API
    for folder in shared_folders:
        if (debug): print("Processing folder:",folder)
        if (shared_folders[folder]["sharedfoldername"] in collection_dict.keys()) or ("Shared-"+shared_folders[folder]["sharedfoldername"] in collection_dict.keys()):
            if shared_folders[folder]["sharedfoldername"] in collection_dict.keys():
                shared_folder_name = shared_folders[folder]["sharedfoldername"]
            else:
                shared_folder_name = "Shared-" + shared_folders[folder]["sharedfoldername"]

            if not shared_folders[folder]["deleted"] or shared_folders[folder]["deleted"] == "False":
                json_body = {"organizationId": bw_org_id, "name": shared_folder_name, "externalid": "null"}
                if (debug): print(json_body)
                json_group = []
                group_added = {}
                #loop all users in the shared folder
                for user in shared_folders[folder]["users"]:
                    if ("group_name" in user):
                        #Create the group if group doesnt exists in Bitwarden
                        if not user["group_name"] in group_dict_name:
                            if add_group_if_not_exists:
                                json_resp = create_a_group(bw_api_endpoint, access_token, user["group_name"], '' )
                                group_dict_name[user["group_name"]] = {"id" :json_resp["id"], "name":json_resp["name"], "externalId":json_resp["externalId"]}
                                if (debug):
                                    print("Group Added: ",user["group_name"])

                        if not user["group_name"] in group_added and user["group_name"] in group_dict_name:
                            group_added[user["group_name"]] = True
                            if (debug): print("username: ",user["username"],"group: ",type(user["group_name"]))
                            if user["readonly"] == "1":
                                readOnly = True
                            else:
                                readOnly = False

                            if user["give"] == "1":
                                hidePasswords = False
                            else:
                                hidePasswords = True

                            json_group.append({  "id": group_dict_name[user["group_name"]]["id"], "readOnly": readOnly, "hidePasswords": hidePasswords })
                    else:
                        # If group name not found, this is individual user permission
                        if (debug): print("add individual ",shared_folder_name,"| username: ",user["username"])
                        if user["username"] not in account_list:
                            account_list[user["username"]] = []
                        if user["readonly"] == "1":
                            readOnly = True
                        else:
                            readOnly = False

                        if user["give"] == "1":
                            hidePasswords = False
                        else:
                            hidePasswords = True
                        account_list[user["username"]].append({ "id": collection_dict[shared_folder_name], "readOnly": readOnly  })

                json_body["groups"] = json_group
                update_collection_cli(bw_cli_session, shared_folder_name, collection_dict[shared_folder_name], json_body, bw_org_id)
                time.sleep(delay_after_api_call_secs)
                if (debug):
                    print("Group List For Collection ID: ",collection_dict[shared_folder_name])
                    print(json_group)
    #Update all individual accounts affected
    update_all_individual_accounts(account_list)

def find_program_path(f_name):
    # Check if 'bw' file exists in the same directory as the script
    script_dir = os.path.dirname(os.path.realpath(__file__))
    program_path = os.path.join(script_dir, f_name)

    if os.path.isfile(program_path):
        # Check if 'bw' is executable
        if os.access(bw_path, os.X_OK):
            return program_path
        else:
            print(f"'{f_name}' file at {program_path} is not executable")

    # If 'bw' file not found in script directory, or it's not executable
    # check if 'bw' is a system-wide command
    system_bw = shutil.which(f_name)
    if system_bw:
        return system_bw

    return ""

def initial_environment_check():
    global bw_path
    # meant for checking things
    # maybe download the CLI?
    is_writable = os.access(script_location, os.W_OK)
    if not is_writable:
        print("The script's location is not writable.")
        sys.exit(1)

    bw_path = find_program_path('bw')
    if bw_path == "":
        print("Bitwarden CLI (bw) is not found in the system")
        sys.exit(2)

def get_account_password(f_info):

    acc_password = getpass.getpass(f"Please input your Bitwarden password used on the {f_info} server:")

    if (acc_password == ""):
        print("Password cannot be empty.")
        sys.exit(1)
    
    return acc_password

def delete_file(filepath):
    if os.path.isfile(filepath):
        try:
            os.remove(filepath)
        except OSError as e:
            print(f"Error: {e.filename} - {e.strerror}.")

def delete_all_export_files():
    delete_file(os.path.join(script_location, "export.json"))

    dir_path =  os.path.join(script_location , "attachments")
    if os.path.isdir(dir_path):
        try:
            shutil.rmtree(dir_path)
        except OSError as e:
            print(f"Error: {e.filename} - {e.strerror}.")

def login_on_cli(f_bw_vault_uri, f_bw_acc_client_id, f_bw_acc_client_secret, f_bw_acc_password):
    f_cli_session = ""

    os.environ["BW_CLIENTID"] = f_bw_acc_client_id
    os.environ["BW_CLIENTSECRET"] = f_bw_acc_client_secret
    os.environ["BW_PASSWORD"] = f_bw_acc_password
    output = subprocess.check_output([bw_path, 'status'])
    output_str = output.decode('utf-8')
    data = json.loads(output_str)

    if not data["status"] == "unauthenticated":
        subprocess.run([bw_path, 'logout', '--raw'])
    if f_bw_vault_uri == "https://vault.bitwarden.com/":
        subprocess.run([bw_path, 'config', 'server', 'null', '--raw'])
    else:
        subprocess.run([bw_path, 'config', 'server', f_bw_vault_uri, '--raw'])

    os.environ["BW_CLIENTID"] = f_bw_acc_client_id
    os.environ["BW_CLIENTSECRET"] = f_bw_acc_client_secret
    try:        
        subprocess.run([bw_path, 'login', '--apikey', '--raw'])
    except subprocess.CalledProcessError as e:
        print(f"There is an issue logging in to your origin server. Exit code: {e.returncode}\nError: {e.stderr}")
        exit(1)


    try:
        output = subprocess.check_output([bw_path, 'unlock', '--passwordenv', 'BW_PASSWORD', '--raw'])
        output_str = output.decode('utf-8')
    except subprocess.CalledProcessError as e:
        print(f"There is an issue unlocking your vault with client id {f_bw_acc_client_id}. Make sure you entered the correct password. Exit code: {e.returncode}\nError: {e.stderr}")
        exit(1)

    f_cli_session = output_str
    os.environ["BW_PASSWORD"] = ""
    os.environ["BW_CLIENTSECRET"] = ""

    if (debug) and (f_cli_session):
        print("Login on CLI is successful")

    return f_cli_session

def sync_cli(f_bw_cli_session):
    subprocess.run([bw_path, 'sync', '--session', f_bw_cli_session, '--raw'])

def export_data_from_origin_v2(f_bw_cli_session):
    # export data and all attachments

    #exporting data in unencrypt JSON format
    sync_cli(f_bw_cli_session)

    attach_dir_path = os.path.join(script_location ,"attachments")

    try:
        os.mkdir(attach_dir_path)
    except OSError as e:
        print(f"Error: {e.strerror}.")

    command = [bw_path, "list", "collections", "--organizationid", bw_org_id, "--session", f_bw_cli_session]
    output = subprocess.check_output(command)

    output_str = output.decode('utf-8')
    data_collections = json.loads(output_str)

    if (debug):
        print("Loading collections list from CLI. Number of collections: ",len(data_collections))
        print("")

    existing_cols = []
    for each_col in data_collections:
        existing_cols.append(each_col["id"])


    command = [bw_path, "list", "items", "--organizationid", bw_org_id, "--session", f_bw_cli_session]
    output = subprocess.check_output(command)

    output_str = output.decode('utf-8')
    data_items = json.loads(output_str)

    if (debug):
        print("Loading items list from CLI. Number of items: ",len(data_items))
        print("")

    for item in data_items:
            if "attachments" in item:

                #create a collection for that item
                new_col_id = create_guid()
                while new_col_id in existing_cols:
                    new_col_id = create_guid()
                
                new_col_dict = {"id": new_col_id, "organizationId": bw_org_id, "externalid": None, "name": item['id'], "groups": [] }
                data_collections.append(new_col_dict)
                existing_cols.append(new_col_id)

                item["collectionIds"].append(new_col_id)

                attachment_dir = os.path.join(attach_dir_path, item["id"])
                
                try:
                    os.mkdir(attachment_dir)
                except OSError as e:
                    print(f"Error: {e.strerror}.")

                for attachment in item["attachments"]:
                    if (debug):
                        print("Saving attachment:", os.path.join(attachment_dir, attachment['fileName']))
                    subprocess.run([
                        bw_path, 
                        "get", 
                        "attachment", 
                        attachment['fileName'],
                        "--itemid", 
                        str(item['id']), 
                        "--output", 
                        os.path.join(attachment_dir, attachment['fileName']),
                        "--session", 
                        f_bw_cli_session,
                        "--raw"
                    ], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)


    data_export = {"encrypted": False, "collections": data_collections, "items": data_items}

    #write the modiied export file again
    try:
        # Open the JSON file in write mode, which will overwrite any existing file
        with open(EXPORT_FILE_NAME, 'w', encoding='utf-8') as json_file:
            # Write the data to the JSON file
            json.dump(data_export, json_file, indent=4)

    except Exception as e:
        print(f"Error writing new export file: {e}")
        exit(2)

    return True

def import_attachments_to_destination_v2(f_dest_bw_cli_session):
    global dest_bw_org_id

    sync_cli(f_dest_bw_cli_session)
    coll_list = load_collection_list_cli(dest_bw_org_id, f_dest_bw_cli_session)

    coll_list_by_name = {}
    if coll_list:
        for each_coll in coll_list:
            coll_list_by_name[each_coll["name"]] = each_coll["id"]


    # specify the directory you want to check
    directory_path = os.path.join(script_location , "attachments")

    # check if the directory exists
    if os.path.isdir(directory_path):
        if (debug):
            print("Importing attachments")    
        # list all the directories inside it
        all_subdirectories = [name for name in os.listdir(directory_path) 
                            if os.path.isdir(os.path.join(directory_path, name))]
        
        # list all files in the subdirectories
        for subdir in all_subdirectories:

            #get the collection id
            new_coll_id = coll_list_by_name[subdir]
            output = subprocess.check_output([bw_path, 'list', 'items', '--collectionid', new_coll_id, '--session', f_dest_bw_cli_session])

            output_str = output.decode('utf-8')
            new_item_arr = json.loads(output_str)
            if len(new_item_arr) > 0:
                new_item_dict = new_item_arr.pop()
                subdir_path = os.path.join(directory_path, subdir)
                for dirpath, dirnames, filenames in os.walk(subdir_path):
                    for filename in filenames:
                        if (debug):
                            print(f"Importing file {filename}")
                        full_path_filename = os.path.join(subdir_path, filename)
                        
                        command = [
                            bw_path, 
                            "create", 
                            "attachment",
                            "--file",
                            full_path_filename,
                            "--itemid", 
                            str(new_item_dict['id']),
                            "--session", 
                            f_dest_bw_cli_session,
                            "--raw"
                        ]
                        output = subprocess.check_output(command)

                        output_str = output.decode('utf-8')
                        attach_item_details = json.loads(output_str)

                        if (debug) and (len(attach_item_details)>0):
                            print("Importing Attachment Successful. Item Name: ",attach_item_details["name"])
                        
            else:
                print(f"item with collection id {new_coll_id} is not found. unable to import attachment")
            
            #delete collection
            subprocess.run([
                bw_path, 
                "delete", 
                "org-collection",
                "--organizationid",
                str(dest_bw_org_id),
                new_coll_id,
                "--session", 
                f_dest_bw_cli_session
            ])

def import_data_to_destination_v2(f_dest_bw_cli_session,):
    global dest_bw_org_id, script_location

    command = [
        bw_path, 
        "import", 
        "bitwardenjson",
        "--organizationid",
        str(dest_bw_org_id),
        os.path.join(script_location, EXPORT_FILE_NAME),
        "--session", 
        f_dest_bw_cli_session
    ]
    output = subprocess.check_output(command)

    output_str = output.decode('utf-8')

    if (debug):
        print("Importing JSON file. Output: ",output_str)

    # import the JSON file
    subprocess.run([
        bw_path, 
        "sync",
        "--session", 
        f_dest_bw_cli_session,
        "--raw"
    ])

    import_attachments_to_destination_v2(f_dest_bw_cli_session)

    #clean up the files
    delete_all_export_files()    

def import_attachments_to_destination(f_dest_bw_cli_session, f_new_coll_name):
    global dest_bw_org_id

    # specify the directory you want to check
    directory_path = os.path.join(script_location , "attachments")

    # check if the directory exists
    if os.path.isdir(directory_path):
        if (debug):
            print("Importing attachments")    
        # list all the directories inside it
        all_subdirectories = [name for name in os.listdir(directory_path) 
                            if os.path.isdir(os.path.join(directory_path, name))]
        
        # list all files in the subdirectories
        for subdir in all_subdirectories:

            #get the collection id
            new_coll_id = f_new_coll_name[subdir]
            output = subprocess.check_output([bw_path, 'list', 'items', '--collectionid', new_coll_id, '--session', f_dest_bw_cli_session])

            output_str = output.decode('utf-8')
            new_item_arr = json.loads(output_str)
            if len(new_item_arr) > 0:
                new_item_dict = new_item_arr.pop()
                subdir_path = os.path.join(directory_path, subdir)
                for dirpath, dirnames, filenames in os.walk(subdir_path):
                    for filename in filenames:
                        if (debug):
                            print(f"Importing file {filename}")
                        full_path_filename = os.path.join(subdir_path, filename)
                        subprocess.run([
                            bw_path, 
                            "create", 
                            "attachment",
                            "--file",
                            full_path_filename,
                            "--itemid", 
                            str(new_item_dict['id']),
                            "--session", 
                            f_dest_bw_cli_session,
                            "--raw"
                        ], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
                        
            else:
                print(f"item with collection id {new_coll_id} is not found. unable to import attachment")
            
            #delete collection
            subprocess.run([
                bw_path, 
                "delete", 
                "org-collection",
                "--organizationid",
                str(dest_bw_org_id),
                new_coll_id,
                "--session", 
                f_dest_bw_cli_session
            ])
            
def import_groups_to_destination(f_access_token, f_group_list_for_import):
    global dest_bw_api_endpoint
    # Function to create a group via BW Public API

    json_body = {   
        "overwriteExisting": True,
        "largeImport": True,
        "groups": f_group_list_for_import,
        "members": []
    }

    if (debug):
        print("JSON Body: ", json_body)
        print("API Endpoint: ", dest_bw_api_endpoint)

    http_headers = {'Authorization': 'Bearer ' + f_access_token, 'Content-Type': 'application/json'}
    response = requests.post(dest_bw_api_endpoint+"public/organization/import", json=json_body, headers=http_headers)
    
    if (debug):
        print("Bulk Importing groups. Response Status Code: ",response.status_code)

    if (response.status_code != 200):
        print("Error Bulk importing group. Response Code: ", response.status_code)
        print("Response JSON: ",response.json())

def is_uuid(string):
    uuid_regex = r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b'
    match = re.match(uuid_regex, string)
    return bool(match)

def load_permissions_from_origin_cli_v2(f_bw_cli_session):
    global access_token, bw_org_id

    coll_dict = load_collection_list_cli(bw_org_id, f_bw_cli_session)

    coll_list_by_name = []

    if len(coll_dict) > 0:
        if access_token == "":
            access_token = login_to_bw_public_api(bw_identity_endpoint,bw_org_client_id,bw_org_client_secret)
        
        group_list = load_groups_api(bw_api_endpoint,access_token)
        group_dict_id = {}
        group_list_for_import = []
        external_id_list = []
        for group in group_list:
            group_dict_id[group["id"]] = {"id" :group["id"], "name":group["name"], "externalId":group["externalId"]}
            if not group["externalId"]:
                new_externalid = f"random-{str(random.randint(100000, 999999))}"
                while new_externalid in external_id_list:
                    new_externalid = f"migrated-{str(random.randint(100000, 999999))}"
                group["externalId"] = new_externalid
            group_list_for_import.append({ "name":group["name"], "externalId": group["externalId"], "memberExternalIds": [] })
            external_id_list.append(group["externalId"])


        for bw_col in coll_dict:

            # getting collection permissions details for groups from CLI

            #http_headers = {'Authorization': 'Bearer ' + access_token}
            #response = requests.get(bw_api_endpoint+"public/collections/" + bw_col["id"], headers=http_headers)

            response = load_collection_details_cli(bw_org_id, bw_col["id"],f_bw_cli_session)
            
            group_permissions = []

            if (len(response) > 0):
                if len(response["groups"]) > 0:
                    for each_group in response["groups"]:
                        each_group["name"] = group_dict_id[each_group["id"]]["name"]
                        group_permissions.append(each_group)

            coll_list_by_name.append( { "id": bw_col["id"] , "name": bw_col["name"], "externalId": bw_col["externalId"], "groups": group_permissions, "users": []} )


    return coll_list_by_name, group_list_for_import

def create_collection_cli(f_dest_bw_cli_session, f_coll_name, f_new_data_col, f_bw_org_id):
    # Adding a collection via CLI

    try:
        cmd3 = [bw_path, 'encode']
        cmd4 = [bw_path, '--session', f_dest_bw_cli_session, 'create', 'org-collection', '--organizationid', f_bw_org_id]

        p3 = subprocess.Popen(cmd3, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        output3 = p3.communicate(input=json.dumps(f_new_data_col).encode())[0]

        p4 = subprocess.Popen(cmd4, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        output, _ = p4.communicate(input=output3)

        output_str = output.decode('utf-8')
        data = json.loads(output_str)
        

    except subprocess.CalledProcessError as e:
        print(f"There is an issue when creating collection {f_coll_name}. Exit code: {e.returncode}\nError: {e.stderr}")
        exit(1)

    return data

def import_permissions_to_dest_cli_v2(f_dest_bw_cli_session, f_access_token, f_coll_list_by_name):
    global dest_bw_api_endpoint

    #sync the CLI before doing anything
    sync_cli(f_dest_bw_cli_session)

    groups_list = load_groups_api(dest_bw_api_endpoint,f_access_token)

    #convert into a dictionary with name as key
    group_dict_by_name = {}
    for each_group in groups_list:
        group_dict_by_name[each_group["name"]] = each_group["id"]
    
    if (debug):
        print("** Destination group by name", group_dict_by_name,"\n")


    coll_list = load_collection_list_cli(dest_bw_org_id, f_dest_bw_cli_session)
    #convert into a dictionary with name as key
    coll_dict_by_name = {}
    for each_coll in coll_list:
        coll_dict_by_name[each_coll["name"]] = each_coll["id"]

    if (debug):
        print("** Destination collection by name", coll_dict_by_name,"\n")

    for each_old_coll in f_coll_list_by_name:

        collection_name = each_old_coll["name"]
        json_body = {"organizationId": dest_bw_org_id, "name": collection_name, "externalId": each_old_coll["externalId"] }

        
        if len(each_old_coll["groups"]) > 0:
            json_group =[]
            for each_group in each_old_coll["groups"]:
                each_group["id"] = group_dict_by_name[each_group["name"]]
                json_group.append( each_group )
            json_body["groups"] = json_group

            #only update the collection if it has any groups
            update_collection_cli(f_dest_bw_cli_session, collection_name, coll_dict_by_name[collection_name], json_body, dest_bw_org_id)

    return True

def rewrite_export_file(f_new_coll_id):

    data = {}

    try:
        # Open the JSON file
        with open(EXPORT_FILE_NAME, 'r', encoding='utf-8') as json_file:
            # Load the data from the JSON file
            data = json.load(json_file)
    except FileNotFoundError:
        print(f"Error: The file {EXPORT_FILE_NAME} does not exist.")
        exit(2)

    except json.JSONDecodeError:
        print(f"Error: The file {EXPORT_FILE_NAME} is not a valid JSON file.")
        exit(2)

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        exit(2)
    
    if "collections" in data:
        if len(data["collections"]) > 0:
            for each_collection in data["collections"]:
                each_collection["id"] = f_new_coll_id[each_collection["id"]]

    if "items" in data:
        if len(data["items"]) > 0:
            for each_item in data["items"]:
                if "collectionIds" in each_item:
                    if len(each_item["collectionIds"]) > 0:
                        tmp_col = []
                        for each_collection in each_item["collectionIds"]:
                            tmp_col.append(f_new_coll_id[each_collection])
                        each_item["collectionIds"] = tmp_col

    try:
        # Open the JSON file in write mode, which will overwrite any existing file
        with open(EXPORT_FILE_NAME, 'w', encoding='utf-8') as json_file:
            # Write the data to the JSON file
            json.dump(data, json_file, indent=4)

    except Exception as e:
        print(f"Error writing new export file: {e}")
        exit(2)

def migrate_bw2bw_roles():
    return 0

def add_attachments():
    global bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password, dest_bw_acc_password
    initial_environment_check()

    dest_bw_acc_password = get_account_password("destination")
    dest_bw_cli_session = login_on_cli(dest_bw_vault_uri, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_acc_password)
    import_attachments_to_destination(dest_bw_cli_session, f_new_coll_name)
    return 0

def export_data_complete_bw():
    global bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password

    initial_environment_check()
    bw_acc_password = get_account_password("source")

    #cleanup before starting new import
    delete_all_export_files()

    bw_cli_session = login_on_cli(bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password)
    print("Exporting data from source server...")
    export_data_from_origin_v2(bw_cli_session)

def import_data_complete_bw():
    global dest_bw_vault_uri, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_acc_password
    initial_environment_check()
    dest_bw_acc_password = get_account_password("destination")

    print("Importing data to destination server...")
    dest_bw_cli_session = login_on_cli(dest_bw_vault_uri, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_acc_password)

    import_data_to_destination_v2(dest_bw_cli_session)    

def check_duplicate_group_names(f_access_token, f_bw_api_endpoint):
    if(debug):
        print("** Checking duplicate group names")

    groups_list = load_groups_api(f_bw_api_endpoint,f_access_token)

    groups_names = []
    dup_found = False
    for each_group in groups_list:
        if each_group["name"] in groups_names:
            print("Duplicate group name found: ", each_group["name"])
            dup_found = True
            
        else:
            groups_names.append(each_group["name"])

    if (dup_found):
        print("** Group names in source server contains duplicate. Please make sure the group names are unique")
        exit(2)

    if(debug):
        print("** No duplicate group names")

def check_duplicate_collection_names(f_bw_cli_session, f_bw_org_id):
    if(debug):
        print("** Checking duplicate collections names")

    collections_list = load_collection_list_cli(f_bw_org_id, f_bw_cli_session)

    collections_names = []
    dup_found = False

    for each_collection in collections_list:
        if each_collection["name"] in collections_names:
            print("** Duplicate group name found: ", each_collection["name"])
            dup_found = True
            
        else:
            collections_names.append(each_collection["name"])

    if (dup_found):
        print("** Collection names in source server contains duplicate. Please make sure the group names are unique")
        exit(2)

    if(debug):
        print("** No duplicate Collection names")

    return True

def check_duplicate_names(f_bw_cli_session, f_access_token, f_bw_api_endpoint, f_bw_org_id):
    check_duplicate_group_names(f_access_token, f_bw_api_endpoint)
    check_duplicate_collection_names(f_bw_cli_session, f_bw_org_id)

def migrate_data_bw_to_bw_v2():
    global bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password
    global dest_bw_vault_uri, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_acc_password
    global access_token, bw_api_endpoint, bw_identity_endpoint, bw_org_id

    initial_environment_check()
    bw_acc_password = get_account_password("source")
    dest_bw_acc_password = get_account_password("destination")

    ##read password from file for development only
    #with open("source_pass.txt", 'r') as file:
    #   bw_acc_password = file.read()
    #with open("destination_pass.txt", 'r') as file:
    #   dest_bw_acc_password = file.read()

    #bw_acc_password = bw_acc_password.strip()
    #dest_bw_acc_password = dest_bw_acc_password.strip()


    #cleanup before starting new import
    delete_all_export_files()

    bw_cli_session = login_on_cli(bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password)

    if access_token == "":
        access_token = login_to_bw_public_api(bw_identity_endpoint,bw_org_client_id,bw_org_client_secret)


    check_duplicate_names(bw_cli_session, access_token, bw_api_endpoint, bw_org_id)

    print("** Exporting data from source server...")
    export_data_from_origin_v2(bw_cli_session)

    coll_list_by_name, group_list_for_import = load_permissions_from_origin_cli_v2(bw_cli_session)

    #Login to Destination Public API
    
    access_token = login_to_bw_public_api(dest_bw_identity_endpoint, dest_bw_org_client_id, dest_bw_org_client_secret)

    print("** Importing data to destination server...")
    dest_bw_cli_session = login_on_cli(dest_bw_vault_uri, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_acc_password)
    
    import_data_to_destination_v2(dest_bw_cli_session) 

    import_groups_to_destination(access_token, group_list_for_import)

    import_permissions_to_dest_cli_v2(dest_bw_cli_session, access_token, coll_list_by_name)

def get_members_details(f_bw_api_endpoint, f_access_token, f_member_id):

    http_headers = {'Authorization': 'Bearer ' + f_access_token}
    response = requests.get(f_bw_api_endpoint + "public/members/" + f_member_id, headers=http_headers)
    member_details = {}
    if (response.status_code == 200):
        json_data = response.json()
        if len(json_data) > 0:
            member_details = json_data
        else:
            print(f"JSON Response does not contain data. load_group_details_api. Response: {response}. Group ID:{f_member_id}")
    else:
        print(f"Failed getting member details. MemberID: {f_member_id}, Response: {response.status_code}")
        sys.exit(2)

    return member_details

def load_users_details_from_api(f_bw_api_endpoint, f_access_token):

    member_list = get_members_list(f_bw_api_endpoint, f_access_token)

    f_member_details_list = {}
    if len(member_list) > 0:
        for member in member_list:
            f_member_details_list[member['email']]  = get_members_details(f_bw_api_endpoint, f_access_token, member["id"])

    return f_member_details_list

def import_users_to_dest(f_bw_api_endpoint, f_access_token, f_member_details_list):
    dest_member_list = get_members_list(f_bw_api_endpoint, f_access_token)

    coll_list = load_collections_api(f_bw_api_endpoint, f_access_token)

    #create a dictionary based on externalId. The externalId containds the collection id of source server
    coll_dict_externalid = {}
    if len(coll_list) > 0:
        for each_col in coll_list:
            coll_dict_externalid[each_col["externalId"]] = each_col["id"]


    for each_dest_member in dest_member_list:
        if each_dest_member["email"] in f_member_details_list:
            origin_user_details = f_member_details_list[each_dest_member["email"]]
            if len(origin_user_details["collections"]) > 0:
                for each_col in origin_user_details["collections"]:
                    if each_col["id"] in coll_dict_externalid:
                        each_col["id"] = coll_dict_externalid[each_col["id"]]
            user_dict = {
                "type": origin_user_details["type"],
                "accessAll": origin_user_details["accessAll"],
                "externalId": origin_user_details["externalId"],
                "resetPasswordEnrolled": each_dest_member["resetPasswordEnrolled"],
                "collections": origin_user_details["collections"]
            }
            update_user_collection( f_bw_api_endpoint, f_access_token, each_dest_member['id'], user_dict )

def migrate_users_bw_to_bw():
    global access_token, bw_api_endpoint, dest_access_token, dest_bw_api_endpoint

    initial_environment_check()

    if access_token == "":
        access_token = login_to_bw_public_api(bw_identity_endpoint, bw_org_client_id, bw_org_client_secret)

    if dest_access_token == "":
        dest_access_token = login_to_bw_public_api(dest_bw_identity_endpoint, dest_bw_org_client_id, dest_bw_org_client_secret)

    print("Exporting data from source server...")
    member_details_list = load_users_details_from_api( bw_api_endpoint, access_token)

    print("Importing data to destination server...")
    import_users_to_dest(dest_bw_api_endpoint, dest_access_token, member_details_list)

def migrate_group_members_bw_to_bw():
    global access_token, bw_api_endpoint, dest_access_token, dest_bw_api_endpoint

    initial_environment_check()

    if access_token == "":
        access_token = login_to_bw_public_api(bw_identity_endpoint, bw_org_client_id, bw_org_client_secret)

    if dest_access_token == "":
        dest_access_token = login_to_bw_public_api(dest_bw_identity_endpoint, dest_bw_org_client_id, dest_bw_org_client_secret)

    print("Getting group membership from source server...")
    groups_members_dict = load_groups_members(bw_api_endpoint, access_token)

    if debug:
        print("Source Data:")
        print(groups_members_dict)

    print("Importing data to destination server...")
    migrate_groups_members(dest_bw_api_endpoint, dest_access_token, groups_members_dict)

def update_collection_ext_id(f_bw_cli_session, f_dest_bw_org_id, f_coll_list):
    #Convert collection from list to dictionary.
    #Collection name as key, external ID as value

    coll_name_extid = {}
    for each_col in f_coll_list:
        coll_name_extid[each_col["name"]] = each_col["externalId"]
    dest_coll_list = load_collection_list_cli(f_dest_bw_org_id, f_bw_cli_session)

    if len(dest_coll_list) == 0:
        print("Exiting. Empty collection list on destination or CLI failed")
        sys.exit(1)    
    for each_col in dest_coll_list:
        dest_coll_details = load_collection_details_cli(f_dest_bw_org_id, each_col["id"], f_bw_cli_session)
        if dest_coll_details["name"] in coll_name_extid:
            if coll_name_extid[each_col["name"]] is not None:
                dest_coll_details["externalId"] = coll_name_extid[dest_coll_details["name"]]
                update_collection_cli(f_bw_cli_session, dest_coll_details["name"], dest_coll_details["id"], dest_coll_details, f_dest_bw_org_id)


def migrate_col_ext_id_bw_to_bw():
    global bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password
    global dest_bw_vault_uri, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_acc_password
    global bw_org_id, dest_bw_org_id

    initial_environment_check()
    bw_acc_password = get_account_password("source")
    dest_bw_acc_password = get_account_password("destination")

    # #read password from file for development only
    # with open("source_pass.txt", 'r') as file:
    #   bw_acc_password = file.read()
    # with open("destination_pass.txt", 'r') as file:
    #   dest_bw_acc_password = file.read()

    # bw_acc_password = bw_acc_password.strip()
    # dest_bw_acc_password = dest_bw_acc_password.strip()

    bw_cli_session = login_on_cli(bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password)

    print("Getting collection list from source server...")
    coll_list = load_collection_list_cli(bw_org_id, bw_cli_session)

    if len(coll_list) == 0:
        print("Exiting. Empty collection list from source")
        sys.exit(1)

    print("Updating collection on destination server...")    
    dest_bw_cli_session = login_on_cli(dest_bw_vault_uri, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_acc_password)

    update_collection_ext_id(dest_bw_cli_session, dest_bw_org_id, coll_list)


def do_diff_users(f_access_token, f_dest_access_token):

    member_details_list = load_users_details_from_api( bw_api_endpoint, f_access_token)
    dest_member_details_list = load_users_details_from_api( dest_bw_api_endpoint, f_dest_access_token)

    if len(member_details_list) < 1:
        print(f"The member list from source is empty")
    if len(dest_member_details_list) < 1:
        print(f"The member list from destination is empty")

    #will do later. Just realized that comparing users may not be required.

    return 0

def compare_dicts(dict1, dict2):
    any_diff = False
    print(f"Number of records: Source: {len(dict1)}, Destination: {len(dict2)}")

    for key in dict1.keys() | dict2.keys():
        if key not in dict1:
            any_diff = True
            print(f'"{key}" is present in destination server, but not in source')
            if len(dict2[key]) > 0:
                print('Values:', dict2[key])
        elif key not in dict2:
            any_diff = True
            print(f'"{key}" is present in source server, but not in destination')
            if len(dict1[key]) > 0:
                print('Values:', dict1[key])
        else:
            dict1_values = set(dict1[key])
            dict2_values = set(dict2[key])
            
            common_values = dict1_values & dict2_values
            only_in_dict1 = dict1_values - dict2_values
            only_in_dict2 = dict2_values - dict1_values
            
            if only_in_dict1 or only_in_dict2:
                any_diff = True
                print(f'Differences in key "{key}":')
                
                if common_values:
                    print('Common values:', list(common_values))
                
                if only_in_dict1:
                    print('Values only in source server:', list(only_in_dict1))
                
                if only_in_dict2:
                    print('Values only in destination server:', list(only_in_dict2))
                    
                print()
    if not any_diff:
        print("No difference found.")

def populate_groups(f_bw_api_endpoint,f_access_token, f_group_list, f_coll_dict):
    
    coll_dict_id = {}
    for each_col in f_coll_dict:
        coll_dict_id[each_col["id"]] = each_col["name"]

    group_dict_name = {}
    for each_group in f_group_list:
        group_details = load_group_details_api(f_bw_api_endpoint,f_access_token, each_group["id"])
        group_dict_name[each_group["name"]] = []

        if "collections" in group_details.keys():
            for each_col_group in group_details["collections"]:
                if each_col_group["id"] in coll_dict_id.keys():
                    group_dict_name[each_group["name"]].append(coll_dict_id[each_col_group["id"]])

    return group_dict_name

def populate_members(f_bw_api_endpoint,f_access_token, f_member_list, f_coll_dict):
    
    coll_dict_id = {}
    for each_col in f_coll_dict:
        coll_dict_id[each_col["id"]] = each_col["name"]

    member_dict_email = {}
    for each_member in f_member_list:
        member_details = get_members_details(f_bw_api_endpoint, f_access_token, each_member["id"])
        member_dict_email[each_member["email"]] = []

        if "collections" in member_details.keys():
            for each_col_member in member_details["collections"]:
                if each_col_member["id"] in coll_dict_id.keys():
                    member_dict_email[each_member["email"]].append(coll_dict_id[each_col_member["id"]])

    return member_dict_email

def do_diff_collections(coll_dict_source, coll_dict_dest):

    #print(f"Number of collections: Source: {len(coll_dict_source)}, Destination: {len(coll_dict_dest)}")

    #extracting the names

    name_list_source = {}
    name_list_dest = {}
    
    for each_col in coll_dict_source:
        name_list_source[each_col["name"]]= []

    for each_col in coll_dict_dest:
        name_list_dest[each_col["name"]]= []
    
    compare_dicts(name_list_source, name_list_dest)

def do_diff_bw_to_bw():
    global access_token, dest_access_token, bw_cli_session, dest_bw_cli_session, bw_acc_password, dest_bw_acc_password

    initial_environment_check()

    bw_acc_password = get_account_password("source")
    dest_bw_acc_password = get_account_password("destination")
    if access_token == "":
        access_token = login_to_bw_public_api(bw_identity_endpoint, bw_org_client_id, bw_org_client_secret)

    if dest_access_token == "":
        dest_access_token = login_to_bw_public_api(dest_bw_identity_endpoint, dest_bw_org_client_id, dest_bw_org_client_secret)

    #do_diff_users(access_token, dest_access_token)

    bw_cli_session = login_on_cli(bw_vault_uri, bw_acc_client_id, bw_acc_client_secret, bw_acc_password)
    coll_dict_source = load_collection_list_cli(bw_org_id, bw_cli_session)

    dest_bw_cli_session = login_on_cli(dest_bw_vault_uri, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_acc_password)
    coll_dict_dest = load_collection_list_cli(dest_bw_org_id, dest_bw_cli_session)

    print()
    print("comparing collections")
    print("----------------------------")
    do_diff_collections(coll_dict_source, coll_dict_dest)
    print("----------------------------")
    print()

    #getting group list, populate, and compate
    group_list_source = load_groups_api(bw_api_endpoint, access_token)
    group_list_dest = load_groups_api(dest_bw_api_endpoint, dest_access_token)

    group_dict_by_name_source = populate_groups(bw_api_endpoint, access_token, group_list_source, coll_dict_source)
    group_dict_by_name_dest = populate_groups(dest_bw_api_endpoint, dest_access_token, group_list_dest, coll_dict_dest)

    print("comparing groups")
    print("----------------------------")
    compare_dicts(group_dict_by_name_source, group_dict_by_name_dest)
    print("----------------------------")
    print()

    #getting member list, populate, and compate
    member_list_source = get_members_list(bw_api_endpoint, access_token)
    member_list_dest = get_members_list(dest_bw_api_endpoint, dest_access_token)

    member_dict_by_name_source = populate_members(bw_api_endpoint, access_token, member_list_source, coll_dict_source)
    member_dict_by_name_dest = populate_members(dest_bw_api_endpoint, dest_access_token, member_list_dest, coll_dict_dest)

    print("comparing members")
    print("----------------------------")
    compare_dicts(member_dict_by_name_source, member_dict_by_name_dest)
    print("----------------------------")
    print()

def save_json_to_file(f_my_list, f_filename):
    json_data = json.dumps(f_my_list, indent=4)
    print("writing to file: " + script_location + f_filename)

    # write json data to a file
    try:
        with open(os.path.join( script_location, f_filename), 'w', encoding='utf-8') as json_file:
            json_file.write(json_data)
    except IOError as e:
        print(f'An error occurred while writing to the file: {e}')
    except Exception as e:
        print(f'An unexpected error occurred: {e}')

def print_help():
    print("usage: bwAdminTools.py <options>")
    print("")
    print("Options:")
    sys.stdout.write("%-20s %-50s\n" % ("-h, --help","Display help for commands "))
    sys.stdout.write("%-20s %-50s\n" % ("-c","The commands. See below for command list"))
    sys.stdout.write("%-20s %-50s\n" % ("-d","Show debug/verbose output"))
    sys.stdout.write("%-20s %-50s\n" % ("-f, --config","File contains BW and LP configurations. Default: config.cfg"))
    print("")
    print("Commands:")
    sys.stdout.write("%-20s %-50s\n" % ("migratebw","To migrate from one Bitwarden server to another server"))
    sys.stdout.write("%-20s %-50s\n" % ("migratebwusers","To migrate individualusers collection permission from one Bitwarden server to another server"))
    sys.stdout.write("%-20s %-50s\n" % ("migrategroupmembers","To migrate group membership from one Bitwarden server to another server"))
    sys.stdout.write("%-20s %-50s\n" % ("migratecolextid","To migrate External ID of collections from one Bitwarden server to another server"))
    sys.stdout.write("%-20s %-50s\n" % ("diffbw","To compare collections, groups, and members between 2 organizations"))
    sys.stdout.write("%-20s %-50s\n" % ("migrate1p","To migrate vault permissions from 1Password"))
    sys.stdout.write("%-20s %-50s\n" % ("migratelp","To migrate shared folder permissions from Lastpass"))
    print("")
    print("Examples:")
    print("python3 bwAdminTools.py -c migratebw")
    print("python3 bwAdminTools.py -c migratebwusers -f myconfig.cfg ")

def load_configfile_lastpass(config):
    global lp_cid, lp_api_secret, lp_api_uri
    try:        
        lp_cid = config.get('config', 'lp_cid')
        lp_api_secret = config.get('config', 'lp_api_secret')
        lp_api_uri = config.get('config', 'lp_api_uri')
    except configparser.NoSectionError as e:
        print(f"Missing 'config' section in the config file. Error: {str(e)}")
        sys.exit(2)
    except configparser.NoOptionError as e:
        print(f"Missing required option in the config file. Error: {str(e)}")
        sys.exit(2)
    except Exception as e:
        print(f"An unknown error occurred. Error: {str(e)}")
        sys.exit(2)

    variables = {
                'bw_acc_client_id': bw_acc_client_id, 
                'bw_acc_client_secret': bw_acc_client_secret, 
                'lp_cid': lp_cid, 
                'lp_api_secret': lp_api_secret, 
                'lp_api_uri': lp_api_uri
                }

    empty_vars = [k for k, v in variables.items() if v == "" or v == '""']

    if empty_vars:
        print("Empty config found. Please check the config file.")
        for var in empty_vars:
            print(f"The variable '{var}' is empty.")
        sys.exit(2)

def load_configfile_bw2bw(config):
    global dest_bw_vault_uri, dest_bw_org_client_id, dest_bw_org_client_secret, dest_bw_acc_client_id, dest_bw_acc_client_secret, dest_bw_org_id, dest_bw_identity_endpoint, dest_bw_api_endpoint

    try:
        dest_bw_vault_uri = config.get('config', 'dest_bw_vault_uri')
        dest_bw_org_client_id = config.get('config', 'dest_bw_org_client_id')
        dest_bw_org_client_secret = config.get('config', 'dest_bw_org_client_secret')
        dest_bw_acc_client_id = config.get('config', 'dest_bw_acc_client_id')
        dest_bw_acc_client_secret = config.get('config', 'dest_bw_acc_client_secret')
        dest_bw_org_id = config.get('config', 'dest_bw_org_id')

    except configparser.NoSectionError as e:
        print(f"Missing 'config' section in the config file. Error: {str(e)}")
        sys.exit(2)
    except configparser.NoOptionError as e:
        print(f"Missing required option in the config file. Error: {str(e)}")
        sys.exit(2)
    except Exception as e:
        print(f"An unknown error occurred. Error: {str(e)}")
        sys.exit(2)


    variables = {'dest_bw_vault_uri': dest_bw_vault_uri, 
                'dest_bw_org_client_id': dest_bw_org_client_id, 
                'dest_bw_org_client_secret': dest_bw_org_client_secret, 
                'dest_bw_acc_client_id': dest_bw_acc_client_id,
                'dest_bw_acc_client_secret' : dest_bw_acc_client_secret,
                'dest_bw_org_id' : dest_bw_org_id,
                }

    empty_vars = [k for k, v in variables.items() if v == "" or v == '""']

    if empty_vars:
        print("Empty config found. Please check the config file.")
        for var in empty_vars:
            print(f"The variable '{var}' is empty.")
        sys.exit(2)

    if dest_bw_vault_uri[-1] != '/':
        dest_bw_vault_uri = dest_bw_vault_uri + "/"

    if dest_bw_vault_uri == "https://bitwarden.com/":
        dest_bw_vault_uri == "https://vault.bitwarden.com/"
    elif dest_bw_vault_uri == "https://bitwarden.eu/":
        dest_bw_vault_uri == "https://vault.bitwarden.eu/"

    if dest_bw_vault_uri == "https://vault.bitwarden.com/":
        dest_bw_identity_endpoint = "https://identity.bitwarden.com/"
        dest_bw_api_endpoint = "https://api.bitwarden.com/"
    elif dest_bw_vault_uri == "https://vault.bitwarden.eu/":
        dest_bw_identity_endpoint = "https://identity.bitwarden.eu/"
        dest_bw_api_endpoint = "https://api.bitwarden.eu/"
    else:
        dest_bw_identity_endpoint = dest_bw_vault_uri + "identity/"
        dest_bw_api_endpoint = dest_bw_vault_uri + "api/"

def load_configfile_basic(config):
    global bw_vault_uri, bw_org_client_id, bw_org_client_secret, bw_identity_endpoint, bw_api_endpoint, bw_org_id, bw_acc_client_id, bw_acc_client_secret
    try:
        bw_vault_uri = config.get('config', 'bw_vault_uri')
        bw_org_client_id = config.get('config', 'bw_org_client_id')
        bw_org_client_secret = config.get('config', 'bw_org_client_secret')
        bw_org_id = config.get('config', 'bw_org_id')
        bw_acc_client_id = config.get('config', 'bw_acc_client_id')
        bw_acc_client_secret = config.get('config', 'bw_acc_client_secret')

    except configparser.NoSectionError as e:
        print(f"Missing 'config' section in the config file. Error: {str(e)}")
        sys.exit(2)
    except configparser.NoOptionError as e:
        print(f"Missing required option in the config file. Error: {str(e)}")
        sys.exit(2)
    except Exception as e:
        print(f"An unknown error occurred. Error: {str(e)}")
        sys.exit(2)

    variables = {'bw_vault_uri': bw_vault_uri, 
                'bw_org_client_id': bw_org_client_id, 
                'bw_org_client_secret': bw_org_client_secret, 
                'bw_org_id': bw_org_id,
                'bw_acc_client_id': bw_acc_client_id,
                'bw_acc_client_secret': bw_acc_client_secret,
                }

    empty_vars = [k for k, v in variables.items() if v == "" or v == '""']

    if empty_vars:
        print("Empty config found. Please check the config file.")
        for var in empty_vars:
            print(f"The variable '{var}' is empty.")
        sys.exit(2)

    if bw_vault_uri[-1] != '/':
        bw_vault_uri = bw_vault_uri + "/"

    if bw_vault_uri == "https://bitwarden.com/":
        bw_vault_uri = "https://vault.bitwarden.com/"
    elif bw_vault_uri == "https://bitwarden.eu/":
        bw_vault_uri = "https://vault.bitwarden.eu/"

    if bw_vault_uri == "https://vault.bitwarden.com/":
        bw_identity_endpoint = "https://identity.bitwarden.com/"
        bw_api_endpoint = "https://api.bitwarden.com/"
    elif bw_vault_uri == "https://vault.bitwarden.eu/":
        bw_identity_endpoint = "https://identity.bitwarden.eu/"
        bw_api_endpoint = "https://api.bitwarden.eu/"
    else:
        bw_identity_endpoint = bw_vault_uri + "identity/"
        bw_api_endpoint = bw_vault_uri + "api/"

def load_configfile(configfile, command):
  
    config = configparser.ConfigParser()
    config.read(configfile)

    if 'config' not in config.sections():
        config.add_section('config')

    load_configfile_basic(config)
    if command in ["migratebw","migratebwv2","migratecolextid","migratebwusers", "migrategroupmembers"]:
        load_configfile_bw2bw(config)
    elif command in ["diffbw","exportperm","purgecoldest","purgegroupdest","importdata"]:
        load_configfile_bw2bw(config)
    elif command in ["migratesf", "migratelp"]:
        load_configfile_lastpass(config)

def main(argv):
    configfile = "config.cfg"
    command = ""
    global access_token
    global verbose
    global debug

    try:
        opts, args = getopt.getopt(argv,"hvdc:f:",["help","config="])
    except getopt.GetoptError:
        print("Invalid options!")   
        print_help()
        sys.exit(2)
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            print_help()
            sys.exit()
        elif opt in ("-f", "--config"):
            configfile = arg
        elif opt == "-c":
            command = arg
        elif opt == "-v":
            verbose = True
        elif opt == "-d":
            debug = True

    if os.path.exists(configfile):
        load_configfile(configfile, command)
    else:
        print("Config file is not found.")
        sys.exit(2)

    if command == "purgecol":
        delete_all_collections(bw_identity_endpoint, bw_api_endpoint, bw_org_client_id, bw_org_client_secret)
    elif command == "purgecoldest":
        delete_all_collections(dest_bw_identity_endpoint, dest_bw_api_endpoint, dest_bw_org_client_id, dest_bw_org_client_secret)
    elif command == "purgegroup":
        delete_all_groups(bw_identity_endpoint, bw_api_endpoint, bw_org_client_id, bw_org_client_secret)
    elif command == "purgegroupdest":
        delete_all_groups(dest_bw_identity_endpoint, dest_bw_api_endpoint, dest_bw_org_client_id, dest_bw_org_client_secret)
    elif (command == "migratesf") or (command == "migratelp"):
        migrate_lastpass_permissions()
    elif command == "migratebw":
        migrate_data_bw_to_bw_v2()
    elif command == "migratebwv2":
        migrate_data_bw_to_bw_v2()
    elif command == "addattachment":
        add_attachments()
    elif command == "migratebwusers":
        migrate_users_bw_to_bw()
    elif command == "migrategroupmembers":
        migrate_group_members_bw_to_bw()
    elif command == "migratecolextid":
        migrate_col_ext_id_bw_to_bw()        
    elif command == "exportdata":
        export_data_complete_bw()
    elif command == "importdata":
        import_data_complete_bw()
    elif command == "diffbw":
        do_diff_bw_to_bw()
        
    else:
        print("Invalid Command!")
        print_help()
        sys.exit(2)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1:])
    else:
        print_help()