# Bitwarden Admin-Scripts - Target Architecture

**Phase:** 0 (Design)
**Version:** 1.0
**Status:** Draft for Review
**Date:** 2025-11-04

---

## 🎯 Executive Summary

This document defines the target architecture for the refactored admin-scripts repository. The goal is to transform a collection of 80+ standalone scripts into a unified, modular, testable Python-based administrative toolset while maintaining backward compatibility with existing Bash and PowerShell scripts.

### Key Architectural Principles

1. **Modularity** - Separate concerns into distinct, reusable modules
2. **Testability** - Design for unit and integration testing
3. **Security** - Centralized, encrypted credential management
4. **Cross-Platform** - Support Linux, macOS, and Windows
5. **Extensibility** - Easy to add new commands and features
6. **Backward Compatibility** - Maintain support for legacy scripts during transition

---

## 📐 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface Layer                     │
├─────────────────────────────────────────────────────────────┤
│  Unified CLI (bw-admin)  │  Legacy Scripts (Bash/PS Wrappers)│
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                   Application Layer (Python)                 │
├─────────────────────────────────────────────────────────────┤
│  bw_admin/                                                   │
│  ├── cli/          Command-line interface handlers          │
│  ├── core/         Business logic & workflows               │
│  ├── api/          API client implementations               │
│  ├── config/       Configuration & credential management    │
│  └── utils/        Shared utilities & helpers               │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                    Integration Layer                         │
├─────────────────────────────────────────────────────────────┤
│  BW CLI Wrapper  │  Public API Client  │  Vault Mgmt API   │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                    External Services                         │
├─────────────────────────────────────────────────────────────┤
│  Bitwarden CLI   │  Bitwarden API      │  External APIs    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Component Architecture

### 1. CLI Layer (`bw_admin/cli/`)

**Purpose:** Unified command-line interface for all administrative operations

**Technology:** Click or Typer (Python CLI framework)

**Structure:**
```python
bw_admin/cli/
├── __init__.py
├── main.py              # Entry point, command registration
├── commands/
│   ├── __init__.py
│   ├── users.py         # User management commands
│   ├── collections.py   # Collection management
│   ├── vault.py         # Vault operations
│   ├── reports.py       # Reporting commands
│   └── migrate.py       # Migration tools
├── options.py           # Common CLI options
└── output.py            # Output formatting (table, JSON, CSV)
```

**Command Structure:**
```bash
bw-admin <resource> <action> [options]

# Examples:
bw-admin users confirm --org-id=xxx [--secrets-manager]
bw-admin users list --format=table [--with-2fa]
bw-admin collections create --for=groups [--nested]
bw-admin vault export --output=backup.json [--encrypt]
bw-admin reports passwords --check-pwned
```

**Key Responsibilities:**
- Parse command-line arguments
- Validate input
- Call appropriate core modules
- Format and display output
- Handle errors gracefully

---

### 2. Core Layer (`bw_admin/core/`)

**Purpose:** Business logic and workflow orchestration

**Structure:**
```python
bw_admin/core/
├── __init__.py
├── users.py             # User management logic
├── collections.py       # Collection operations
├── groups.py            # Group management
├── items.py             # Vault item operations
├── reports.py           # Report generation
├── migrations.py        # Data migration logic
├── permissions.py       # Permission management
└── workflows.py         # Complex multi-step workflows
```

**Design Patterns:**
- **Service Pattern** - Each module provides service functions
- **Strategy Pattern** - Different implementation strategies (CLI vs API)
- **Repository Pattern** - Data access abstraction

**Example Interface:**
```python
# bw_admin/core/users.py
from typing import List, Optional
from bw_admin.api.models import Member, ConfirmResult

class UserService:
    """Service for user management operations."""

    def __init__(self, client: BWClient, org_id: str):
        self.client = client
        self.org_id = org_id

    def list_members(self, status: Optional[int] = None) -> List[Member]:
        """List organization members, optionally filtered by status."""
        pass

    def confirm_accepted_users(
        self,
        dry_run: bool = False,
        secrets_manager: bool = False
    ) -> ConfirmResult:
        """Confirm all accepted users in the organization."""
        pass

    def invite_user(
        self,
        email: str,
        user_type: int,
        access_all: bool = False
    ) -> Member:
        """Invite a new user to the organization."""
        pass
```

**Key Responsibilities:**
- Implement business rules
- Orchestrate multi-step operations
- Handle data transformations
- Provide clean, testable interfaces
- No direct I/O (delegated to other layers)

