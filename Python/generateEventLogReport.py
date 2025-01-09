#!/usr/bin/env python3

"""
Bitwarden event Log Report Script
=================================

This script fetches event logs from the Bitwarden API within a specified date range, enriches them with user data,
and displays the logs in a tabular format, syslog format, or saves them as a CSV. It also includes the ability to
cache the Bitwarden member list for faster subsequent runs.

Usage:
------
python3 generateEventLogReport.py --client_id <YOUR_CLIENT_ID> --client_secret <YOUR_CLIENT_SECRET>

Required Arguments:
-------------------
--client_id          : Your Bitwarden Client ID.
--client_secret      : Your Bitwarden Client Secret.

Optional Arguments:
-------------------
--vault_uri          : Bitwarden Vault URI (default: "https://vault.bitwarden.com").
--api_url            : Bitwarden API URL (default: "https://api.bitwarden.com").
--start_date         : Start date for logs (default: 30 days ago).
--end_date           : End date for logs (default: today).
--output_csv         : Path to save logs as a CSV file.
--columns            : Columns to display (default: event, device, date, userName, userEmail, ipAddress).
--failed_login_attempt
                     : Display failed login attempts (events 1005 and 1006).
--syslog             : Print logs in a typical syslog format.
--cache_members      : Use a local cache file for member data (to speed up subsequent runs).

Examples:
---------
1. Display logs from the last 30 days:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET

2. Save logs to a CSV:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --output_csv logs.csv

3. Customize displayed columns:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --columns event date

4. Fetch logs within a specific date range:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET \
       --start_date 2024-11-11T00:00:00Z --end_date 2024-11-31T23:59:59Z

5. Display only failed login attempts:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --failed_login_attempt

6. Display logs in syslog format:
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --syslog

7. Cache member data for faster repeated runs (avoiding repeated API calls):
   python3 generateEventLogReport.py --client_id YOUR_CLIENT_ID --client_secret YOUR_CLIENT_SECRET --cache_members
"""

import requests
import pandas as pd
from datetime import datetime, timedelta
import argparse
import logging
from typing import List, Dict, Any
from mappings import EVENT_TYPE_MAPPING, DEVICE_TYPE_MAPPING

import os
import socket
import json

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Constants
DEFAULT_VAULT_URI = "https://vault.bitwarden.com"
DEFAULT_API_URL = "https://api.bitwarden.com"
DATE_FORMAT = "%Y-%m-%dT%H:%M:%S.%fZ"

# ------------------- NEW: cache file constant -------------------
CACHE_FILE_PATH = "/tmp/bitwarden_members_cache.json"


def load_member_cache(cache_file: str) -> Dict[str, Any]:
    """
    Attempt to load members from a local JSON cache file.
    Returns an empty dict if file not found or invalid.
    """
    if not os.path.isfile(cache_file):
        return {}

    try:
        with open(cache_file, 'r') as f:
            data = json.load(f)
            if "data" in data:  # basic validation check
                return data
            else:
                return {}
    except (json.JSONDecodeError, IOError):
        return {}


def save_member_cache(cache_file: str, members: Dict[str, Any]) -> None:
    """
    Write members data to a local JSON file as cache.
    """
    try:
        with open(cache_file, 'w') as f:
            json.dump(members, f)
    except IOError as e:
        logging.warning(f"Could not write cache file '{cache_file}': {e}")


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
    # Create a lookup for members
    member_lookup = {member.get('id'): member for member in members.get('data', [])}
    member_lookup.update({member.get('userId'): member for member in members.get('data', []) if member.get('userId')})

    for log in event_logs:
        # Prioritize actingUserId over memberId
        user_id = log.get('actingUserId') or log.get('memberId')
        member_info = member_lookup.get(user_id, {})

        user_name = member_info.get('name') or 'Unknown'
        user_email = member_info.get('email') or 'Unknown'

        user_display_name = user_name.split()[0] if user_name != 'Unknown' else (
            user_email.split('@')[0] if user_email != 'Unknown' else 'Unknown'
        )

        if user_email == "Unknown":
            logging.debug(f"User ID '{user_id}' could not be found in member data. Log details: {log}")

        item_id = log.get('itemId')
        collection_id = log.get('collectionId')
        policy_id = log.get('policyId')
        member_id = log.get('memberId')
        event_type = EVENT_TYPE_MAPPING.get(log.get('type', -1), "Unknown event type.")

        if item_id:
            event_type += f" {item_id[:8]}."
        if collection_id:
            event_type += f" (Collection ID: {collection_id[:8]})"
        if policy_id:
            event_type += f" (Policy ID: {policy_id[:8]})"
        if member_id and 'Member ID' not in event_type:
            event_type += f" {member_id[:8]}."

        device_name = DEVICE_TYPE_MAPPING.get(log.get('device', -1), f"Unknown Device Type ({log.get('device')})")
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


