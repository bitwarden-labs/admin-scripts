#!/usr/bin/env python3

# Python script for BW admin tools

# Release Notes:
# v0.3 - 2023.02.06
# - Import attachments from Lastpass to Bitwarden using lpass CLI and Vault Management API 
#   - Import personal folders only, shared only, or all folders.
#   - The script will perform search based on item name. If multiple results returned, the script will choose the first item.


# External module required: 
# pip3 install requests
# 
# Requirements Before Running The Script
# - Fill in the config file. See config-example.cfg
# - The data is already imported (collections created)
# - Vault Management API is running


# TODO: Do not overwrite existing group permissions. Get the list and append it instead.
# TODO: Do not overwrite existing user permissions. Get the list and append it instead. This could cause more API calls since we need to get the collection list individually.
# Roadmap: See Internal Board. INT-51


import json
import subprocess
import sys
import getopt
import configparser
import os.path
import os
import re
from subprocess import Popen, PIPE
import shutil

#TODO: Automatic run of CLI and bw serve?
bw_vault_uri = ""
bw_org_client_id = ""
bw_org_client_secret = ""
bw_vault_mgmt_uri = ""
bw_org_id=""

lp_cid = ""
lp_app_hash = ""
lp_api_uri = ""

access_token = ""

delay_after_api_call_secs = 1
debug = False
verbose = False
add_group_if_not_exists = True
lpass_path = ""
bw_path = ""

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

def add_attachment_to_bw_cli(item_id, attach_name):
    print("Adding attachemnt to BW, item id:", item_id, "Name:", attach_name)
    try:        
        subprocess.run([bw_path, 'create', 'attachment', '--itemid',item_id,'--file',attach_name,"--quiet"])
    except subprocess.CalledProcessError as e:
        print(f"There is an issue uploading the attachement {attach_name} Exit code: {e.returncode}\nError: {e.stderr}")
        exit(1)

def search_item_cli(item_name):

    output = subprocess.check_output([bw_path, 'list', 'items', '--search', item_name])

    output_str = output.decode('utf-8')
    data = json.loads(output_str)

    if (debug):
        print("** Item Search Result from CLI:")
        print("** Item data: ", data,"\n")
    return data

def check_import_attachments(item_id, item_name):
    if (debug): print("Processing Item:",item_name)
    pipe = Popen('lpass show '+item_id, shell=True, stdout=PIPE)
    bw_item_id = ""
    for line in pipe.stdout:
        line_str = line.decode('utf-8').strip() 
        if line_str.find("att-") == 0:
            if (debug): print("Line:",line_str)
            if bw_item_id == "":
                #first attachment, get item ID in BW
                item_search_result = search_item_cli(item_name)
                
                if len(item_search_result)>0:
                    for item_found in item_search_result:
                        if (debug): print("processing search result:", item_found)
                        if item_name == item_found['name']:
                            bw_item_id = item_found['id']
                            print("Item found in BW, Item ID:",bw_item_id)
                            break
                else:
                    print("Item is not found in Bitwarden. Item:",item_name," skipped")
                    break

            if not bw_item_id == "":
                re_result = re.search(r"(.+):\s(.+)$",line_str.strip())
                attach_id = re_result.group(1).strip()
                attach_name = re_result.group(2).strip()
                pipe = Popen(f'echo "S" | {lpass_path} show --attach '+attach_id+" "+item_id, shell=True, stdout=PIPE)
                #(output, err) = pipe.communicate()
                p_status = pipe.wait()
                if p_status == 0:
                    print("Success!")
                    add_attachment_to_bw_cli(bw_item_id, attach_name)
                    os.remove(attach_name)
                    #shall we check whether removal is successful?
                else:
                    print("Downloading attachmend failed! Name:",attach_name)

    return 0

def import_attachments(source):


    pipe = Popen(f'{lpass_path} ls --color=never', shell=True, stdout=PIPE)
    
    for line in pipe.stdout:
        #print("Line:",line.decode('utf-8').strip())
        folder_and_name = item_id = folder = item_name =""
        re_result = re.search(r"(.+)\[id:\s(\d+)\]",line.decode('utf-8').strip())
        if re_result:
            folder_and_name = re_result.group(1)
            item_id = re_result.group(2)
        
        shared = False
        if folder_and_name.find("Shared-") == 0:
            shared=True
            folder_and_name = folder_and_name[7:]

        re_result = re.search(r"(.+)/(.+)?$",folder_and_name)
        if re_result:
            #folder = re_result.group(1)
            item_name = re_result.group(2).strip()

        if not item_name.strip() == "":
            if source == "all":
                check_import_attachments(item_id, item_name)
            elif source == "shared" and shared:
                check_import_attachments(item_id, item_name)
            elif source == "personal" and not shared:
                check_import_attachments(item_id, item_name)

 

def print_help():
    print("usage: bwLPmigration.py <options>")
    print("")
    print("Options:")
    sys.stdout.write("%-18s %-50s\n" % ("-h, --help","Display help for commands "))
    sys.stdout.write("%-18s %-50s\n" % ("-c","The commands. See below for command list"))
    sys.stdout.write("%-18s %-50s\n" % ("-f, --config","File contains BW and LP configurations. Default: config.cfg"))
    sys.stdout.write("%-18s %-50s\n" % ("-v","Verbose Output"))
    sys.stdout.write("%-18s %-50s\n" % ("-d","Debug Output"))
    print("")
    print("Commands:")
    sys.stdout.write("%-18s %-50s\n" % ("importattall","To import attachments from personal and shared folders"))
    sys.stdout.write("%-18s %-50s\n" % ("importattpersonal","To import attachments from personal folders"))
    sys.stdout.write("%-18s %-50s\n" % ("importattshared","To import attachments from shared folders"))
        
    print("")
    print("Examples:")
    print("bwLPmigration.py -c migratesf -f myconfig.cfg # To migrate shared folder permissions from LP")

def load_configfile(configfile):
    global bw_vault_uri
    global bw_org_client_id
    global bw_org_client_secret
    global bw_vault_mgmt_uri
    global bw_org_id 

    config = configparser.ConfigParser()
    config.read(configfile)
    if 'config' not in config.sections():
        config.add_section('config')

    try:
        bw_vault_uri = config.get('config', 'bw_vault_uri')
        bw_org_client_id = config.get('config', 'bw_org_client_id')
        bw_org_client_secret = config.get('config', 'bw_org_client_secret')
        bw_org_id = config.get('config', 'bw_org_id')
    except configparser.NoOptionError :
        print('Missing Config. Please check again the config file')
        sys.exit(1) 
    
    if any(v == "" or v == '""' for v in [bw_vault_uri, bw_org_client_id, bw_org_client_secret, bw_org_id]):
        print("Empty config found. Please check the config file.")
        sys.exit(2)


def main(argv):
    configfile = "config.cfg"
    command = ""
    global access_token
    global verbose
    global debug
    global lpass_path
    global bw_path
    lpass_path = find_program_path("lpass")
    bw_path = find_program_path("bw")
    
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
        load_configfile(configfile)
    else:
        print("Config file is not found.")
        sys.exit(2)
    if command == "importattall":
        import_attachments("all")
    elif command == "importattpersonal":
        import_attachments("personal")
    elif command == "importattshared":
        import_attachments("shared")


    else:
        print("Invalid Command!")
        print_help()
        sys.exit(2)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1:])
    else:
        print_help()