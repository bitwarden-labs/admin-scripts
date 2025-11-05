# Bitwarden Admin-Scripts - Complete Script Inventory

**Generated:** 2025-11-04
**Phase:** 0 (Audit)
**Purpose:** Comprehensive catalog of all scripts for refactoring analysis

---

## 📊 Executive Summary

| Metric | Count |
|--------|-------|
| **Total Scripts & Tools** | 110+ |
| **Bash Scripts** | 42+ (33 main + 9 repos) |
| **PowerShell Scripts** | 29 (27 main + 2 repos) |
| **Python Scripts/Modules** | 40+ (20 main + 20 repos) |
| **Ansible Playbooks/Roles** | 30+ |
| **GitHub Actions Workflows** | 3 |
| **Identified Overlaps** | 10+ major duplications |
| **Categories** | 13 functional domains |
| **Repos to Consolidate** | 12 bitwarden-labs repositories |

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

## 📦 Repos Folder Analysis (12 Repositories)

The `repos/` folder contains 12 cloned bitwarden-labs repositories with additional tools, workflows, and automation. These repositories will be consolidated into the main mono-repo as part of Phase 1.

### 9. Ansible Automation & Infrastructure as Code (3 repos)

Ansible-based deployment and configuration management.

#### brilliance-bwdc
- **GitHub:** git@github.com:bitwarden-labs/brilliance-bwdc.git
- **Purpose:** Bitwarden Directory Connector deployment via Ansible
- **Contents:**
  - 5 Python scripts (authenticate_cli.py, get_data_json.py, get_mp.py, inject-secret.py, variables.py)
  - 11 Ansible roles (bws-access, encrypted-secrets, python-venv, bwdc setup, keyring, etc.)
  - Bash script: bwdc.sh
- **Category:** BWDC Deployment, Infrastructure Automation

#### bws-ansible-examples
- **GitHub:** https://github.com/bitwarden-labs/bws-ansible-examples
- **Purpose:** Bitwarden Secrets Manager + Ansible integration examples
- **Contents:**
  - 3 self-contained roles (demonstration, certbot-nginx-vikunja, transfer-credentials)
  - Extensive YAML playbooks
  - Bash script: get-certs.sh
- **Category:** Secrets Manager Integration, Ansible Automation

#### nginx-from-source-ansible
- **GitHub:** https://github.com/bitwarden-labs/nginx-from-source-ansible
- **Purpose:** nginx reverse proxy deployment with real-IP module
- **Contents:**
  - 8 Ansible roles (certbot, fail2ban, machine-setup, nginx, nginx-sites, node-exporter, static-files, users-groups)
  - Complete from-source nginx build
- **Category:** Reverse Proxy, Infrastructure Automation

**Dependencies:** Ansible, Python 3.x
**Overlap Level:** NEW (Infrastructure as Code approach not in main scripts)

---

### 10. GitHub Actions Workflows (3 repos)

Cloud-native automation via GitHub Actions.

#### backup-automations
- **GitHub:** git@github.com:bitwarden-labs/backup-automations.git
- **Purpose:** Automated vault backups to S3
- **Contents:**
  - GitHub Actions workflow: vault-backup.yml
  - Exports org vault using BW CLI and Secrets Manager
  - S3 storage with retention policy (keeps last 10)
- **Category:** Backup & Data Protection

#### bwconfirm
- **GitHub:** git@github.com:bitwarden-labs/bwconfirm.git
- **Purpose:** Automated user confirmation container
- **Contents:**
  - Bash script: bwConfirm.sh
  - GitHub Actions workflow: docker-publish.yml
  - Docker container for scheduled confirmation
  - **Warning:** Bypasses fingerprint verification
- **Category:** User Management Automation

#### vault-stats-workflow
- **GitHub:** git@github.com:bitwarden-labs/vault-stats-workflow.git
- **Purpose:** Vault statistics reporting via GitHub Actions
- **Contents:**
  - GitHub Actions workflow: bitwarden-vault-stats.yaml
  - Generates item counts (logins, cards, identities, notes)
  - Sends results via Bitwarden Send
  - Uses BWS for credentials
