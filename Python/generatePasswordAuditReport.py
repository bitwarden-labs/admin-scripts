#!/usr/bin/env python3

"""
Bitwarden Password Audit Report Script
=====================================

This script starts a local Bitwarden server, unlocks the vault using the provided master password, and retrieves the list of items in the vault for a specified organization. It then checks the passwords of these items against the PwnedPasswords API to generate an "Exposed Passwords" report, a "Reused Passwords" report, and an "Unsecure Websites" report, displaying the results in tabular format.

Usage:
------
python3 generatePasswordAuditReport.py --master_password <YOUR_MASTER_PASSWORD> --email <YOUR_EMAIL> --organization_id <YOUR_ORG_ID>

Optional Arguments:
-------------------
--bw_exec            : Path to the Bitwarden CLI executable (default: './bw').
--port               : Port on which to run the local API server (default: 8087).
--server_uri         : Bitwarden server URI to configure the CLI (default: 'https://vault.bitwarden.com').

Examples:
---------
1. Start the server and unlock the vault:
   python3 generatePasswordAuditReport.py --master_password YOUR_MASTER_PASSWORD --email YOUR_EMAIL --organization_id YOUR_ORG_ID

2. Specify a different Bitwarden CLI executable and port:
   python3 generatePasswordAuditReport.py --bw_exec /path/to/bw --port 8088 --master_password YOUR_MASTER_PASSWORD --email YOUR_EMAIL --organization_id YOUR_ORG_ID
"""

import subprocess
import requests
import time
import json
import sys
import argparse
import logging
import hashlib
import pandas as pd
from collections import Counter

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Constants
DEFAULT_BW_EXEC = "./bw"
DEFAULT_PORT = 8087
DEFAULT_SERVER_URI = "https://vault.bitwarden.com"

