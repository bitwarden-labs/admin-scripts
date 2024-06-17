from libs.utils import decrypt_get_secret, encrypt_aes_256_cbc, decrypt_aes_256_cbc
import base64

# Setup

password='encryptionPassword'
secret = "This is a secret message"

base64_filename = '/Users/adambramley/Bitwarden/bitwarden-labs/admin-scripts/Python/permissions-report/encrypted_secret_base64.txt'
binary_filename = '/Users/adambramley/Bitwarden/bitwarden-labs/admin-scripts/Python/permissions-report/encrypted_secret.bin'

### Encrypt Secret
encrypted_secret = encrypt_aes_256_cbc(data=secret, password=password)
print(encrypted_secret)
print(type(encrypted_secret))

### Encode already encrypted secrets
encrypted_secret_base64 = base64.b64encode(encrypted_secret).decode('utf-8')
print(encrypted_secret_base64)
print(type(encrypted_secret_base64))

print("-------------------------------------------------------------------")
print("Writing to disk")
print("-------------------------------------------------------------------")

### Write secrets to disk
with open(base64_filename, 'w') as file:
  file.write(encrypted_secret_base64)
  print(f"Text file with encrypted string written - contents {encrypted_secret_base64}")

with open(binary_filename, 'wb') as file:
  file.write(encrypted_secret)
  print(f"Encrypted binary written - contents {encrypted_secret}")

### Decrypt Secrets

print("-------------------------------------------------------------------")
print("Beginning decryption")
print("-------------------------------------------------------------------")

print("-------------------------------------------------------------------")
print("Decrypting encoded string")
print("-------------------------------------------------------------------")

decrytped_secret_base64 = decrypt_get_secret(filename=base64_filename, secret_pass=password)
print(f"decrypted encoded secret is: {decrytped_secret_base64}")
print(type(decrytped_secret_base64))

print("-------------------------------------------------------------------")
print("Decrypting binary")
print("-------------------------------------------------------------------")

with open(binary_filename, 'rb') as file:
  binary_secret = file.read()

print(f"decoded_secret = {binary_secret}")
print(f"decoded_secret's filetype is {type(binary_secret)}")

# decrypted_binary = decrypt_get_secret(re_encoded_secret, secret_pass=password)
decrypted_binary = decrypt_aes_256_cbc(encrypted_data_with_salt_iv=binary_secret, password=password)
print(f"decrypted secret is: {decrypted_binary}")
