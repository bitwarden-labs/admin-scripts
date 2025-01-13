#!/usr/bin/env python3

"""
This script fetches event logs from the Bitwarden API in live mode, only grabbing newly created logs each iteration.

Arguments:
----------
--client_id, --client_secret : Required for Bitwarden API authentication.

Optional:
---------
--vault_uri, --api_url       : Adjust Bitwarden endpoints (defaults shown).
--columns                    : Columns to display (default: event, device, date, userName, userEmail, ipAddress).
--syslog                     : Print logs in a syslog format.
--output_csv                 : Save logs to CSV at this path.
--cache_members              : Cache the members in /tmp/bitwarden_members_cache.json for faster reruns.
--interval                   : Seconds to wait between fetches in live mode (default: 60).
--disable_logging            : Disable all logging info.

Examples:
--------

python getEventLogsLiveFeed.py --client_id $CLIENT_ID --client_secret $CLIENT_SECRET --interval 5 
python getEventLogsLiveFeed.py --client_id $CLIENT_ID --client_secret $CLIENT_SECRET --interval 5 --syslog
python getEventLogsLiveFeed.py --client_id $CLIENT_ID --client_secret $CLIENT_SECRET --interval 5 --syslog --cache_members
python getEventLogsLiveFeed.py --client_id $CLIENT_ID --client_secret $CLIENT_SECRET --interval 5 --syslog --cache_members --disable_logging 
python getEventLogsLiveFeed.py --client_id $CLIENT_ID --client_secret $CLIENT_SECRET --interval 5 --syslog --cache_members --disable_logging --output_csv output.csv
"""

import argparse
import logging
import requests
import time
import json
import os
import socket
import warnings
import pandas as pd
import sys
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional
from dateutil.parser import parse as date_parser

# Suppress specific urllib3 warning
warnings.filterwarnings("ignore", category=UserWarning, module='urllib3', message='urllib3 v2 only supports OpenSSL 1.1.1+')

# Constants
DEFAULT_VAULT_URI = "https://vault.bitwarden.com"
DEFAULT_API_URL   = "https://api.bitwarden.com"
DATE_FORMAT       = "%Y-%m-%dT%H:%M:%S.%fZ"
CACHE_FILE_PATH   = "/tmp/bitwarden_members_cache.json"

def get_event_type_mapping() -> Dict[int, str]:
    """Return the event type mapping for Bitwarden logs."""
    return {
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
    }

def get_device_type_mapping() -> Dict[int, str]:
    """Return the device type mapping for Bitwarden logs."""
    return {
        1: "Web vault",
        2: "Browser extension",
        3: "Mobile app",
        4: "Desktop app",
        5: "CLI",
        6: "API",
        7: "Other",
    }

def load_member_cache(cache_file: str) -> Dict[str, Any]:
    """Load cached member data from JSON."""
    if not os.path.isfile(cache_file):
        return {}
    try:
        with open(cache_file, 'r') as f:
            data = json.load(f)
            if "data" in data:  # basic validation
                return data
            else:
                return {}
    except (json.JSONDecodeError, IOError):
        return {}

def save_member_cache(cache_file: str, members: Dict[str, Any]) -> None:
    """Write members data to a local JSON file as cache."""
    try:
        with open(cache_file, 'w') as f:
            json.dump(members, f)
    except IOError as e:
        logging.warning(f"Could not write cache file '{cache_file}': {e}")

def get_access_token(client_id: str, client_secret: str, vault_uri: str) -> str:
    """Obtain an OAuth2 access token from Bitwarden."""
    url = f"{vault_uri}/identity/connect/token"
    payload = {
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
        'scope': 'api.organization'
    }
    headers = {
        'Content-Type': 'application/x-www-form-urlencoded'
    }
    response = requests.post(url, data=payload, headers=headers)
    response.raise_for_status()
    return response.json()['access_token']

def get_members(api_url: str, access_token: str) -> Dict[str, Any]:
    """Fetch members from the Bitwarden API."""
    url = f"{api_url}/public/members"
    headers = {
        'Authorization': f"Bearer {access_token}"
    }
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    return response.json()