- **Category:** Reporting & Analytics

**Dependencies:** GitHub Actions, bw CLI, bws CLI
**Overlap Level:** NEW (Cloud-native automation approach)

---

### 11. Container & Docker Solutions (2 repos)

Containerized deployment patterns.

#### bwdc-container
- **GitHub:** git@github.com:bitwarden-labs/bwdc-container.git
- **Purpose:** Containerized BWDC deployment example
- **Contents:**
  - Dockerfile
  - entrypoint.sh
- **Category:** Container/Docker, Directory Connector

#### events-public-api-client (includes Docker)
- See category 12 below for full details
- Includes Docker support for containerized event processing

**Dependencies:** Docker, docker-compose
**Overlap Level:** MEDIUM (Related to existing BWDC but containerized)

---

### 12. Advanced Event Processing & SIEM Integration (2 repos)

Professional-grade event processing with multiple export formats.

#### events-public-api-client
- **GitHub:** git@github.com:bitwarden-labs/events-public-api-client.git
- **Purpose:** Python CLI for retrieving and analyzing Bitwarden events
- **Contents:**
  - main.py (CLI entry point)
  - 19 Python modules:
    - API clients (public.py, event_processor.py)
    - Converters (CSV, JSON, NDJSON, UDM, Syslog)
    - Utilities (cache, export, logger, format_date)
    - Type definitions (event_types, device_types)
  - **Export formats:** JSON, CSV, UDM (Google Chronicle), Syslog (RFC 5424), NDJSON
  - **Features:** Live monitoring, caching, multiple output formats
  - Docker support
- **Category:** Event Analytics, SIEM Integration
- **Overlap:** STRONG - Similar to existing event export but far more sophisticated

#### event-cleanup
- **GitHub:** git@github.com:bitwarden-labs/event-cleanup.git
- **Purpose:** Event log database maintenance for self-hosted
- **Contents:**
  - Bash script: clear-events.sh
  - SQL script: clear-events.sql
  - Deletes events older than retention period (default 5 days)
  - Designed for cron scheduling
- **Category:** Database Maintenance, Event Management
- **Overlap:** STRONG - Similar to existing event cleanup scripts

**Dependencies:** Python 3.x, requests, Docker (optional)
**Overlap Level:** HIGH (Event processing exists but repos version more advanced)

---

### 13. Installation & Deployment Scripts (1 repo)

Self-hosted Bitwarden installation automation for multiple Linux distributions.

#### deployment-scripts
- **GitHub:** git@github.com:bitwarden-labs/deployment-scripts.git
- **Purpose:** Automated Bitwarden Self-Hosted installations
- **Contents:**
  - 5 Bash scripts:
    - Bitwarden_Setup_Ubuntu.sh
    - Bitwarden_Setup_Debian.sh
    - Bitwarden_Setup_RHEL.sh
    - Bitwarden_Setup_Fedora.sh
    - Bitwarden_Setup_Raspbian.sh
  - Full Docker installation and Bitwarden setup per distro
- **Category:** Installation & Deployment
- **Overlap:** STRONG - Similar to existing install scripts but more comprehensive

**Dependencies:** Docker, docker-compose
**Overlap Level:** HIGH (Installation scripts exist but per-distro versions more detailed)

---

### 14. Client Lifecycle Management (1 repo)

Windows client and browser extension management.

#### client-deployment
- **GitHub:** git@github.com:bitwarden-labs/client-deployment.git
- **Branch:** KH_client_deployment_ps (not main)
- **Purpose:** Client software deployment and configuration
- **Contents:**
  - BitwardenUpgrade.ps1 - Automated desktop client upgrades with version checking, logging, data.json management
  - Bitwarden-Edge-Ext-EU-reg-key.ps1 - Registry configuration for Edge extension (EU/self-hosted)
- **Category:** Client Management, Windows Administration
- **Overlap:** NEW (No existing client lifecycle management)

**Dependencies:** PowerShell, Windows
**Overlap Level:** LOW (New functionality)

