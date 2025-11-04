# Testing Strategy

**Phase:** 0 (Foundation)
**Framework:** pytest
**Target Coverage:** 80%+

---

## 🎯 Testing Philosophy

The admin-scripts testing strategy is built on these principles:

1. **Comprehensive Coverage** - Test all critical paths
2. **Fast Feedback** - Unit tests run in seconds
3. **Reliable** - Tests are deterministic and reproducible
4. **Maintainable** - Tests are clear and easy to update
5. **Platform-Agnostic** - Tests run on Linux, macOS, and Windows

---

## 📋 Testing Pyramid

```
        /\
       /  \
      /    \     E2E Tests (5%)
     /------\    - Full workflow tests
    /        \   - Real Bitwarden instance
   /          \  - Slow, comprehensive
  /------------\
 /              \ Integration Tests (25%)
/                \ - Component interaction
/------------------\ - Mock API responses
/                    \ - Database required
/----------------------\
/                        \ Unit Tests (70%)
/--------------------------\ - Pure functions
                             - No external deps
                             - Fast, isolated
```

---

## 🧪 Test Categories

### 1. Unit Tests (70% of test suite)

**Purpose:** Test individual functions and classes in isolation

**Location:** `tests/unit/`

**Characteristics:**
- No external dependencies (mock everything)
- Fast execution (< 1 second total)
- High coverage of edge cases
- Test one thing at a time

**Example:**
```python
# tests/unit/test_encryption.py
def test_encrypt_decrypt_roundtrip():
    """Test that encrypted data can be decrypted"""
    from bw_admin.config.encryption import encrypt, decrypt

    plaintext = "sensitive_password"
    key = "test_encryption_key_32_bytes!!"

    encrypted = encrypt(plaintext, key)
    decrypted = decrypt(encrypted, key)

    assert decrypted == plaintext
    assert encrypted != plaintext  # Actually encrypted
```

### 2. Integration Tests (25% of test suite)

**Purpose:** Test how components work together

**Location:** `tests/integration/`

**Characteristics:**
- Mock external APIs (Bitwarden)
- Test component interactions
- Moderate execution time (< 30 seconds)
- Use fixtures for complex setup

**Example:**
```python
# tests/integration/test_user_confirm.py
@pytest.mark.integration
def test_confirm_users_workflow(mock_bw_api):
    """Test complete user confirmation workflow"""
    from bw_admin.core.users import confirm_accepted_users

    # Mock API returns 3 pending users
    mock_bw_api.list_members.return_value = [
        {"id": "1", "status": 1},
        {"id": "2", "status": 1},
        {"id": "3", "status": 1},
    ]

    result = confirm_accepted_users(org_id="test-org")

    assert result.confirmed == 3
    assert mock_bw_api.confirm_member.call_count == 3
```

### 3. End-to-End Tests (5% of test suite)

**Purpose:** Test complete workflows against real or staging environment

**Location:** `tests/e2e/`

**Characteristics:**
- Requires test Bitwarden organization
- Slow execution (minutes)
- Run in CI only or manually
- Marked with `@pytest.mark.e2e`

**Example:**
```python
# tests/e2e/test_vault_export.py
@pytest.mark.e2e
@pytest.mark.slow
def test_full_vault_export_workflow(test_org_credentials):
    """Test exporting actual vault data"""
    from bw_admin.cli import main

    result = main([
        "vault", "export",
        "--org-id", test_org_credentials.org_id,
        "--output", "/tmp/test-export.json",
        "--encrypt"
    ])

    assert result.exit_code == 0
    assert os.path.exists("/tmp/test-export.json")
    # Verify file is actually encrypted
```

---

## 🏗️ Test Infrastructure

### Directory Structure

```
tests/
├── unit/
│   ├── test_bw_wrapper.py      # BW CLI wrapper tests
│   ├── test_api_client.py      # API client tests
│   ├── test_encryption.py      # Encryption/decryption
│   ├── test_config.py          # Config management
│   └── test_utils.py           # Utility functions
├── integration/
│   ├── test_user_operations.py # User workflows
│   ├── test_collections.py     # Collection operations
│   └── test_reports.py         # Report generation
├── e2e/
│   ├── test_cli_commands.py    # Full CLI workflows
│   └── test_migrations.py      # Migration scenarios
├── fixtures/
│   ├── mock_responses.json     # Mock API responses
│   ├── sample_exports.json     # Sample data files
│   └── test_configs.py         # Test configurations
├── conftest.py                 # Shared pytest fixtures
└── pytest.ini                  # Pytest configuration
```

