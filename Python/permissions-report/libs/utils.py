import shutil
import os
from libs import constants
import sys
from libs.encryption import encrypt_aes_256_cbc, decrypt_aes_256_cbc
import random
import string
import getpass
import base64
import configparser
import smtplib
import platform
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import csv


def create_file_name(filename):
    # Detect the operating system
    os_name = platform.system()
    
    # Assign the file name based on the OS
    if os_name == "Windows":
        file_name = filename +".exe"
    elif os_name == "Linux":
        file_name = filename
    else:
        file_name = filename  # For OS other than Windows and Linux

    return file_name

def find_program_path(f_name):

    # check if 'bw' is a system-wide command
    system_bw = shutil.which(f_name)
    if system_bw:
        return system_bw

    # If bw is not in $PATH
    # Check if 'bw' file exists in the same directory as the script

    main_program_dir = get_main_program_dir()
    program_path = os.path.join(main_program_dir, f_name)

    if os.path.isfile(program_path):
        # Check if 'bw' is executable
        if os.access(program_path, os.X_OK):
            return program_path
        else:
            print(f"'{f_name}' file at {program_path} is not executable")
    return ""

def check_file_exists(f_filename):

    main_program_dir = get_main_program_dir()

    # Construct the full path to the file
    file_path = os.path.join(main_program_dir, f_filename)
    
    # Check if the file exists
    if os.path.exists(file_path):
        return True
    else:
        return False

def check_dependencies():

    if os.environ.get('BW_PASSPHRASE') is None:
        # Print a warning message instead of raising an exception
        print("Warning: Environment variable 'BW_PASSPHRASE' is not set. Please set the env. variable")
        sys.exit(1)

    if not check_file_exists(constants.CONFIG_FILE):
        print("config file is not found. Please run the setup")
        sys.exit(1)

    #check if Bitwarden CLI is in the system
    bw_path = find_program_path(create_file_name("bw"))
    if bw_path == "":
        print("Bitwarden CLI (bw) is not found in the system. Please download it from https://bitwarden.com/download/")
        sys.exit(1)
    return bw_path

def generate_random_string(length=16):
    # Define the characters that can be used in the string
    characters = string.ascii_letters + string.digits  # This includes both lowercase and uppercase letters, and digits
    # Generate a random string of the specified length
    random_string = ''.join(random.choices(characters, k=length))
    return random_string

def get_main_program_dir():
    # Current script's directory (e.g., '/path/to/main_program/libs')
    current_script_dir = os.path.dirname(os.path.realpath(__file__))

    # Main program directory (one directory up from the current script's directory)
    main_program_dir = os.path.dirname(current_script_dir)

    return main_program_dir

def load_configfile(configfile):
    config_vars = {}

    main_program_dir = get_main_program_dir()
    file_path = os.path.join(main_program_dir, configfile)

    config = configparser.ConfigParser()
    config.read(file_path)

    if 'config' not in config.sections():
        config.add_section('config')
    try:
        config_vars['org_id'] = config.get('config', 'org_id')
        config_vars['account_client_id'] = config.get('config', 'account_client_id')
        config_vars['vault_url'] = config.get('config', 'vault_url')
        config_vars['account_password'] = config.get('config', 'account_password')
        config_vars['account_api_secret'] = config.get('config', 'account_api_secret')
        config_vars['org_api_secret'] = config.get('config', 'org_api_secret')

    except configparser.NoSectionError as e:
        print(f"Missing 'config' section in the config file. Error: {str(e)}")
        sys.exit(1)
    except configparser.NoOptionError as e:
        print(f"Missing required option in the config file. Error: {str(e)}. Please run the setup again")
        sys.exit(1)
    except Exception as e:
        print(f"An unknown error occurred. Error: {str(e)}")
        sys.exit(1)

    config_vars['org_client_id'] = "organization." + config_vars['org_id']

    if "vault.bitwarden.com" in config_vars['vault_url']:
        config_vars['identity_url'] = "https://identity.bitwarden.com/"
        config_vars['api_url'] = "https://api.bitwarden.com/"
    elif "vault.bitwarden.eu" in config_vars['vault_url']:
        config_vars['identity_url'] = "https://identity.bitwarden.eu/"
        config_vars['api_url'] = "https://api.bitwarden.eu/"
    else:
        config_vars['identity_url'] = config_vars['vault_url'] + "identity/"
        config_vars['api_url'] = config_vars['vault_url'] + "api/"
        
    #decrypt all secrets
    bw_passphrase = os.environ.get('BW_PASSPHRASE')

    decrypted_secret = decrypt_aes_256_cbc(base64.b64decode(config_vars['account_password']), bw_passphrase)
    #Decode the decrypted byte string back to a string
    config_vars['account_password'] = decrypted_secret.decode('utf-8')

    decrypted_secret = decrypt_aes_256_cbc(base64.b64decode(config_vars['account_api_secret']), bw_passphrase)
    config_vars['account_api_secret'] = decrypted_secret.decode('utf-8')

    decrypted_secret = decrypt_aes_256_cbc(base64.b64decode(config_vars['org_api_secret']), bw_passphrase)
    config_vars['org_api_secret'] = decrypted_secret.decode('utf-8')
   
    return config_vars

