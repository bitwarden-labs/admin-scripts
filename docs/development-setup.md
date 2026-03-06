# Development Environment Setup

**Phase:** 0 (Foundation)
**Target Audience:** Developers contributing to admin-scripts
**Est. Setup Time:** 15-30 minutes

---

## 🎯 Prerequisites

Before setting up the development environment, ensure you have:

### Required Software

| Tool | Minimum Version | Purpose | Installation |
|------|----------------|---------|--------------|
| **Python** | 3.8+ | Core runtime | [python.org](https://www.python.org/downloads/) |
| **Bitwarden CLI** | Latest | Vault operations | [CLI Guide](https://bitwarden.com/help/cli/) |
| **Git** | 2.x | Version control | [git-scm.com](https://git-scm.com/) |
| **jq** | 1.6+ | JSON processing (for legacy scripts) | [stedolan.github.io/jq](https://stedolan.github.io/jq/download/) |

### Optional (Platform-Specific)

| Tool | Platform | Purpose |
|------|----------|---------|
| **Bash** | Linux/macOS | Running Bash scripts |
| **PowerShell** | Windows/macOS/Linux | Running PowerShell scripts |
| **bws CLI** | All | Secrets Manager operations |
| **OpenSSL** | Linux/macOS | Encryption operations |

---

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/bitwarden-labs/admin-scripts.git
cd admin-scripts
```

### 2. Set Up Python Environment

Create a virtual environment to isolate dependencies:

```bash
# Create virtual environment
python3 -m venv venv

# Activate it
# On Linux/macOS:
source venv/bin/activate

# On Windows:
venv\Scripts\activate
```

### 3. Install Python Dependencies

```bash
# Install development dependencies
pip install -r requirements-dev.txt

# If requirements-dev.txt doesn't exist yet (Phase 0), install manually:
pip install pytest pytest-cov requests pandas cryptography
```

### 4. Verify Installation

```bash
# Check Python version
python --version  # Should be 3.8+

# Check Bitwarden CLI
bw --version

# Check jq
jq --version

# Check pytest
pytest --version
```

### 5. Configure Pre-Commit Hooks (Recommended)

```bash
# Install pre-commit
pip install pre-commit

# Set up git hooks
pre-commit install
```

---

## 📁 Repository Structure

After setup, your directory should look like:

```
admin-scripts/
├── venv/                    # Python virtual environment (ignored by git)
├── API Scripts/             # Legacy API-based scripts
├── Bash Scripts/            # Legacy Bash scripts
├── Powershell/              # Legacy PowerShell scripts
├── Python/                  # Legacy Python scripts
├── bw_admin/                # NEW: Refactored Python modules (Phase 2+)
│   ├── core/               # Core business logic
│   ├── cli/                # CLI interface (Phase 3+)
│   ├── api/                # API clients
│   ├── config/             # Configuration management (Phase 4+)
│   └── utils/              # Shared utilities
├── tests/                   # NEW: Test suite (Phase 0+)
│   ├── unit/               # Unit tests
│   ├── integration/        # Integration tests
│   └── fixtures/           # Test data
├── docs/                    # Documentation
├── scripts/                 # NEW: Helper scripts for development
└── README.md
```

---

## 🧪 Running Tests

### Run All Tests

```bash
# From repository root
pytest
```

### Run Specific Test Categories

```bash
# Unit tests only
pytest tests/unit/

# Integration tests only
pytest tests/integration/

# With coverage report
pytest --cov=bw_admin --cov-report=html

# View coverage report
open htmlcov/index.html  # macOS
xdg-open htmlcov/index.html  # Linux
start htmlcov/index.html  # Windows
```

### Test Markers

```bash
# Run fast tests only
pytest -m "not slow"

# Run tests requiring API access
pytest -m "api"

# Skip integration tests
pytest -m "not integration"
```

---

## 🔐 Configuration

### Setting Up Test Credentials

For running integration tests, you'll need test credentials:

```bash
# Create config directory
mkdir -p ~/.config/bw-admin

# Create encrypted config (Phase 4+)
bw-admin config init

# Or manually create test config
cat > ~/.config/bw-admin/test-config.json <<EOF
{
  "test_mode": true,
  "api_url": "https://vault.bitwarden.com/api",
  "identity_url": "https://vault.bitwarden.com/identity",
  "test_org_id": "your-test-org-id"
}
EOF
```

**⚠️ Important:**
- Never commit real credentials
- Use dedicated test organization
- Keep test config out of repository

---

## 🛠️ Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Changes

Edit code in your preferred editor:
- VS Code (recommended): Includes Python extension
- PyCharm: Full IDE experience
- Vim/Neovim: For terminal enthusiasts

### 3. Run Tests Frequently

```bash
# Quick check during development
pytest tests/unit/

# Full test suite before committing
pytest
```

### 4. Format Code

```bash
# Auto-format with black (if configured)
black bw_admin/

# Check with flake8
flake8 bw_admin/
```

### 5. Commit Changes

```bash
git add <files>
git commit -m "Brief description of changes"
```

Pre-commit hooks will automatically:
- Run linters
- Check for secrets
- Format code
- Run fast tests

### 6. Push and Create PR

```bash
git push origin feature/your-feature-name
# Then create PR on GitHub
```

---

## 🐛 Troubleshooting

### "bw command not found"

**Solution:** Add Bitwarden CLI to PATH:

```bash
# Linux/macOS
export PATH="$PATH:/path/to/bw"

# Or install globally
# macOS (Homebrew)
brew install bitwarden-cli

# Linux (snap)
snap install bw
```

### "Module not found" errors

**Solution:** Ensure virtual environment is activated:

```bash
source venv/bin/activate  # Linux/macOS
venv\Scripts\activate     # Windows
```

### Python version issues

**Solution:** Use `python3` explicitly or set up pyenv:

```bash
# Install pyenv (macOS)
brew install pyenv

# Install Python 3.10
pyenv install 3.10.0
pyenv local 3.10.0
```

### Permission errors with bw CLI

**Solution:** Ensure bw is executable:

```bash
chmod +x /path/to/bw
```

### Tests failing with "Organization not found"

**Solution:** Set up test organization ID in config:

```bash
export BW_TEST_ORG_ID="your-test-org-id"
```

---

## 📚 Additional Resources

### Documentation
- [script-inventory.md](script-inventory.md) - Catalog of all scripts
- [architecture.md](architecture.md) - System design
- [testing-strategy.md](testing-strategy.md) - Testing approach

### External Links
- [Bitwarden CLI Documentation](https://bitwarden.com/help/cli/)
- [Bitwarden API Reference](https://bitwarden.com/help/api/)
- [Python Testing with pytest](https://docs.pytest.org/)

### Development Tools
- [Black Code Formatter](https://github.com/psf/black)
- [Flake8 Linter](https://flake8.pycqa.org/)
- [pre-commit Framework](https://pre-commit.com/)

---

## 🤝 Getting Help

- **Documentation:** Check [docs/](../docs/) folder first
- **Issues:** Search [GitHub Issues](https://github.com/bitwarden-labs/admin-scripts/issues)
- **Community:** [Bitwarden Community Forums](https://community.bitwarden.com/)

---

## 📋 Development Checklist

Before submitting a PR, ensure:

- [ ] All tests pass (`pytest`)
- [ ] Code is formatted (`black bw_admin/`)
- [ ] No linting errors (`flake8 bw_admin/`)
- [ ] Documentation updated if needed
- [ ] CHANGELOG.md updated (if applicable)
- [ ] No secrets or credentials committed
- [ ] Branch is up to date with main

---

**Document Status:** ✅ Complete (Phase 0)
**Last Updated:** 2025-11-04
**Maintained By:** Admin-Scripts Team