### Fixtures (`conftest.py`)

```python
import pytest
from unittest.mock import Mock, MagicMock

@pytest.fixture
def mock_bw_cli():
    """Mock Bitwarden CLI wrapper"""
    mock = Mock()
    mock.unlock.return_value = "fake_session_key"
    mock.list_members.return_value = []
    return mock

@pytest.fixture
def mock_bw_api():
    """Mock Bitwarden API client"""
    mock = Mock()
    mock.get_organization.return_value = {"id": "test-org", "name": "Test Org"}
    return mock

@pytest.fixture
def sample_config(tmp_path):
    """Create temporary test config"""
    config = {
        "api_url": "https://vault.bitwarden.com/api",
        "identity_url": "https://vault.bitwarden.com/identity",
        "org_id": "test-org-id"
    }
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps(config))
    return config_file

@pytest.fixture
def test_org_credentials():
    """Load test organization credentials from environment"""
    return {
        "org_id": os.getenv("BW_TEST_ORG_ID"),
        "client_id": os.getenv("BW_TEST_CLIENT_ID"),
        "client_secret": os.getenv("BW_TEST_CLIENT_SECRET"),
    }
```

---

## 🎭 Mocking Strategy

### What to Mock

✅ **Always Mock:**
- External API calls (Bitwarden API)
- BW CLI subprocess calls
- File system operations (unless testing file I/O specifically)
- Network requests
- Time-dependent operations (`datetime.now()`)

❌ **Never Mock:**
- Pure functions (encryption, parsing, formatting)
- Domain logic (business rules)
- Data transformations
- Simple utilities

### Mock Examples

```python
# Mock subprocess calls to bw CLI
@patch('subprocess.run')
def test_bw_list_members(mock_run):
    mock_run.return_value = Mock(
        stdout='[{"id": "1", "email": "user@example.com"}]',
        returncode=0
    )

    result = bw_cli.list_members(session_key="test", org_id="org-1")
    assert len(result) == 1

# Mock API requests
@patch('requests.post')
def test_api_authentication(mock_post):
    mock_post.return_value = Mock(
        json=lambda: {"access_token": "fake_token"},
        status_code=200
    )

    token = api_client.authenticate(client_id="id", client_secret="secret")
    assert token == "fake_token"
```

---

## 🚀 Test Execution

### Local Development

```bash
# Run all tests
pytest

# Run specific category
pytest tests/unit/
pytest tests/integration/

# Run with coverage
pytest --cov=bw_admin --cov-report=html

# Run fast tests only (skip slow E2E)
pytest -m "not slow"

# Run specific test file
pytest tests/unit/test_encryption.py

# Run specific test function
pytest tests/unit/test_encryption.py::test_encrypt_decrypt_roundtrip

# Verbose output
pytest -v

# Show print statements
pytest -s
```

### CI/CD Pipeline

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        python-version: [3.8, 3.9, 3.10, 3.11]

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: ${{ matrix.python-version }}

      - name: Install dependencies
        run: |
          pip install -r requirements-dev.txt

      - name: Run unit tests
        run: pytest tests/unit/ -v

      - name: Run integration tests
        run: pytest tests/integration/ -v

      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

---

## 📊 Coverage Requirements

### Target Coverage

| Component | Target | Current | Notes |
|-----------|--------|---------|-------|
| Core logic (`bw_admin/core/`) | 90%+ | TBD | Critical business logic |
| API clients (`bw_admin/api/`) | 80%+ | TBD | External integrations |
| CLI interface (`bw_admin/cli/`) | 70%+ | TBD | User-facing code |
| Utilities (`bw_admin/utils/`) | 85%+ | TBD | Reusable functions |
| Config (`bw_admin/config/`) | 80%+ | TBD | Configuration management |
| **Overall** | **80%+** | **0%** | **Initial target** |

### Coverage Enforcement

```ini
# pytest.ini or .coveragerc
[coverage:run]
source = bw_admin
omit =
    */tests/*
    */venv/*
    */__pycache__/*

[coverage:report]
fail_under = 80
show_missing = true
skip_covered = false
```

---

## 🔍 Test Data Management

### Fixtures and Sample Data

**Location:** `tests/fixtures/`