---

### 3. API Layer (`bw_admin/api/`)

**Purpose:** Integration with Bitwarden services and external APIs

**Structure:**
```python
bw_admin/api/
├── __init__.py
├── client.py            # Abstract client interface
├── cli_client.py        # BW CLI wrapper implementation
├── public_api.py        # Public API client
├── vault_api.py         # Vault Management API client
├── models.py            # Data models/DTOs
├── exceptions.py        # API-specific exceptions
└── responses.py         # Response parsers
```

**Client Architecture:**
```python
# Abstract interface
class BWClient(ABC):
    """Abstract Bitwarden client interface."""

    @abstractmethod
    def authenticate(self) -> str:
        """Authenticate and return session/token."""
        pass

    @abstractmethod
    def list_members(self, org_id: str) -> List[Member]:
        """List organization members."""
        pass

    # ... other methods

# Implementations
class CLIClient(BWClient):
    """Bitwarden CLI wrapper implementation."""
    # Calls bw binary via subprocess

class PublicAPIClient(BWClient):
    """Public API HTTP client implementation."""
    # Makes direct HTTP requests

class VaultAPIClient(BWClient):
    """Vault Management API client implementation."""
    # Uses Vault Management API
```

**Key Responsibilities:**
- Abstract external service differences
- Handle authentication/sessions
- Parse responses into models
- Retry logic and error handling
- Rate limiting (for API clients)

---

### 4. Configuration Layer (`bw_admin/config/`)

**Purpose:** Secure configuration and credential management

**Structure:**
```python
bw_admin/config/
├── __init__.py
├── manager.py           # Config loading/saving
├── encryption.py        # AES-256-CBC encryption
├── credentials.py       # Credential storage
├── defaults.py          # Default configurations
└── validators.py        # Config validation
```

**Config File Format:**
```json
{
  "version": "1.0",
  "environments": {
    "production": {
      "api_url": "https://vault.bitwarden.com/api",
      "identity_url": "https://vault.bitwarden.com/identity",
      "org_id": "encrypted:U2FsdGVkX1...",
      "client_id": "encrypted:U2FsdGVkX1...",
      "client_secret": "encrypted:U2FsdGVkX1..."
    },
    "self_hosted": {
      "api_url": "https://vault.example.com/api",
      "identity_url": "https://vault.example.com/identity",
      "org_id": "encrypted:U2FsdGVkX1...",
      "client_id": "encrypted:U2FsdGVkX1...",
      "client_secret": "encrypted:U2FsdGVkX1..."
    }
  },
  "active_environment": "production"
}
```

**Encryption Strategy:**
- **Algorithm:** AES-256-CBC (compatible with OpenSSL)
- **Key Derivation:** PBKDF2 with 600,000+ iterations
- **Salt:** Random, stored with encrypted data
- **Master Password:** User-provided, never stored

**Config Locations (by platform):**
```
Linux:   ~/.config/bw-admin/config.json
macOS:   ~/Library/Application Support/bw-admin/config.json
Windows: %APPDATA%\bw-admin\config.json
```

**Key Responsibilities:**
- Load/save configuration files
- Encrypt/decrypt sensitive fields
- Validate configuration structure
- Provide platform-specific paths
- Environment management

---

### 5. Utilities Layer (`bw_admin/utils/`)

**Purpose:** Shared utilities and helper functions

**Structure:**
```python
bw_admin/utils/
├── __init__.py
├── json_utils.py        # JSON parsing/formatting
├── logging.py           # Logging configuration
├── validators.py        # Input validation
├── formatters.py        # Output formatters
├── date_utils.py        # Date/time utilities
└── platform.py          # Platform detection
```

**Key Responsibilities:**
- Reusable utility functions
- Common validation logic
- Output formatting helpers
- Logging setup
- Platform-specific helpers

---

## 🔄 Data Flow

### Example: User Confirmation Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. CLI Entry Point                                          │
│    $ bw-admin users confirm --org-id=xxx                   │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. CLI Command Handler (cli/commands/users.py)             │
│    - Parse arguments                                        │
│    - Load configuration                                     │
│    - Validate inputs                                        │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Configuration Manager (config/manager.py)                │
│    - Decrypt credentials                                    │
│    - Return config object                                   │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. User Service (core/users.py)                             │
│    - Create UserService instance                            │
│    - Call confirm_accepted_users()                          │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. API Client (api/cli_client.py or api/public_api.py)     │
│    - List members (status=1)                                │
│    - For each: confirm member                               │
│    - Return results                                         │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. External Service (Bitwarden CLI or API)                  │
│    - Execute actual operations                              │
│    - Return responses                                       │
└────────────┬────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Output Formatter (cli/output.py)                         │
│    - Format results (table/JSON/CSV)                        │
│    - Display to user                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Architecture

