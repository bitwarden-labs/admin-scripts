#!/usr/bin/env python3

"""
Bitwarden event Log Report Script
=================================

This script can fetch event logs from the Bitwarden API:
- Single-run (using --start_date / --end_date)
- True live feed mode (using --live), only grabbing newly created logs each iteration.

Changes: 
--------
1. Uses `dateutil.parser.parse` to handle all inbound timestamps from the Bitwarden API,
   ensuring the script can handle fractional seconds, offsets, and other ISO-8601 variants.

Arguments:
----------
--client_id, --client_secret : Required for Bitwarden API authentication.

Optional:
---------
--vault_uri, --api_url       : Adjust Bitwarden endpoints (defaults shown).
--start_date, --end_date     : For single-run mode. ISO8601 timestamps.
--columns                    : Columns to display (default: event, device, date, userName, userEmail, ipAddress).
--failed_login_attempt       : Show only events 1005/1006 (invalid login attempts).
--syslog                     : Print logs in a syslog format.
--output_csv                 : Save logs to CSV at this path.
--cache_members              : Cache the members in /tmp/bitwarden_members_cache.json for faster reruns.
--live                       : Run continuously, fetching only new logs since the last retrieved event time.
--interval                   : Seconds to wait between fetches in live mode (default: 60).
"""

import argparse
import logging
import requests
import time
import json
import os
import socket
from datetime import datetime, timedelta, timezone
from typing import List, Dict, Any, Optional

import pandas as pd
from dateutil import parser as date_parser

# Constants
DEFAULT_VAULT_URI = "https://vault.bitwarden.com"
DEFAULT_API_URL   = "https://api.bitwarden.com"
DATE_FORMAT       = "%Y-%m-%dT%H:%M:%S.%fZ"
CACHE_FILE_PATH   = "/tmp/bitwarden_members_cache.json"

# mappings.py

# Event type mapping for Bitwarden logs
EVENT_TYPE_MAPPING = {
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
    -1: "Unknown event type."
}

# Device type mapping for Bitwarden logs
DEVICE_TYPE_MAPPING = {
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
    25: "Linux CLI",
    -1: "Unknown Device Type"
}

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

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
    resp = requests.post(url, data=payload)
    resp.raise_for_status()
    return resp.json()["access_token"]

def get_members(api_url: str, access_token: str) -> Dict[str, Any]:
    """Fetch the organization's members from Bitwarden."""
    headers = {"Authorization": f"Bearer {access_token}"}
    resp = requests.get(f"{api_url}/public/members", headers=headers)
    resp.raise_for_status()
    return resp.json()

def get_event_logs(api_url: str, access_token: str, start_date: str, end_date: str) -> List[Dict[str, Any]]:
    """Fetch Bitwarden event logs within [start_date, end_date]."""
    headers = {"Authorization": f"Bearer {access_token}"}
    all_event_logs = []
    continuation_token = None

    while True:
        url = f"{api_url}/public/events?start={start_date}&end={end_date}"
        if continuation_token:
            url += f"&continuationToken={continuation_token}"

        resp = requests.get(url, headers=headers)
        resp.raise_for_status()
        data = resp.json()

        all_event_logs.extend(data.get("data", []))
        continuation_token = data.get("continuationToken")

        if not continuation_token:
            break

    return all_event_logs