def get_event_logs(api_url: str, access_token: str, start_date: str, end_date: str) -> List[Dict[str, Any]]:
    """Fetch event logs from the Bitwarden API."""
    url = f"{api_url}/public/events"
    headers = {
        'Authorization': f"Bearer {access_token}"
    }
    params = {
        'start': start_date,
        'end': end_date
    }
    response = requests.get(url, headers=headers, params=params)
    response.raise_for_status()
    return response.json().get('data', [])

def enrich_event_logs(event_logs: List[Dict[str, Any]], members: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Enrich logs using member data and known mappings."""
    member_lookup = {m.get('id'): m for m in members.get('data', [])}
    member_lookup.update({m.get('userId'): m for m in members.get('data', []) if m.get('userId')})

    event_type_mapping = get_event_type_mapping()
    device_type_mapping = get_device_type_mapping()

    for log in event_logs:
        user_id = log.get('actingUserId') or log.get('memberId')
        member_info = member_lookup.get(user_id, {})

        user_name = member_info.get('name')  or 'Unknown'
        user_email = member_info.get('email') or 'Unknown'
        user_display_name = user_name.split()[0] if user_name != 'Unknown' else (
            user_email.split('@')[0] if user_email != 'Unknown' else 'Unknown'
        )

        event_type  = event_type_mapping.get(log.get('type'), "Unknown event type")
        device_type = device_type_mapping.get(log.get('deviceType'), "Unknown Device")

        # Optional partial ID context
        if log.get('itemId'):
            event_type += f" {log['itemId'][:8]}."
        if log.get('collectionId'):
            event_type += f" (Collection: {log['collectionId'][:8]})"
        if log.get('policyId'):
            event_type += f" (Policy: {log['policyId'][:8]})"
        if log.get('memberId') and 'Member ID' not in event_type:
            event_type += f" {log['memberId'][:8]}."

        log.update({
            "userName":  user_display_name,
            "userEmail": user_email,
            "event":     event_type,
            "device":    device_type
        })
    return event_logs

def save_to_csv(event_logs: List[Dict[str, Any]], columns: List[str], output_file: str) -> None:
    """Append logs to CSV and add headers if the file is empty."""
    df = pd.DataFrame(event_logs)
    # Check if the file exists and if it is empty
    file_exists = os.path.isfile(output_file)
    if file_exists and os.path.getsize(output_file) == 0:
        file_exists = False  # Treat as if the file does not exist to write headers

    df.to_csv(output_file, columns=columns, index=False, mode='a', header=not file_exists)
    logging.info(f"Logs appended to {output_file}")

def display_syslog_logs(event_logs: List[Dict[str, Any]], columns: List[str]) -> None:
    """
    Print logs in syslog format: <14>Jan 12 13:37:00 hostname script[PID]: event=... device=...
    """
    if not event_logs:
        logging.info("No logs available for syslog display.")
        return

    df = pd.DataFrame(event_logs)
    if 'date' in df.columns:
        # Use normal pandas parse here for display
        df['date'] = pd.to_datetime(df['date'], errors='coerce')
        df['syslog_date'] = df['date'].dt.strftime('%b %d %H:%M:%S')
    else:
        df['syslog_date'] = datetime.now().strftime('%b %d %H:%M:%S')

    hostname    = socket.gethostname()
    script_name = "getEventLogsLiveFeed.py"
    pid         = os.getpid()
    PRI         = 14  # <facility=1(user-level), severity=6(info) => 14>

    for _, row in df.iterrows():
        msg_parts = []
        for col in columns:
            if col in row and pd.notna(row[col]):
                msg_parts.append(f"{col}={row[col]}")
        msg_str = " ".join(msg_parts)
        print(f"<{PRI}>{row['syslog_date']} {hostname} {script_name}[{pid}]: {msg_str}")
        # Flush the output to ensure it is displayed immediately
        sys.stdout.flush()

def display_logs(event_logs: List[Dict[str, Any]], columns: List[str]) -> None:
    """Display logs in a tabular format."""
    if not event_logs:
        logging.info("No logs available for display.")
        return

    df = pd.DataFrame(event_logs)
    print(df[columns].to_string(index=False))

def get_max_event_time(event_logs: List[Dict[str, Any]]) -> Optional[datetime]:
    """Get the maximum event time from the logs."""
    if not event_logs:
        return None
    return max(date_parser(log['date']) for log in event_logs)

def main():
    parser = argparse.ArgumentParser(description="Fetch Bitwarden event logs.")
    parser.add_argument('--client_id', required=True, help="Bitwarden Client ID")
    parser.add_argument('--client_secret', required=True, help="Bitwarden Client Secret")
    parser.add_argument('--vault_uri', default=DEFAULT_VAULT_URI, help="Bitwarden Vault URI")
    parser.add_argument('--api_url', default=DEFAULT_API_URL, help="Bitwarden API URL")
    parser.add_argument('--columns', nargs='+', default=["event", "device", "date", "userName", "userEmail", "ipAddress"],
                        help="Columns to display (default: event, device, date, userName, userEmail, ipAddress)")
    parser.add_argument('--syslog', action='store_true', help="Display logs in syslog format")
    parser.add_argument('--output_csv', help="Path to CSV file to save logs")
    parser.add_argument('--cache_members', action='store_true', help="Use local cache file instead of fetching from the API.")
    parser.add_argument('--interval', type=int, default=60, help="Seconds between fetches in live mode (default: 60).")
    parser.add_argument('--disable_logging', action='store_true', help="Disable all logging info")

    args = parser.parse_args()

    # Configure logging
    log_format = '%(asctime)s - %(levelname)s - %(message)s'
    if args.disable_logging:
        logging.basicConfig(level=logging.CRITICAL, format=log_format)
    else:
        logging.basicConfig(level=logging.INFO, format=log_format)

    try:
        logging.info("Fetching access token...")
        access_token = get_access_token(args.client_id, args.client_secret, args.vault_uri)

        # Fetch or cache members
        if args.cache_members:
            logging.info(f"Trying to load members from cache: {CACHE_FILE_PATH}")
            members = load_member_cache(CACHE_FILE_PATH)
            if not members:
                logging.info("No valid cache found; fetching members from API...")
                members = get_members(args.api_url, access_token)
                save_member_cache(CACHE_FILE_PATH, members)
            else:
                logging.info("Members loaded from cache.")
        else:
            logging.info("Caching disabled; fetching members from API...")
            members = get_members(args.api_url, access_token)

        logging.info(f"Live mode: pulling only new logs. Interval = {args.interval} seconds.")
        logging.info("Press Ctrl+C to stop.")

        latest_event_time = datetime.utcnow() - timedelta(seconds=args.interval)

        while True:
            try:
                start_str = latest_event_time.strftime(DATE_FORMAT)
                end_time  = datetime.utcnow()
                end_str   = end_time.strftime(DATE_FORMAT)

                logging.info(f"Fetching logs from {start_str} to {end_str}...")
                event_logs = get_event_logs(args.api_url, access_token, start_str, end_str)
                if not event_logs:
                    logging.info("No new logs found.")
                else:
                    enriched_logs = enrich_event_logs(event_logs, members)
                    # Output or store
                    if args.syslog:
                        display_syslog_logs(enriched_logs, args.columns)
                    if args.output_csv:
                        save_to_csv(enriched_logs, args.columns, args.output_csv)
                    if not args.syslog:
                        display_logs(enriched_logs, args.columns)

                    logging.info(f"Total logs fetched: {len(event_logs)}")

                    # Update the "latest_event_time" to the max timestamp
                    max_dt = get_max_event_time(enriched_logs)
                    if max_dt:
                        # Add offset of 1 microsecond to avoid duplicates at boundary
                        latest_event_time = max_dt + timedelta(microseconds=1)

                time.sleep(args.interval)

            except KeyboardInterrupt:
                logging.info("Live mode interrupted by user. Exiting...")
                break
            except requests.exceptions.RequestException as e:
                logging.error(f"HTTP request failed: {e}")
                time.sleep(args.interval)
            except Exception as e:
                logging.error(f"Unexpected error: {e}")
                time.sleep(args.interval)

    except requests.exceptions.RequestException as e:
        logging.error(f"HTTP request failed: {e}")
    except Exception as e:
        logging.error(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