def encrypt_pass():
    bw_passprahse = getpass.getpass("Please enter the pass phrase:")
    bw_plain_secret = getpass.getpass("Please enter the string to encrypt:")
    encrypted_secret = encrypt_aes_256_cbc(bw_plain_secret, bw_passprahse)
    encrypted_secret_base64 = base64.b64encode(encrypted_secret).decode('utf-8')
    print(f"Encrypted Text: {encrypted_secret_base64}")

def initial_setup():

    main_program_dir = get_main_program_dir()

    prompt = """
    Please choose your data region:
    1. US Region
    2. EU Region
    3. Self-hosted
    Enter your choice (1/2/3): """

    user_choice = input(prompt)
    
    if user_choice == '1':
        vault_url = "https://vault.bitwarden.com/"
    elif user_choice == '2':
        vault_url = "https://vault.bitwarden.eu/"
    elif user_choice == '3':
        vault_url = input("Please enter your self-host URL e.g. https://vault.domain.com/: ")        
    else:
        # Handle invalid input
        print("Invalid choice. Please run the setup again")
        sys.exit(1)

    if not vault_url.endswith("/"):
        vault_url += "/"

    prompt = """
    What passphrase should we use to encrypt the secrets?
    1. I will enter the passphrase
    2. Create a random passphrase
    Enter your choice (1/2): """

    user_choice_pass = input(prompt)

    if user_choice_pass == '1':
        secret_pass = getpass.getpass("Please enter the secret pass:")        
    elif user_choice_pass == '2':
        secret_pass = generate_random_string(20)
        
    else:
        # Handle invalid input
        print("Invalid choice. Please run the setup again")
        sys.exit(1)

    account_client_id = input("Enter your Bitwarden Account API Client ID:")
    account_client_secret = getpass.getpass("Enter your Bitwarden Account API Secret:")
    account_password = getpass.getpass("Please enter the Bitwarden Account Master Password:")
    org_id = input("Enter your Bitwarden Organization ID:")
    org_api_client_secret = getpass.getpass("Enter your Bitwarden Organization API Secret:")

    #writing secrets to files

    encrypted_account_password = encrypt_aes_256_cbc(account_password, secret_pass)
    encrypted_account_password_base64 = base64.b64encode(encrypted_account_password).decode('utf-8')
    
    encrypted_account_client_secret = encrypt_aes_256_cbc(account_client_secret, secret_pass)
    encrypted_account_client_secret_base64 = base64.b64encode(encrypted_account_client_secret).decode('utf-8')

    encrypted_api_client_secret = encrypt_aes_256_cbc(org_api_client_secret, secret_pass)
    encrypted_api_client_secret_base64 = base64.b64encode(encrypted_api_client_secret).decode('utf-8')

    # writing config file
    config = configparser.ConfigParser()
    section = 'config'
    # Check if the section already exists, if not, add it
    if not config.has_section(section):
        config.add_section(section)
    
    # Set the values in the config object
    config.set(section, 'org_id', org_id)
    config.set(section, 'account_client_id', account_client_id)
    config.set(section, 'vault_url', vault_url)
    config.set(section, 'account_password', encrypted_account_password_base64)
    config.set(section, 'account_api_secret', encrypted_account_client_secret_base64)
    config.set(section, 'org_api_secret', encrypted_api_client_secret_base64)

    # Write the configuration to a file
    file_path = os.path.join(main_program_dir, constants.CONFIG_FILE)

    try:
        with open(file_path, 'w') as configfile:
            config.write(configfile)
    except PermissionError:
        print(f"Error: Permission denied to write to the file '{file_path}'.")
    except OSError as e:
        # For other kinds of I/O errors (like an error writing to the file)
        print(f"Error: An error occurred while writing to the file '{file_path}': {e}")

    if user_choice_pass == '1':
        secret_pass = "<user input>"

    print("")
    print("IMPORTANT!!! Please take note of your passphrase")
    print(f"Your passphrase is {secret_pass}")
    print("")
    
