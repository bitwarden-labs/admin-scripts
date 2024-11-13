#!/usr/bin/env python3

"""
Bitwarden event Log Report Script
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
--start_date     : Start date for logs (default: 1 day ago).
--end_date       : End date for logs (default: today).
--output_csv     : Path to save logs as a CSV file.
--columns        : Columns to display (default: event, device, date, userName, userEmail, ipAddress).

Examples:
---------
1. Display logs from the last 1 day:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET

2. Save logs to a CSV:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --output_csv logs.csv

3. Customize displayed columns:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --columns event date

4. Fetch logs within a specific date range:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --start_date 2024-11-11T00:00:00Z --end_date 2024-11-31T23:59:59Z

"""

import requests
import pandas as pd
from datetime import datetime, timedelta
import argparse
import logging
from typing import List, Dict, Any
from mappings import EVENT_TYPE_MAPPING, DEVICE_TYPE_MAPPING

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Constants
DEFAULT_VAULT_URI = "https://vault.bitwarden.com"
DEFAULT_API_URL = "https://api.bitwarden.com"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"

# Functions
def get_access_token(client_id: str, client_secret: str, vault_uri: str) -> str:
    url = f"{vault_uri}/identity/connect/token"
    payload = {
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
        'scope': 'api.organization'
    }
    response = requests.post(url, data=payload)
    response.raise_for_status()
    return response.json().get('access_token')

def get_members(api_url: str, access_token: str) -> Dict[str, Any]:
    headers = {"Authorization": f"Bearer {access_token}"}
    response = requests.get(f"{api_url}/public/members", headers=headers)
    response.raise_for_status()
    return response.json()

def get_event_logs(api_url: str, access_token: str, start_date: str, end_date: str) -> List[Dict[str, Any]]:
    headers = {"Authorization": f"Bearer {access_token}"}
    all_event_logs = []
    continuation_token = None

    while True:
        uri = f"{api_url}/public/events?start={start_date}&end={end_date}"
        if continuation_token:
            uri += f"&continuationToken={continuation_token}"
        
        response = requests.get(uri, headers=headers)
        response.raise_for_status()
        data = response.json()

        all_event_logs.extend(data.get('data', []))
        continuation_token = data.get('continuationToken')

        if not continuation_token:
            break

    return all_event_logs

def enrich_event_logs(event_logs: List[Dict[str, Any]], members: Dict[str, Any]) -> List[Dict[str, Any]]:
    # Create a lookup for members using both 'id' and 'userId' to improve matching accuracy
    member_lookup = {member.get('id'): member for member in members.get('data', [])}
    member_lookup.update({member.get('userId'): member for member in members.get('data', []) if member.get('userId')})

    for log in event_logs:
        # Prioritize actingUserId over memberId for enrichment
        user_id = log.get('actingUserId') or log.get('memberId')
        member_info = member_lookup.get(user_id, {})

        user_name = member_info.get('name') or 'Unknown'
        user_email = member_info.get('email') or 'Unknown'

        # Use short user name if available
        user_display_name = user_name.split()[0] if user_name != 'Unknown' else (user_email.split('@')[0] if user_email != 'Unknown' else 'Unknown')

        # Check if user data could not be enriched and log information
        if user_email == "Unknown":
            logging.debug(f"User ID '{user_id}' could not be found in member data. Log details: {log}")

        # Enrich event with contextual information
        item_id = log.get('itemId')
        collection_id = log.get('collectionId')
        policy_id = log.get('policyId')
        member_id = log.get('memberId')
        event_type = EVENT_TYPE_MAPPING.get(log.get('type', -1), "Unknown event type.")
        
        # Adding more context to event, e.g., itemId, collectionId, policyId, or memberId
        if item_id:
            event_type += f" {item_id[:8]}."
        if collection_id:
            event_type += f" (Collection ID: {collection_id[:8]})"
        if policy_id:
            event_type += f" (Policy ID: {policy_id[:8]})"
        if member_id and 'Member ID' not in event_type:
            event_type += f" {member_id[:8]}."

        # Update log with enriched details
        device_name = DEVICE_TYPE_MAPPING.get(log.get('device', -1), f"Unknown Device Type ({log.get('device')})")
        # Include more detailed device information
        if 'CLI' in device_name:
            device_name = f"CLI - {device_name.split()[-1]}"
        elif 'Extension' not in device_name and 'Unknown' not in device_name:
            device_name = f"Web vault - {device_name}"

        log.update({
            "userName": user_display_name,
            "userEmail": user_email,
            "event": event_type,
            "device": device_name
        })
    
    return event_logs

def save_to_csv(event_logs: List[Dict[str, Any]], columns: List[str], output_file: str) -> None:
    df = pd.DataFrame(event_logs)
    df.to_csv(output_file, columns=columns, index=False)
    logging.info(f"Logs saved to {output_file}")

def display_logs(event_logs: List[Dict[str, Any]], columns: List[str]) -> None:
    df = pd.DataFrame(event_logs)

    if 'date' in df.columns:
        df['date'] = pd.to_datetime(df['date']).dt.strftime('%b %d, %Y, %I:%M:%S %p')

    existing_columns = [col for col in columns if col in df.columns]
    
    if not existing_columns:
        logging.warning("No matching columns to display.")
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
    parser.add_argument('--columns', nargs='+', default=["event", "device", "date", "userName", "userEmail", "ipAddress"], help="Columns to display")

    args = parser.parse_args()

    try:
        logging.info("Fetching access token...")
        access_token = get_access_token(args.client_id, args.client_secret, args.vault_uri)

        logging.info("Fetching members...")
        members = get_members(args.api_url, access_token)

        logging.info("Fetching event logs...")
        event_logs = get_event_logs(args.api_url, access_token, args.start_date, args.end_date)

        enriched_logs = enrich_event_logs(event_logs, members)

        if args.output_csv:
            save_to_csv(enriched_logs, args.columns, args.output_csv)
        else:
            display_logs(enriched_logs, args.columns)

        logging.info(f"Total logs fetched: {len(event_logs)}")
    except requests.exceptions.RequestException as e:
        logging.error(f"HTTP request failed: {e}")
    except Exception as e:
        logging.error(f"An error occurred: {e}")