def enrich_event_logs(event_logs: List[Dict[str, Any]], members: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Enrich logs using member data and known mappings."""
    member_lookup = {m.get('id'): m for m in members.get('data', [])}
    member_lookup.update({m.get('userId'): m for m in members.get('data', []) if m.get('userId')})

    for log in event_logs:
        user_id = log.get('actingUserId') or log.get('memberId')
        member_info = member_lookup.get(user_id, {})

        user_name = member_info.get('name')  or 'Unknown'
        user_email = member_info.get('email') or 'Unknown'
        user_display_name = user_name.split()[0] if user_name != 'Unknown' else (
            user_email.split('@')[0] if user_email != 'Unknown' else 'Unknown'
        )

        event_type  = EVENT_TYPE_MAPPING.get(log.get('type'), "Unknown event type")
        device_name = DEVICE_TYPE_MAPPING.get(log.get('device'), f"Unknown Device ({log.get('device')})")

        # Optional partial ID context
        if log.get('itemId'):
            event_type += f" {log['itemId'][:8]}."
        if log.get('collectionId'):
            event_type += f" (Collection: {log['collectionId'][:8]})"
        if log.get('policyId'):
            event_type += f" (Policy: {log['policyId'][:8]})"
        if log.get('memberId') and 'Member ID' not in event_type:
            event_type += f" {log['memberId'][:8]}."

        # Tweak the device name
        if 'CLI' in device_name:
            # e.g., "CLI - 1.29.0"
            device_name = f"CLI - {device_name.split()[-1]}"
        elif ('Extension' not in device_name) and ('Unknown' not in device_name):
            # e.g., "Web vault - Safari"
            device_name = f"Web vault - {device_name}"

        log.update({
            "userName":  user_display_name,
            "userEmail": user_email,
            "event":     event_type,
            "device":    device_name
        })
    return event_logs

def filter_failed_login_attempts(event_logs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Return only logs for events 1005 or 1006."""
    return [log for log in event_logs if log.get('type') in [1005, 1006]]

def display_failed_login_attempts(event_logs: List[Dict[str, Any]]) -> None:
    """Group and display failed login attempts by user."""
    logs_by_user = {}
    for log in filter_failed_login_attempts(event_logs):
        user_key = f"{log['userName']} ({log['userEmail']})"
        logs_by_user.setdefault(user_key, []).append(log)

    for user, logs in logs_by_user.items():
        print(f"\n# {user}\n")
        df = pd.DataFrame(logs, columns=['date','device','event'])
        if 'date' in df.columns:
            df['date'] = pd.to_datetime(df['date']).dt.strftime('%b %d, %Y, %I:%M:%S %p')
        print(df.to_string(index=False))

def display_logs(event_logs: List[Dict[str, Any]], columns: List[str]) -> None:
    """Display logs in a simple table with specified columns."""
    df = pd.DataFrame(event_logs)
    if 'date' in df.columns:
        # Keep this as is, or parse with dateutil if you want to handle odd formats
        df['date'] = pd.to_datetime(df['date'], errors='coerce').dt.strftime('%b %d, %Y, %I:%M:%S %p')

    existing_cols = [col for col in columns if col in df.columns]
    if not existing_cols:
        logging.warning("No matching columns to display.")
        return

    print(df[existing_cols].to_string(index=False))

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
    script_name = "generateEventLogReport.py"
    pid         = os.getpid()
    PRI         = 14  # <facility=1(user-level), severity=6(info) => 14>

    for _, row in df.iterrows():
        msg_parts = []
        for col in columns:
            if col in row and pd.notna(row[col]):
                msg_parts.append(f"{col}={row[col]}")
        msg_str = " ".join(msg_parts)
        print(f"<{PRI}>{row['syslog_date']} {hostname} {script_name}[{pid}]: {msg_str}")

def save_to_csv(event_logs: List[Dict[str, Any]], columns: List[str], output_file: str) -> None:
    """Save logs to CSV."""
    df = pd.DataFrame(event_logs)
    df.to_csv(output_file, columns=columns, index=False)
    logging.info(f"Logs saved to {output_file}")


# ------------------- FIXED: Use dateutil parser to handle all formats. -------------------
def get_max_event_time(event_logs: List[Dict[str, Any]]) -> Optional[datetime]:
    """
    Parse the 'date' field from logs and return the maximum timestamp found.
    Using dateutil.parser.parse to handle offsets, nanosecond precision, etc.
    """
    max_dt = None
    for log in event_logs:
        log_date_str = log.get('date')
        if not log_date_str:
            continue
        try:
            # date_parser.parse can handle 9-digit fractional seconds, +00:00 offset, etc.
            parsed_dt = date_parser.parse(log_date_str)
            # Convert to UTC and remove tzinfo if you want a naive datetime
            # e.g.: parsed_dt = parsed_dt.astimezone(timezone.utc).replace(tzinfo=None)
        except (ValueError, TypeError):
            continue  # skip unrecognized dates

        if max_dt is None or parsed_dt > max_dt:
            max_dt = parsed_dt

    return max_dt


def main():
    parser = argparse.ArgumentParser(description="Fetch Bitwarden event logs.")
    parser.add_argument('--client_id', required=True, help="Bitwarden Client ID")
    parser.add_argument('--client_secret', required=True, help="Bitwarden Client Secret")
    parser.add_argument('--vault_uri', default=DEFAULT_VAULT_URI, help="Bitwarden Vault URI")
    parser.add_argument('--api_url', default=DEFAULT_API_URL, help="Bitwarden API URL")
    parser.add_argument('--columns', nargs='+', default=["event", "device", "date", "userName", "userEmail", "ipAddress"],
                        help="Columns to display (default: event, device, date, userName, userEmail, ipAddress)")
    parser.add_argument('--failed_login_attempt', action='store_true', help="Display only events 1005 and 1006")
    parser.add_argument('--syslog', action='store_true', help="Display logs in syslog format")
    parser.add_argument('--output_csv', help="Path to CSV file to save logs")
    parser.add_argument('--cache_members', action='store_true', help="Use local cache file instead of fetching from the API.")
    parser.add_argument('--interval', type=int, default=60, help="Seconds between fetches in live mode (default: 60).")

    args = parser.parse_args()

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
                    if args.failed_login_attempt:
                        display_failed_login_attempts(enriched_logs)
                    elif args.syslog:
                        display_syslog_logs(enriched_logs, args.columns)
                    elif args.output_csv:
                        save_to_csv(enriched_logs, args.columns, args.output_csv)
                    else:
                        display_logs(enriched_logs, args.columns)

                    logging.info(f"Total logs fetched: {len(event_logs)}")

                    # Update the "latest_event_time" to the max timestamp
                    max_dt = get_max_event_time(event_logs)
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