def filter_failed_login_attempts(event_logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [log for log in event_logs if log.get('type') in [1005, 1006]]


def display_failed_login_attempts(event_logs: List[Dict[str, Any]]) -> None:
    failed_attempts = filter_failed_login_attempts(event_logs)
    grouped_data = {}

    for log in failed_attempts:
        user_key = f"{log['userName']} ({log['userEmail']})"
        if user_key not in grouped_data:
            grouped_data[user_key] = []
        grouped_data[user_key].append(log)

    for user, logs in grouped_data.items():
        print(f"# {user}\n")
        df = pd.DataFrame(logs, columns=['date', 'device', 'event'])
        if 'date' in df.columns:
            df['date'] = pd.to_datetime(df['date']).dt.strftime('%b %d, %Y, %I:%M:%S %p')
        print(df.to_string(index=False))
        print("\n")


def display_logs(event_logs: List[Dict[str, Any]], columns: List[str]) -> None:
    df = pd.DataFrame(event_logs)
    if 'date' in df.columns:
        df['date'] = pd.to_datetime(df['date']).dt.strftime('%b %d, %Y, %I:%M:%S %p')

    existing_columns = [col for col in columns if col in df.columns]
    if not existing_columns:
        logging.warning("No matching columns to display.")
        return

    print(df[existing_columns].to_string(index=False))


def save_to_csv(event_logs: List[Dict[str, Any]], columns: List[str], output_file: str) -> None:
    df = pd.DataFrame(event_logs)
    df.to_csv(output_file, columns=columns, index=False)
    logging.info(f"Logs saved to {output_file}")


def display_syslog_logs(event_logs: List[Dict[str, Any]], columns: List[str]) -> None:
    if not event_logs:
        logging.info("No logs available for syslog display.")
        return

    df = pd.DataFrame(event_logs)

    if 'date' in df.columns:
        df['date'] = pd.to_datetime(df['date'], errors='coerce')
        df['syslog_date'] = df['date'].dt.strftime('%b %d %H:%M:%S')
    else:
        df['syslog_date'] = datetime.now().strftime('%b %d %H:%M:%S')

    hostname = socket.gethostname()
    script_name = "generateEventLogReport.py"
    pid = os.getpid()
    PRI = 14  # facility=1 (user-level), severity=6 (info) => <14>

    for _, row in df.iterrows():
        message_parts = []
        for col in columns:
            if col in row and pd.notna(row[col]):
                message_parts.append(f"{col}={row[col]}")

        message_str = " ".join(message_parts)
        print(f"<{PRI}>{row['syslog_date']} {hostname} {script_name}[{pid}]: {message_str}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Fetch Bitwarden event logs.")
    parser.add_argument('--client_id', required=True, help="Bitwarden Client ID")
    parser.add_argument('--client_secret', required=True, help="Bitwarden Client Secret")
    parser.add_argument('--vault_uri', default=DEFAULT_VAULT_URI, help="Bitwarden Vault URI")
    parser.add_argument('--api_url', default=DEFAULT_API_URL, help="Bitwarden API URL")
    parser.add_argument('--start_date', default=(datetime.now() - timedelta(days=30)).strftime(DATE_FORMAT),
                        help="Start date for logs")
    parser.add_argument('--end_date', default=datetime.now().strftime(DATE_FORMAT), help="End date for logs")
    parser.add_argument('--output_csv', help="Path to CSV file to save logs")
    parser.add_argument('--columns', nargs='+',
                        default=["event", "device", "date", "userName", "userEmail", "ipAddress"],
                        help="Columns to display")
    parser.add_argument('--failed_login_attempt', action='store_true',
                        help="Display failed login attempts (events 1005 and 1006)")
    parser.add_argument('--syslog', action='store_true', help="Display logs in syslog format")

    # ------------------- NEW: cache_members argument -------------------
    parser.add_argument('--cache_members', action='store_true',
                        help="Use local cache file instead of fetching from API if available.")

    args = parser.parse_args()

    try:
        logging.info("Fetching access token...")
        access_token = get_access_token(args.client_id, args.client_secret, args.vault_uri)

        # ------------------- NEW: load from cache or fetch from API -------------------
        if args.cache_members:
            logging.info(f"Trying to load members from cache file: {CACHE_FILE_PATH}")
            members = load_member_cache(CACHE_FILE_PATH)
            if not members:
                logging.info("Cache not found or invalid; fetching members from API...")
                members = get_members(args.api_url, access_token)
                save_member_cache(CACHE_FILE_PATH, members)
            else:
                logging.info("Members loaded successfully from cache.")
        else:
            logging.info("Caching disabled; fetching members from API...")
            members = get_members(args.api_url, access_token)
        # ------------------------------------------------------------------------------

        logging.info("Fetching event logs...")
        event_logs = get_event_logs(args.api_url, access_token, args.start_date, args.end_date)

        enriched_logs = enrich_event_logs(event_logs, members)

        if args.failed_login_attempt:
            display_failed_login_attempts(enriched_logs)
        elif args.syslog:
            display_syslog_logs(enriched_logs, args.columns)
        elif args.output_csv:
            save_to_csv(enriched_logs, args.columns, args.output_csv)
        else:
            display_logs(enriched_logs, args.columns)

        logging.info(f"Total logs fetched: {len(event_logs)}")
    except requests.exceptions.RequestException as e:
        logging.error(f"HTTP request failed: {e}")
    except Exception as e:
        logging.error(f"An error occurred: {e}")
