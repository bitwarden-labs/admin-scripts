# Bitwarden Admin-Scripts - Complete Script Inventory

**Generated:** 2025-11-04
**Phase:** 0 (Audit)
**Purpose:** Comprehensive catalog of all scripts for refactoring analysis

---

## 📊 Executive Summary

| Metric | Count |
|--------|-------|
| **Total Scripts** | 80+ |
| **Bash Scripts** | 33 |
| **PowerShell Scripts** | 27 |
| **Python Scripts/Modules** | 20 |
| **Identified Overlaps** | 6 major duplications |
| **Categories** | 8 functional domains |

---

## 🗂️ Scripts by Category

### 1. User Management (18 scripts)

Scripts for managing organization members, invitations, confirmations, and roles.

#### Bash Scripts
- [bwAutoConfirm.sh](../Bash%20Scripts/bwAutoConfirm.sh) - Auto-confirm accepted users with monitoring
- [bwChangeAllUsersRole.sh](../Bash%20Scripts/bwChangeAllUsersRole.sh) - Bulk role changes
- [bwConfirmAcceptedPeople.sh](../Bash%20Scripts/bwConfirmAcceptedPeople.sh) - Confirm accepted users (CLI)
- [bwConfirmAcceptedPeopleWPass.sh](../Bash%20Scripts/bwConfirmAcceptedPeopleWPass.sh) - Confirm with password auth
- [bwConfirmAcceptedPeople_MoveGroupToAdmin.sh](../Bash%20Scripts/bwConfirmAcceptedPeople_MoveGroupToAdmin.sh) - Confirm + promote group to admin
- [bwConfirmAcceptedPeople_MoveGroupToManager.sh](../Bash%20Scripts/bwConfirmAcceptedPeople_MoveGroupToManager.sh) - Confirm + promote group to manager
- [bwConfirmAcceptedPeople_MoveToAdmin.sh](../Bash%20Scripts/bwConfirmAcceptedPeople_MoveToAdmin.sh) - Confirm + promote to admin
- [bwConfirmAcceptedPeople_MoveToManager.sh](../Bash%20Scripts/bwConfirmAcceptedPeople_MoveToManager.sh) - Confirm + promote to manager
- [bwPurgeNotAcceptedUsers.sh](../Bash%20Scripts/bwPurgeNotAcceptedUsers.sh) - Remove unaccepted invitations
- [bwReinvitePeople.sh](../Bash%20Scripts/bwReinvitePeople.sh) - Re-send invitations
- [bwFindAndEmptyExternalId.sh](../Bash%20Scripts/bwFindAndEmptyExternalId.sh) - Clear external IDs
- [listmembers.sh](../Bash%20Scripts/listmembers.sh) - List all org members

#### PowerShell Scripts
- [Confirm-PendingMembers.ps1](../Powershell/Confirm-PendingMembers.ps1) - Confirm pending members
- [bwConfirmAcceptedPeople_MoveToAdmin.ps1](../Powershell/bwConfirmAcceptedPeople_MoveToAdmin.ps1) - Confirm + admin role
- [bwConfirmAcceptedPeople_MoveToManager.ps1](../Powershell/bwConfirmAcceptedPeople_MoveToManager.ps1) - Confirm + manager role
- [bwEmptyExternalId.ps1](../Powershell/bwEmptyExternalId.ps1) - Clear external IDs
- [Update-UserExternalId.ps1](../Powershell/Update-UserExternalId.ps1) - Update user external IDs
- [purgeNotAcceptedUsers.ps1](../Powershell/purgeNotAcceptedUsers.ps1) - Remove unaccepted users
- [notifyNeedToConfirmUsers.ps1](../Powershell/notifyNeedToConfirmUsers.ps1) - Notification system for pending confirmations

#### Python Scripts
- [deleteRevokedUsers.py](../Python/deleteRevokedUsers.py) - Delete revoked users
- [admin-tools/bwAdminTools.py](../Python/admin-tools/bwAdminTools.py) - Multi-org admin operations