**Files:**
- `mock_responses.json` - Sample API responses
- `sample_vault_export.json` - Example vault data
- `test_collections.json` - Collection structures
- `keeper_export_sample.csv` - Migration test data

**Usage:**
```python
@pytest.fixture
def sample_api_response():
    """Load sample API response from fixtures"""
    with open("tests/fixtures/mock_responses.json") as f:
        return json.load(f)["list_members_response"]
```

### Test Database (if needed)

For integration tests requiring database:

```python
@pytest.fixture(scope="session")
def test_db():
    """Create temporary test database"""
    db = create_test_database()
    yield db
    db.cleanup()
```

---

## ⚡ Performance Testing

### Test Execution Time Targets

| Category | Target | Action if Exceeded |
|----------|--------|-------------------|
| Single unit test | < 10ms | Optimize or mock |
| Unit test suite | < 5s | Review slow tests |
| Integration test suite | < 30s | Parallelize or optimize |
| Full test suite | < 2 min | Add parallel execution |

### Profiling Slow Tests

```bash
# Identify slowest tests
pytest --durations=10

# Profile specific test
pytest --profile tests/integration/test_slow.py
```

---

## 🐛 Debugging Tests

### Useful pytest Options

```bash
# Stop at first failure
pytest -x

# Enter debugger on failure
pytest --pdb

# Show local variables on failure
pytest -l

# Capture output (no -s)
pytest --capture=no

# Re-run failed tests only
pytest --lf
```

### Print Debugging

```python
def test_something(capfd):
    """Test with captured output"""
    print("Debug info")
    result = function_under_test()

    out, err = capfd.readouterr()
    assert "Debug info" in out
```

---

## 📝 Test Naming Conventions

### Test File Names
- `test_<module_name>.py` - Mirror source structure
- Example: `bw_admin/core/users.py` → `tests/unit/test_users.py`

### Test Function Names
```python
# Good names (descriptive)
def test_encrypt_returns_different_value_than_input():
def test_confirm_users_raises_error_when_org_not_found():
def test_parse_config_handles_missing_file_gracefully():

# Bad names (vague)
def test_encrypt():
def test_users():
def test_config():
```

### Test Documentation

```python
def test_complex_scenario():
    """
    Test that user confirmation works with mixed statuses.

    Scenario:
    - 3 pending users (status=1)
    - 2 confirmed users (status=2)
    - 1 revoked user (status=-1)

    Expected:
    - Only pending users should be confirmed
    - Confirmed and revoked users should be skipped
    """
    # Test implementation
```

---

## 🚨 Test Markers

Define custom markers in `pytest.ini`:

```ini
[pytest]
markers =
    slow: marks tests as slow (deselect with '-m "not slow"')
    integration: integration tests requiring mocks
    e2e: end-to-end tests requiring real environment
    api: tests that interact with Bitwarden API
    cli: tests that invoke CLI commands
    windows_only: tests that only run on Windows
    linux_only: tests that only run on Linux
```

**Usage:**
```python
@pytest.mark.slow
@pytest.mark.e2e
def test_full_migration():
    """End-to-end migration test"""
    pass

# Run tests by marker
pytest -m integration
pytest -m "not slow"
pytest -m "api and not e2e"
```

---

## 📚 Testing Best Practices

### DO:
✅ Write tests before or alongside code (TDD encouraged)
✅ Keep tests simple and focused (one assertion per test when possible)
✅ Use descriptive test names that explain the scenario
✅ Mock external dependencies consistently
✅ Clean up resources (files, connections) in fixtures
✅ Use parametrize for testing multiple inputs
✅ Write tests for both success and failure paths

### DON'T:
❌ Write tests that depend on each other
❌ Use sleep() for timing (use mocks instead)
❌ Test implementation details (test behavior, not internals)
❌ Commit test credentials or secrets
❌ Skip writing tests because "it's simple code"
❌ Leave failing tests in the codebase

---

## 🔄 Continuous Improvement

### Metrics to Track

1. **Test Coverage** - Maintain 80%+
2. **Test Execution Time** - Keep under 2 minutes
3. **Flaky Tests** - Zero tolerance
4. **Test to Code Ratio** - Aim for 1:1 or better

### Regular Reviews

- **Weekly:** Review failed CI runs
- **Monthly:** Analyze coverage gaps
- **Quarterly:** Update testing strategy

---

**Document Status:** ✅ Complete (Phase 0)
**Last Updated:** 2025-11-04
**Next Review:** After Phase 2 (when core modules exist)