def decrypt_get_secret(filename, secret_pass):
    main_program_dir = get_main_program_dir()
    file_path = os.path.join(main_program_dir, filename)

    encrypted_secret_base64 = read_file(file_path)
    #When decrypting, if you encoded the encrypted data in Base64, decode it back from Base64 before decryption
    decrypted_secret = decrypt_aes_256_cbc(base64.b64decode(encrypted_secret_base64), secret_pass)

    #Decode the decrypted byte string back to a string
    decoded_secret = decrypted_secret.decode('utf-8')
    return decoded_secret

def read_file(file_path):
    try:
        with open(file_path, 'r') as file:
            data = file.read()
            return data
    except FileNotFoundError:
        print(f"Error: The file '{file_path}' was not found.")
    except PermissionError:
        print(f"Error: Permission denied to read the file '{file_path}'.")
    except OSError as e:
        # For other kinds of I/O errors (like an error reading the file)
        print(f"Error: An error occurred while reading the file '{file_path}': {e}")
    sys.exit(1)

def write_file(file_path, data, writemode):
    try:
        with open(file_path, writemode) as file:
            file.write(data)
    except PermissionError:
        print(f"Error: Permission denied to write to the file '{file_path}'.")
    except OSError as e:
        # For other kinds of I/O errors (like an error writing to the file)
        print(f"Error: An error occurred while writing to the file '{file_path}': {e}")

def write_csv_file(file_path, data, writemode):
    try:
        with open(file_path, mode=writemode, newline='') as file:
            writer = csv.writer(file)
            writer.writerows(data)
    except PermissionError:
        print(f"Error: Permission denied to write to the file '{file_path}'.")
    except OSError as e:
        # For other kinds of I/O errors (like an error writing to the file)
        print(f"Error: An error occurred while writing to the file '{file_path}': {e}")


def send_html_email(host, port, username, password, sender_email, receiver_emails, subject, html_content):
    """
    Send an HTML email.

    :param host: SMTP server host (e.g., 'smtp.gmail.com')
    :param port: SMTP server port (e.g., 587 for TLS)
    :param username: Username for SMTP server authentication (leave empty for no auth)
    :param password: Password for SMTP server authentication
    :param sender_email: Email address of the sender
    :param receiver_email: Email address of the receiver
    :param subject: Subject of the email
    :param html_content: HTML content of the email
    """

    if isinstance(receiver_emails, str):
        receiver_emails = receiver_emails.split(',')
    # Create a MIMEMultipart message
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = sender_email
    msg['To'] = ", ".join(receiver_emails)  # Join all receiver addresses into a single string for the header

    # Attach the HTML content
    part = MIMEText(html_content, 'html')
    msg.attach(part)

    try:
        # Connect to the SMTP server
        with smtplib.SMTP(host, port) as server:
            server.ehlo()  # Can be omitted
            server.starttls()  # Secure the connection
            server.ehlo()  # Can be omitted
            # If username is provided, authenticate
            if username:
                server.login(username, password)
            # Send email
            server.sendmail(sender_email, receiver_emails, msg.as_string())
        print("Email sent successfully!")
    except Exception as e:
        print(f"Failed to send email: {e}")