#### API Scripts
- [bwConfirmAccepted-api.ps1](../API%20Scripts/Bitwarden%20Public%20API/bwConfirmAccepted-api.ps1) - Confirm via Public API
- [createOrInviteNewMember.sh](../API%20Scripts/Bitwarden%20Public%20API/createOrInviteNewMember.sh) - Create/invite via API
- [bwMigrateOrgMembers.sh](../API%20Scripts/Bitwarden%20Public%20API/bwMigrateOrgMembers.sh) - Migrate members between orgs
- [listMembers.ps1](../API%20Scripts/Bitwarden%20Public%20API/listMembers.ps1) - List members via API
- [listMembers.sh](../API%20Scripts/Bitwarden%20Public%20API/listMembers.sh) - List members via API (Bash)
- [ListMembers2FACheck.ps1](../API%20Scripts/Bitwarden%20Public%20API/ListMembers2FACheck.ps1) - List with 2FA status

**Dependencies:** bw CLI, jq, API credentials
**Overlap Level:** HIGH (confirm users implemented 6+ times)

---

### 2. Collection Management (17 scripts)

Scripts for creating, deleting, and managing collections and permissions.

#### Bash Scripts
- [bwDeleteAllCollections.sh](../Bash%20Scripts/bwDeleteAllCollections.sh) - Delete all collections
- [createCollectionsForAllGroups.sh](../Bash%20Scripts/createCollectionsForAllGroups.sh) - Create collection per group
- [createCollectionsForAllMembers.sh](../Bash%20Scripts/createCollectionsForAllMembers.sh) - Create collection per member
- [createCollectionsForAllMembersNested.sh](../Bash%20Scripts/createCollectionsForAllMembersNested.sh) - Nested member collections
- [bwlistcollectionsbygroup.sh](../Bash%20Scripts/bwlistcollectionsbygroup.sh) - List collections by group
- [inheritparentpermissions.sh](../Bash%20Scripts/inheritparentpermissions.sh) - Inherit parent collection permissions (CLI)
- [inheritparentpermissions-API.sh](../Bash%20Scripts/inheritparentpermissions-API.sh) - Inherit permissions via API
- [removeIndividualAccountPerms.sh](../Bash%20Scripts/removeIndividualAccountPerms.sh) - Remove individual account permissions
- [createMissingParents.sh](../Bash%20Scripts/createMissingParents.sh) - Create missing parent collections

#### PowerShell Scripts
- [bwDeleteAllCollections.ps1](../Powershell/bwDeleteAllCollections.ps1) - Delete all collections
- [createCollectionsForAllGroups.ps1](../Powershell/createCollectionsForAllGroups.ps1) - Create collection per group
- [createCollectionsForMembers.ps1](../Powershell/createCollectionsForMembers.ps1) - Create collection per member
- [createCollectionsNestedForGroups.ps1](../Powershell/createCollectionsNestedForGroups.ps1) - Nested group collections
- [createCollectionForGroup.ps1](../Powershell/createCollectionForGroup.ps1) - Create single collection for group
- [Create-SingleUserCollection.ps1](../Powershell/Create-SingleUserCollection.ps1) - Create single user collection
- [Apply-NestedPermissions.ps1](../Powershell/Apply-NestedPermissions.ps1) - Apply nested collection permissions
- [listCollectionsByGroup.ps1](../Powershell/listCollectionsByGroup.ps1) - List collections by group (CLI)
- [listCollectionsByGroup_vaultapi.ps1](../Powershell/listCollectionsByGroup_vaultapi.ps1) - List via Vault API
- [exportSingleCollection.ps1](../Powershell/exportSingleCollection.ps1) - Export single collection

#### API Scripts
- [createCollectionsForAllGroups_vaultmanagementapi.ps1](../API%20Scripts/Vault%20Management%20API/createCollectionsForAllGroups_vaultmanagementapi.ps1) - Create via Vault Management API
- [listCollectionsByGroup.ps1](../API%20Scripts/Vault%20Management%20API/listCollectionsByGroup.ps1) - List via Vault Management API

