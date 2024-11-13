#!/usr/bin/env python3

"""
Bitwarden Event Log Report Script
=================================

This script fetches event logs from the Bitwarden API within a specified date range, enriches them with user data,
and displays the logs in a tabular format or saves them as a CSV.

Usage:
------
python3 generateEventLogReport.py --client_id <YOUR_CLIENT_ID> --client_secret <YOUR_CLIENT_SECRET>

Optional Arguments:
-------------------
--vault_uri      : Bitwarden Vault URI (default: "https://vault.bitwarden.com").
--api_url        : Bitwarden API URL (default: "https://api.bitwarden.com").
--start_date     : Start date for logs (default: 30 days ago).
--end_date       : End date for logs (default: today).
--output_csv     : Path to save logs as a CSV file.
--columns        : Columns to display (default: typeText, device, date, userName, userEmail, ipAddress).

Examples:
---------
1. Display logs from the last 30 days:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET

2. Save logs to a CSV:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --output_csv logs.csv

3. Customize displayed columns:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --columns typeText date

4. Fetch logs within a specific date range:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --start_date 2024-11-11T00:00:00Z --end_date 2024-11-31T23:59:59Z

"""

import requests
import pandas as pd
from datetime import datetime, timedelta
import argparse


# Constants
DEFAULT_VAULT_URI = "https://vault.bitwarden.com"
DEFAULT_API_URL = "https://api.bitwarden.com"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"

# Functions
def get_access_token(client_id, client_secret, vault_uri):
    url = f"{vault_uri}/identity/connect/token"
    payload = {
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
        'scope': 'api.organization'
    }
    response = requests.post(url, data=payload)
    response.raise_for_status()
    return response.json()['access_token']

def get_members(api_url, access_token):
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.get(f"{api_url}/public/members", headers=headers)
    response.raise_for_status()
    return response.json()

def get_event_logs(api_url, access_token, start_date, end_date):
    headers = {"Authorization": f"Bearer {access_token}"}
    uri = f"{api_url}/public/events?start={start_date}&end={end_date}"
    all_event_logs = []
    continuation_token = None

    while True:
        # Add continuation token only if it exists
        if continuation_token:
            uri = f"{api_url}/public/events?start={start_date}&end={end_date}&continuationToken={continuation_token}"
        
        response = requests.get(uri, headers=headers)
        response.raise_for_status()
        data = response.json()

        all_event_logs.extend(data.get('data', []))
        continuation_token = data.get('continuationToken')

        if not continuation_token:
            break

    return all_event_logs

