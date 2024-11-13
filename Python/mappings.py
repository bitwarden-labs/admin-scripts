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