---

### 15. Reverse Proxy Configuration (1 repo)

Sample reverse proxy configurations for nginx and Apache2.

#### reverse-proxy_configurations
- **GitHub:** git@github.com:bitwarden-labs/reverse-proxy_configurations.git
- **Purpose:** Sample reverse proxy configurations
- **Contents:**
  - apache2/vault.example.com.conf
  - nginx/vault.example.com.conf
  - Community forum guide references
  - Real-IP module documentation
- **Category:** Reverse Proxy Configuration
- **Overlap:** LOW (Reference configurations, not scripts)

**Dependencies:** nginx or Apache2
**Overlap Level:** LOW (Configuration examples)

---

## 🔄 Identified Overlaps & Duplications (UPDATED)

### Critical Duplicates (Merge Candidates)

| Functionality | Main Scripts | Repos | Total Impls | Priority |
|---------------|--------------|-------|-------------|----------|
| **User Confirmation** | 11 (Bash/PS/API) | +1 (bwconfirm repo) | **12** | **CRITICAL** |
| **Event Processing** | 4 (PS/Python) | +2 (events-public-api-client, event-cleanup) | **6** | **CRITICAL** |
| **Installation/Deployment** | 1-2 scripts | +5 (deployment-scripts per distro) | **6-7** | **HIGH** |
| **Create Collections for Groups** | 8 (Bash/PS/API) | - | **8** | **HIGH** |
| **List Members** | 5 (Bash/PS/API) | - | **5** | **HIGH** |
| **Export Org Vault** | 4 (Bash/PS variants) | - | **4** | **MEDIUM** |
| **Delete All Collections** | 2 (Bash/PS) | - | **2** | **MEDIUM** |
| **Purge Groups** | 2 (Bash/PS) | - | **2** | **LOW** |
| **Purge Not Accepted Users** | 2 (Bash/PS) | - | **2** | **LOW** |
| **List Collections by Group** | 4 (Bash/PS/API) | - | **4** | **MEDIUM** |
| **Confirm SM Users** | 2 (Bash/PS) | - | **2** | **LOW** |

### New Capabilities from Repos (No Main Script Equivalent)

| Capability | Repo | Type | Priority for Integration |
|------------|------|------|--------------------------|
| **Automated Vault Backups** | backup-automations | GitHub Actions | **HIGH** |
| **Vault Statistics** | vault-stats-workflow | GitHub Actions | **MEDIUM** |
| **Client Lifecycle Management** | client-deployment | PowerShell | **MEDIUM** |
| **Ansible Automation** | 3 repos (brilliance-bwdc, bws-ansible-examples, nginx-from-source-ansible) | Ansible | **MEDIUM** |
| **SIEM Integration** | events-public-api-client | Python (UDM, Syslog formats) | **HIGH** |
| **Container Deployments** | 2 repos (bwdc-container, bwconfirm) | Docker | **LOW** |
| **Reverse Proxy Configs** | reverse-proxy_configurations | Config files | **LOW** |

**Refactoring Recommendation:**
1. Consolidate overlapping functionality into unified CLI commands
2. Integrate unique capabilities from repos (backups, SIEM, client management)
3. Extract reusable patterns from Ansible roles
4. Preserve GitHub Actions workflows as templates

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

## 🎯 Refactoring Priorities (UPDATED)

### Phase 1 Candidates (Script Overlap Analysis + Repos Consolidation)

**Critical Consolidations (Including Repos):**
1. User confirmation (12 implementations: 11 main + bwconfirm repo → 1 unified)
2. Event processing (6 implementations: 4 main + 2 repos → 1 unified with SIEM support)
3. Installation/deployment (6-7 implementations: 1-2 main + 5 repos → 1 unified multi-distro)
4. Collection creation scripts (8 implementations → 1 modular)

**High Priority:**
5. Org vault exports (4 implementations → 1 unified)
6. Integrate backup automation (backup-automations repo → `bw-admin backup` commands)
7. Integrate SIEM formats (events-public-api-client → event export module)

### Phase 2 Candidates (Modularization)