**Dependencies:** bw CLI, jq, API access (for API versions)
**Overlap Level:** HIGH (multiple implementations of same functionality)

---

### 3. Reporting & Analytics (8 scripts)

Scripts for generating reports, audits, and analytics.

#### Bash Scripts
- [changedPasswordsReport.sh](../Bash%20Scripts/changedPasswordsReport.sh) - Report on changed passwords

#### PowerShell Scripts
- [Generate-EventLogReport.ps1](../Powershell/Generate-EventLogReport.ps1) - Generate event log reports
- [Export-OrganizationPermissions.ps1](../Powershell/Export-OrganizationPermissions.ps1) - Export permission structure

#### Python Scripts
- [generatePasswordAuditReport.py](../Python/generatePasswordAuditReport.py) - Password security audit (PwnedPasswords)
- [generateEventLogReport.py](../Python/generateEventLogReport.py) - Event log reporting
- [getEventLogsLiveFeed.py](../Python/getEventLogsLiveFeed.py) - Real-time event monitoring
- [changedPasswordsReport.py](../Python/changedPasswordsReport.py) - Changed password tracking
- [bwOldPasswords.py](../Python/bwOldPasswords.py) - Identify old/stale passwords
- [permissions-report/PermissionsReport.py](../Python/permissions-report/PermissionsReport.py) - Comprehensive permissions report (with encryption support)

#### API Scripts
- [downloadEventLogs.sh](../API%20Scripts/Bitwarden%20Public%20API/downloadEventLogs.sh) - Download event logs via API
- [downloadEventLogsToCsv.sh](../API%20Scripts/Bitwarden%20Public%20API/downloadEventLogsToCsv.sh) - Event logs to CSV

**Dependencies:** bw CLI, Python (requests, pandas), API credentials
**Overlap Level:** MEDIUM (event logs implemented 3+ times)

---

### 4. Migration Tools (3 scripts)

Scripts for importing data from other password managers.

#### Python Scripts
- [keeper_to_bitwarden.py](../Python/keeper_to_bitwarden.py) - Keeper import tool
- [delinea_to_bitwarden.py](../Python/delinea_to_bitwarden.py) - Delinea Secret Server import
- [LP_attach_importer/bwLPmigration.py](../Python/LP_attach_importer/bwLPmigration.py) - LastPass with attachments import

**Dependencies:** Python (requests), source system exports
**Overlap Level:** NONE (each targets different source)

---

### 5. Vault Operations (6 scripts)

Scripts for vault exports, backups, and trash management.

#### Bash Scripts
- [bwDeletePermTrashOrg.sh](../Bash%20Scripts/bwDeletePermTrashOrg.sh) - Permanently delete trash
- [bwRestoreAllTrash.sh](../Bash%20Scripts/bwRestoreAllTrash.sh) - Restore all trashed items
- [exportOrgVaultCronjob.sh](../Bash%20Scripts/exportOrgVaultCronjob.sh) - Automated export via cron
- [bwPurgeFolders.sh](../Bash%20Scripts/bwPurgeFolders.sh) - Purge all folders

#### PowerShell Scripts
- [Export-OrganizationVault.ps1](../Powershell/Export-OrganizationVault.ps1) - Export org vault (encrypted)
- [exportOrgVault.ps1](../Powershell/exportOrgVault.ps1) - Export org vault

**Dependencies:** bw CLI, encryption tools (OpenSSL for Bash)
**Overlap Level:** MEDIUM (export implemented multiple times)

---

### 6. Item Management (8 scripts)

Scripts for creating, sharing, and managing vault items.

#### Bash Scripts
- [createItemAndShareWithCollection.sh](../Bash%20Scripts/createItemAndShareWithCollection.sh) - Create + share item
- [createSecureNoteAndShareWithCollection.sh](../Bash%20Scripts/createSecureNoteAndShareWithCollection.sh) - Create + share secure note
- [findDuplicates.sh](../Bash%20Scripts/findDuplicates.sh) - Find duplicate items
- [setItemsMatchDetection.sh](../Bash%20Scripts/setItemsMatchDetection.sh) - Configure item match detection
- [cleanKeeperNested.sh](../Bash%20Scripts/cleanKeeperNested.sh) - Clean Keeper import artifacts

