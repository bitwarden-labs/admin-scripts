from encryption import encrypt_aes_256_cbc
import os

keys = ["serverURL", "client_id", "client_secret", "owner_username", "owner_masterpassword"]
env_file_path = ""
encryption_password = ""

# Check if .env exists, and uses initialise_env() to create it if it does not
def check_env_file():
  current_directory = os.getcwd()
  env_file_path = os.path.join(current_directory, '.env')

  if os.path.isfile(env_file_path):
    print(".env file exists")
    return True
  else:
    print(".env file not yet created.  Initialising .env file.")
    env_file_path, encryption_password = initialise_env()
    encrypt_env(env_file_path)

# Creates a .env file with the key:value pairs needed for interaction with Bitwarden
def initialise_env():
  env_file_path = '.env'
  encryption_password = input(f"Please enter a password to encrypt your .env file: \n")

  with open(env_file_path, 'w') as env_file:
    for key in keys:
      value = input(f"Please enter your {key}: \n")
      env_file.write(f"{key}={value}\n")

  return env_file_path, encryption_password

# Encrypts non-comment values in .env file
def encrypt_env(env_file_path):
  env_vars = {}

  with open(env_file_path, 'r') as env_file:
    for line in env_file:
      line = line.strip()

      if line and not line.startswith(('#', '//')):
        key, value = line.split('=', 1)
        key = key.strip()
        value = value.strip()
        env_vars[key] = value # assigns keys to values in Python dictionary

  with open(env_file_path, 'w') as env_file:
    for key, value in env_vars.items():
        encrypted_value = encrypt_aes_256_cbc(value, password=encryption_password)
        env_file.write(f"{key}={encrypted_value}\n")

check_env_file()
