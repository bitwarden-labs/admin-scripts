from encryption import decrypt_aes_256_cbc
from dotenv import load_dotenv
import os

# Obtain encrypted secrets

encryption_password = input(f"Please enter your decryption password: \n")
env_vars = {}

with open(".env", 'r') as env_file:
  for line in env_file:
    line = line.strip()

    if line and not line.startswith(('#', '//')):
      key, value = line.split('=', 1)
      key = key.strip()
      value = value.strip()
      env_vars[key] = value

for value in env_vars.values():
  print(value)
  value = value.encode('utf-8')
  print(value)
  decrypted_value = decrypt_aes_256_cbc(value, password=encryption_password)
  print(decrypted_value)

# Decrypt encrypted secrets
# Write decrypted.env
# Load decrypted.env into memory
# Delete decrypted.env
