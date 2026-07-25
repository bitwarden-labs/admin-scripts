#!/bin/bash
# Development Environment Validation Script
# Tests that the development environment is correctly set up

set -e

echo "======================================"
echo "Dev Environment Validation Script"
echo "======================================"
echo ""

ERRORS=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ERRORS=$((ERRORS + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

info() {
    echo -e "ℹ $1"
}

# Check Python version
echo "1. Checking Python installation..."
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

    if [ "$MAJOR" -ge 3 ] && [ "$MINOR" -ge 8 ]; then
        pass "Python $PYTHON_VERSION (meets requirement: 3.8+)"
    else
        fail "Python $PYTHON_VERSION (requires 3.8+)"
    fi
else
    fail "Python 3 not found in PATH"
fi
echo ""

# Check virtual environment
echo "2. Checking virtual environment..."
if [ -d "venv" ] || [ -d ".venv" ]; then
    pass "Virtual environment directory exists"

    if [ -n "$VIRTUAL_ENV" ]; then
        pass "Virtual environment is activated"
        info "  Location: $VIRTUAL_ENV"
    else
        warn "Virtual environment exists but not activated"
        info "  Run: source venv/bin/activate"
    fi
else
    warn "No virtual environment found"
    info "  Create one with: python3 -m venv venv"
fi
echo ""

# Check required tools
echo "3. Checking required external tools..."

# Bitwarden CLI
if command -v bw &> /dev/null; then
    BW_VERSION=$(bw --version)
    pass "Bitwarden CLI installed ($BW_VERSION)"
else
    warn "Bitwarden CLI (bw) not found"
    info "  Install: https://bitwarden.com/help/cli/"
fi

# jq (for legacy scripts)
if command -v jq &> /dev/null; then
    JQ_VERSION=$(jq --version)
    pass "jq installed ($JQ_VERSION)"
else
    warn "jq not found (needed for legacy Bash scripts)"
    info "  Install: https://stedolan.github.io/jq/download/"
fi

# Git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    pass "Git installed ($GIT_VERSION)"
else
    fail "Git not found"
fi
echo ""

# Check Python packages
echo "4. Checking Python packages..."
if [ -n "$VIRTUAL_ENV" ]; then
    # Check if pytest is installed
    if python3 -c "import pytest" 2>/dev/null; then
        PYTEST_VERSION=$(python3 -c "import pytest; print(pytest.__version__)")
        pass "pytest installed ($PYTEST_VERSION)"
    else
        fail "pytest not installed"
        info "  Install: pip install -r requirements-dev.txt"
    fi

    # Check if requests is installed
    if python3 -c "import requests" 2>/dev/null; then
        pass "requests installed"
    else
        warn "requests not installed"
    fi

    # Check if cryptography is installed
    if python3 -c "import cryptography" 2>/dev/null; then
        pass "cryptography installed"
    else
        warn "cryptography not installed"
    fi
else
    warn "Cannot check packages - virtual environment not activated"
fi
echo ""

# Check directory structure
echo "5. Checking project structure..."
REQUIRED_DIRS=("docs" "tests" "tests/unit" "tests/integration" ".github/workflows")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        pass "Directory exists: $dir"
    else
        fail "Missing directory: $dir"
    fi
done
echo ""

# Check key files
echo "6. Checking key files..."
REQUIRED_FILES=("pytest.ini" "requirements-dev.txt" "tests/conftest.py" ".github/workflows/test.yml")

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        pass "File exists: $file"
    else
        fail "Missing file: $file"
    fi
done
echo ""

# Try to collect tests
echo "7. Validating test framework..."
if [ -n "$VIRTUAL_ENV" ] && python3 -c "import pytest" 2>/dev/null; then
    info "Attempting to collect tests..."
    if python3 -m pytest --collect-only -q 2>/dev/null; then
        pass "Test framework can collect tests"
    else
        warn "Test collection has issues (may need bw_admin package)"
    fi
else
    warn "Skipping test validation (pytest not available)"
fi
echo ""

# Check documentation
echo "8. Checking documentation..."
DOCS=("docs/refactor-plan.md" "docs/architecture.md" "docs/script-inventory.md")

for doc in "${DOCS[@]}"; do
    if [ -f "$doc" ]; then
        pass "Documentation exists: $(basename $doc)"
    else
        warn "Missing documentation: $(basename $doc)"
    fi
done
echo ""

# Summary
echo "======================================"
echo "Validation Summary"
echo "======================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo "Your development environment is ready."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Checks passed with $WARNINGS warning(s)${NC}"
    echo "Environment is functional but some optional components are missing."
    exit 0
else
    echo -e "${RED}✗ $ERRORS error(s) and $WARNINGS warning(s) found${NC}"
    echo "Please fix the errors above before proceeding."
    exit 1
fi