### Credential Management

**Storage:**
- All credentials encrypted at rest
- AES-256-CBC with PBKDF2 key derivation
- Compatible with OpenSSL for Bash/PS interop

**Access:**
- Master password required on first use per session
- Option to cache decrypted credentials in memory (with timeout)
- Environment variables for CI/CD use cases

**Best Practices:**
- Never log credentials
- Clear sensitive data from memory after use
- Support for system keychains (future enhancement)

### Input Validation

All user inputs validated at CLI layer:
- Organization IDs (UUID format)
- Email addresses (RFC 5322)
- URLs (proper scheme and format)
- File paths (existence and permissions)

### API Security

- HTTPS only (enforce TLS)
- API token rotation support
- Rate limiting respect
- Timeout configuration

---

## 🌍 Cross-Platform Support

### Platform Detection

```python
# bw_admin/utils/platform.py
import platform

def get_platform() -> str:
    """Return normalized platform name."""
    system = platform.system()
    if system == "Darwin":
        return "macos"
    elif system == "Windows":
        return "windows"
    elif system == "Linux":
        return "linux"
    else:
        return "unknown"
```

### Platform-Specific Behavior

| Feature | Linux | macOS | Windows |
|---------|-------|-------|---------|
| **Config Path** | ~/.config/bw-admin/ | ~/Library/Application Support/bw-admin/ | %APPDATA%\bw-admin\ |
| **Binary Name** | bw | bw | bw.exe |
| **Path Separator** | / | / | \ |
| **Encryption** | OpenSSL compatible | OpenSSL compatible | CryptoAPI compatible |
| **Keychain** | Secret Service API | Keychain | Credential Manager |

### BW CLI Wrapper

Abstract subprocess calls for cross-platform compatibility:

```python
# bw_admin/api/cli_client.py
def _find_bw_binary(self) -> str:
    """Locate bw binary across platforms."""
    binary_name = "bw.exe" if platform.system() == "Windows" else "bw"

    # Check PATH
    bw_path = shutil.which(binary_name)
    if bw_path:
        return bw_path

    # Check common locations
    common_paths = {
        "linux": ["/usr/local/bin/bw", "~/.local/bin/bw"],
        "macos": ["/usr/local/bin/bw", "/opt/homebrew/bin/bw"],
        "windows": [r"C:\Program Files\Bitwarden CLI\bw.exe"]
    }
    # ... search logic
```

---

## 📦 Package Structure

```
admin-scripts/
├── bw_admin/                   # Main Python package
│   ├── __init__.py
│   ├── __main__.py            # CLI entry point
│   ├── cli/                   # CLI layer
│   ├── core/                  # Business logic
│   ├── api/                   # API clients
│   ├── config/                # Configuration
│   └── utils/                 # Utilities
├── legacy/                     # Legacy scripts (Phase 5)
│   ├── bash/                  # Bash wrappers
│   ├── powershell/            # PowerShell wrappers
│   └── README.md              # Migration guide
├── tests/                      # Test suite
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docs/                       # Documentation
├── scripts/                    # Development helpers
├── setup.py                    # Package setup
├── pyproject.toml             # Modern Python packaging
├── requirements.txt           # Production dependencies
├── requirements-dev.txt       # Development dependencies
├── pytest.ini                 # Test configuration
├── .gitignore
└── README.md
```

---

## 🔌 Extension Points

The architecture is designed to be extensible:

### 1. New Commands

Add new CLI commands by creating command modules:

```python
# bw_admin/cli/commands/my_feature.py
import click
from bw_admin.core.my_feature import MyFeatureService

@click.group()
def my_feature():
    """My custom feature commands."""
    pass

@my_feature.command()
@click.option('--org-id', required=True)
def do_something(org_id):
    """Do something custom."""
    service = MyFeatureService(org_id=org_id)
    result = service.execute()
    click.echo(result)
```

### 2. New API Clients

Implement the `BWClient` interface:

```python
# bw_admin/api/custom_client.py
from bw_admin.api.client import BWClient

class CustomClient(BWClient):
    """Custom API client implementation."""
    # Implement required methods
```

### 3. New Report Types

Extend report generation:

