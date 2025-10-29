#!/usr/bin/env python3
"""
Keeper to Bitwarden Migration Script

This script migrates data from a Keeper password manager JSON export to Bitwarden
using the Bitwarden CLI. It handles:
- Authentication (login/unlock)
- Org-collection creation from shared folders
- Folder creation
- Item migration with proper type mapping
- File attachments
"""

import json
import subprocess
import sys
import getpass
import time
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Dict, List, Optional, Any
from pathlib import Path


class BitwardenAuth:
    """Handle Bitwarden CLI authentication"""

    def __init__(self):
        self.session_key: Optional[str] = None

    def authenticate(self) -> str:
        """
        Authenticate with Bitwarden CLI.
        Handles both login and unlock scenarios.
        Returns the session key.
        """
        # First, check the current status
        result = subprocess.run(
            ['bw', 'status'],
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            print(f"Error checking Bitwarden status: {result.stderr}")
            sys.exit(1)

        status = json.loads(result.stdout)
        print(f"Bitwarden status: {status['status']}")

        if status['status'] == 'unlocked':
            print("Vault is already unlocked. Using existing session.")
            # Try to get the session from environment or prompt for re-auth
            return self._get_session_key()

        elif status['status'] == 'locked':
            print("Vault is locked. Unlocking...")
            return self._unlock_vault()

        else:  # unauthenticated
            print("Not authenticated. Logging in...")
            return self._login()

    def _login(self) -> str:
        """Perform initial login to Bitwarden"""
        master_password = getpass.getpass("Enter your Bitwarden master password: ")

        # Use environment variable to pass password (avoids stdin issues)
        env = {**subprocess.os.environ, 'BW_PASSWORD': master_password}

        result = subprocess.run(
            ['bw', 'login', '--passwordenv', 'BW_PASSWORD', '--raw'],
            capture_output=True,
            text=True,
            env=env
        )

        if result.returncode != 0:
            # Check if already logged in
            if "already logged in" in result.stderr.lower():
                print("Already logged in. Attempting to unlock...")
                return self._unlock_vault()
            else:
                print(f"Login failed: {result.stderr}")
                sys.exit(1)

        self.session_key = result.stdout.strip()
        print("Successfully logged in!")
        return self.session_key

    def _unlock_vault(self) -> str:
        """Unlock an already logged-in vault"""
        master_password = getpass.getpass("Enter your Bitwarden master password to unlock: ")

        # Use environment variable to pass password (avoids stdin issues)
        env = {**subprocess.os.environ, 'BW_PASSWORD': master_password}

        result = subprocess.run(
            ['bw', 'unlock', '--passwordenv', 'BW_PASSWORD', '--raw'],
            capture_output=True,
            text=True,
            env=env
        )

        if result.returncode != 0:
            print(f"Unlock failed: {result.stderr}")
            sys.exit(1)

        self.session_key = result.stdout.strip()
        print("Successfully unlocked vault!")
        return self.session_key

    def _get_session_key(self) -> str:
        """Prompt user for session key when vault is already unlocked"""
        print("\nVault is unlocked but we need the session key.")
        print("Please run 'bw unlock' in another terminal to get the session key,")
        print("or we can unlock again here.")

        choice = input("Re-unlock? (y/n): ").lower()
        if choice == 'y':
            return self._unlock_vault()
        else:
            session_key = getpass.getpass("Paste your session key: ")
            self.session_key = session_key.strip()
            return self.session_key


class KeeperToBitwardenMigration:
    """Main migration class"""

    def __init__(self, keeper_export_path: str, attachments_dir: str, session_key: str, max_workers: int = 5):
        self.keeper_export_path = Path(keeper_export_path)
        self.attachments_dir = Path(attachments_dir)
        self.session_key = session_key
        self.max_workers = max_workers

        # In-memory mappings
        self.shared_folder_map: Dict[str, str] = {}  # Keeper path -> Bitwarden collection ID
        self.folder_map: Dict[str, str] = {}  # Keeper folder path -> Bitwarden folder ID
        self.item_attachments: List[Dict[str, Any]] = []  # Items with attachments to process
        self.passkey_items: List[Dict[str, Any]] = []  # Items with passkeys that weren't transferred

        # Thread safety
        self.lock = threading.Lock()

        # Load Keeper export
        with open(self.keeper_export_path, 'r') as f:
            self.keeper_data = json.load(f)

    def _run_parallel(self, func, items, max_workers, item_name="item", result_callback=None):
        """
        Generic helper to run a function in parallel over a list of items.

        Args:
            func: Function to call for each item
            items: List of items to process
            max_workers: Max number of parallel workers
            item_name: Name for display in progress messages
            result_callback: Optional callback(result) called for each successful result

        Returns: (success_count, failed_items, results)
        """
        total = len(items)
        success_count = 0
        failed_items = []
        results = []

        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all tasks
            future_to_item = {executor.submit(func, item): item for item in items}

            # Process as they complete
            for idx, future in enumerate(as_completed(future_to_item), 1):
                item = future_to_item[future]
                try:
                    result = future.result()
                    if result and result.get('success'):
                        # Display path or name from result
                        display = result.get('path_normalized', result.get('path', result.get('name', f'{item_name} {idx}')))
                        print(f"[{idx}/{total}] ✓ {display}")
                        success_count += 1
                        results.append(result)

                        # Call optional callback with result
                        if result_callback:
                            result_callback(result)
                    else:
                        display = result.get('path', result.get('name', f'{item_name} {idx}')) if result else str(item)
                        print(f"[{idx}/{total}] ✗ Failed: {display}")
                        failed_items.append(item)
                except Exception as e:
                    print(f"[{idx}/{total}] ✗ Error: {str(e)}")
                    failed_items.append(item)

        return success_count, failed_items, results

    def encode_bw_data(self, data: str) -> Optional[str]:
        """Encode data using bw encode for create/edit operations"""
        env = {'BW_SESSION': self.session_key}

        result = subprocess.run(
            ['bw', 'encode'],
            input=data,
            capture_output=True,
            text=True,
            env={**subprocess.os.environ, **env}
        )

        if result.returncode != 0:
            print(f"Encoding failed: {result.stderr}")
            return None

        return result.stdout.strip()

    def is_rate_limit_error(self, error_message: str) -> bool:
        """Check if error message indicates rate limiting"""
        rate_limit_indicators = [
            'rate limit',
            'too many requests',
            '429',
            'try again later',
            'slow down'
        ]
        error_lower = error_message.lower()
        return any(indicator in error_lower for indicator in rate_limit_indicators)

    def run_bw_command(self, args: List[str], input_data: Optional[str] = None, encode: bool = False) -> Dict[str, Any]:
        """Run a Bitwarden CLI command with the session key"""
        env = {'BW_SESSION': self.session_key}

        # Encode data if needed for create/edit operations
        if encode and input_data:
            input_data = self.encode_bw_data(input_data)
            if not input_data:
                return None

        result = subprocess.run(
            ['bw'] + args,
            input=input_data,
            capture_output=True,
            text=True,
            env={**subprocess.os.environ, **env}
        )

        if result.returncode != 0:
            error_msg = result.stderr

            # Check for rate limiting
            if self.is_rate_limit_error(error_msg):
                return {
                    'error': 'rate_limit',
                    'message': error_msg
                }

            print(f"Command failed: bw {' '.join(args)}")
            print(f"Error: {error_msg}")
            return None

        # Some commands return raw text, others return JSON
        try:
            return json.loads(result.stdout) if result.stdout.strip() else None
        except json.JSONDecodeError:
            return {'output': result.stdout.strip()}

    def run_bw_command_with_retry(self, args: List[str], input_data: Optional[str] = None,
                                   encode: bool = False, max_retries: int = 5) -> Dict[str, Any]:
        """Run a Bitwarden CLI command with rate limit aware retry logic"""
        base_wait_time = 10  # Start with 10 seconds for rate limits

        for attempt in range(max_retries):
            result = self.run_bw_command(args, input_data, encode)

            # Success
            if result and result.get('error') != 'rate_limit':
                return result

            # Rate limit hit
            if result and result.get('error') == 'rate_limit':
                if attempt < max_retries - 1:
                    # Exponential backoff: 10s, 20s, 40s, 80s, 160s
                    wait_time = base_wait_time * (2 ** attempt)
                    print(f"  ⚠️  Rate limit hit. Waiting {wait_time}s before retry {attempt + 2}/{max_retries}...")
                    time.sleep(wait_time)
                    continue
                else:
                    print(f"  ✗ Rate limit exceeded after {max_retries} retries")
                    return None

            # Other failure
            if result is None:
                if attempt < max_retries - 1:
                    # Regular retry with shorter backoff
                    wait_time = 2 ** attempt
                    time.sleep(wait_time)
                    continue
                else:
                    return None

        return None

    def create_collection(self, shared_folder: Dict[str, Any], org_id: str) -> Dict[str, Any]:
        """Create a single collection"""
        folder_path = shared_folder['path']
        keeper_uid = shared_folder['uid']

        # Replace backslashes with forward slashes
        folder_path_normalized = folder_path.replace('\\', '/')

        collection = {
            "organizationId": org_id,
            "name": folder_path_normalized,
            "externalId": keeper_uid
        }

        result = self.run_bw_command_with_retry(
            ['create', 'org-collection', '--organizationid', org_id],
            input_data=json.dumps(collection),
            encode=True
        )

        # Return with original path for mapping purposes
        return {
            'success': result is not None and 'error' not in result,
            'path': folder_path,
            'path_normalized': folder_path_normalized,
            'id': result.get('id') if result else None
        }

    def migrate_shared_folders(self, parallel=False):
        """Create Bitwarden org-collections from Keeper shared folders"""
        mode = "Parallel" if parallel else "Sequential"
        print(f"\n=== Migrating Shared Folders to Org-Collections ({mode}) ===")

        # First get the organization ID
        orgs = self.run_bw_command(['list', 'organizations'])
        if not orgs or len(orgs) == 0:
            print("  ✗ No organization found. Collections require an organization.")
            print("  → Skipping org-collections. Items will be created in personal vault.")
            return

        org_id = orgs[0]['id']
        shared_folders = self.keeper_data.get('shared_folders', [])

        if not shared_folders:
            return

        # Wrap folders with org_id for processing
        folders_with_org = [(folder, org_id) for folder in shared_folders]

        if parallel:
            # Parallel execution
            print(f"Creating {len(shared_folders)} collections using {min(5, self.max_workers)} parallel workers")

            def callback(result):
                with self.lock:
                    self.shared_folder_map[result['path']] = result['id']

            success_count, _, _ = self._run_parallel(
                lambda item: self.create_collection(item[0], item[1]),
                folders_with_org,
                min(5, self.max_workers),
                "collection",
                callback
            )
            print(f"Successfully created {success_count}/{len(shared_folders)} collections")
        else:
            # Sequential execution
            for shared_folder in shared_folders:
                folder_path = shared_folder['path']
                print(f"Creating collection: {folder_path}")

                result = self.create_collection(shared_folder, org_id)

                if result['success']:
                    self.shared_folder_map[folder_path] = result['id']
                    if result['path_normalized'] != folder_path:
                        print(f"  ✓ Created collection: {result['path_normalized']} (ID: {result['id']})")
                    else:
                        print(f"  ✓ Created collection with ID: {result['id']}")
                else:
                    print(f"  ✗ Failed to create collection for: {folder_path}")

    def create_folder(self, folder_path: str) -> Dict[str, Any]:
        """Create a single folder"""
        # Replace backslashes with forward slashes
        folder_path_normalized = folder_path.replace('\\', '/')

        folder = {
            "name": folder_path_normalized
        }

        result = self.run_bw_command_with_retry(
            ['create', 'folder'],
            input_data=json.dumps(folder),
            encode=True
        )

        # Return with original path for mapping purposes
        return {
            'success': result is not None and 'error' not in result,
            'path': folder_path,
            'path_normalized': folder_path_normalized,
            'id': result.get('id') if result else None
        }

    def migrate_folders(self, parallel=False):
        """Create Bitwarden folders from Keeper folder definitions"""
        mode = "Parallel" if parallel else "Sequential"
        print(f"\n=== Migrating Folders ({mode}) ===")

        # Collect all unique folder paths from records
        folder_paths = set()
        for record in self.keeper_data.get('records', []):
            folders = record.get('folders', [])
            for folder_def in folders:
                folder_path = folder_def.get('folder')
                if folder_path:
                    folder_paths.add(folder_path)

        folder_list = sorted(folder_paths)

        if not folder_list:
            print("No folders to migrate.")
            return

        if parallel:
            # Parallel execution
            # Note: Bitwarden folders are flat (no parent-child dependencies)
            # Nesting is just represented in the folder name, so we can create in parallel
            print(f"Creating {len(folder_list)} folders using {min(5, self.max_workers)} parallel workers")

            def callback(result):
                with self.lock:
                    self.folder_map[result['path']] = result['id']

            success_count, _, _ = self._run_parallel(
                self.create_folder,
                folder_list,
                min(5, self.max_workers),
                "folder",
                callback
            )
            print(f"Successfully created {success_count}/{len(folder_list)} folders")
        else:
            # Sequential execution
            for folder_path in folder_list:
                print(f"Creating folder: {folder_path}")

                result = self.create_folder(folder_path)

                if result['success']:
                    self.folder_map[folder_path] = result['id']
                    if result['path_normalized'] != folder_path:
                        print(f"  ✓ Created folder: {result['path_normalized']} (ID: {result['id']})")
                    else:
                        print(f"  ✓ Created folder with ID: {result['id']}")
                else:
                    print(f"  ✗ Failed to create folder: {folder_path}")

    def map_keeper_type_to_bitwarden(self, keeper_type: str) -> int:
        """
        Map Keeper item types to Bitwarden types.
        Bitwarden types: 1=login, 2=note, 3=card, 4=identity, 5=sshKey
        """
        type_mapping = {
            'login': 1,
            'encryptedNotes': 2,
            'bankCard': 3,
            'address': 4,
            'contact': 4,
            'sshKeys': 5,  # SSH keys have their own type
            'Insurance Card': 2,  # Custom types as secure notes
        }
        return type_mapping.get(keeper_type, 2)  # Default to Secure Note

    def extract_totp_secret(self, otp_uri: str) -> Optional[str]:
        """
        Extract TOTP secret from otpauth:// URI or return raw secret.
        Bitwarden accepts both otpauth:// URIs and raw secrets.
        """
        if not otp_uri:
            return None

        # If it's an otpauth:// URI, extract the secret parameter
        if otp_uri.startswith('otpauth://'):
            import urllib.parse
            parsed = urllib.parse.urlparse(otp_uri)
            params = urllib.parse.parse_qs(parsed.query)
            secret = params.get('secret', [None])[0]
            return secret if secret else None

        # Otherwise, assume it's a raw TOTP secret
        return otp_uri.strip()

    def calculate_ssh_fingerprint(self, public_key: str) -> Optional[str]:
        """
        Calculate SHA256 fingerprint for an SSH public key.
        Returns fingerprint in the format: SHA256:base64_string
        """
        import hashlib
        import base64

        if not public_key:
            return None

        try:
            # Split the public key and extract the base64 part
            parts = public_key.strip().split()
            if len(parts) < 2:
                return None

            # Decode the base64 key data
            key_data = base64.b64decode(parts[1])

            # Calculate SHA256 hash
            fingerprint = hashlib.sha256(key_data).digest()

            # Convert to base64 format (Bitwarden's format, without padding)
            fingerprint_b64 = base64.b64encode(fingerprint).decode().rstrip('=')

            return f'SHA256:{fingerprint_b64}'
        except Exception as e:
            print(f"  ⚠️  Failed to calculate SSH fingerprint: {e}")
            return None

    def create_bitwarden_item(self, record: Dict[str, Any]) -> Optional[str]:
        """Create a Bitwarden item from a Keeper record"""
        keeper_type = record.get('$type', 'login')
        bw_type = self.map_keeper_type_to_bitwarden(keeper_type)

        # Base item structure
        item = {
            "organizationId": None,
            "collectionIds": [],
            "folderId": None,
            "type": bw_type,
            "name": record.get('title', 'Untitled'),
            "notes": record.get('notes', ''),
            "favorite": False,
            "fields": [],
            "login": None,
            "secureNote": None,
            "card": None,
            "identity": None,
            "sshKey": None,
            "reprompt": 0
        }

        # Handle folders and collections
        folders = record.get('folders', [])
        for folder_def in folders:
            # Check for shared folder (collection)
            shared_folder = folder_def.get('shared_folder')
            if shared_folder and shared_folder in self.shared_folder_map:
                collection_id = self.shared_folder_map[shared_folder]
                item['collectionIds'].append(collection_id)
                # Get org ID from first collection
                if not item['organizationId']:
                    orgs = self.run_bw_command(['list', 'organizations'])
                    if orgs and len(orgs) > 0:
                        item['organizationId'] = orgs[0]['id']

            # Check for personal folder
            folder_path = folder_def.get('folder')
            if folder_path and folder_path in self.folder_map:
                item['folderId'] = self.folder_map[folder_path]

        # Type-specific handling
        if keeper_type == 'login' or bw_type == 1:
            item['login'] = {
                "username": record.get('login', ''),
                "password": record.get('password', ''),
                "totp": None,
                "uris": []
            }

            # Add URI if present
            login_url = record.get('login_url', '')
            if login_url:
                item['login']['uris'] = [{
                    "match": None,
                    "uri": login_url
                }]

            # Handle TOTP ($oneTimeCode)
            custom_fields = record.get('custom_fields', {})
            otp_code = custom_fields.get('$oneTimeCode')
            if otp_code:
                # Handle both string and array
                if isinstance(otp_code, list):
                    otp_code = otp_code[0]  # Take first one

                totp_secret = self.extract_totp_secret(otp_code)
                if totp_secret:
                    item['login']['totp'] = totp_secret

        elif keeper_type == 'sshKeys':
            # SSH keys - use dedicated sshKey type
            custom_fields = record.get('custom_fields', {})
            key_pair = custom_fields.get('$keyPair', {})

            private_key = key_pair.get('privateKey', '')
            public_key = key_pair.get('publicKey', '')

            # Only create SSH key if we have actual key data
            if private_key and public_key:
                # Calculate the SSH key fingerprint
                fingerprint = self.calculate_ssh_fingerprint(public_key)

                item['sshKey'] = {
                    "privateKey": private_key,
                    "publicKey": public_key,
                    "keyFingerprint": fingerprint
                }
            else:
                # No SSH key data - convert to secure note instead
                item['type'] = 2
                item['secureNote'] = {"type": 0}

        elif keeper_type == 'bankCard':
            # Credit card
            custom_fields = record.get('custom_fields', {})
            payment_card = custom_fields.get('$paymentCard', {})

            item['card'] = {
                "cardholderName": custom_fields.get('$text:cardholderName', ''),
                "number": payment_card.get('cardNumber', ''),
                "brand": None,
                "expMonth": None,
                "expYear": None,
                "code": payment_card.get('cardSecurityCode', '')
            }

            # Parse expiration date (format: MM/YYYY)
            exp_date = payment_card.get('cardExpirationDate', '')
            if '/' in exp_date:
                parts = exp_date.split('/')
                if len(parts) == 2:
                    item['card']['expMonth'] = parts[0]
                    item['card']['expYear'] = parts[1]

        elif keeper_type in ['address', 'contact']:
            # Identity
            custom_fields = record.get('custom_fields', {})
            address = custom_fields.get('$address', {})
            name = custom_fields.get('$name', {})

            item['identity'] = {
                "title": None,
                "firstName": name.get('first', ''),
                "middleName": None,
                "lastName": name.get('last', ''),
                "address1": address.get('street1', ''),
                "address2": None,
                "city": address.get('city', ''),
                "state": address.get('state', ''),
                "postalCode": address.get('zip', ''),
                "country": address.get('country', ''),
                "company": custom_fields.get('$text:company', ''),
                "email": custom_fields.get('$email', ''),
                "phone": custom_fields.get('$phone', {}).get('number', ''),
                "ssn": None,
                "username": None,
                "passportNumber": None,
                "licenseNumber": None
            }

        else:
            # Everything else as secure note
            item['secureNote'] = {"type": 0}

        # Handle custom fields (other than special types already processed)
        custom_fields = record.get('custom_fields', {})
        has_passkey = False

        for key, value in custom_fields.items():
            # Handle passkeys - add warning note and track for report
            if key == '$passkey':
                has_passkey = True
                if item['notes']:
                    item['notes'] += "\n\n"
                item['notes'] += "⚠️ PASSKEY WAS NOT TRANSFERRED\n"
                item['notes'] += "Passkeys cannot be migrated between password managers.\n"
                item['notes'] += "You will need to re-enroll this passkey in Bitwarden."
                continue

            # Skip already processed fields
            if key in ['$oneTimeCode', '$keyPair', '$paymentCard', '$address', '$name', '$email', '$phone', '$note']:
                continue

            # Extract field name and type from key (format: $type:name)
            field_name = key
            field_type = 0  # text

            if ':' in key:
                parts = key.split(':', 1)
                field_name = parts[1]
                if 'pinCode' in parts[0]:
                    field_type = 1  # hidden

            item['fields'].append({
                "name": field_name,
                "value": str(value),
                "type": field_type
            })

        # Create the item with retry logic
        result = self.run_bw_command_with_retry(
            ['create', 'item'],
            input_data=json.dumps(item),
            encode=True
        )

        if result and 'error' not in result:
            item_id = result.get('id')

            # Track items with passkeys for report (store raw Keeper record)
            if has_passkey:
                self.passkey_items.append(record)

            return item_id
        return None

    def create_bitwarden_item_with_retry(self, record: Dict[str, Any]) -> Optional[str]:
        """Create a Bitwarden item with rate limit aware retry logic"""
        # This method now just wraps create_bitwarden_item
        # The retry logic is handled by run_bw_command_with_retry
        return self.create_bitwarden_item(record)

    def _create_item_wrapper(self, record: Dict[str, Any]) -> Dict[str, Any]:
        """Wrapper for create_bitwarden_item that returns a result dict"""
        title = record.get('title', 'Untitled')
        item_id = self.create_bitwarden_item_with_retry(record)

        return {
            'success': item_id is not None,
            'name': title,
            'item_id': item_id,
            'record': record
        }

    def migrate_records(self, parallel=False):
        """Migrate all Keeper records to Bitwarden items"""
        mode = "Parallel" if parallel else "Sequential"
        print(f"\n=== Migrating Records ({mode}) ===")

        records = self.keeper_data.get('records', [])
        total = len(records)

        if parallel:
            # Parallel execution
            print(f"Using {self.max_workers} parallel workers")

            def callback(result):
                # Check for attachments
                attachments = result['record'].get('attachments', [])
                if attachments:
                    with self.lock:
                        self.item_attachments.append({
                            'item_id': result['item_id'],
                            'item_title': result['name'],
                            'attachments': attachments
                        })

            success_count, failed_items, _ = self._run_parallel(
                self._create_item_wrapper,
                records,
                self.max_workers,
                "item",
                callback
            )

            print(f"\nSuccessfully migrated {success_count}/{total} records")
            if failed_items:
                print(f"Failed items: {len(failed_items)}")
                for record in failed_items[:10]:
                    print(f"  - {record.get('title', 'Untitled')}")
                if len(failed_items) > 10:
                    print(f"  ... and {len(failed_items) - 10} more")
        else:
            # Sequential execution
            success_count = 0

            for idx, record in enumerate(records, 1):
                title = record.get('title', 'Untitled')
                print(f"[{idx}/{total}] Migrating: {title}")

                item_id = self.create_bitwarden_item(record)

                if item_id:
                    print(f"  ✓ Created item with ID: {item_id}")
                    success_count += 1

                    # Check for attachments
                    attachments = record.get('attachments', [])
                    if attachments:
                        self.item_attachments.append({
                            'item_id': item_id,
                            'item_title': title,
                            'attachments': attachments
                        })
                else:
                    print(f"  ✗ Failed to create item: {title}")

            print(f"\nSuccessfully migrated {success_count}/{total} records")

    def upload_attachment(self, item_data: Dict[str, Any], attachment: Dict[str, Any]) -> Dict[str, Any]:
        """Upload a single attachment and return result"""
        item_id = item_data['item_id']
        item_title = item_data['item_title']
        file_uid = attachment['file_uid']
        file_name = attachment['name']

        # Look for the file in attachments directory
        possible_paths = [
            self.attachments_dir / file_uid,
            self.attachments_dir / 'files' / file_uid,
        ]

        file_path = None
        for path in possible_paths:
            if path.exists():
                file_path = path
                break

        if not file_path:
            return {
                'success': False,
                'item_title': item_title,
                'file_name': file_name,
                'error': 'File not found'
            }

        # Upload with rate limit aware retry
        result = self.run_bw_command_with_retry(
            ['create', 'attachment', '--itemid', item_id, '--file', str(file_path)]
        )

        if result and 'error' not in result:
            return {
                'success': True,
                'item_title': item_title,
                'file_name': file_name
            }

        return {
            'success': False,
            'item_title': item_title,
            'file_name': file_name,
            'error': 'Upload failed'
        }

    def migrate_attachments(self, parallel=False):
        """Upload attachments to Bitwarden items"""
        mode = "Parallel" if parallel else "Sequential"
        print(f"\n=== Migrating Attachments ({mode}) ===")

        if not self.item_attachments:
            print("No attachments to migrate.")
            return

        if parallel:
            # Parallel execution
            # Build list of all attachments to upload
            upload_tasks = []
            for item_data in self.item_attachments:
                for attachment in item_data['attachments']:
                    upload_tasks.append((item_data, attachment))

            total_attachments = len(upload_tasks)
            print(f"Uploading {total_attachments} attachments using {min(5, self.max_workers)} parallel workers")

            # Use _run_parallel with a lambda wrapper
            success_count, failed_uploads, _ = self._run_parallel(
                lambda task: self.upload_attachment(task[0], task[1]),
                upload_tasks,
                min(5, self.max_workers),
                "attachment"
            )

            print(f"\nSuccessfully uploaded {success_count}/{total_attachments} attachments")
            if failed_uploads:
                print(f"Failed uploads: {len(failed_uploads)}")
        else:
            # Sequential execution
            for item_data in self.item_attachments:
                item_id = item_data['item_id']
                item_title = item_data['item_title']
                attachments = item_data['attachments']

                print(f"\nProcessing attachments for: {item_title}")

                for attachment in attachments:
                    file_uid = attachment['file_uid']
                    file_name = attachment['name']

                    # Look for the file in attachments directory
                    possible_paths = [
                        self.attachments_dir / file_uid,
                        self.attachments_dir / 'files' / file_uid,
                    ]

                    file_path = None
                    for path in possible_paths:
                        if path.exists():
                            file_path = path
                            break

                    if not file_path:
                        print(f"  ✗ File not found: {file_name} ({file_uid})")
                        print(f"     Searched in: {', '.join(str(p) for p in possible_paths)}")
                        continue

                    print(f"  Uploading: {file_name}")

                    result = self.run_bw_command(
                        ['create', 'attachment', '--itemid', item_id, '--file', str(file_path)]
                    )

                    if result:
                        print(f"    ✓ Uploaded successfully")
                    else:
                        print(f"    ✗ Failed to upload")

    def write_passkey_report(self):
        """Write a JSON report of items with passkeys"""
        if not self.passkey_items:
            return

        report_path = self.keeper_export_path.parent / "passkey_items_report.json"

        # Write raw Keeper records to file
        with open(report_path, 'w', encoding='utf-8') as f:
            json.dump(self.passkey_items, f, indent=2, ensure_ascii=False)

        print(f"\n⚠️  Passkey Report:")
        print(f"   {len(self.passkey_items)} items had passkeys that were not transferred")
        print(f"   Report saved to: {report_path}")
        print(f"   These items have been marked with a warning note in Bitwarden")

    def migrate(self, use_parallel: bool = True):
        """Run the complete migration"""
        mode = "Parallel" if use_parallel else "Sequential"
        print("=" * 60)
        print(f"Keeper to Bitwarden Migration ({mode})")
        print("=" * 60)

        # Run all migration phases
        self.migrate_shared_folders(parallel=use_parallel)
        self.migrate_folders(parallel=use_parallel)
        self.migrate_records(parallel=use_parallel)
        self.migrate_attachments(parallel=use_parallel)

        # Write passkey report if any items had passkeys
        if self.passkey_items:
            self.write_passkey_report()

        print("\n" + "=" * 60)
        print("Migration Complete!")
        print("=" * 60)
        print(f"Shared folders mapped: {len(self.shared_folder_map)}")
        print(f"Folders created: {len(self.folder_map)}")
        print(f"Items with attachments: {len(self.item_attachments)}")
        if self.passkey_items:
            print(f"Items with passkeys (not transferred): {len(self.passkey_items)}")

    def cleanup(self):
        """Clean up sensitive data from memory and lock vault"""
        print("\n=== Cleaning Up ===")

        # Lock the Bitwarden vault
        try:
            result = subprocess.run(
                ['bw', 'lock'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print("✓ Bitwarden vault locked")
            else:
                print("⚠️  Could not lock vault (it may already be locked)")
        except Exception as e:
            print(f"⚠️  Could not lock vault: {e}")

        # Clear session key from memory
        if hasattr(self, 'session_key'):
            self.session_key = None
            print("✓ Session key cleared from memory")


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Migrate Keeper password manager export to Bitwarden',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Parallel migration (default, 5 workers)
  python3 keeper_to_bitwarden.py export.json

  # Sequential migration (slower, but uses less memory)
  python3 keeper_to_bitwarden.py export.json --sequential

  # Increase workers if no rate limits (faster but may hit limits)
  python3 keeper_to_bitwarden.py export.json --workers 10

  # Custom attachments directory
  python3 keeper_to_bitwarden.py export.json --attachments-dir ./files
        """
    )
    parser.add_argument(
        'export_file',
        help='Path to Keeper JSON export file'
    )
    parser.add_argument(
        '--attachments-dir',
        default='./attachments',
        help='Path to directory containing attachment files (default: ./attachments)'
    )
    parser.add_argument(
        '--workers',
        type=int,
        default=5,
        help='Number of parallel workers for migration (default: 5, increase if no rate limits)'
    )
    parser.add_argument(
        '--sequential',
        action='store_true',
        help='Use sequential processing instead of parallel (slower but uses less resources)'
    )

    args = parser.parse_args()

    # Authenticate with Bitwarden
    print("Authenticating with Bitwarden...")
    auth = BitwardenAuth()
    session_key = auth.authenticate()

    # Run migration
    migration = KeeperToBitwardenMigration(
        keeper_export_path=args.export_file,
        attachments_dir=args.attachments_dir,
        session_key=session_key,
        max_workers=args.workers
    )

    try:
        migration.migrate(use_parallel=not args.sequential)
    finally:
        # Always clean up sensitive data
        migration.cleanup()


if __name__ == '__main__':
    main()
