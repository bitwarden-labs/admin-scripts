#!/usr/bin/env python3
"""
Delinea (Thycotic) Secret Server to Bitwarden Migration Script

This script converts a Delinea Secret Server XML export to Bitwarden JSON and imports it
directly using the Bitwarden CLI.

Usage:
    # Direct import (recommended)
    python3 delinea_to_bitwarden.py secrets-export.xml

    # Export to JSON only (no import)
    python3 delinea_to_bitwarden.py secrets-export.xml --export-only -o output.json
"""

import argparse
import base64
import getpass
import hashlib
import json
import subprocess
import sys
import tempfile
import uuid
import xml.sax
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, List, Any


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


class DelineaXMLHandler(xml.sax.handler.ContentHandler):
    """SAX handler for parsing Delinea Secret Server XML exports"""

    def __init__(self):
        super().__init__()
        self.stack = []
        self.templates = {}  # Template definitions
        self.secrets = []    # All secrets/items
        self.folders = []    # Folder structure

        # Current parsing context
        self.template = None
        self.secret = None
        self.folder = None

    def startElement(self, name, attrs):
        """Handle opening XML tags"""
        if len(self.stack) == 0 and name != 'ImportFile':
            raise Exception('Invalid Delinea Secret Server XML Export File')

        # Template definition
        if len(self.stack) == 2 and self.stack[1] == 'SecretTemplates':
            if name == 'secrettype':
                self.template = {'name': '', 'fields': {}, 'field': None}

        # Secret (item)
        elif len(self.stack) == 2 and self.stack[1] == 'Secrets':
            if name == 'Secret':
                self.secret = {
                    'name': '', 'template': '', 'folder': '',
                    'totp_code': '', 'items': {}, 'item': None
                }

        # Folder
        elif len(self.stack) == 2 and self.stack[1] == 'Folders':
            if name == 'Folder':
                self.folder = {
                    'name': '', 'path': '', 'permissions': [],
                    'permission': None, 'shared': False
                }

        # Template field
        elif len(self.stack) == 4 and name == 'field':
            if self.stack[1] == 'SecretTemplates' and self.template:
                self.template['field'] = {
                    'field_name': '', 'slug': '', 'slug_type': ''
                }

        # Secret item (field value)
        elif len(self.stack) == 4 and name == 'SecretItem':
            if self.stack[1] == 'Secrets' and self.secret:
                self.secret['item'] = {
                    'field_name': '', 'slug': '', 'value': ''
                }

        # Folder permission
        elif len(self.stack) == 4 and name == 'Permission':
            if self.stack[1] == 'Folders' and self.folder:
                self.folder['permission'] = {
                    'group_name': '', 'user_name': '',
                    'secret_role': '', 'folder_role': ''
                }

        self.stack.append(name)

    def endElement(self, name):
        """Handle closing XML tags"""
        self.stack.pop(-1)

        if len(self.stack) == 2:
            # Save completed template
            if self.stack[1] == 'SecretTemplates' and name == 'secrettype':
                if self.template:
                    key = self.template.get('name')
                    if key:
                        self.templates[key] = self.template
                    self.template = None

            # Save completed secret
            elif self.stack[1] == 'Secrets' and name == 'Secret':
                if self.secret:
                    self.secrets.append(self.secret)
                    self.secret = None

            # Save completed folder
            elif self.stack[1] == 'Folders' and name == 'Folder':
                if self.folder:
                    self.folders.append(self.folder)
                    self.folder = None

        elif len(self.stack) == 4:
            # Save template field
            if name == 'field' and self.stack[1] == 'SecretTemplates':
                if self.template and isinstance(self.template['field'], dict):
                    key = self.template['field'].get('slug') or self.template['field'].get('field_name')
                    if key:
                        self.template['fields'][key] = self.template['field']
                    self.template['field'] = None

            # Save secret item
            elif name == 'SecretItem' and self.stack[1] == 'Secrets':
                if self.secret and isinstance(self.secret['item'], dict):
                    key = self.secret['item'].get('slug') or self.secret['item'].get('field_name')
                    value = self.secret['item'].get('value')
                    if key:
                        self.secret['items'][key] = self.secret['item']
                    self.secret['item'] = None

            # Save folder permission
            elif name == 'Permission' and self.stack[1] == 'Folders':
                if self.folder and isinstance(self.folder['permission'], dict):
                    self.folder['permissions'].append(self.folder['permission'])
                    self.folder['permission'] = None

    def characters(self, content):
        """Handle text content within XML tags"""
        if len(self.stack) < 4 or not content:
            return

        # Template content
        if self.stack[1] == 'SecretTemplates' and self.template:
            if len(self.stack) == 4 and self.stack[3] == 'name':
                self.template['name'] += content
            elif self.stack[3] == 'fields' and isinstance(self.template['field'], dict):
                if len(self.stack) == 6 and self.stack[4] == 'field':
                    if self.stack[5] == 'fieldslugname':
                        self.template['field']['slug'] += content
                    elif self.stack[5] == 'name':
                        self.template['field']['field_name'] += content
                    elif content == 'true':
                        if self.stack[5] in ('isurl', 'ispassword', 'isnotes', 'isfile'):
                            self.template['field']['slug_type'] = self.stack[5]

        # Secret content
        elif self.stack[1] == 'Secrets' and self.secret:
            if len(self.stack) == 4:
                if self.stack[3] == 'SecretName':
                    self.secret['name'] += content
                elif self.stack[3] == 'SecretTemplateName':
                    self.secret['template'] += content
                elif self.stack[3] == 'FolderPath':
                    self.secret['folder'] += content
                elif self.stack[3] == 'TotpKey':
                    self.secret['totp_code'] += content
            elif len(self.stack) == 6 and isinstance(self.secret['item'], dict):
                if self.stack[5] == 'FieldName':
                    self.secret['item']['field_name'] += content
                elif self.stack[5] == 'Slug':
                    self.secret['item']['slug'] += content
                elif self.stack[5] == 'Value':
                    self.secret['item']['value'] += content

        # Folder content
        elif self.stack[1] == 'Folders' and self.folder:
            if len(self.stack) == 4:
                if self.stack[3] == 'FolderName':
                    self.folder['name'] += content
                elif self.stack[3] == 'FolderPath':
                    self.folder['path'] += content
            elif len(self.stack) == 6 and isinstance(self.folder['permission'], dict):
                if self.stack[5] == 'GroupName':
                    self.folder['permission']['group_name'] += content
                elif self.stack[5] == 'UserName':
                    self.folder['permission']['user_name'] += content
                elif self.stack[5] == 'SecretAccessRoleName':
                    self.folder['permission']['secret_role'] += content
                elif self.stack[5] == 'FolderAccessRoleName':
                    self.folder['permission']['folder_role'] += content


