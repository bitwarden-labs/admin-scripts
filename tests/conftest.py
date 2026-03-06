"""
Shared pytest fixtures for admin-scripts test suite.

This file contains fixtures that are available to all tests without needing
to import them explicitly.
"""

import json
import os
import pytest
from pathlib import Path
from unittest.mock import Mock, MagicMock, patch
from typing import Dict, Any


# ============================================================================
# Mock Fixtures
# ============================================================================

@pytest.fixture
def mock_bw_cli():
    """
    Mock Bitwarden CLI wrapper.

    Provides mocked responses for common CLI operations without
    actually calling the bw binary.
    """
    mock = Mock()

    # Common CLI operations
    mock.unlock.return_value = "mock_session_key_abc123"
    mock.lock.return_value = None
    mock.sync.return_value = {"success": True}

    # List operations
    mock.list_members.return_value = []
    mock.list_collections.return_value = []
    mock.list_groups.return_value = []
    mock.list_items.return_value = []

    # Get operations
    mock.get_organization.return_value = {
        "id": "test-org-id",
        "name": "Test Organization"
    }

    # Confirm operations
    mock.confirm_member.return_value = {"success": True}

    return mock


@pytest.fixture
def mock_bw_api():
    """
    Mock Bitwarden API client.

    Provides mocked responses for Public API and Vault Management API calls.
    """
    mock = Mock()

    # Authentication
    mock.authenticate.return_value = "mock_access_token_xyz789"

    # Organizations
    mock.get_organization.return_value = {
        "id": "test-org-id",
        "name": "Test Organization",
        "seats": 10,
        "plan": "enterprise"
    }

    # Members
    mock.list_members.return_value = []
    mock.get_member.return_value = {
        "id": "member-1",
        "email": "user@example.com",
        "status": 2,
        "type": 2
    }
    mock.invite_member.return_value = {"id": "new-member-id"}
    mock.confirm_member.return_value = {"success": True}

    # Collections
    mock.list_collections.return_value = []
    mock.get_collection.return_value = {
        "id": "collection-1",
        "name": "Test Collection"
    }
    mock.create_collection.return_value = {"id": "new-collection-id"}

    # Groups
    mock.list_groups.return_value = []
    mock.create_group.return_value = {"id": "new-group-id"}

    # Events
    mock.get_events.return_value = {"data": [], "continuationToken": None}

    return mock


@pytest.fixture
def mock_subprocess():
    """
    Mock subprocess.run for CLI command execution.

    Prevents actual subprocess calls during tests.
    """
    with patch('subprocess.run') as mock_run:
        mock_run.return_value = Mock(
            stdout='{"success": true}',
            stderr='',
            returncode=0
        )
        yield mock_run


# ============================================================================
# Configuration Fixtures
# ============================================================================

@pytest.fixture
def sample_config(tmp_path) -> Dict[str, Any]:
    """
    Create a temporary test configuration file.

    Returns:
        Dict with config data and path to temp config file
    """
    config_data = {
        "api_url": "https://vault.bitwarden.com/api",
        "identity_url": "https://vault.bitwarden.com/identity",
        "org_id": "test-org-id-123",
        "test_mode": True
    }

    config_file = tmp_path / "test-config.json"
    config_file.write_text(json.dumps(config_data, indent=2))

    return {
        "path": str(config_file),
        "data": config_data
    }


@pytest.fixture
def encrypted_config(tmp_path):
    """
    Create a mock encrypted configuration.

    For testing encryption/decryption workflows.
    """
    encrypted_data = "U2FsdGVkX1+mock_encrypted_data_here=="
    encrypted_file = tmp_path / "encrypted-config.enc"
    encrypted_file.write_text(encrypted_data)

    return {
        "path": str(encrypted_file),
        "data": encrypted_data,
        "key": "test_encryption_key_32_bytes!!"
    }


# ============================================================================
# Sample Data Fixtures
# ============================================================================

@pytest.fixture
def sample_members():
    """Sample organization members for testing."""
    return [
        {
            "id": "member-1",
            "email": "alice@example.com",
            "name": "Alice User",
            "status": 2,  # Confirmed
            "type": 2,    # User
            "accessAll": False
        },
        {
            "id": "member-2",
            "email": "bob@example.com",
            "name": "Bob Admin",
            "status": 2,  # Confirmed
            "type": 1,    # Admin
            "accessAll": True
        },
        {
            "id": "member-3",
            "email": "charlie@example.com",
            "name": "Charlie Pending",
            "status": 1,  # Accepted (needs confirmation)
            "type": 2,    # User
            "accessAll": False
        }
    ]


@pytest.fixture
def sample_collections():
    """Sample collections for testing."""
    return [
        {
            "id": "collection-1",
            "organizationId": "test-org-id",
            "name": "Engineering",
            "externalId": None
        },
        {
            "id": "collection-2",
            "organizationId": "test-org-id",
            "name": "Marketing",
            "externalId": None
        }
    ]


@pytest.fixture
def sample_groups():
    """Sample groups for testing."""
    return [
        {
            "id": "group-1",
            "organizationId": "test-org-id",
            "name": "Developers",
            "accessAll": False,
            "externalId": None
        },
        {
            "id": "group-2",
            "organizationId": "test-org-id",
            "name": "Admins",
            "accessAll": True,
            "externalId": None
        }
    ]