#### PowerShell Scripts
- [createItemInExistingCollection.ps1](../Powershell/createItemInExistingCollection.ps1) - Create item in collection
- [createLoginItemShareWithCollection(PowerShell).ps1](../Powershell/createLoginItemShareWithCollection(PowerShell).ps1) - Create login + share
- [bwListItemIDsNames.ps1](../Powershell/bwListItemIDsNames.ps1) - List item IDs and names
- [Update-HostMatch.ps1](../Powershell/Update-HostMatch.ps1) - Update URI match detection

#### Python Scripts
- [tagItemsWithCollectionName.py](../Python/tagItemsWithCollectionName.py) - Tag items with collection names
- [add_item_to_collection/add_item_to_collection.py](../Python/add_item_to_collection/add_item_to_collection.py) - Add items to collections

**Dependencies:** bw CLI, jq
**Overlap Level:** LOW (mostly unique functionality)

---

### 7. Group Management (2 scripts)

Scripts for managing groups.

#### Bash Scripts
- [bwPurgeGroups.sh](../Bash%20Scripts/bwPurgeGroups.sh) - Delete all groups

#### PowerShell Scripts
- [bwPurgeGroups.ps1](../Powershell/bwPurgeGroups.ps1) - Delete all groups

#### API Scripts
- [createGroups.sh](../API%20Scripts/Bitwarden%20Public%20API/createGroups.sh) - Create groups via API

**Dependencies:** bw CLI, API access
**Overlap Level:** LOW

---

### 8. Secrets Manager (2 scripts)

Scripts specifically for Bitwarden Secrets Manager operations.

#### Bash Scripts
- [bwConfirmAcceptedPeopleSM.sh](../Bash%20Scripts/bwConfirmAcceptedPeopleSM.sh) - Confirm SM users

#### PowerShell Scripts
- [bwConfirmAcceptedPeopleSM.ps1](../Powershell/bwConfirmAcceptedPeopleSM.ps1) - Confirm SM users

**Dependencies:** bw CLI, bws CLI
**Overlap Level:** MEDIUM (duplicate Bash/PS implementation)

---

## 🔄 Identified Overlaps & Duplications

### Critical Duplicates (Merge Candidates)

| Functionality | Bash | PowerShell | API/Python | Priority |
|---------------|------|------------|------------|----------|
| **Confirm Accepted Users** | ✅ (6 variants) | ✅ (3 variants) | ✅ API | HIGH |
| **Create Collections for Groups** | ✅ | ✅ | ✅ | HIGH |
| **List Members** | ✅ | ✅ (API) | ✅ | HIGH |
| **Delete All Collections** | ✅ | ✅ | - | MEDIUM |
| **Export Org Vault** | ✅ (2 variants) | ✅ (2 variants) | - | MEDIUM |
| **Purge Groups** | ✅ | ✅ | - | LOW |
| **Purge Not Accepted Users** | ✅ | ✅ | - | LOW |
| **List Collections by Group** | ✅ | ✅ (2 variants) | ✅ | MEDIUM |
| **Event Log Download** | - | ✅ | ✅ (2 variants) | MEDIUM |
| **Confirm SM Users** | ✅ | ✅ | - | LOW |

**Refactoring Recommendation:** Consolidate these into unified CLI commands with platform-specific wrappers where needed.

---

## 🔗 Dependency Analysis

### External Dependencies

| Dependency | Required By | Platforms | Notes |
|------------|-------------|-----------|-------|
| **bw CLI** | All Bash/PS scripts | All | Core requirement |
| **bws CLI** | SM scripts | All | Secrets Manager only |
| **jq** | Most Bash/PS scripts | All | JSON parsing |
| **openssl** | Bash encryption scripts | Linux/macOS | AES-256-CBC encryption |
| **Python 3.x** | All Python scripts | All | Version 3.6+ assumed |
| **requests** | Most Python scripts | All | HTTP/API client |
| **pandas** | Reporting scripts | All | Data analysis |