def enrich_event_logs(event_logs, members):
    # Create a lookup using both 'id' and 'userId' for better matching
    member_lookup = {}
    for member in members.get('data', []):
        if member.get('id'):
            member_lookup[member['id']] = member
        if member.get('userId'):
            member_lookup[member['userId']] = member

    for log in event_logs:
        # Match on memberId or actingUserId
        user_id = log.get('memberId') or log.get('actingUserId', '')
        member_info = member_lookup.get(user_id, {})
        
        log["userName"] = member_info.get('name', 'Unknown')
        log["userEmail"] = member_info.get('email', 'Unknown')
        
        # Add typeText and device mappings
        event_type_mapping = {
            1000: "Logged In.",
            1001: "Changed account password.",
            1002: "Enabled/updated two-step login.",
            1003: "Disabled two-step login.",
            1004: "Recovered account from two-step login.",
            1005: "Login attempt failed with incorrect password.",
            1006: "Login attempt failed with incorrect two-step login.",
            1007: "User exported their individual vault items.",
            1008: "User updated a password issued through account recovery.",
            1009: "User migrated their decryption key with Key Connector.",
            1010: "User requested device approval.",
            1100: "Created item.",
            1101: "Edited item.",
            1102: "Permanently deleted item.",
            1103: "Created attachment for item.",
            1104: "Deleted attachment for item.",
            1105: "Moved item to an organization.",
            1106: "Edited collections for item.",
            1107: "Viewed item.",
            1108: "Viewed password for item.",
            1109: "Viewed hidden field for item.",
            1110: "Viewed security code for item.",
            1111: "Copied password for item.",
            1112: "Copied hidden field for item.",
            1113: "Copied security code for item.",
            1114: "Autofilled item.",
            1115: "Sent item to trash.",
            1116: "Restored item.",
            1117: "Viewed Card Number for item.",
            1300: "Created collection.",
            1301: "Edited collection.",
            1302: "Deleted collection.",
            1400: "Created group.",
            1401: "Edited group.",
            1402: "Deleted group.",
            1500: "Invited user.",
            1501: "Confirmed user.",
            1502: "Edited user.",
            1503: "Removed user.",
            1504: "Edited groups for user.",
            1505: "Unlinked SSO for user.",
            1506: "User enrolled in account recovery.",
            1507: "User withdrew from account recovery.",
            1508: "Master Password reset for user.",
            1509: "Reset SSO link for user.",
            1510: "User logged in using SSO for the first time.",
            1511: "Revoked organization access for user.",
            1512: "Restored organization access for user.",
            1513: "Approved device for user.",
            1514: "Denied device for user.",
            1600: "Edited organization settings.",
            1601: "Purged organization vault.",
            1602: "Exported organization vault.",
            1603: "Organization Vault access by a managing Provider.",
            1604: "Organization enabled SSO.",
            1605: "Organization disabled SSO.",
            1606: "Organization enabled Key Connector.",
            1607: "Organization disabled Key Connector.",
            1608: "Families Sponsorships synced.",
            1609: "Modified collection management setting.",
            1700: "Modified policy.",
            2000: "Added domain.",
            2001: "Removed domain.",
            2002: "Domain verified.",
            2003: "Domain not verified.",
            -1: "Unknown event type."  # Default for unrecognized types
        }

        device_type_mapping = {
            0: "Android",
            1: "iOS",
            2: "Chrome Extension",
            3: "Firefox Extension",
            4: "Opera Extension",
            5: "Edge Extension",
            6: "Windows",
            7: "macOS",
            8: "Linux",
            9: "Chrome",
            10: "Firefox",
            11: "Opera",
            12: "Edge",
            13: "Internet Explorer",
            14: "Unknown Browser",
            15: "Android (Amazon)",
            16: "UWP",
            17: "Safari",
            18: "Vivaldi",
            19: "Vivaldi Extension",
            20: "Safari Extension",
            21: "SDK",
            22: "Server",
            23: "Windows CLI",
            24: "MacOs CLI",
            25: "Linux CLI"
        }

        log["typeText"] = event_type_mapping.get(log.get('type', -1), "Unknown event type.")
        log["device"] = device_type_mapping.get(log.get('device', -1), f"Unknown Device Type ({log.get('device')})")

    return event_logs

def save_to_csv(event_logs, columns, output_file):
    df = pd.DataFrame(event_logs)
    df.to_csv(output_file, columns=columns, index=False)

def display_logs(event_logs, columns):
    df = pd.DataFrame(event_logs)

    # Format the date column
    if 'date' in df.columns:
        df['date'] = pd.to_datetime(df['date']).dt.strftime('%b %d, %Y, %I:%M:%S %p')

    existing_columns = [col for col in columns if col in df.columns]
    
    if not existing_columns:
        print("No matching columns to display.")
        return
    
    print(df[existing_columns].to_string(index=False))
    
# Main function
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch Bitwarden event logs.")
    parser.add_argument('--client_id', required=True, help="Bitwarden Client ID")
    parser.add_argument('--client_secret', required=True, help="Bitwarden Client Secret")
    parser.add_argument('--vault_uri', default=DEFAULT_VAULT_URI, help="Bitwarden Vault URI")
    parser.add_argument('--api_url', default=DEFAULT_API_URL, help="Bitwarden API URL")
    parser.add_argument('--start_date', default=(datetime.now() - timedelta(days=30)).strftime(DATE_FORMAT), help="Start date for logs")
    parser.add_argument('--end_date', default=datetime.now().strftime(DATE_FORMAT), help="End date for logs")
    parser.add_argument('--output_csv', help="Path to CSV file to save logs")
    parser.add_argument('--columns', nargs='+', default=["typeText", "device", "date", "userName", "userEmail", "ipAddress"], help="Columns to display")

    args = parser.parse_args()

    print("Fetching access token...")
    access_token = get_access_token(args.client_id, args.client_secret, args.vault_uri)

    print("Fetching members...")
    members = get_members(args.api_url, access_token)

    print("Fetching event logs...")
    event_logs = get_event_logs(args.api_url, access_token, args.start_date, args.end_date)
    enriched_logs = enrich_event_logs(event_logs, members)

    if args.output_csv:
        print(f"Saving logs to {args.output_csv}...")
        save_to_csv(enriched_logs, args.columns, args.output_csv)
    else:
        print("Displaying logs...")
        display_logs(enriched_logs, args.columns)

    print(f"Total logs fetched: {len(event_logs)}")