class DelineaToBitwardenConverter:
    """Converts Delinea Secret Server data to Bitwarden JSON format"""

    PERSONAL_FOLDER_PREFIX = '\\Personal Folders'

    def __init__(self, xml_path: str):
        self.xml_path = xml_path
        self.handler = DelineaXMLHandler()
        self.folder_map = {}  # Maps folder path to folder ID

    def parse_xml(self):
        """Parse the XML export file"""
        print(f"Parsing XML export: {self.xml_path}")
        try:
            xml.sax.parse(self.xml_path, self.handler)
        except xml.sax.SAXParseException as e:
            print(f"\n❌ XML Parsing Error:")
            print(f"   File: {self.xml_path}")
            print(f"   Line: {e.getLineNumber()}, Column: {e.getColumnNumber()}")
            print(f"   Error: {e.getMessage()}")
            print(f"\nThe XML export from Delinea Secret Server is malformed.")
            print(f"This could be due to:")
            print(f"  1. Special characters in secret fields that weren't properly escaped")
            print(f"  2. Incomplete or corrupted export")
            print(f"  3. Unsupported characters in secret names or values")
            print(f"\nTroubleshooting steps:")
            print(f"  1. Check line {e.getLineNumber()} in the XML file for issues")
            print(f"  2. Try re-exporting from Delinea Secret Server")
            print(f"  3. Check if any secrets have unusual characters (e.g., <, >, &, unescaped quotes)")
            print(f"  4. Try exporting a smaller subset of secrets to isolate the problem")
            sys.exit(1)
        except Exception as e:
            print(f"\n❌ Unexpected error while parsing XML:")
            print(f"   {type(e).__name__}: {e}")
            sys.exit(1)

        print(f"  Found {len(self.handler.secrets)} secrets")
        print(f"  Found {len(self.handler.folders)} folders")
        print(f"  Found {len(self.handler.templates)} templates")

    def trim_personal_folder(self, folder_path: str) -> str:
        """Remove the Personal Folders prefix from paths and convert backslashes to forward slashes"""
        if folder_path.startswith(self.PERSONAL_FOLDER_PREFIX):
            folder_path = folder_path[len(self.PERSONAL_FOLDER_PREFIX):]
        # Convert backslashes to forward slashes for Bitwarden compatibility
        folder_path = folder_path.replace('\\', '/')
        return folder_path.lstrip('/')

    def normalize_folders(self):
        """Normalize folder paths and remove personal folder prefix"""
        for folder in self.handler.folders:
            folder['path'] = self.trim_personal_folder(folder['path'])

        for secret in self.handler.secrets:
            secret['folder'] = self.trim_personal_folder(secret['folder'])

        # Remove empty root folder
        self.handler.folders = [f for f in self.handler.folders if f['path']]

    def detect_item_type(self, secret: Dict, items: Dict) -> int:
        """
        Detect Bitwarden item type based on template and fields.
        Returns: 1=login, 2=note, 3=card, 4=identity, 5=sshKey

        Type Mappings:
        - SSH Keys (type 5): Items with private-key/public-key fields
        - Cards (type 3): Credit Card template OR card-number field
        - Identities (type 4): Contact template OR address/name fields OR SSN fields
        - Logins (type 1): Database/Server credentials (host/server fields) OR username/password/url
        - Secure Notes (type 2): Pin, Security Alarm Code templates OR default fallback

        Custom fields are created for any remaining unmapped fields.
        """
        template_name = secret.get('template', '')

        # Template-based detection
        if template_name in ('Pin', 'Security Alarm Code'):
            return 2  # Secure Note
        elif template_name == 'Contact':
            return 4  # Identity
        elif template_name == 'Credit Card':
            return 3  # Card

        # Field-based detection
        # SSH Keys - check for private-key/public-key fields
        if 'private-key' in items or 'public-key' in items:
            return 5  # SSH Key
        # Credit Card
        elif 'card-number' in items:
            return 3  # Card
        # SSN Card -> Identity (has SSN field in identity type)
        elif 'ssn' in items or 'social-security-number' in items:
            return 4  # Identity
        # Database/Server credentials -> Login (has username/password)
        elif any(x in items for x in ('host', 'server', 'database', 'machine', 'ip-address---host-name')):
            return 1  # Login (treat as login item)
        # Identity - has name or address fields
        elif any(x in items for x in ('address1', 'last-name', 'first-name')):
            return 4  # Identity
        # Login - has username/password/url
        elif any(x in items for x in ('username', 'password', 'url', 'website')):
            return 1  # Login
        else:
            return 2  # Default to Secure Note

    def pop_field(self, items: Dict, key: str) -> tuple:
        """Remove and return a field from items dict"""
        field = items.pop(key, None)
        value = field.get('value', '') if isinstance(field, dict) else ''
        return str(value), field

    def pop_field_value(self, items: Dict, key: str) -> str:
        """Remove and return just the value from items dict"""
        return self.pop_field(items, key)[0]

    def parse_card_expiration(self, exp_date: str) -> tuple:
        """Parse card expiration date into (month, year)"""
        if not exp_date or len(exp_date) < 4:
            return None, None

        month, sep, year = exp_date.partition('/')
        if not sep:
            month = exp_date[:2]
            year = exp_date[2:]

        # Normalize month
        if len(month) == 1:
            month = '0' + month
        elif len(month) != 2:
            month = None

        # Normalize year
        if len(year) == 2:
            year = '20' + year
        elif len(year) != 4:
            year = None

        return month, year

    def calculate_ssh_fingerprint(self, public_key: str) -> Optional[str]:
        """
        Calculate SHA256 fingerprint for an SSH public key.
        Returns fingerprint in the format: SHA256:base64_string
        """
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
            print(f"  Warning: Failed to calculate SSH fingerprint: {e}")
            return None

    def convert_secret_to_bitwarden_item(self, secret: Dict) -> Dict:
        """Convert a Delinea secret to a Bitwarden item"""
        items = secret['items'].copy()  # Make a copy so we can pop fields

        # Detect item type
        item_type = self.detect_item_type(secret, items)

        # Base item structure
        item = {
            "id": str(uuid.uuid4()),
            "organizationId": None,
            "folderId": None,
            "type": item_type,
            "name": secret.get('name', 'Untitled'),
            "notes": self.pop_field_value(items, 'notes'),
            "favorite": False,
            "fields": [],
            "revisionDate": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            "creationDate": datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            "deletedDate": None
        }

        # Handle folder assignment
        folder_path = secret.get('folder', '')
        if folder_path and folder_path in self.folder_map:
            item['folderId'] = self.folder_map[folder_path]

        # Type-specific handling
        if item_type == 1:  # Login
            item['login'] = self.build_login(items, secret)
        elif item_type == 2:  # Secure Note
            item['secureNote'] = {"type": 0}
        elif item_type == 3:  # Card
            item['card'] = self.build_card(items)
        elif item_type == 4:  # Identity
            item['identity'] = self.build_identity(items)
        elif item_type == 5:  # SSH Key
            item['sshKey'] = self.build_ssh_key(items)

        # Add remaining fields as custom fields
        item['fields'] = self.build_custom_fields(items, secret)

        return item

    def build_login(self, items: Dict, secret: Dict) -> Dict:
        """Build login object for Bitwarden"""
        login = {
            "username": "",
            "password": "",
            "totp": None,
            "uris": []
        }

        # Extract username
        for username_field in ('username', 'client-id'):
            if username_field in items:
                login['username'] = self.pop_field_value(items, username_field)
                break

        # Extract password
        for password_field in ('password', 'client-secret'):
            if password_field in items:
                login['password'] = self.pop_field_value(items, password_field)
                break

        # Extract URL
        for url_field in ('url', 'website'):
            if url_field in items:
                url = self.pop_field_value(items, url_field)
                if url:
                    login['uris'].append({
                        "match": None,
                        "uri": url
                    })
                break

        # Extract host/server for database/server credentials
        # These get added as URIs to make them easily accessible
        for host_field in ('host', 'server', 'machine', 'ip-address---host-name'):
            if host_field in items:
                host = self.pop_field_value(items, host_field)
                if host:
                    # If it looks like a URL, use it as-is
                    # Otherwise, just store the hostname/IP
                    if '://' not in host:
                        host = f'ssh://{host}'  # Use ssh:// as a generic protocol
                    login['uris'].append({
                        "match": None,
                        "uri": host
                    })
                break

        # Extract TOTP
        totp_code = secret.get('totp_code', '')
        if totp_code:
            login['totp'] = f'otpauth://totp/?secret={totp_code}'

        return login

    def build_card(self, items: Dict) -> Dict:
        """Build card object for Bitwarden"""
        card = {
            "cardholderName": "",
            "brand": None,
            "number": "",
            "expMonth": None,
            "expYear": None,
            "code": ""
        }

        # Card number
        card['number'] = self.pop_field_value(items, 'card-number')

        # Cardholder name
        card['cardholderName'] = self.pop_field_value(items, 'full-name')

        # CVV/Security code
        card['code'] = self.pop_field_value(items, 'security-code')

        # Expiration date
        exp_date = self.pop_field_value(items, 'expiration-date')
        if exp_date:
            month, year = self.parse_card_expiration(exp_date)
            card['expMonth'] = month
            card['expYear'] = year

        # Card type/brand
        self.pop_field_value(items, 'card-type')  # Remove but don't use

        return card

    def build_identity(self, items: Dict) -> Dict:
        """Build identity object for Bitwarden"""
        identity = {
            "title": None,
            "firstName": "",
            "middleName": None,
            "lastName": "",
            "address1": "",
            "address2": None,
            "address3": None,
            "city": "",
            "state": "",
            "postalCode": "",
            "country": "",
            "company": "",
            "email": "",
            "phone": "",
            "ssn": None,
            "username": None,
            "passportNumber": None,
            "licenseNumber": None
        }

        # Name fields
        identity['firstName'] = self.pop_field_value(items, 'first-name')
        identity['lastName'] = self.pop_field_value(items, 'last-name')

        # Address fields (format 1: address1, address2, etc.)
        if 'address1' in items:
            identity['address1'] = self.pop_field_value(items, 'address1')
            a2 = self.pop_field_value(items, 'address2')
            a3 = self.pop_field_value(items, 'address3')
            if a3:
                a2 = (a2 + ' ' + a3).strip()
            identity['address2'] = a2 if a2 else None
            identity['city'] = self.pop_field_value(items, 'city')
            identity['state'] = self.pop_field_value(items, 'state')
            identity['postalCode'] = self.pop_field_value(items, 'zip')
            identity['country'] = self.pop_field_value(items, 'country')

        # Address fields (format 2: address-1, address-2, address-3)
        elif 'address-1' in items:
            identity['address1'] = self.pop_field_value(items, 'address-1')
            identity['address2'] = self.pop_field_value(items, 'address-2')
            addr3 = self.pop_field_value(items, 'address-3')
            if addr3:
                # address-3 might contain "City, State Zip"
                parts = addr3.split(',')
                if len(parts) >= 2:
                    identity['city'] = parts[0].strip()
                    state_zip = parts[1].strip()
                    # Try to split state and zip
                    state_parts = state_zip.rsplit(' ', 1)
                    if len(state_parts) == 2:
                        identity['state'] = state_parts[0]
                        identity['postalCode'] = state_parts[1]
                    else:
                        identity['state'] = state_zip

        # Contact fields
        identity['email'] = self.pop_field_value(items, 'email')

        # Phone (try multiple field names)
        for phone_field in ('contact-number', 'work-phone', 'home-phone', 'mobile-phone', 'phone'):
            if phone_field in items:
                identity['phone'] = self.pop_field_value(items, phone_field)
                break

        # SSN
        for ssn_field in ('ssn', 'social-security-number'):
            if ssn_field in items:
                identity['ssn'] = self.pop_field_value(items, ssn_field)
                break

        # Company
        identity['company'] = self.pop_field_value(items, 'company')

        return identity

    def build_ssh_key(self, items: Dict) -> Dict:
        """Build SSH key object for Bitwarden"""
        ssh_key = {
            "privateKey": "",
            "publicKey": "",
            "keyFingerprint": None
        }

        # Extract private key
        private_key = self.pop_field_value(items, 'private-key')
        ssh_key['privateKey'] = private_key

        # Extract public key
        public_key = self.pop_field_value(items, 'public-key')
        ssh_key['publicKey'] = public_key

        # Calculate fingerprint from public key
        if public_key:
            ssh_key['keyFingerprint'] = self.calculate_ssh_fingerprint(public_key)

        # Extract passphrase if present (will be added as custom field)
        # Note: Bitwarden doesn't have a dedicated passphrase field in sshKey,
        # so we'll leave it in items to be picked up as a custom field

        return ssh_key

    def build_custom_fields(self, items: Dict, secret: Dict) -> List[Dict]:
        """Build custom fields from remaining items"""
        fields = []
        template_name = secret.get('template', '')
        template = self.handler.templates.get(template_name, {})
        template_fields = template.get('fields', {})

        for slug, item in items.items():
            if not isinstance(item, dict):
                continue

            value = item.get('value', '')
            if not value:
                continue

            field_name = item.get('field_name', slug)

            # Determine field type based on template metadata
            field_type = 0  # Default to text
            template_field = template_fields.get(slug, {})
            slug_type = template_field.get('slug_type', '')

            if slug_type == 'ispassword':
                field_type = 1  # Hidden
            elif slug_type == 'isnotes':
                field_type = 0  # Text (can be multiline)

            fields.append({
                "name": field_name,
                "value": value,
                "type": field_type
            })

        return fields

    def build_folders(self) -> List[Dict]:
        """Build Bitwarden folders structure"""
        folders = []

        for folder in self.handler.folders:
            folder_path = folder['path']
            if not folder_path:
                continue

            folder_id = str(uuid.uuid4())
            self.folder_map[folder_path] = folder_id

            folders.append({
                "id": folder_id,
                "name": folder_path
            })

        return folders

    def convert(self) -> Dict:
        """Main conversion method"""
        print("\nStarting conversion...")

        # Parse XML
        self.parse_xml()

        # Normalize folder paths
        print("Normalizing folder paths...")
        self.normalize_folders()

        # Build folders
        print("Building folder structure...")
        folders = self.build_folders()

        # Convert secrets to items
        print("Converting secrets to Bitwarden items...")
        items = []
        for idx, secret in enumerate(self.handler.secrets, 1):
            try:
                item = self.convert_secret_to_bitwarden_item(secret)
                items.append(item)
            except Exception as e:
                print(f"  Warning: Failed to convert secret '{secret.get('name', 'Unknown')}': {e}")

        print(f"\nConversion complete!")
        print(f"  Total folders: {len(folders)}")
        print(f"  Total items: {len(items)}")

        return {
            "folders": folders,
            "items": items
        }

    def import_to_bitwarden(self, session_key: str) -> bool:
        """
        Convert and import directly to Bitwarden using CLI.
        Returns True if successful, False otherwise.
        """
        # Convert the data
        bitwarden_data = self.convert()

        # Write to temporary file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False, encoding='utf-8') as tmp_file:
            tmp_path = tmp_file.name
            json.dump(bitwarden_data, tmp_file, indent=2, ensure_ascii=False)

        try:
            # Verify vault is unlocked before importing
            print("\nVerifying vault status...")
            env = {**subprocess.os.environ, 'BW_SESSION': session_key}
            status_result = subprocess.run(
                ['bw', 'status'],
                capture_output=True,
                text=True,
                env=env
            )

            if status_result.returncode == 0:
                status = json.loads(status_result.stdout)
                if status['status'] != 'unlocked':
                    print(f"\n⚠️  Vault is {status['status']}, not unlocked!")
                    print(f"Please unlock your vault first, then retry the import.")
                    print(f"\nThe converted data has been saved to: {tmp_path}")
                    print(f"You can import manually with:")
                    print(f"  bw unlock")
                    print(f"  bw import bitwardenjson {tmp_path}")
                    return False
                print(f"Vault is unlocked ✓")

            print(f"\nImporting {len(bitwarden_data['items'])} items into Bitwarden...")

            # Run bw import command
            result = subprocess.run(
                ['bw', 'import', 'bitwardenjson', tmp_path],
                capture_output=True,
                text=True,
                env=env
            )

            if result.returncode != 0:
                print(f"\nImport failed: {result.stderr}")
                print(f"\nThe converted data has been saved to: {tmp_path}")
                print(f"You can try importing manually with:")
                print(f"  bw import bitwardenjson {tmp_path}")
                return False

            print("\nImport successful!")
            print(result.stdout)

            # Sync vault to ensure changes are reflected
            print("\nSyncing vault...")
            sync_result = subprocess.run(
                ['bw', 'sync'],
                capture_output=True,
                text=True,
                env=env
            )

            if sync_result.returncode == 0:
                print("Vault synced successfully ✓")
            else:
                print(f"Warning: Sync failed: {sync_result.stderr}")
                print("You may need to manually sync with: bw sync")

            # Clean up temp file on success
            try:
                Path(tmp_path).unlink()
            except:
                pass

            return True

        except Exception as e:
            print(f"\nError during import: {e}")
            print(f"The converted data has been saved to: {tmp_path}")
            return False


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Convert Delinea (Thycotic) Secret Server XML export to Bitwarden',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Direct import to Bitwarden (recommended)
  python3 delinea_to_bitwarden.py secrets-export.xml

  # Export to JSON file only (no import)
  python3 delinea_to_bitwarden.py secrets-export.xml --export-only -o bitwarden-import.json

