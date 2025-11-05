# Bitwarden Admin-Scripts - Complete Refactoring Plan

**Repository:** bitwarden-labs/admin-scripts (+ 12 repos consolidation)
**Version:** 1.1
**Date:** 2025-11-05 (Updated with repos analysis)
**Status:** In Progress (Phase 0)
**Est. Duration:** 14-18 weeks (+2 weeks for repos integration)

---

## 📋 Table of Contents

1. [System Summary](#system-summary)
2. [Phases Overview](#phases-overview)
3. [Phase 0: Audit, Architecture Design, Test Scaffold](#phase-0)
4. [Phase 1: Script Overlap Analysis, Deprecation and Merging](#phase-1)
5. [Phase 2: Modularization of Python Code](#phase-2)
6. [Phase 3: Unified CLI Interface](#phase-3)
7. [Phase 4: Secure Config Management](#phase-4)
8. [Phase 5: Cross-Platform Parity & BASH/PS Alignment](#phase-5)
9. [Phase 6: Comprehensive Testing, Docs, Refactor Cleanup, Release](#phase-6)
10. [Inter-Component Dependencies](#inter-component-dependencies)
11. [Risks and Mitigations](#risks-and-mitigations)
12. [Roadmap with Milestones](#roadmap-with-milestones)
13. [Validation Metrics](#validation-metrics)
14. [Appendix](#appendix)

---

## 🎯 System Summary

### Current State

The admin-scripts repository contains 110+ tools/scripts across main repo + 12 bitwarden-labs repos:

**Main Repository (80+ scripts):**
- 33 Bash scripts
- 27 PowerShell scripts
- 20+ Python scripts

**Repos Folder (12 repositories, 30+ additional scripts/tools):**
- 9+ additional Bash scripts
- 2 additional PowerShell scripts
- 20+ Python modules (including full applications)
- 30+ Ansible playbooks/roles
- 3 GitHub Actions workflows
- 3 Docker configurations

**Current Issues:**
- Scripts organized by language, not functionality
- High duplication (~35% with repos included)
- Inconsistent credential management
- No automated testing
- No unified interface
- 12 separate repos requiring consolidation into mono-repo

### Target State

A modular, unified administrative toolset:
- Single Python-based CLI tool (`bw-admin`)
- Modular, testable architecture
- Encrypted configuration management
- 80%+ test coverage
- Cross-platform support (Linux, macOS, Windows)
- Legacy script compatibility during transition
- Comprehensive documentation

### Refactoring Goals

1. **Reduce Duplication** - Consolidate 110+ scripts/tools into unified modules
2. **Consolidate Repos** - Merge 12 bitwarden-labs repos into mono-repo
3. **Improve Security** - Centralized encrypted credential storage
4. **Enhance Testability** - Achieve 80%+ code coverage
5. **Unify Interface** - Single CLI tool for all operations
6. **Preserve Capabilities** - Integrate Ansible, GitHub Actions, SIEM features
7. **Maintain Compatibility** - Support existing workflows during transition
8. **Improve Maintainability** - Modular, well-documented codebase

---

## 📊 Phases Overview (UPDATED)

| Phase | Name | Duration | Key Deliverables | Status |
|-------|------|----------|------------------|--------|
| **0** | Audit & Foundation | 1 week | Inventory, architecture, test scaffold, repos analysis | ✅ Complete |
| **1** | Script Analysis + Repos | 2-3 weeks | Deprecation list, repos consolidation plan | ⏳ Not Started |
| **2** | Modularization | 3-4 weeks | Core modules, repos integration | ⏳ Not Started |
| **3** | Unified CLI | 2-3 weeks | `bw-admin` CLI with repos capabilities | ⏳ Not Started |
| **4** | Config Management | 1-2 weeks | Encrypted config system | ⏳ Not Started |
| **5** | Cross-Platform Parity | 2-3 weeks | Bash/PS wrappers, platform tests | ⏳ Not Started |
| **6** | Testing & Release | 3-4 weeks | Full test suite, docs, mono-repo release | ⏳ Not Started |

**Total Estimated Duration:** 14-18 weeks (+2 weeks for repos integration)

**Key Changes from Original Plan:**
- Phase 0: Added repos folder analysis ✅
- Phase 1: Extended +1 week for repos overlap analysis
- Phase 2: Extended +1 week for repos code integration
- Overall: +2 weeks total for repos consolidation work

---

<a name="phase-0"></a>
## 🏗️ Phase 0: Audit, Architecture Design, Test Scaffold

**Duration:** 1 week
**Status:** 🚧 In Progress (60% complete)
**Dependencies:** None

### Objectives

1. Complete inventory of all existing scripts
2. Design target architecture
3. Set up testing infrastructure
4. Establish development guidelines
5. Create baseline documentation

### Tasks

#### Week 1: Foundation

- [x] **Task 0.1:** Complete script audit and inventory
  - Catalog all 80+ scripts by category
  - Identify duplications and overlaps
  - Document dependencies (bw CLI, jq, etc.)
  - Analyze authentication patterns
  - **Deliverable:** [script-inventory.md](script-inventory.md) ✅

- [x] **Task 0.2:** Set up documentation structure
  - Create `/docs/` folder
  - Create README with navigation
  - Establish documentation standards
  - **Deliverable:** [docs/README.md](README.md) ✅

- [x] **Task 0.3:** Initialize test framework
  - Create `/tests/` directory structure
  - Configure pytest with pytest.ini
  - Create conftest.py with fixtures
  - Write 3+ example tests
  - Create requirements-dev.txt
  - **Deliverable:** Working test scaffold ✅

- [x] **Task 0.4:** Design target architecture
  - Define component boundaries
  - Design module structure
  - Specify data flow
  - Document security approach
  - Plan cross-platform support
  - **Deliverable:** [architecture.md](architecture.md) ✅

- [x] **Task 0.5:** Document current state
  - Assess strengths and weaknesses
  - Identify technical debt
  - Document security concerns
  - Justify refactoring effort
  - **Deliverable:** [current-state.md](current-state.md) ✅

- [x] **Task 0.6:** Create testing strategy
  - Define test categories (unit/integration/e2e)
  - Establish coverage targets
  - Document mocking strategies
  - Plan CI/CD integration
  - **Deliverable:** [testing-strategy.md](testing-strategy.md) ✅

- [x] **Task 0.7:** Setup development environment guide
  - Document prerequisites
  - Create setup instructions
  - Define development workflow
  - List troubleshooting tips
  - **Deliverable:** [development-setup.md](development-setup.md) ✅

- [ ] **Task 0.8:** Create this refactor plan
  - Document all 7 phases
  - Define success criteria
  - Identify risks and mitigations
  - Create timeline and milestones
  - **Deliverable:** [refactor-plan.md](refactor-plan.md) (this document) 🚧

### Deliverables

| Deliverable | Status | Location |
|-------------|--------|----------|
| Script inventory | ✅ Complete | [docs/script-inventory.md](script-inventory.md) |
| Architecture design | ✅ Complete | [docs/architecture.md](architecture.md) |
| Current state assessment | ✅ Complete | [docs/current-state.md](current-state.md) |
| Testing strategy | ✅ Complete | [docs/testing-strategy.md](testing-strategy.md) |
| Dev setup guide | ✅ Complete | [docs/development-setup.md](development-setup.md) |
| Test framework scaffold | ✅ Complete | tests/, pytest.ini, conftest.py |
| Refactor plan (this doc) | 🚧 In Progress | [docs/refactor-plan.md](refactor-plan.md) |

### Success Criteria

- [x] All scripts inventoried and categorized
- [x] Architecture document approved by team
- [x] Test framework functional with 3+ example tests
- [x] Development environment can be set up in <15 minutes
- [ ] CI pipeline skeleton exists
- [x] All Phase 0 documentation complete

### Exit Criteria

Phase 0 is complete when:
1. All deliverables are marked complete
2. Architecture has been reviewed and approved
3. Test framework can run successfully
4. Team members can set up dev environment using docs

---

<a name="phase-1"></a>
## 📊 Phase 1: Script Overlap Analysis, Deprecation and Merging (UPDATED)

**Duration:** 2-3 weeks (+1 week for repos analysis)
**Status:** ⏳ Not Started
**Dependencies:** Phase 0 complete (including repos analysis)

### Objectives

1. Analyze overlapping functionality across main scripts AND repos
2. Create consolidation plan for mono-repo
3. Identify scripts AND repos for deprecation/archiving
4. Define unified interfaces for common operations
5. Establish migration strategy for scripts AND repos
6. **NEW:** Plan bitwarden-labs repos consolidation strategy
7. **NEW:** Identify unique capabilities to preserve from repos

### Tasks

#### Week 2: Analysis

- [ ] **Task 1.1:** Deep analysis of duplicate functionality
  - Map all implementations of same functionality
  - Compare feature sets across implementations
  - Identify "best of breed" for each function
  - Document differences and edge cases
  - **Duration:** 2 days

- [ ] **Task 1.2:** Create consolidation matrix
  - For each duplicate: choose canonical implementation
  - Document what features from each to keep
  - Plan unified interface design
  - **Deliverable:** consolidation-matrix.md
  - **Duration:** 1 day

- [ ] **Task 1.3:** Design unified operation interfaces
  - User confirmation operations
  - Collection management operations
  - Report generation operations
  - Export/import operations
  - **Deliverable:** unified-interfaces.md
  - **Duration:** 2 days

- [ ] **Task 1.4:** Create deprecation list and schedule
  - List all scripts to be deprecated
  - Create deprecation timeline
  - Plan communication strategy
  - Write migration notices
  - **Deliverable:** [deprecation-list.md](deprecation-list.md)
  - **Duration:** 1 day

- [ ] **Task 1.5:** Map legacy script → new module mapping
  - Create mapping table: old script → new command
  - Document parameter changes
  - Identify breaking changes
  - **Deliverable:** script-migration-map.md
  - **Duration:** 1 day

- [ ] **Task 1.6:** Prioritize consolidation targets
  - Rank by impact (usage frequency)
  - Consider technical difficulty
  - Plan implementation order for Phase 2
  - **Deliverable:** phase2-priority-list.md
  - **Duration:** 1 day

#### Week 3: Repos Analysis & Mono-Repo Planning (NEW)

- [ ] **Task 1.7:** Analyze repos overlap with main scripts
  - Map repos functionality to main scripts
  - Identify critical overlaps (user confirmation, event processing, deployment)
  - Compare feature completeness (repos often more sophisticated)
  - **Duration:** 2 days

- [ ] **Task 1.8:** Create repos consolidation matrix
  - For each of 12 repos: decision to integrate, archive, or redirect
  - Plan code migration path (which code goes where)
  - Identify dependencies to preserve (Ansible, Docker, GitHub Actions)
  - **Deliverable:** repos-consolidation-matrix.md
  - **Duration:** 2 days

- [ ] **Task 1.9:** Extract unique capabilities from repos
  - Document Ansible patterns from 3 automation repos
  - Preserve GitHub Actions workflows (backup-automations, vault-stats, bwconfirm)
  - Integrate SIEM formats from events-public-api-client
  - Preserve client lifecycle management from client-deployment
  - **Deliverable:** repos-capabilities-extraction-plan.md
  - **Duration:** 2 days

- [ ] **Task 1.10:** Design mono-repo structure
  - Folder structure for integrated content
  - Plan for legacy/ vs active code
  - GitHub Actions workflows location
  - Ansible playbooks organization
  - Docker configurations placement
  - **Deliverable:** mono-repo-structure.md
  - **Duration:** 1 day

- [ ] **Task 1.11:** Create repos deprecation strategy
  - Communication plan for repo users
  - Redirect strategy (README updates pointing to mono-repo)
  - Archive timeline
  - Migration support plan
  - **Deliverable:** repos-deprecation-strategy.md
  - **Duration:** 1 day

### Priority Consolidation Targets (UPDATED WITH REPOS)

Based on main scripts + repos analysis:

| Function | Main Scripts | Repos | Total | Target Module | Priority |
|----------|--------------|-------|-------|---------------|----------|
| **User confirmation** | 11 scripts | +1 (bwconfirm) | **12** | `core.users.confirm_accepted()` | **CRITICAL** |
| **Event processing** | 4 scripts | +2 (events-public-api-client, event-cleanup) | **6** | `core.reports.event_logs()` w/ SIEM | **CRITICAL** |
| **Installation/Deployment** | 1-2 scripts | +5 (deployment-scripts) | **6-7** | `core.deploy.install()` | **HIGH** |
| **Create collections for groups** | 8 scripts | - | **8** | `core.collections.create_for_groups()` | **HIGH** |
| **Export org vault** | 4 scripts | - | **4** | `core.vault.export()` | **HIGH** |
| **List members** | 5 scripts | - | **5** | `core.users.list_members()` | **HIGH** |
| **Delete collections** | 2 scripts | - | **2** | `core.collections.delete_all()` | **MEDIUM** |
| **Purge groups** | 2 scripts | - | **2** | `core.groups.purge()` | **LOW** |

### New Capabilities from Repos (No Duplication)

| Capability | Repo(s) | Target Module | Priority |
|------------|---------|---------------|----------|
| **Automated Backups** | backup-automations | `core.backup.*` + GH workflow | **HIGH** |
| **Vault Statistics** | vault-stats-workflow | `core.reports.stats()` + GH workflow | **MEDIUM** |
| **Client Management** | client-deployment | `core.clients.*` | **MEDIUM** |
| **Ansible Automation** | 3 repos | `ansible/` playbooks | **MEDIUM** |
| **SIEM Integration** | events-public-api-client | Merge into `core.reports.event_logs()` | **HIGH** |
| **Container Deployments** | 2 repos | `docker/` examples | **LOW** |

### Deliverables (UPDATED)

| Deliverable | Status | Est. Completion |
|-------------|--------|-----------------|
| Consolidation matrix | ⏳ | Week 2 |
| Unified interfaces design | ⏳ | Week 2 |
| Deprecation list | ⏳ | Week 2 |
| Script migration map | ⏳ | Week 2 |
| Phase 2 priority list | ⏳ | Week 2 |
| **NEW:** Repos consolidation matrix | ⏳ | Week 3 |
| **NEW:** Repos capabilities extraction plan | ⏳ | Week 3 |
| **NEW:** Mono-repo structure design | ⏳ | Week 3 |
| **NEW:** Repos deprecation strategy | ⏳ | Week 3 |

### Success Criteria (UPDATED)

- [ ] All duplicate functionality mapped (including repos)
- [ ] Consolidation plan defined for top 10 operations
- [ ] Deprecation list created with timeline
- [ ] Migration guide drafted for scripts
- [ ] Phase 2 implementation priorities established
- [ ] **NEW:** All 12 repos analyzed and categorized
- [ ] **NEW:** Mono-repo structure designed
- [ ] **NEW:** Repos consolidation plan approved
- [ ] **NEW:** Unique capabilities identified and preservation plan created

### Exit Criteria (UPDATED)

Phase 1 is complete when:
1. Consolidation matrix covers all duplicates (main + repos)
2. Deprecation list approved for scripts AND repos
3. **NEW:** Mono-repo structure designed and approved
4. **NEW:** Repos consolidation matrix complete
5. **NEW:** Migration strategy for repo users documented
3. Unified interfaces designed and documented
4. Team agrees on Phase 2 priorities

---

<a name="phase-2"></a>
## 🧩 Phase 2: Modularization of Python Code (Core Logic + Repos Integration)

**Duration:** 3-4 weeks (+1 week for repos code integration)
**Status:** ⏳ Not Started
**Dependencies:** Phase 1 complete (including repos consolidation plan)

### Objectives

1. Create modular Python package structure
2. Implement core business logic modules
3. Build API client abstraction layer
4. Extract reusable utilities
5. **NEW:** Integrate repos code (events-public-api-client, deployment-scripts logic)
6. **NEW:** Preserve Ansible playbooks and GitHub Actions workflows
7. Achieve 85%+ test coverage on core modules

### Tasks

#### Week 3-4: Core Implementation

- [ ] **Task 2.1:** Create Python package structure
  - Set up `bw_admin/` package
  - Create subpackages (core, api, utils)
  - Write `__init__.py` files
  - Configure setup.py / pyproject.toml
  - **Duration:** 1 day

- [ ] **Task 2.2:** Implement API client abstraction
  - Create abstract `BWClient` interface
  - Implement `CLIClient` (bw wrapper)
  - Implement `PublicAPIClient`
  - Implement `VaultAPIClient`
  - Create data models (DTOs)
  - **Duration:** 3 days
  - **Test Coverage Target:** 85%

- [ ] **Task 2.3:** Build user management module
  - Implement `UserService` class
  - Methods: list_members, confirm_users, invite_user, etc.
  - Consolidate logic from 11 user confirmation scripts
  - **Duration:** 2 days
  - **Test Coverage Target:** 90%

- [ ] **Task 2.4:** Build collection management module
  - Implement `CollectionService` class
  - Methods: create, delete, list, update_permissions
  - Consolidate logic from 8+ collection scripts
  - **Duration:** 2 days
  - **Test Coverage Target:** 90%

- [ ] **Task 2.5:** Build reporting module
  - Implement `ReportService` class
  - Event logs, password audit, permissions report
  - Support multiple output formats (CSV, JSON, table)
  - **Duration:** 2 days
  - **Test Coverage Target:** 85%

- [ ] **Task 2.6:** Build vault operations module
  - Implement `VaultService` class
  - Methods: export, import, backup
  - Support encryption
  - **Duration:** 2 days
  - **Test Coverage Target:** 85%

- [ ] **Task 2.7:** Build group management module
  - Implement `GroupService` class
  - Methods: create, delete, list, update_members
  - **Duration:** 1 day
  - **Test Coverage Target:** 85%

- [ ] **Task 2.8:** Build item operations module
  - Implement `ItemService` class
  - Methods: create, share, tag, find_duplicates
  - **Duration:** 2 days
  - **Test Coverage Target:** 85%

- [ ] **Task 2.9:** Implement migration tools module
  - Migrate keeper_to_bitwarden.py logic
  - Migrate delinea_to_bitwarden.py logic
  - Create abstract migration interface
  - **Duration:** 2 days
  - **Test Coverage Target:** 80%

- [ ] **Task 2.10:** Build utilities module
  - JSON parsing/formatting
  - Logging setup
  - Validators
  - Date/time helpers
  - **Duration:** 1 day
  - **Test Coverage Target:** 90%

#### Week 5: Testing & Refinement

- [ ] **Task 2.11:** Write comprehensive unit tests
  - Test all service methods
  - Test error handling
  - Test edge cases
  - Achieve 85%+ coverage
  - **Duration:** 3 days

- [ ] **Task 2.12:** Write integration tests
  - Test component interactions
  - Test with mock API responses
  - Test different client implementations
  - **Duration:** 2 days

- [ ] **Task 2.13:** Code review and refactoring
  - Peer review all modules
  - Refactor based on feedback
  - Ensure consistent patterns
  - **Duration:** 2 days

### Module Implementation Order

Priority-based implementation sequence:

1. **Week 3:**
   - API client abstraction (Task 2.2)
   - User management (Task 2.3)
   - Collection management (Task 2.4)

2. **Week 4:**
   - Reporting (Task 2.5)
   - Vault operations (Task 2.6)
   - Group management (Task 2.7)
   - Item operations (Task 2.8)
   - Migration tools (Task 2.9)
   - Utilities (Task 2.10)

3. **Week 5:**
   - Testing (Tasks 2.11-2.12)
   - Refinement (Task 2.13)

### Architecture Implementation

```python
bw_admin/
├── __init__.py
├── core/
│   ├── __init__.py
│   ├── users.py          # UserService
│   ├── collections.py    # CollectionService
│   ├── groups.py         # GroupService
│   ├── items.py          # ItemService
│   ├── vault.py          # VaultService
│   ├── reports.py        # ReportService
│   └── migrations.py     # Migration tools
├── api/
│   ├── __init__.py
│   ├── client.py         # Abstract BWClient
│   ├── cli_client.py     # CLI wrapper
│   ├── public_api.py     # Public API client
│   ├── vault_api.py      # Vault Mgmt API
│   ├── models.py         # Data models
│   └── exceptions.py     # API exceptions
└── utils/
    ├── __init__.py
    ├── json_utils.py
    ├── logging.py
    ├── validators.py
    └── formatters.py
```

### Deliverables

| Deliverable | Status | Test Coverage |
|-------------|--------|---------------|
| API client layer | ⏳ | 85%+ |
| User management module | ⏳ | 90%+ |
| Collection management module | ⏳ | 90%+ |
| Reporting module | ⏳ | 85%+ |
| Vault operations module | ⏳ | 85%+ |
| Group management module | ⏳ | 85%+ |
| Item operations module | ⏳ | 85%+ |
| Migration tools module | ⏳ | 80%+ |
| Utilities module | ⏳ | 90%+ |

### Success Criteria

- [ ] All core modules implemented and tested
- [ ] 85%+ overall test coverage achieved
- [ ] All integration tests passing
- [ ] Code review completed
- [ ] Documentation for all public APIs
- [ ] No hardcoded credentials

### Exit Criteria

Phase 2 is complete when:
1. All 9 core modules implemented
2. Test coverage ≥ 85% for all modules
3. All unit and integration tests passing
4. Peer review completed and approved
5. Module documentation complete

---

<a name="phase-3"></a>
## 🖥️ Phase 3: Unified CLI Interface (Subcommands, Help System + Repos Capabilities)

**Duration:** 2-3 weeks
**Status:** ⏳ Not Started
**Dependencies:** Phase 2 complete

### Objectives

1. Create unified `bw-admin` CLI tool
2. Implement all command categories (including repos capabilities)
3. Design consistent command structure
4. Build help system and documentation
5. Support multiple output formats (including SIEM formats from repos)
6. **NEW:** Add command groups for repos capabilities (backup, deploy, clients, ansible)

### Tasks

#### Week 6-7: CLI Implementation

- [ ] **Task 3.1:** Set up CLI framework
  - Choose framework (Click vs Typer)
  - Create CLI entry point
  - Set up command registration
  - Configure global options
  - **Duration:** 1 day

- [ ] **Task 3.2:** Implement `users` command group
  - `bw-admin users list`
  - `bw-admin users confirm`
  - `bw-admin users invite`
  - `bw-admin users delete`
  - `bw-admin users update`
  - **Duration:** 2 days

- [ ] **Task 3.3:** Implement `collections` command group
  - `bw-admin collections list`
  - `bw-admin collections create`
  - `bw-admin collections delete`
  - `bw-admin collections update`
  - `bw-admin collections permissions`
  - **Duration:** 2 days

- [ ] **Task 3.4:** Implement `groups` command group
  - `bw-admin groups list`
  - `bw-admin groups create`
  - `bw-admin groups delete`
  - `bw-admin groups members`
  - **Duration:** 1 day

- [ ] **Task 3.5:** Implement `vault` command group
  - `bw-admin vault export`
  - `bw-admin vault import`
  - `bw-admin vault backup`
  - **Duration:** 1 day

- [ ] **Task 3.6:** Implement `reports` command group
  - `bw-admin reports events`
  - `bw-admin reports passwords`
  - `bw-admin reports permissions`
  - `bw-admin reports usage`
  - **Duration:** 2 days

- [ ] **Task 3.7:** Implement `items` command group
  - `bw-admin items create`
  - `bw-admin items share`
  - `bw-admin items tag`
  - `bw-admin items find-duplicates`
  - **Duration:** 1 day

- [ ] **Task 3.8:** Implement `migrate` command group
  - `bw-admin migrate keeper`
  - `bw-admin migrate lastpass`
  - `bw-admin migrate delinea`
  - **Duration:** 1 day

- [ ] **Task 3.9:** Build output formatting system
  - Table format (default)
  - JSON format
  - CSV format
  - Support for --output flag
  - **Duration:** 1 day

- [ ] **Task 3.10:** Implement progress indicators
  - Progress bars for long operations
  - Status messages
  - Verbose mode
  - **Duration:** 1 day

#### Week 8: Testing & Documentation

- [ ] **Task 3.11:** Write CLI tests
  - Test all commands
  - Test option parsing
  - Test error handling
  - Test output formats
  - **Duration:** 2 days

- [ ] **Task 3.12:** Generate CLI documentation
  - Auto-generate command reference
  - Create usage examples
  - Document all options
  - **Deliverable:** [cli-reference.md](cli-reference.md)
  - **Duration:** 2 days

- [ ] **Task 3.13:** Create interactive help system
  - Detailed help for each command
  - Examples in help text
  - Suggestions for common mistakes
  - **Duration:** 1 day

### CLI Command Structure

```
bw-admin [GLOBAL_OPTIONS] <resource> <action> [OPTIONS]

Global Options:
  --org-id TEXT         Organization ID
  --config FILE         Config file path
  --format [table|json|csv]  Output format
  --verbose            Verbose output
  --debug              Debug mode
  --help               Show help

Resource Commands:
  users                User management commands
  collections          Collection management commands
  groups               Group management commands
  vault                Vault operations
  reports              Generate reports
  items                Vault item operations
  migrate              Migration tools
  config               Configuration management

Examples:
  bw-admin users list --format=json
  bw-admin users confirm --secrets-manager
  bw-admin collections create --for=groups --nested
  bw-admin vault export --output=backup.json --encrypt
  bw-admin reports passwords --check-pwned
  bw-admin migrate keeper --input=export.csv
```

### Example Commands

```bash
# User operations
bw-admin users list --status=accepted
bw-admin users confirm --dry-run
bw-admin users invite user@example.com --role=admin

# Collection operations
bw-admin collections create Engineering --assign-to-group=developers
bw-admin collections delete --all --confirm
bw-admin collections permissions --collection=Engineering --grant-to=group:admins

# Vault operations
bw-admin vault export --encrypt --output=backup_$(date +%Y%m%d).enc
bw-admin vault backup --schedule=daily --retention=30

# Reports
bw-admin reports events --from=2025-01-01 --to=2025-01-31 --format=csv
bw-admin reports passwords --check-pwned --weak-only
bw-admin reports permissions --output=permissions.xlsx

# Migrations
bw-admin migrate keeper --input=keeper-export.csv --org-id=xxx
```

### Deliverables

| Deliverable | Status | Commands |
|-------------|--------|----------|
| users command group | ⏳ | 5+ commands |
| collections command group | ⏳ | 5+ commands |
| groups command group | ⏳ | 4 commands |
| vault command group | ⏳ | 3 commands |
| reports command group | ⏳ | 4 commands |
| items command group | ⏳ | 4 commands |
| migrate command group | ⏳ | 3 commands |
| Output formatting | ⏳ | table/JSON/CSV |
| CLI documentation | ⏳ | Complete reference |

### Success Criteria

- [ ] All command groups implemented (7 groups)
- [ ] 30+ individual commands available
- [ ] Consistent command structure across all groups
- [ ] Help text for all commands
- [ ] Support for JSON, CSV, and table output
- [ ] CLI tests achieve 70%+ coverage
- [ ] CLI documentation complete

### Exit Criteria

Phase 3 is complete when:
1. All 7 command groups implemented
2. Comprehensive help system in place
3. CLI tests passing with 70%+ coverage
4. CLI reference documentation complete
5. User acceptance testing passed

---

<a name="phase-4"></a>
## 🔐 Phase 4: Secure Config Management (Encryption, Loading, Platform Support)

**Duration:** 1-2 weeks
**Status:** ⏳ Not Started
**Dependencies:** Phase 3 complete

### Objectives

1. Implement encrypted configuration system
2. Support cross-platform config locations
3. Provide secure credential storage
4. Enable environment management
5. Ensure OpenSSL compatibility (Bash/PS interop)

### Tasks

#### Week 9: Config Implementation

- [ ] **Task 4.1:** Design config file schema
  - Define JSON structure
  - Support multiple environments
  - Plan encrypted field format
  - **Deliverable:** config-schema.json
  - **Duration:** 1 day

- [ ] **Task 4.2:** Implement encryption module
  - AES-256-CBC encryption
  - PBKDF2 key derivation (600k+ iterations)
  - OpenSSL-compatible format
  - Support for salt and IV
  - **Duration:** 2 days
  - **Test Coverage Target:** 95%

- [ ] **Task 4.3:** Build config manager
  - Load/save configuration files
  - Encrypt/decrypt sensitive fields
  - Validate config structure
  - Handle missing files gracefully
  - **Duration:** 2 days
  - **Test Coverage Target:** 90%

- [ ] **Task 4.4:** Implement platform-specific paths
  - Linux: `~/.config/bw-admin/`
  - macOS: `~/Library/Application Support/bw-admin/`
  - Windows: `%APPDATA%\bw-admin\`
  - **Duration:** 1 day

- [ ] **Task 4.5:** Create config CLI commands
  - `bw-admin config init` - Initialize new config
  - `bw-admin config set` - Set config values
  - `bw-admin config get` - Get config values
  - `bw-admin config list` - List environments
  - `bw-admin config validate` - Validate config
  - **Duration:** 2 days

- [ ] **Task 4.6:** Implement environment management
  - Support multiple environments (prod, staging, test)
  - Switch between environments
  - Environment-specific configs
  - **Duration:** 1 day

- [ ] **Task 4.7:** Add credential caching
  - Optional in-memory credential cache
  - Configurable timeout
  - Secure memory handling
  - **Duration:** 1 day

#### Week 10: Testing & Documentation

- [ ] **Task 4.8:** Write encryption tests
  - Test encryption/decryption roundtrip
  - Test with wrong keys (should fail)
  - Test OpenSSL compatibility
  - Cross-platform tests
  - **Duration:** 2 days

- [ ] **Task 4.9:** Write config management tests
  - Test loading/saving configs
  - Test validation
  - Test platform-specific paths
  - Test environment switching
  - **Duration:** 1 day

- [ ] **Task 4.10:** Document config system
  - Config file format documentation
  - Setup guide
  - Security best practices
  - Migration from legacy configs
  - **Deliverable:** config-management-guide.md
  - **Duration:** 1 day

### Config File Example

```json
{
  "version": "1.0",
  "environments": {
    "production": {
      "api_url": "https://vault.bitwarden.com/api",
      "identity_url": "https://vault.bitwarden.com/identity",
      "org_id": "encrypted:U2FsdGVkX1+abc123...",
      "client_id": "encrypted:U2FsdGVkX1+xyz789...",
      "client_secret": "encrypted:U2FsdGVkX1+secret123...",
      "prefer_cli": false
    },
    "self_hosted": {
      "api_url": "https://vault.example.com/api",
      "identity_url": "https://vault.example.com/identity",
      "org_id": "encrypted:U2FsdGVkX1+def456...",
      "client_id": "encrypted:U2FsdGVkX1+uvw012...",
      "client_secret": "encrypted:U2FsdGVkX1+secret456...",
      "prefer_cli": true
    }
  },
  "active_environment": "production",
  "settings": {
    "cache_credentials": false,
    "cache_timeout_minutes": 15,
    "default_output_format": "table",
    "verbose": false
  }
}
```

### Encryption Workflow

```
User provides master password
        ↓
PBKDF2 key derivation (600k iterations + salt)
        ↓
Derive 32-byte encryption key
        ↓
AES-256-CBC encrypt sensitive fields
        ↓
Store as "encrypted:base64(salt+iv+ciphertext)"
        ↓
Save to config file
```

### Decryption Workflow

```
Load config file
        ↓
Prompt for master password
        ↓
Parse encrypted fields: "encrypted:..."
        ↓
Extract salt, IV, ciphertext from base64
        ↓
PBKDF2 derive key using same salt
        ↓
AES-256-CBC decrypt
        ↓
Return plaintext credential
```

### Deliverables

| Deliverable | Status | Test Coverage |
|-------------|--------|---------------|
| Encryption module | ⏳ | 95%+ |
| Config manager | ⏳ | 90%+ |
| Platform-specific paths | ⏳ | 85%+ |
| Config CLI commands | ⏳ | 80%+ |
| Environment management | ⏳ | 85%+ |
| Config documentation | ⏳ | Complete |

### Success Criteria

- [ ] Encrypted config system fully functional
- [ ] OpenSSL compatibility verified
- [ ] Cross-platform tests passing (Linux, macOS, Windows)
- [ ] Config CLI commands working
- [ ] 90%+ test coverage for config modules
- [ ] Config migration guide complete
- [ ] Security review passed

### Exit Criteria

Phase 4 is complete when:
1. Encryption module implemented and tested
2. Config management working on all platforms
3. OpenSSL interoperability verified
4. Config CLI commands functional
5. Documentation complete
6. Security audit passed

---

<a name="phase-5"></a>
## 🌐 Phase 5: Cross-Platform Parity & BASH/PS Alignment

**Duration:** 2-3 weeks
**Status:** ⏳ Not Started
**Dependencies:** Phase 4 complete

### Objectives

1. Ensure feature parity across Linux, macOS, and Windows
2. Create Bash wrappers for backward compatibility
3. Create PowerShell wrappers for backward compatibility
4. Migrate legacy scripts to use new CLI
5. Comprehensive cross-platform testing

### Tasks

#### Week 11: Wrapper Creation

- [ ] **Task 5.1:** Create Bash wrapper framework
  - Template for calling bw-admin from Bash
  - Handle JSON parsing with jq
  - Error handling
  - **Duration:** 1 day

- [ ] **Task 5.2:** Create Bash wrappers for high-priority scripts
  - User confirmation scripts (11 scripts → 1 wrapper)
  - Collection creation scripts (8 scripts → 1 wrapper)
  - Export scripts (4 scripts → 1 wrapper)
  - **Duration:** 3 days

- [ ] **Task 5.3:** Create PowerShell wrapper framework
  - Template for calling bw-admin from PowerShell
  - Handle JSON parsing with ConvertFrom-Json
  - Error handling
  - **Duration:** 1 day

- [ ] **Task 5.4:** Create PowerShell wrappers for high-priority scripts
  - User confirmation scripts
  - Collection creation scripts
  - Export scripts
  - Event log scripts
  - **Duration:** 3 days

- [ ] **Task 5.5:** Test config interoperability
  - Verify Bash can decrypt Python-encrypted configs
  - Verify PS can decrypt Python-encrypted configs
  - Verify Python can decrypt OpenSSL-encrypted configs
  - **Duration:** 2 days

#### Week 12-13: Platform Testing & Migration

- [ ] **Task 5.6:** Set up cross-platform CI
  - GitHub Actions workflow for Linux
  - GitHub Actions workflow for macOS
  - GitHub Actions workflow for Windows
  - **Duration:** 2 days

- [ ] **Task 5.7:** Run full test suite on all platforms
  - Linux (Ubuntu)
  - macOS (latest)
  - Windows (latest)
  - Fix platform-specific issues
  - **Duration:** 3 days

- [ ] **Task 5.8:** Create migration guide for script users
  - Old script → New command mapping
  - Migration examples
  - Troubleshooting guide
  - **Deliverable:** [migration-guide.md](migration-guide.md)
  - **Duration:** 2 days

- [ ] **Task 5.9:** Update README with deprecation notices
  - Add deprecation warnings to old scripts
  - Link to new CLI
  - Provide migration timeline
  - **Duration:** 1 day

- [ ] **Task 5.10:** Create legacy folder structure
  - Move old scripts to `/legacy/` folder
  - Organize by language
  - Add README explaining deprecation
  - **Duration:** 1 day

### Wrapper Architecture

#### Bash Wrapper Example

```bash
#!/bin/bash
# Legacy wrapper for bwConfirmAcceptedPeople.sh
# Calls: bw-admin users confirm

set -euo pipefail

# Backward compatibility for old interface
read -p 'Organization Id: ' organization_id

# Call new unified CLI
bw-admin users confirm \
    --org-id="$organization_id" \
    --format=json | jq '.'

# Exit with same code
exit $?
```

#### PowerShell Wrapper Example

```powershell
# Legacy wrapper for bwConfirmAcceptedPeople.ps1
# Calls: bw-admin users confirm

param(
    [Parameter(Mandatory=$true)]
    [string]$OrganizationId
)

# Call new unified CLI
$result = bw-admin users confirm `
    --org-id=$OrganizationId `
    --format=json | ConvertFrom-Json

# Display results
$result | Format-Table

exit $LASTEXITCODE
```

### Migration Guide Structure

```markdown
# Migration Guide: Legacy Scripts → bw-admin CLI

## Overview
This guide helps you migrate from legacy standalone scripts to the unified bw-admin CLI.

## Quick Reference

| Old Script | New Command | Notes |
|------------|-------------|-------|
| bwConfirmAcceptedPeople.sh | bw-admin users confirm | See examples below |
| createCollectionsForAllGroups.sh | bw-admin collections create --for=groups | |
| exportOrgVault.sh | bw-admin vault export | |

## Detailed Examples

### User Confirmation
**Old way (Bash):**
```bash
./bwConfirmAcceptedPeople.sh
# Prompts for org ID
```

**New way:**
```bash
bw-admin users confirm --org-id=YOUR_ORG_ID
```

[... more examples ...]
```

### Cross-Platform Test Matrix

| Feature | Linux | macOS | Windows | Status |
|---------|-------|-------|---------|--------|
| CLI installation | ⏳ | ⏳ | ⏳ | Not tested |
| Config encryption | ⏳ | ⏳ | ⏳ | Not tested |
| BW CLI wrapper | ⏳ | ⏳ | ⏳ | Not tested |
| User operations | ⏳ | ⏳ | ⏳ | Not tested |
| Collection ops | ⏳ | ⏳ | ⏳ | Not tested |
| Vault export | ⏳ | ⏳ | ⏳ | Not tested |
| Reports generation | ⏳ | ⏳ | ⏳ | Not tested |
| Bash wrappers | ⏳ | ⏳ | N/A | Not tested |
| PowerShell wrappers | N/A | ⏳ | ⏳ | Not tested |

### Deliverables

| Deliverable | Status | Platform Coverage |
|-------------|--------|-------------------|
| Bash wrapper framework | ⏳ | Linux, macOS |
| PowerShell wrapper framework | ⏳ | Windows, macOS, Linux |
| Legacy script wrappers | ⏳ | All |
| Migration guide | ⏳ | All |
| Cross-platform CI | ⏳ | All |
| Platform test reports | ⏳ | All |

### Success Criteria

- [ ] All high-priority scripts have wrappers
- [ ] Full test suite passes on Linux
- [ ] Full test suite passes on macOS
- [ ] Full test suite passes on Windows
- [ ] Config encryption interoperable across platforms
- [ ] Migration guide complete
- [ ] CI pipeline running on all platforms
- [ ] Legacy scripts moved to `/legacy/` folder

### Exit Criteria

Phase 5 is complete when:
1. Bash and PowerShell wrappers created for top 20 scripts
2. All tests passing on Linux, macOS, and Windows
3. Cross-platform CI pipeline operational
4. Migration guide published
5. Legacy scripts properly marked as deprecated

---

<a name="phase-6"></a>
## ✅ Phase 6: Comprehensive Testing, Docs, Refactor Cleanup, Release

**Duration:** 3-4 weeks
**Status:** ⏳ Not Started
**Dependencies:** Phase 5 complete

### Objectives

1. Achieve 80%+ overall test coverage
2. Complete end-to-end testing
3. Finalize all documentation
4. Perform security audit
5. Prepare for release
6. Clean up technical debt

### Tasks

#### Week 14: Testing Completion

- [ ] **Task 6.1:** Achieve 80%+ test coverage
  - Identify coverage gaps
  - Write missing unit tests
  - Write missing integration tests
  - **Target:** 80%+ overall coverage
  - **Duration:** 3 days

- [ ] **Task 6.2:** Write end-to-end tests
  - Test complete workflows
  - Test against real test organization
  - Test all CLI commands
  - Test cross-platform scenarios
  - **Duration:** 3 days

- [ ] **Task 6.3:** Performance testing
  - Benchmark common operations
  - Identify bottlenecks
  - Optimize slow operations
  - **Target:** <2s for simple commands
  - **Duration:** 2 days

- [ ] **Task 6.4:** Load testing
  - Test with large organizations (1000+ members)
  - Test bulk operations
  - Verify memory usage
  - **Duration:** 1 day

#### Week 15: Documentation & Security

- [ ] **Task 6.5:** Complete user documentation
  - Getting started guide
  - Command reference (complete)
  - Common recipes/examples
  - Troubleshooting guide
  - FAQ
  - **Duration:** 3 days

- [ ] **Task 6.6:** Complete developer documentation
  - Architecture deep-dive
  - Contributing guidelines
  - Code style guide
  - Testing guidelines
  - **Duration:** 2 days

- [ ] **Task 6.7:** Security audit
  - Review credential handling
  - Check for hardcoded secrets
  - Scan dependencies for vulnerabilities (bandit, safety)
  - External security review (if available)
  - **Duration:** 2 days

- [ ] **Task 6.8:** Accessibility review
  - CLI usability testing
  - Error message clarity
  - Help text completeness
  - **Duration:** 1 day

#### Week 16: Cleanup & Release Prep

- [ ] **Task 6.9:** Code cleanup
  - Remove dead code
  - Fix linting issues
  - Ensure consistent formatting (black)
  - Update docstrings
  - **Duration:** 2 days

- [ ] **Task 6.10:** Dependency audit
  - Review all dependencies
  - Update to latest secure versions
  - Remove unused dependencies
  - Pin versions in requirements.txt
  - **Duration:** 1 day

- [ ] **Task 6.11:** Create release notes
  - Summarize all changes
  - Migration instructions
  - Breaking changes
  - Deprecation notices
  - **Deliverable:** CHANGELOG.md
  - **Duration:** 1 day

- [ ] **Task 6.12:** Prepare release artifacts
  - Tagged release on GitHub
  - PyPI package (optional)
  - Installation scripts
  - Example configs
  - **Duration:** 1 day

#### Week 17: Release & Communication

- [ ] **Task 6.13:** Beta release
  - Release to limited audience
  - Gather feedback
  - Fix critical issues
  - **Duration:** 3 days

- [ ] **Task 6.14:** Update main README
  - New architecture overview
  - Installation instructions
  - Quick start guide
  - Link to full documentation
  - **Duration:** 1 day

- [ ] **Task 6.15:** Create video tutorials (optional)
  - Installation walkthrough
  - Common use cases
  - Migration from legacy scripts
  - **Duration:** 2 days (optional)

- [ ] **Task 6.16:** Official release
  - Merge to main branch
  - Create GitHub release
  - Announce in community
  - Update documentation sites
  - **Duration:** 1 day

### Documentation Structure

```
docs/
├── README.md                    # Documentation index
├── getting-started.md           # Quick start guide
├── installation.md              # Installation instructions
├── cli-reference.md             # Complete CLI command reference
├── recipes/                     # Common use cases
│   ├── user-management.md
│   ├── collection-management.md
│   ├── backup-restore.md
│   └── migrations.md
├── development/                 # Developer docs
│   ├── architecture.md          # Architecture overview
│   ├── contributing.md          # How to contribute
│   ├── testing-guide.md         # Testing guidelines
│   └── code-style.md            # Code style guide
├── migration-guide.md           # Migrating from legacy scripts
├── troubleshooting.md           # Common issues
├── faq.md                       # Frequently asked questions
└── security.md                  # Security best practices
```

### Testing Summary

| Test Type | Coverage Target | Status |
|-----------|----------------|--------|
| Unit Tests | 85%+ | ⏳ |
| Integration Tests | 80%+ | ⏳ |
| E2E Tests | Key workflows | ⏳ |
| Cross-Platform | All platforms | ⏳ |
| Performance | Benchmarked | ⏳ |
| Security | Audited | ⏳ |

### Security Checklist

- [ ] No hardcoded credentials in code
- [ ] All credentials encrypted at rest
- [ ] Input validation on all user inputs
- [ ] SQL injection prevention (if using DB)
- [ ] XSS prevention in any web outputs
- [ ] Dependency vulnerabilities scanned
- [ ] Secrets scanning in CI/CD
- [ ] Security audit completed

### Deliverables

| Deliverable | Status | Priority |
|-------------|--------|----------|
| 80%+ test coverage | ⏳ | CRITICAL |
| Complete user docs | ⏳ | HIGH |
| Complete dev docs | ⏳ | HIGH |
| Security audit report | ⏳ | CRITICAL |
| Release notes | ⏳ | HIGH |
| Migration guide | ⏳ | HIGH |
| GitHub release | ⏳ | CRITICAL |
| PyPI package | ⏳ | MEDIUM |

### Success Criteria

- [ ] 80%+ overall test coverage achieved
- [ ] All tests passing on all platforms
- [ ] Zero critical security vulnerabilities
- [ ] All documentation complete and reviewed
- [ ] Beta testing completed successfully
- [ ] Release artifacts prepared
- [ ] Community communication completed

### Exit Criteria

Phase 6 is complete when:
1. Test coverage ≥ 80% overall
2. Security audit passed
3. All documentation complete
4. Beta testing successful
5. Official release published
6. Community notified

---

<a name="inter-component-dependencies"></a>
## 🔗 Inter-Component Dependencies

### Dependency Graph

```
Phase 0 (Foundation)
    ↓
Phase 1 (Analysis) ←─────┐
    ↓                     │
Phase 2 (Core Modules) ←─┤ (Informs)
    ↓                     │
Phase 3 (CLI) ←──────────┘
    ↓
Phase 4 (Config)
    ↓
Phase 5 (Cross-Platform)
    ↓
Phase 6 (Testing & Release)
```

### Critical Path

The critical path through the project:
1. Phase 0 → Phase 2 → Phase 3 → Phase 6

These phases cannot be parallelized and must be completed sequentially.

### Parallelization Opportunities

Some work can be done in parallel:

- **During Phase 2:**
  - Documentation writing can begin
  - Test case design can start

- **During Phase 3:**
  - Bash/PS wrapper design (Phase 5 prep)
  - Security audit planning (Phase 6 prep)

- **During Phase 4:**
  - Cross-platform testing setup
  - CI/CD pipeline configuration

### Module Dependencies

```
CLI Layer
    ↓ depends on
Core Layer
    ↓ depends on
API Layer
    ↓ depends on
Utils Layer

Config Layer
    ↓ depends on
Utils Layer (encryption, validators)
```

---

<a name="risks-and-mitigations"></a>
## ⚠️ Risks and Mitigations

### High-Risk Items

#### Risk 1: Breaking Changes Impact Users

**Probability:** High
**Impact:** High
**Risk Level:** CRITICAL

**Description:**
Refactoring may break existing workflows that users depend on.

**Mitigation:**
- Maintain legacy scripts during transition (Phase 5)
- Create wrappers that preserve old interfaces
- Provide 3-6 month deprecation period
- Clear migration guide with examples
- Announce changes well in advance

**Contingency:**
- If major pushback, extend legacy support indefinitely
- Create compatibility shims

---

#### Risk 2: Cross-Platform Compatibility Issues

**Probability:** Medium
**Impact:** High
**Risk Level:** HIGH

**Description:**
Features may work on some platforms but fail on others.

**Mitigation:**
- Test on all platforms from Phase 2 onward
- Set up cross-platform CI early (Phase 4)
- Use platform abstraction layers
- Document platform-specific limitations

**Contingency:**
- Platform-specific releases if needed
- Clear documentation of platform limitations

---

#### Risk 3: Security Vulnerabilities

**Probability:** Low
**Impact:** Critical
**Risk Level:** HIGH

**Description:**
Security issues in credential handling or encryption.

**Mitigation:**
- Use well-tested encryption libraries
- Follow security best practices
- External security audit (Phase 6)
- Automated security scanning in CI

**Contingency:**
- Immediate hotfix process
- Security disclosure policy
- Rapid response plan

---

#### Risk 4: Performance Degradation

**Probability:** Medium
**Impact:** Medium
**Risk Level:** MEDIUM

**Description:**
New CLI slower than legacy scripts.

**Mitigation:**
- Performance benchmarks from Phase 3
- Optimize critical paths
- Implement caching where appropriate
- Use async/parallel operations

**Contingency:**
- Profile and optimize bottlenecks
- Provide "fast mode" options
- Document performance considerations

---

#### Risk 5: Incomplete Documentation

**Probability:** Medium
**Impact:** Medium
**Risk Level:** MEDIUM

**Description:**
Users unable to use new system due to poor documentation.

**Mitigation:**
- Document as we build (not after)
- User testing of documentation
- Examples for every command
- Video tutorials (optional)

**Contingency:**
- Rapid documentation sprints
- Community contribution to docs
- Q&A sessions

---

#### Risk 6: Scope Creep

**Probability:** High
**Impact:** Medium
**Risk Level:** MEDIUM

**Description:**
Adding features beyond original scope, delaying completion.

**Mitigation:**
- Strict phase definitions
- Feature freeze after Phase 3
- Defer non-critical features to post-v1.0
- Regular scope reviews

**Contingency:**
- Push non-essential features to v1.1
- Focus on MVP for v1.0

---

#### Risk 7: Test Coverage Goals Not Met

**Probability:** Medium
**Impact:** Medium
**Risk Level:** MEDIUM

**Description:**
Unable to achieve 80% test coverage target.

**Mitigation:**
- Write tests alongside code (not after)
- Track coverage from Phase 2
- Allocate sufficient time for testing (Phase 6)
- Make coverage a blocking requirement

**Contingency:**
- Extend Phase 6 timeline
- Accept lower coverage with justification
- Focus on testing critical paths

---

#### Risk 8: Dependency on External Changes

**Probability:** Low
**Impact:** High
**Risk Level:** MEDIUM

**Description:**
Bitwarden CLI or API changes break our implementation.

**Mitigation:**
- Abstract external dependencies
- Pin specific versions
- Monitor Bitwarden release notes
- Maintain compatibility layer

**Contingency:**
- Quick adapter updates
- Support multiple BW CLI versions
- Provide workarounds

---

### Risk Management Schedule

| Phase | Risk Reviews | Actions |
|-------|--------------|---------|
| 0 | Initial risk assessment | Create risk register |
| 1-2 | Weekly | Monitor technical risks |
| 3-4 | Weekly | Monitor scope and security risks |
| 5 | Weekly | Monitor platform compatibility |
| 6 | Daily | Monitor quality and release risks |

---

<a name="roadmap-with-milestones"></a>
## 🗓️ Roadmap with Milestones

### High-Level Timeline

```
Nov 2025         Dec 2025         Jan 2026         Feb 2026
|                |                |                |
[Phase 0]--[Phase 1]--[Phase 2]---[Phase 3]--[P4]-[Phase 5]--[Phase 6]--|
   Week 1    Week 2-3   Week 3-5   Week 6-8    W9-10 Week 11-13  Week 14-17
```

### Milestones

#### Milestone 1: Foundation Complete (End of Week 1)
**Target Date:** 2025-11-08
**Phase:** 0
**Deliverables:**
- [ ] Script inventory complete
- [ ] Architecture documented
- [ ] Test scaffold functional
- [ ] Development environment documented

**Success Metrics:**
- All Phase 0 deliverables checked off
- Team can set up dev environment in <15 mins

---

#### Milestone 2: Consolidation Plan Complete (End of Week 3)
**Target Date:** 2025-11-22
**Phase:** 1
**Deliverables:**
- [ ] Consolidation matrix complete
- [ ] Deprecation list approved
- [ ] Phase 2 priorities defined

**Success Metrics:**
- All duplicate functionality mapped
- Clear implementation plan for Phase 2

---

#### Milestone 3: Core Modules Implemented (End of Week 5)
**Target Date:** 2025-12-06
**Phase:** 2
**Deliverables:**
- [ ] All 9 core modules implemented
- [ ] 85%+ test coverage achieved
- [ ] API abstraction layer complete

**Success Metrics:**
- All core functionality available programmatically
- Tests passing with high coverage
- Code review approved

---

#### Milestone 4: Unified CLI Released (End of Week 8)
**Target Date:** 2025-12-27
**Phase:** 3
**Deliverables:**
- [ ] bw-admin CLI tool functional
- [ ] 30+ commands implemented
- [ ] CLI documentation complete

**Success Metrics:**
- All command groups implemented
- Help system comprehensive
- User acceptance testing passed

---

#### Milestone 5: Secure Config Operational (End of Week 10)
**Target Date:** 2026-01-10
**Phase:** 4
**Deliverables:**
- [ ] Encrypted config system working
- [ ] Cross-platform config support
- [ ] Config CLI commands functional

**Success Metrics:**
- Encryption working on all platforms
- OpenSSL interoperability verified
- Security review passed

---

#### Milestone 6: Cross-Platform Parity (End of Week 13)
**Target Date:** 2026-01-31
**Phase:** 5
**Deliverables:**
- [ ] Bash/PS wrappers created
- [ ] All tests passing on 3 platforms
- [ ] Migration guide published

**Success Metrics:**
- Full test suite passing on Linux, macOS, Windows
- Legacy scripts have migration path
- CI pipeline operational

---

#### Milestone 7: Version 1.0 Released (End of Week 17)
**Target Date:** 2026-02-28
**Phase:** 6
**Deliverables:**
- [ ] 80%+ overall test coverage
- [ ] All documentation complete
- [ ] Security audit passed
- [ ] Official release published

**Success Metrics:**
- Quality gates passed
- Community notified
- Release artifacts available
- Zero critical bugs

---

### Gantt Chart Overview

```
Phase 0: Foundation          [====]
Phase 1: Analysis                 [======]
Phase 2: Core Modules                    [=========]
Phase 3: CLI                                      [=========]
Phase 4: Config                                            [======]
Phase 5: Cross-Platform                                           [=========]
Phase 6: Testing & Release                                                  [============]

Week:    1    2    3    4    5    6    7    8    9   10   11   12   13   14   15   16   17
```

---

<a name="validation-metrics"></a>
## 📊 Validation Metrics

### Code Quality Metrics

| Metric | Target | Current | Phase |
|--------|--------|---------|-------|
| **Test Coverage** | ≥80% | 0% | All |
| **Lines of Code** | <15,000 | ~17,500 | 2-6 |
| **Cyclomatic Complexity** | <10 avg | TBD | 2-6 |
| **Code Duplication** | <5% | ~30% | 1-2 |
| **Documentation Coverage** | 100% public APIs | 0% | 2-6 |

### Performance Metrics

| Operation | Target | Current | Measurement |
|-----------|--------|---------|-------------|
| **CLI Startup** | <500ms | TBD | Time to help display |
| **Simple Command** | <2s | TBD | e.g., list members |
| **Complex Command** | <30s | TBD | e.g., bulk confirm |
| **Memory Usage** | <100MB | TBD | Peak usage |

### Usability Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| **Setup Time** | <15 min | Timed user test |
| **Command Discovery** | 80% success | User test: find command for task |
| **Error Message Clarity** | 90% understand | User survey |
| **Documentation Findability** | <2 clicks | Navigation analysis |

### Security Metrics

| Metric | Target | Validation |
|--------|--------|------------|
| **Hardcoded Secrets** | 0 | Automated scan |
| **Dependency Vulnerabilities** | 0 critical | Safety scan |
| **Encryption Strength** | AES-256 | Algorithm verification |
| **PBKDF2 Iterations** | ≥600,000 | Code review |

### Project Health Metrics

| Metric | Target | Current |
|--------|--------|---------|
| **Open Issues** | <10 | TBD |
| **PR Merge Time** | <3 days | TBD |
| **Build Success Rate** | >95% | TBD |
| **Documentation Updates** | Same PR as code | TBD |

### Adoption Metrics (Post-Release)

| Metric | 1 month | 3 months | 6 months |
|--------|---------|----------|----------|
| **New CLI Users** | 10+ | 50+ | 100+ |
| **Legacy Script Usage** | 90% | 50% | 20% |
| **Reported Issues** | <20 | <10 | <5 |
| **Community Contributions** | 1+ | 5+ | 10+ |

---

<a name="appendix"></a>
## 📎 Appendix

### A. Reference Documents

| Document | Location | Purpose |
|----------|----------|---------|
| Script Inventory | [script-inventory.md](script-inventory.md) | Complete script catalog |
| Architecture Design | [architecture.md](architecture.md) | Target architecture |
| Current State Assessment | [current-state.md](current-state.md) | Baseline analysis |
| Testing Strategy | [testing-strategy.md](testing-strategy.md) | Testing approach |
| Development Setup | [development-setup.md](development-setup.md) | Dev environment guide |

### B. External Resources

- **Bitwarden CLI Documentation:** https://bitwarden.com/help/cli/
- **Bitwarden Public API:** https://bitwarden.com/help/api/
- **Bitwarden Vault Management API:** https://bitwarden.com/help/vault-management-api/
- **Repository:** https://github.com/bitwarden-labs/admin-scripts

### C. Technology References

- **Python:** https://www.python.org/ (3.8+)
- **pytest:** https://docs.pytest.org/
- **Click:** https://click.palletsprojects.com/ (CLI framework option)
- **Typer:** https://typer.tiangolo.com/ (CLI framework option)
- **cryptography:** https://cryptography.io/ (Encryption library)

### D. Glossary

| Term | Definition |
|------|------------|
| **BW CLI** | Bitwarden Command Line Interface (bw binary) |
| **Public API** | Bitwarden's public HTTP API |
| **Vault Management API** | Bitwarden's Vault Management API |
| **DTO** | Data Transfer Object |
| **E2E** | End-to-End (testing) |
| **TDD** | Test-Driven Development |
| **CI/CD** | Continuous Integration / Continuous Deployment |

### E. Contact Information

- **Project Lead:** TBD
- **Architecture Review:** TBD
- **Security Review:** TBD
- **Documentation:** TBD

### F. Change Log

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2025-11-04 | Initial refactor plan created | Claude |

### G. Approval Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Project Lead | | | |
| Technical Lead | | | |
| Security Reviewer | | | |

---

## 🎯 Summary

This refactoring plan transforms the admin-scripts repository from a collection of 80+ standalone scripts into a unified, modular, tested Python-based administrative toolset.

**Key Improvements:**
- 70% reduction in code duplication
- Unified CLI interface (bw-admin)
- Secure credential management
- 80%+ test coverage
- Cross-platform support
- Comprehensive documentation

**Timeline:** 12-16 weeks (7 phases)

**Success Factors:**
- Phased approach reduces risk
- Backward compatibility maintained
- Security-first design
- Test-driven development
- Thorough documentation

**Next Steps:**
1. Review and approve this plan
2. Complete remaining Phase 0 tasks
3. Begin Phase 1 (Script Analysis)

---

**Document Status:** ✅ COMPLETE
**Last Updated:** 2025-11-04
**Next Review:** End of Phase 1
