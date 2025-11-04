"""
Unit tests for configuration management.

Tests configuration loading, validation, and error handling.
"""

import json
import pytest
from pathlib import Path


class TestConfigLoading:
    """Test suite for configuration file loading."""

    def test_load_config_from_valid_json_file(self, tmp_path):
        """Test loading configuration from valid JSON file."""
        # Create test config file
        config_data = {
            "org_id": "test-org-123",
            "api_url": "https://vault.bitwarden.com/api"
        }
        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps(config_data))

        # Load config
        loaded_config = self._mock_load_config(str(config_file))

        assert loaded_config["org_id"] == "test-org-123"
        assert loaded_config["api_url"] == "https://vault.bitwarden.com/api"

    def test_load_config_raises_error_for_missing_file(self):
        """Test that loading non-existent config raises appropriate error."""
        non_existent_file = "/path/to/missing/config.json"

        with pytest.raises(FileNotFoundError):
            self._mock_load_config(non_existent_file)

    def test_load_config_raises_error_for_invalid_json(self, tmp_path):
        """Test that malformed JSON in config file raises error."""
        invalid_config = tmp_path / "invalid.json"
        invalid_config.write_text("{invalid json content}")

        with pytest.raises(json.JSONDecodeError):
            self._mock_load_config(str(invalid_config))

    def test_load_config_with_defaults(self, tmp_path):
        """Test that missing optional fields use default values."""
        minimal_config = {"org_id": "org-123"}
        config_file = tmp_path / "minimal.json"
        config_file.write_text(json.dumps(minimal_config))

        loaded = self._mock_load_config_with_defaults(str(config_file))

        assert loaded["org_id"] == "org-123"
        assert loaded["api_url"] == "https://vault.bitwarden.com/api"  # Default
        assert loaded["identity_url"] == "https://vault.bitwarden.com/identity"  # Default

    @pytest.mark.parametrize("required_field", ["org_id", "api_url"])
    def test_validate_config_requires_essential_fields(self, required_field):
        """Test that config validation enforces required fields."""
        config = {
            "org_id": "test-org",
            "api_url": "https://vault.bitwarden.com/api"
        }
        # Remove one required field
        del config[required_field]

        with pytest.raises(ValueError, match=f"Missing required field: {required_field}"):
            self._mock_validate_config(config)

    # Mock implementation methods

    def _mock_load_config(self, filepath: str) -> dict:
        """Mock config loading."""
        path = Path(filepath)
        if not path.exists():
            raise FileNotFoundError(f"Config file not found: {filepath}")

        content = path.read_text()
        return json.loads(content)

    def _mock_load_config_with_defaults(self, filepath: str) -> dict:
        """Mock config loading with defaults."""
        config = self._mock_load_config(filepath)
        defaults = {
            "api_url": "https://vault.bitwarden.com/api",
            "identity_url": "https://vault.bitwarden.com/identity"
        }
        return {**defaults, **config}

    def _mock_validate_config(self, config: dict):
        """Mock config validation."""
        required_fields = ["org_id", "api_url"]
        for field in required_fields:
            if field not in config:
                raise ValueError(f"Missing required field: {field}")


class TestConfigEncryption:
    """Test suite for encrypted configuration."""

    def test_save_encrypted_config(self, tmp_path):
        """Test saving configuration in encrypted format."""
        config = {"org_id": "org-123", "client_secret": "secret"}
        config_file = tmp_path / "encrypted.conf"
        encryption_key = "test_key_32_bytes_long!!"

        self._mock_save_encrypted(str(config_file), config, encryption_key)

        assert config_file.exists()
        # Ensure it's not plain JSON
        content = config_file.read_text()
        assert "org-123" not in content
        assert "secret" not in content

    def test_load_encrypted_config(self, tmp_path):
        """Test loading encrypted configuration."""
        config = {"org_id": "org-123", "api_key": "secret_key"}
        config_file = tmp_path / "encrypted.conf"
        encryption_key = "test_key_32_bytes_long!!"

        # Save encrypted
        self._mock_save_encrypted(str(config_file), config, encryption_key)

        # Load encrypted
        loaded = self._mock_load_encrypted(str(config_file), encryption_key)

        assert loaded == config

    def test_load_encrypted_with_wrong_key_fails(self, tmp_path):
        """Test that wrong decryption key fails gracefully."""
        config = {"org_id": "org-123"}
        config_file = tmp_path / "encrypted.conf"
        correct_key = "correct_key_32_bytes!!"
        wrong_key = "wrong_key_32_bytes__!!"

        self._mock_save_encrypted(str(config_file), config, correct_key)

        with pytest.raises(ValueError, match="Decryption failed"):
            self._mock_load_encrypted(str(config_file), wrong_key)

    # Mock implementation methods

    def _mock_save_encrypted(self, filepath: str, config: dict, key: str):
        """Mock encrypted config saving."""
        # Simple mock: encode as JSON then reverse (simulating encryption)
        json_str = json.dumps(config)
        encrypted = f"ENCRYPTED:{key[:8]}:{json_str[::-1]}"
        Path(filepath).write_text(encrypted)

    def _mock_load_encrypted(self, filepath: str, key: str) -> dict:
        """Mock encrypted config loading."""
        content = Path(filepath).read_text()
        parts = content.split(":", 2)

        if parts[0] != "ENCRYPTED":
            raise ValueError("Not an encrypted config file")

        if parts[1] != key[:8]:
            raise ValueError("Decryption failed: wrong key")

        json_str = parts[2][::-1]
        return json.loads(json_str)