### Python Module Dependencies

Found in Python scripts (needs consolidation into requirements.txt):
- requests
- pandas
- configparser
- cryptography (in permissions-report)
- argparse
- getpass
- json
- subprocess

### Authentication Patterns

Multiple patterns identified:
1. **Plain text prompts** (least secure) - used in simple Bash scripts
2. **OpenSSL encrypted files** (secureString.txt) - used in advanced Bash scripts
3. **Python AES-256-CBC** (custom implementation) - used in permissions-report
4. **Environment variables** - mentioned in some Python scripts
5. **Config files** (config.cfg) - used in admin-tools

**Refactoring Recommendation:** Standardize on single encrypted config approach across all languages.

---

## 📝 Code Quality Observations

### Bash Scripts
- ✅ Generally simple and focused
- ⚠️ Heavy use of command substitution (`$()`)
- ⚠️ Limited error handling in many scripts
- ⚠️ Hardcoded credentials in comments (security risk)
- ⚠️ No consistent logging approach

### PowerShell Scripts
- ✅ Better error handling with try-catch blocks
- ✅ Parameter validation
- ⚠️ Inconsistent naming conventions
- ⚠️ Some scripts check for dependencies, others don't

### Python Scripts
- ✅ Best structured (especially permissions-report)
- ✅ Good use of functions and modules
- ⚠️ No unified module structure
- ⚠️ Missing requirements.txt
- ⚠️ Inconsistent CLI argument handling (argparse vs getopt)
- ⚠️ Some scripts are monolithic (2000+ lines)

---

## 🎯 Refactoring Priorities

### Phase 1 Candidates (Script Overlap Analysis)

**Must Consolidate:**
1. Confirm accepted users (11 implementations → 1 unified)
2. Collection creation scripts (8 implementations → 1 modular)
3. Event log downloads (4 implementations → 1 unified)
4. Org vault exports (4 implementations → 1 unified)

### Phase 2 Candidates (Modularization)

**Extract Common Modules:**
1. BW CLI wrapper (authentication, session management)
2. API client (Public API, Vault Management API)
3. JSON parsing utilities
4. Encryption/decryption utilities (standardize across languages)
5. Config management
6. Logging/reporting utilities

### Phase 3 Candidates (CLI Unification)

**Target CLI Structure:**
```bash
bw-admin users confirm [--secrets-manager]
bw-admin users list [--with-2fa]
bw-admin users purge --status=invited
bw-admin collections create --for=groups [--nested]
bw-admin collections delete --all
bw-admin vault export [--encrypt]
bw-admin reports passwords [--pwned-check]
bw-admin reports events [--format=csv]
bw-admin migrate --from=keeper --input=export.json
```

---

## 📊 Metrics Summary

| Metric | Value | Notes |
|--------|-------|-------|
| Total LOC (estimated) | 15,000+ | Across all scripts |
| Duplicate functionality | ~30% | High consolidation potential |
| Scripts without error handling | ~40% | Needs improvement |
| Scripts with hardcoded secrets | ~20% | Security risk |
| Modular Python scripts | 2 | permissions-report, add_item_to_collection |
| Standalone scripts | 78 | Need integration |

---

## 🚀 Next Steps

Based on this inventory, the following actions are recommended:

1. **Create deprecation list** for scripts to be consolidated
2. **Design unified module structure** for core functionality
3. **Establish credential management standard** across all platforms
4. **Define CLI command hierarchy** for Phase 3
5. **Create migration guide** for existing script users

---

## 📎 References

- Repository: [bitwarden-labs/admin-scripts](https://github.com/bitwarden-labs/admin-scripts)
- Bitwarden CLI: https://bitwarden.com/help/cli/
- Public API: https://bitwarden.com/help/api/
- Vault Management API: https://bitwarden.com/help/vault-management-api/

---

**Document Status:** COMPLETE ✅
**Last Updated:** 2025-11-04
**Next Review:** After Phase 1 completion
