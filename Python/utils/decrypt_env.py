import os
from utils.encryption import decrypt_aes_256_cbc
from dotenv import load_dotenv

temp_env_file_path = 'temp.env'

def load_secrets(secrets_directory, decryption_password):
  """
  This function extracts secrets from the /secrets directory and makes them available to your script.

  Args:
    secrets_directory (str): The directory filepath where encrypted .bin files are stored.
    decryption_password (str): The password to decrypt these secrets.
  """
  secrets = {}

  for filename in os.listdir(secrets_directory):
    if filename.endswith('.bin'):
      key = filename[:-4]
      file_path = os.path.join(secrets_directory, filename)

      with open(file_path, 'rb') as file:
        encrypted_value = file.read()
        decrypted_value = decrypt_aes_256_cbc(encrypted_value, password=decryption_password)
        secrets[key] = decrypted_value.decode('utf-8')

  return secrets

def write_secrets_to_env(secrets, temp_env_file_path):
  """Write secrets to temporary .env file and load them into memory.

  Args:
    secrets (dict): Python dictionary containing decrypted secrets.
    env_file_path (str): Path to the .env file to write to.
  """

  with open(temp_env_file_path, 'w') as temp_env_file:
    for key, value in secrets.items():
      temp_env_file.write(f"{key}={value}\n")

def decrypt_secrets():
  secrets_directory = os.path.join(os.getcwd(), 'secrets')
  decryption_password = input("Please enter the password used to encrypt your secrets: \n")

  secrets = load_secrets(secrets_directory, decryption_password)

  write_secrets_to_env(secrets, temp_env_file_path)
  load_dotenv(temp_env_file_path)
  os.remove(temp_env_file_path)