**Extract Common Modules:**
1. BW CLI wrapper (authentication, session management)
2. API client (Public API, Vault Management API)
3. JSON parsing utilities
4. Encryption/decryption utilities (standardize across languages)
5. Config management
6. Logging/reporting utilities

### Phase 3 Candidates (CLI Unification - EXPANDED)

**Target CLI Structure (Including Repos Capabilities):**
```bash
# User management
bw-admin users confirm [--secrets-manager] [--auto]
bw-admin users list [--with-2fa]
bw-admin users purge --status=invited

# Collection management
bw-admin collections create --for=groups [--nested]
bw-admin collections delete --all

# Vault operations
bw-admin vault export [--encrypt]
bw-admin vault backup [--to=s3] [--retention=10]
bw-admin vault stats [--send-report]

# Reporting
bw-admin reports passwords [--pwned-check]
bw-admin reports events [--format=csv|json|syslog|udm]
bw-admin reports permissions [--output=xlsx]

# Migration
bw-admin migrate --from=keeper --input=export.json

# Deployment (NEW from repos)
bw-admin deploy server --distro=ubuntu|debian|rhel|fedora|raspbian
bw-admin deploy bwdc [--use-ansible] [--container]
bw-admin deploy nginx [--from-source]

# Client management (NEW from repos)
bw-admin clients upgrade [--version=latest]
bw-admin clients configure --edge-extension [--region=eu]

# Ansible (NEW from repos)
bw-admin ansible generate-playbook --for=bwdc
bw-admin ansible generate-playbook --for=nginx

# Event maintenance (NEW from repos)
bw-admin events cleanup [--older-than=5days]
```

---

## 📊 Metrics Summary (UPDATED)

| Metric | Value | Notes |
|--------|-------|-------|
| **Total LOC (estimated)** | 25,000+ | Main scripts + repos |
| **Main scripts LOC** | 15,000+ | Original 80+ scripts |
| **Repos LOC** | 10,000+ | 12 repos, including events-public-api-client |
| **Duplicate functionality** | ~35% | Increased with repos overlap |
| **Scripts without error handling** | ~35% | Repos scripts generally better |
| **Scripts with hardcoded secrets** | ~15% | Repos use BWS/env vars more |
| **Modular Python applications** | 3 | permissions-report, add_item_to_collection, events-public-api-client |
| **Ansible playbooks/roles** | 30+ | Infrastructure as Code approach |
| **GitHub Actions workflows** | 3 | Cloud-native automation |
| **Docker configurations** | 3 | Containerized deployments |
| **Standalone scripts needing integration** | 100+ | Main scripts + repos scripts |
| **Repos requiring consolidation** | 12 | All bitwarden-labs repos |

---

## 🚀 Next Steps (UPDATED)

Based on this inventory (including repos analysis), the following actions are recommended:

1. **Create consolidated deprecation list** for scripts AND repos to be merged
2. **Design unified module structure** incorporating repos functionality
3. **Establish credential management standard** across all platforms
4. **Define expanded CLI command hierarchy** including repos capabilities
5. **Create migration guide** for existing script users AND repo maintainers
6. **Plan mono-repo consolidation strategy** for 12 bitwarden-labs repos
7. **Extract reusable Ansible patterns** from 3 automation repos
8. **Integrate GitHub Actions workflows** as templates
9. **Preserve SIEM integration** from events-public-api-client
10. **Document backup automation** from backup-automations repo

---

## 📎 References

- Repository: [bitwarden-labs/admin-scripts](https://github.com/bitwarden-labs/admin-scripts)
- Bitwarden CLI: https://bitwarden.com/help/cli/
- Public API: https://bitwarden.com/help/api/
- Vault Management API: https://bitwarden.com/help/vault-management-api/

---

**Document Status:** UPDATED WITH REPOS ANALYSIS ✅
**Last Updated:** 2025-11-05 (Added repos folder analysis)
**Repos Analyzed:** 12 bitwarden-labs repositories
**Next Review:** After Phase 1 completion (repos consolidation)