@pytest.fixture
def sample_vault_items():
    """Sample vault items for testing."""
    return [
        {
            "id": "item-1",
            "organizationId": "test-org-id",
            "type": 1,  # Login
            "name": "Example Login",
            "login": {
                "username": "user@example.com",
                "password": "supersecret123",
                "uris": [{"uri": "https://example.com"}]
            }
        },
        {
            "id": "item-2",
            "organizationId": "test-org-id",
            "type": 2,  # Secure Note
            "name": "Important Note",
            "notes": "This is a secure note"
        }
    ]


# ============================================================================
# Test Organization Credentials
# ============================================================================

@pytest.fixture
def test_org_credentials():
    """
    Load test organization credentials from environment variables.

    Required environment variables:
    - BW_TEST_ORG_ID
    - BW_TEST_CLIENT_ID (optional)
    - BW_TEST_CLIENT_SECRET (optional)

    For E2E tests only. Unit/integration tests should use mocks.
    """
    return {
        "org_id": os.getenv("BW_TEST_ORG_ID", "test-org-id"),
        "client_id": os.getenv("BW_TEST_CLIENT_ID"),
        "client_secret": os.getenv("BW_TEST_CLIENT_SECRET"),
    }


@pytest.fixture
def skip_if_no_credentials(test_org_credentials):
    """
    Skip test if real credentials are not available.

    Usage:
        def test_something(skip_if_no_credentials):
            # Test code that requires real credentials
    """
    if not test_org_credentials["client_id"]:
        pytest.skip("Test requires BW_TEST_CLIENT_ID environment variable")


# ============================================================================
# File System Fixtures
# ============================================================================

@pytest.fixture
def temp_workspace(tmp_path):
    """
    Create a temporary workspace directory for testing file operations.

    Returns:
        Path to temporary directory
    """
    workspace = tmp_path / "workspace"
    workspace.mkdir()

    # Create common subdirectories
    (workspace / "exports").mkdir()
    (workspace / "configs").mkdir()
    (workspace / "logs").mkdir()

    return workspace


@pytest.fixture
def mock_file_system(tmp_path):
    """
    Create a mock file system structure for testing.

    Provides a realistic directory structure with sample files.
    """
    fs = {
        "root": tmp_path,
        "exports": tmp_path / "exports",
        "configs": tmp_path / "configs",
    }

    # Create directories
    for path in fs.values():
        if isinstance(path, Path):
            path.mkdir(exist_ok=True)

    # Create sample files
    (fs["configs"] / "config.json").write_text('{"org_id": "test"}')
    (fs["exports"] / "vault-export.json").write_text('{"items": []}')

    return fs


# ============================================================================
# Cleanup Fixtures
# ============================================================================

@pytest.fixture(autouse=True)
def cleanup_temp_files():
    """
    Automatically clean up temporary files after each test.

    This fixture runs for every test automatically.
    """
    # Setup (runs before test)
    temp_files = []

    yield temp_files

    # Teardown (runs after test)
    for temp_file in temp_files:
        if os.path.exists(temp_file):
            try:
                os.remove(temp_file)
            except Exception:
                pass  # Best effort cleanup


# ============================================================================
# Platform-Specific Fixtures
# ============================================================================

@pytest.fixture
def skip_on_windows():
    """Skip test on Windows platforms."""
    if os.name == 'nt':
        pytest.skip("Test not supported on Windows")


@pytest.fixture
def skip_on_linux():
    """Skip test on Linux platforms."""
    if os.name == 'posix' and os.uname().sysname == 'Linux':
        pytest.skip("Test not supported on Linux")


@pytest.fixture
def skip_on_macos():
    """Skip test on macOS platforms."""
    if os.name == 'posix' and os.uname().sysname == 'Darwin':
        pytest.skip("Test not supported on macOS")


# ============================================================================
# Debugging Fixtures
# ============================================================================

@pytest.fixture
def debug_mode():
    """
    Enable debug mode for tests.

    Set BW_ADMIN_DEBUG=1 to see additional debug output during tests.
    """
    return os.getenv("BW_ADMIN_DEBUG", "0") == "1"


# ============================================================================
# Hooks
# ============================================================================

def pytest_configure(config):
    """
    Pytest configuration hook.

    Sets up test environment before test collection.
    """
    # Ensure test mode is enabled
    os.environ["BW_ADMIN_TEST_MODE"] = "1"


def pytest_collection_modifyitems(config, items):
    """
    Pytest hook to modify test collection.

    Adds markers to tests based on their location and requirements.
    """
    for item in items:
        # Add marker based on test path
        if "integration" in str(item.fspath):
            item.add_marker(pytest.mark.integration)
        elif "e2e" in str(item.fspath):
            item.add_marker(pytest.mark.e2e)
            item.add_marker(pytest.mark.slow)

        # Add marker if test name suggests it needs bw CLI
        if "bw_cli" in item.name or "cli" in item.name:
            item.add_marker(pytest.mark.requires_bw)
