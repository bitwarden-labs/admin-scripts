# Development Environment Validation Script (PowerShell)
# Tests that the development environment is correctly set up

$ErrorCount = 0
$WarningCount = 0

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Dev Environment Validation Script" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

function Test-Pass {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Test-Fail {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
    $script:ErrorCount++
}

function Test-Warn {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
    $script:WarningCount++
}

function Show-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Gray
}

# Check Python version
Write-Host "1. Checking Python installation..."
try {
    $pythonVersion = (python --version 2>&1).ToString().Split()[1]
    $major, $minor = $pythonVersion.Split('.')[0..1]

    if ([int]$major -ge 3 -and [int]$minor -ge 8) {
        Test-Pass "Python $pythonVersion (meets requirement: 3.8+)"
    } else {
        Test-Fail "Python $pythonVersion (requires 3.8+)"
    }
} catch {
    Test-Fail "Python not found in PATH"
}
Write-Host ""

# Check virtual environment
Write-Host "2. Checking virtual environment..."
if (Test-Path "venv" -PathType Container) {
    Test-Pass "Virtual environment directory exists"

    if ($env:VIRTUAL_ENV) {
        Test-Pass "Virtual environment is activated"
        Show-Info "  Location: $env:VIRTUAL_ENV"
    } else {
        Test-Warn "Virtual environment exists but not activated"
        Show-Info "  Run: .\venv\Scripts\Activate.ps1"
    }
} else {
    Test-Warn "No virtual environment found"
    Show-Info "  Create one with: python -m venv venv"
}
Write-Host ""

# Check required tools
Write-Host "3. Checking required external tools..."

# Bitwarden CLI
try {
    $bwVersion = (bw --version 2>&1).ToString()
    Test-Pass "Bitwarden CLI installed ($bwVersion)"
} catch {
    Test-Warn "Bitwarden CLI (bw) not found"
    Show-Info "  Install: https://bitwarden.com/help/cli/"
}

# Git
try {
    $gitVersion = (git --version 2>&1).ToString().Split()[2]
    Test-Pass "Git installed ($gitVersion)"
} catch {
    Test-Fail "Git not found"
}
Write-Host ""

# Check Python packages
Write-Host "4. Checking Python packages..."
if ($env:VIRTUAL_ENV) {
    # Check pytest
    try {
        python -c "import pytest" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $pytestVersion = (python -c "import pytest; print(pytest.__version__)" 2>&1)
            Test-Pass "pytest installed ($pytestVersion)"
        } else {
            throw
        }
    } catch {
        Test-Fail "pytest not installed"
        Show-Info "  Install: pip install -r requirements-dev.txt"
    }

    # Check requests
    try {
        python -c "import requests" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Test-Pass "requests installed"
        } else {
            throw
        }
    } catch {
        Test-Warn "requests not installed"
    }

    # Check cryptography
    try {
        python -c "import cryptography" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Test-Pass "cryptography installed"
        } else {
            throw
        }
    } catch {
        Test-Warn "cryptography not installed"
    }
} else {
    Test-Warn "Cannot check packages - virtual environment not activated"
}
Write-Host ""

# Check directory structure
Write-Host "5. Checking project structure..."
$requiredDirs = @("docs", "tests", "tests\unit", "tests\integration", ".github\workflows")

foreach ($dir in $requiredDirs) {
    if (Test-Path $dir -PathType Container) {
        Test-Pass "Directory exists: $dir"
    } else {
        Test-Fail "Missing directory: $dir"
    }
}
Write-Host ""

# Check key files
Write-Host "6. Checking key files..."
$requiredFiles = @("pytest.ini", "requirements-dev.txt", "tests\conftest.py", ".github\workflows\test.yml")

foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Test-Pass "File exists: $file"
    } else {
        Test-Fail "Missing file: $file"
    }
}
Write-Host ""

# Try to collect tests
Write-Host "7. Validating test framework..."
if ($env:VIRTUAL_ENV) {
    try {
        python -c "import pytest" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Show-Info "Attempting to collect tests..."
            python -m pytest --collect-only -q 2>$null
            if ($LASTEXITCODE -eq 0) {
                Test-Pass "Test framework can collect tests"
            } else {
                Test-Warn "Test collection has issues (may need bw_admin package)"
            }
        } else {
            throw
        }
    } catch {
        Test-Warn "Skipping test validation (pytest not available)"
    }
} else {
    Test-Warn "Skipping test validation (virtual environment not activated)"
}
Write-Host ""

# Check documentation
Write-Host "8. Checking documentation..."
$docs = @("docs\refactor-plan.md", "docs\architecture.md", "docs\script-inventory.md")

foreach ($doc in $docs) {
    if (Test-Path $doc) {
        $docName = Split-Path $doc -Leaf
        Test-Pass "Documentation exists: $docName"
    } else {
        $docName = Split-Path $doc -Leaf
        Test-Warn "Missing documentation: $docName"
    }
}
Write-Host ""

# Summary
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

if ($ErrorCount -eq 0 -and $WarningCount -eq 0) {
    Write-Host "✓ All checks passed!" -ForegroundColor Green
    Write-Host "Your development environment is ready."
    exit 0
} elseif ($ErrorCount -eq 0) {
    Write-Host "⚠ Checks passed with $WarningCount warning(s)" -ForegroundColor Yellow
    Write-Host "Environment is functional but some optional components are missing."
    exit 0
} else {
    Write-Host "✗ $ErrorCount error(s) and $WarningCount warning(s) found" -ForegroundColor Red
    Write-Host "Please fix the errors above before proceeding."
    exit 1
}