Export Instructions:
  1. In Delinea Secret Server, go to Admin > See All > Import/Export
  2. Choose "Export Secrets"
  3. Select XML format
  4. Save the file (e.g., secrets-export.xml)
  5. Run this script to convert and import to Bitwarden
        """
    )

    parser.add_argument(
        'xml_file',
        help='Path to Delinea Secret Server XML export file'
    )
    parser.add_argument(
        '--export-only',
        action='store_true',
        help='Export to JSON file only without importing to Bitwarden'
    )
    parser.add_argument(
        '-o', '--output',
        default='bitwarden-import.json',
        help='Output JSON file path (default: bitwarden-import.json). Only used with --export-only'
    )
    parser.add_argument(
        '--compact',
        action='store_true',
        help='Output compact JSON (single line) instead of pretty-printed. Only used with --export-only'
    )

    args = parser.parse_args()

    # Create converter
    converter = DelineaToBitwardenConverter(args.xml_file)

    if args.export_only:
        # Export-only mode: just write JSON file
        print("\n=== Export Mode ===")
        bitwarden_data = converter.convert()

        # Write output (pretty-print by default)
        print(f"\nWriting output to: {args.output}")
        with open(args.output, 'w', encoding='utf-8') as f:
            if args.compact:
                json.dump(bitwarden_data, f, ensure_ascii=False)
            else:
                json.dump(bitwarden_data, f, indent=2, ensure_ascii=False)

        print(f"\nSuccess! Import into Bitwarden using:")
        print(f"  bw import bitwardenjson {args.output}")

    else:
        # Import mode: authenticate and import directly
        print("\n=== Import Mode ===")
        print("Authenticating with Bitwarden...")

        auth = BitwardenAuth()
        session_key = auth.authenticate()

        # Convert and import
        success = converter.import_to_bitwarden(session_key)

        if success:
            print("\n=== Migration Complete! ===")
        else:
            print("\n=== Migration Failed ===")
            sys.exit(1)


if __name__ == '__main__':
    main()