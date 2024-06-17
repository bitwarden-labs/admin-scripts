import os
from encryption import encrypt_aes_256_cbc

keys = ["serverURL", "client_id", "client_secret", "owner_username", "owner_masterpassword"]

def main():
  env_file_path = get_env_file_path()
  secrets_directory = check_secrets_directory()

  if not os.path.isfile(env_file_path):
    print(".env file not present.  Initialising .env file.")
    env_file_path,encryption_password = initialise_env(keys)
  else:
    print(".env file already exists.")
    encryption_password = input("Please enter an encryption password to encrypt your .env secrets: \n")

  encrypt_env(env_file_path, secrets_directory, encryption_password)

def get_env_file_path():
  """Obtain .env file path in current working directory"""
  current_directory = os.getcwd()
  return os.path.join(current_directory, '.env')

def check_secrets_directory():
  """Verify that ./secrets exists for storing encrypted binaries"""
  secrets_directory = os.path.join(os.getcwd(), 'secrets')
  os.makedirs(secrets_directory, exist_ok=True)
  return secrets_directory

def initialise_env(keys):
  """Create and initialise a .env file for use with Bitwarden"""
  env_file_path = '.env'
  encryption_password = input("Please enter a password to encrypt/decrypt your .env file: \n")

  with open(env_file_path, 'w') as env_file:
    for key in keys:
      value = input(f"Please enter your {key}: \n")
      env_file.write(f"{key}={value}\n")

    return env_file_path, encryption_password
  
def encrypt_env(env_file_path, secrets_directory, encryption_password):
  """Encrypt values in the .env file and store them as encyrpted binaries in the secrets directory"""
  env_vars = {}

  try:
    # Obtain list of vars from .env
    with open(env_file_path, 'r') as env_file:
      for line in env_file:
        line = line.strip()
        if line and not line.startswith(('#', '//')):
          key, value = line.split('=', 1)
          env_vars[key.strip()] = value.strip()

    # Encrypt vars as binaries
    for key, value in env_vars.items():

      binary_filename = os.path.join(secrets_directory, key + '.bin')
      with open(binary_filename, 'wb') as file:
        encrypted_value = encrypt_aes_256_cbc(value, password=encryption_password)
        file.write(encrypted_value)
        print(f"Encrypted {value} and wrote {encrypted_value} to {binary_filename}")

  except Exception as e:
    print(f"An error occurred during encryption: {e}")

if __name__ == "__main__":
  main()