# Configure the Bitwarden CLI
def configure_bitwarden_cli(bw_exec, server_uri):
    logging.info(f"🔧 Configuring Bitwarden CLI with server URI: {server_uri}")
    result = subprocess.run([bw_exec, "config", "server", server_uri], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        logging.error(f"❌ Failed to configure Bitwarden CLI. Error: {result.stderr.decode().strip()}")
        sys.exit(1)

# Log in to Bitwarden CLI
def login_to_bitwarden(bw_exec, email, master_password):
    logging.info(f"🔑 Logging in to Bitwarden CLI with email: {email}")
    result = subprocess.run([bw_exec, "login", email, master_password, "--raw"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        logging.error(f"❌ Failed to log in to Bitwarden CLI. Error: {result.stderr.decode().strip()}")
        sys.exit(1)
    logging.info("🔒 Successfully logged in to Bitwarden CLI.")

# Start the local server
def start_local_server(bw_exec, port):
    logging.info(f"🚀 Starting Bitwarden local API server on port {port}...")
    process = subprocess.Popen([bw_exec, "serve", "--port", str(port)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    time.sleep(5)  # Allow time for server to start
    return process

# Unlock the vault using the local server
def unlock_vault(port, master_password):
    logging.info("Fetching access token...")
    url = f"http://localhost:{port}/unlock"
    headers = {"Content-Type": "application/json"}
    body = json.dumps({"password": master_password})
    try:
        response = requests.post(url, headers=headers, data=body)
        if response.status_code == 200 and response.json().get("success", False):
            logging.info("🔒 Vault unlocked successfully.")
            return response.json()
        else:
            logging.error(f"❌ Failed to unlock the vault. Message: {response.text}")
            sys.exit(1)
    except requests.RequestException as e:
        logging.error(f"❌ Failed to unlock the vault. Error: {e}")
        sys.exit(1)

# List items from the organization vault
def list_items(port, organization_id):
    logging.info("📋 Retrieving items from the vault...")
    url = f"http://localhost:{port}/list/object/items?organizationId={organization_id}"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            items = response.json()
            if items.get("success"):
                logging.info("✅ Items retrieved successfully.")
                return items.get('data', {}).get('data', [])
            else:
                logging.error(f"❌ Failed to retrieve items. Message: {items}")
                sys.exit(1)
        else:
            logging.error(f"❌ Failed to retrieve items. Message: {response.text}")
            sys.exit(1)
    except requests.RequestException as e:
        logging.error(f"❌ Failed to retrieve items. Error: {e}")
        sys.exit(1)

# Check if a password has been exposed using the PwnedPasswords API
def check_pwned_password(password):
    sha1_hash = hashlib.sha1(password.encode('utf-8')).hexdigest().upper()
    prefix = sha1_hash[:5]
    suffix = sha1_hash[5:]

    url = f"https://api.pwnedpasswords.com/range/{prefix}"
    response = requests.get(url)
    if response.status_code != 200:
        logging.error(f"❌ Error fetching data from PwnedPasswords API: {response.status_code}")
        return None

    hash_suffixes = response.text.splitlines()
    for line in hash_suffixes:
        hash_suffix, count = line.split(':')
        if hash_suffix == suffix:
            return int(count)
    return 0

# Generate exposed passwords report
def generate_exposed_passwords_report(items):
    logging.info("📊 Generating Exposed Passwords Report...")
    report_data = []
    for item in items:
        if 'login' in item and 'password' in item['login'] and item['login']['password']:
            password = item['login']['password']
            count = check_pwned_password(password)
            if count > 0:
                report_data.append({
                    'Item Name': item['name'],
                    'Exposed Count': count
                })
            else:
                report_data.append({
                    'Item Name': item['name'],
                    'Exposed Count': 0
                })
    # Convert the report to a DataFrame and display it
    df = pd.DataFrame(report_data)
    if not df.empty:
        print("\nExposed Passwords Report:\n")
        print(df.to_string(index=False))
    else:
        logging.info("No items found for the Exposed Passwords Report.")

# Generate reused passwords report
def generate_reused_passwords_report(items):
    logging.info("📊 Generating Reused Passwords Report...")
    passwords = [item['login']['password'] for item in items if 'login' in item and 'password' in item['login'] and item['login']['password']]
    password_counts = Counter(passwords)
    reused_passwords = [pw for pw, count in password_counts.items() if count > 1]

    report_data = []
    for item in items:
        if 'login' in item and 'password' in item['login'] and item['login']['password'] in reused_passwords:
            report_data.append({
                'Item Name': item['name'],
                'Username': item['login'].get('username', 'N/A'),
                'Reused Count': password_counts[item['login']['password']]
            })

    # Convert the report to a DataFrame and display it
    df = pd.DataFrame(report_data)
    if not df.empty:
        print("\nReused Passwords Report:\n")
        print(df.to_string(index=False))
        print("\nReusing passwords makes it easier for attackers to break into multiple accounts. You should change reused passwords to unique values.")
    else:
        logging.info("No items found for the Reused Passwords Report.")

# Generate unsecured websites report
def generate_unsecure_websites_report(items):
    logging.info("📊 Generating Unsecure Websites Report...")
    report_data = []
    for item in items:
        if 'login' in item and 'uris' in item['login'] and item['login']['uris']:
            for uri in item['login']['uris']:
                if uri['uri'].startswith('http://'):
                    report_data.append({
                        'Item Name': item['name'],
                        'Username': item['login'].get('username', 'N/A'),
                        'URI': uri['uri']
                    })
    # Convert the report to a DataFrame and display it
    df = pd.DataFrame(report_data)
    if not df.empty:
        print("\nUnsecure Websites Report:\n")
        print(df.to_string(index=False))
        print("\nURLs that start with http:// don’t use the best available encryption. Change the login URIs for these accounts to https:// for safer browsing.")
    else:
        logging.info("No unsecured websites found for the Unsecure Websites Report.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Start Bitwarden local server and unlock vault.")
    parser.add_argument('--master_password', required=True, help="Master password for Bitwarden vault")
    parser.add_argument('--bw_exec', default=DEFAULT_BW_EXEC, help="Path to the Bitwarden CLI executable")
    parser.add_argument('--port', type=int, default=DEFAULT_PORT, help="Port to run the local API server on")
    parser.add_argument('--email', required=True, help="Email of the Bitwarden user for CLI login")
    parser.add_argument('--server_uri', default=DEFAULT_SERVER_URI, help="Bitwarden server URI to configure the CLI")
    parser.add_argument('--organization_id', required=True, help="Organization ID to list items from")
    
    args = parser.parse_args()

    BW_EXEC = args.bw_exec
    PORT = args.port
    MASTER_PASSWORD = args.master_password
    EMAIL = args.email
    SERVER_URI = args.server_uri
    ORGANIZATION_ID = args.organization_id
    
    # Ensure Bitwarden CLI is available
    if subprocess.call(["which", BW_EXEC], stdout=subprocess.PIPE, stderr=subprocess.PIPE) != 0:
        logging.error(f"❌ Bitwarden CLI ({BW_EXEC}) is not available. Please install it and try again.")
        sys.exit(1)
    
    # Configure the Bitwarden server
    configure_bitwarden_cli(BW_EXEC, SERVER_URI)
    
    # Log in to Bitwarden
    login_to_bitwarden(BW_EXEC, EMAIL, MASTER_PASSWORD)
    
    # Start the server
    server_process = start_local_server(BW_EXEC, PORT)
    
    # Unlock the vault
    unlock_response = unlock_vault(PORT, MASTER_PASSWORD)
    
    # List items from the organization vault
    items = list_items(PORT, ORGANIZATION_ID)
    
    # Generate Exposed Passwords Report
    generate_exposed_passwords_report(items)
    
    # Generate Reused Passwords Report
    generate_reused_passwords_report(items)
    
    # Generate Unsecure Websites Report
    generate_unsecure_websites_report(items)
    
    # Stop the server at the end (optional, for a graceful shutdown)
    logging.info("🚩 Stopping the local API server...")
    server_process.kill()
    logging.info("🚀 Server stopped and script completed.")