```python
# bw_admin/core/reports.py
class ReportGenerator:
    def register_report_type(self, name: str, generator_func):
        """Register custom report generator."""
        pass
```

---

## 🧪 Testing Strategy

### Layered Testing Approach

| Layer | Test Type | Coverage Target | Mock Level |
|-------|-----------|-----------------|------------|
| **CLI** | Integration | 70% | Mock core services |
| **Core** | Unit | 90% | Mock API clients |
| **API** | Unit + Integration | 85% | Mock external services |
| **Config** | Unit | 90% | Mock file system |
| **Utils** | Unit | 90% | None (pure functions) |

### Test Doubles

```python
# tests/conftest.py
@pytest.fixture
def mock_bw_client():
    """Mock BWClient for testing."""
    return Mock(spec=BWClient)

# Use in tests
def test_confirm_users(mock_bw_client):
    service = UserService(client=mock_bw_client, org_id="test")
    service.confirm_accepted_users()
    assert mock_bw_client.list_members.called
```

---

## 🚀 Deployment & Distribution

### Installation Methods

**1. PyPI Package (Future):**
```bash
pip install bw-admin-tools
```

**2. Direct from Git:**
```bash
pip install git+https://github.com/bitwarden-labs/admin-scripts.git
```

**3. Development Install:**
```bash
git clone https://github.com/bitwarden-labs/admin-scripts.git
cd admin-scripts
pip install -e .
```

### Entry Point

```python
# setup.py
entry_points={
    'console_scripts': [
        'bw-admin=bw_admin.cli.main:cli',
    ],
}
```

After installation, `bw-admin` command is available globally.

---

## 📈 Performance Considerations

### Optimization Strategies

1. **Lazy Loading** - Import modules only when needed
2. **Caching** - Cache API responses where appropriate
3. **Batch Operations** - Batch API calls to reduce overhead
4. **Parallel Processing** - Use threading for independent operations
5. **Progress Indicators** - Show progress for long-running operations

### Example: Batch User Confirmation

```python
from concurrent.futures import ThreadPoolExecutor

def confirm_users_batch(members: List[Member], batch_size: int = 10):
    """Confirm users in parallel batches."""
    with ThreadPoolExecutor(max_workers=batch_size) as executor:
        futures = [
            executor.submit(confirm_member, member)
            for member in members
        ]
        results = [f.result() for f in futures]
    return results
```

---

## 🔄 Migration Path

### Phase-by-Phase Architecture Evolution

**Phase 0:** Architecture design ✅
**Phase 1:** Script analysis (architecture unchanged)
**Phase 2:** Core modules implemented (bw_admin/core, bw_admin/api)
**Phase 3:** CLI layer added (bw_admin/cli)
**Phase 4:** Config layer with encryption (bw_admin/config)
**Phase 5:** Legacy wrappers created
**Phase 6:** Full architecture realized

### Backward Compatibility

During transition, both old and new approaches coexist:

```bash
# Legacy (still works)
./Bash Scripts/bwConfirmAcceptedPeople.sh

# New unified CLI (Phase 3+)
bw-admin users confirm --org-id=xxx
```

---

## 📚 Technology Stack

| Layer | Technology | Justification |
|-------|------------|---------------|
| **Language** | Python 3.8+ | Cross-platform, rich ecosystem |
| **CLI Framework** | Click or Typer | Mature, well-documented |
| **HTTP Client** | requests | Industry standard |
| **Testing** | pytest | Flexible, plugin ecosystem |
| **Encryption** | cryptography | Secure, OpenSSL compatible |
| **Config Format** | JSON | Universal support |
| **Logging** | Python logging | Built-in, configurable |

---

## 🎯 Architecture Success Criteria

The architecture is considered successful when:

1. ✅ All 8 functional categories supported
2. ✅ 80%+ code coverage achieved
3. ✅ Cross-platform tests passing
4. ✅ Encrypted config working on all platforms
5. ✅ CLI response time < 2 seconds for simple operations
6. ✅ Legacy scripts still functional
7. ✅ Documentation complete for all public APIs
8. ✅ Zero hardcoded credentials

---

## 📎 Related Documents

- [script-inventory.md](script-inventory.md) - Current script catalog
- [current-state.md](current-state.md) - Assessment of existing code
- [testing-strategy.md](testing-strategy.md) - Testing approach
- [refactor-plan.md](refactor-plan.md) - Implementation roadmap

---

**Document Status:** ✅ Complete (Draft)
**Reviewers:** Pending
**Approval:** Pending
**Next Steps:** Review and finalize before Phase 2 implementation
