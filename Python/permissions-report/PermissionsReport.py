import getopt
import sys
import os
from libs import constants
from libs.utils import check_dependencies, initial_setup, load_configfile, encrypt_pass, write_csv_file
from libs.bwutils import *
#from libs.bwutils import login_on_cli, load_collection_list_cli, login_to_bw_public_api, load_groups_api, load_collection_details_cli, convert_perms_to_text
from libs.bwutils import get_members_list

def convert_collection_list_to_dict(coll_list):
    coll_dict = {}

    for each_coll in coll_list:
        new_coll = { 
            "id" : each_coll["id"],
            "name": each_coll["name"],
            "groups": [],
            "accounts": [],
        }
        coll_dict[each_coll["id"]] = new_coll
    return coll_dict

def convert_group_list_to_dict(group_list):
    group_dict = {}
    if (len(group_list) > 0):
        for each_group in group_list:
            group_dict[each_group["id"]] = {
                "id" : each_group["id"],
                "name": each_group["name"]
            }
    return group_dict

def load_collections_groups_permissions(coll_dict, group_dict, bw_path, config_vars, cli_session):
    for coll_id, coll_value in coll_dict.items():
        coll_details = load_collection_details_cli(bw_path, config_vars["org_id"], coll_id, cli_session)
        if len(coll_details) > 0:
            if len(coll_details["groups"]) > 0:
                for each_group_perm in coll_details["groups"]:
                    new_group_perm = {
                        "name": group_dict[each_group_perm["id"]]["name"],
                        "perms": convert_perms_to_text(each_group_perm["manage"], each_group_perm["readOnly"], each_group_perm["hidePasswords"])
                    }
                    coll_dict[coll_id]["groups"].append(new_group_perm)

    return coll_dict

def load_collections_members_permissions(coll_dict, member_list, config_vars, api_access_token):
    for each_member in member_list:
        member_details = load_member_details_api(config_vars["api_url"],api_access_token, each_member["id"])
        if len(member_details) > 0:
            if len(member_details["collections"]) > 0:
                for each_coll_perm in member_details["collections"]:
                    new_perm = {
                        "email": each_member["email"],
                        "perms": convert_perms_to_text(each_coll_perm["manage"], each_coll_perm["readOnly"], each_coll_perm["hidePasswords"])
                    }

                    coll_dict[each_coll_perm["id"]]["accounts"].append(new_perm)

    return coll_dict

def save_to_csv(coll_dict):
    csv_data = []
    csv_data.append(["Collection Name","Account/Group","Permission"])
    for coll_key, coll_value in coll_dict.items():
        for each_group in coll_value["groups"]:
            csv_data.append( [coll_value["name"], each_group["name"], each_group["perms"]  ] )

        for each_acc in coll_value["accounts"]:            
            csv_data.append( [ coll_value["name"], each_acc["email"], each_acc["perms"]  ] )
    
    write_csv_file("permission_report.csv", csv_data ,"w")

def genreport():
    bw_path = check_dependencies()
    config_vars = load_configfile(constants.CONFIG_FILE)

    cli_session = login_on_cli(bw_path, config_vars['vault_url'], config_vars['account_client_id'], config_vars['account_api_secret'], config_vars['account_password'] )

    coll_list = load_collection_list_cli(bw_path, config_vars['org_id'], cli_session)

    if (len(coll_list) > 0):
        coll_dict = convert_collection_list_to_dict(coll_list)
    else:
        print("There is no collection. If this is not expected, please run it again")
        sys.exit(1)

    api_access_token = login_to_bw_public_api(config_vars['identity_url'], config_vars['org_client_id'], config_vars['org_api_secret'])
    if api_access_token == "":
        print("Login to API failed. Program terminated")
        sys.exit(2)
    
    group_list  = load_groups_api(config_vars['api_url'], api_access_token)
    group_dict = convert_group_list_to_dict(group_list)

    coll_dict = load_collections_groups_permissions(coll_dict, group_dict, bw_path, config_vars, cli_session)

    
    member_list = get_members_list(config_vars['api_url'],api_access_token)

    if len(member_list) > 0:
        coll_dict = load_collections_members_permissions(coll_dict, member_list, config_vars, api_access_token)

    save_to_csv(coll_dict)

def print_help():
    script_name = os.path.basename(__file__)
    print(f"usage: {script_name} <options>")
    print("")
    print("Options:")
    sys.stdout.write("%-18s %-50s\n" % ("-h, --help","Display help for commands "))
    sys.stdout.write("%-18s %-50s\n" % ("-c","The commands. See below for command list"))
    print("")
    print("Commands:")
    sys.stdout.write("%-18s %-50s\n" % ("setup","To setup the environment"))
    sys.stdout.write("%-18s %-50s\n" % ("genreport","To generate report"))
    sys.stdout.write("%-18s %-50s\n" % ("encrypt","To encrypt a single secret"))
    print("")
    print("Examples:")
    print(f"python3 {script_name} -c setup")
    print(f"python3 {script_name} -c genreport")

def main(argv):
    command = ""

    try:
        opts, args = getopt.getopt(argv,"hc:",["help"])
    except getopt.GetoptError:
        print("Invalid options!")   
        print_help()
        sys.exit(2)
    for opt, arg in opts:
        if opt in ("-h", "--help"):
            print_help()
            sys.exit()
        elif opt == "-c":
            command = arg

    if command == "setup":
        initial_setup()
    elif command == "genreport":
        genreport()        
    elif command == "encrypt":
        encrypt_pass()        
    else:
        print("Invalid Command!")
        print_help()
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1:])
    else:
        print_help()