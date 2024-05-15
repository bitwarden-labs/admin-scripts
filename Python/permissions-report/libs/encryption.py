from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives import padding

from base64 import b64decode
import os


def ensure_bytes(input_data):
    # Check if input_data is already a byte string
    if isinstance(input_data, bytes):
        return input_data  # Return as is if it's already a byte string
    elif isinstance(input_data, str):
        # Convert string to bytes using UTF-8 encoding
        return input_data.encode('utf-8')
    else:
        # Handle other types as needed, possibly raising an error
        # For demonstration, converting non-string, non-bytes to a string, then to bytes
        # This is a simple fallback and may not be suitable for all data types
        return str(input_data).encode('utf-8')

def decrypt_aes_256_cbc(encrypted_data_with_salt_iv, password):
    # Your existing setup code for extracting salt, IV, deriving the key, etc.

    password = ensure_bytes(password)

    # Verify the 'Salted__' header is present
    if not encrypted_data_with_salt_iv.startswith(b'Salted__'):
        raise ValueError("The encrypted data is not in the expected format.")
    
    # Extract salt (next 8 bytes after 'Salted__') and IV (following 16 bytes)
    salt = encrypted_data_with_salt_iv[8:24]
    iv = encrypted_data_with_salt_iv[24:40]
    encrypted_data = encrypted_data_with_salt_iv[40:]

    # Derive key using the same parameters as for encryption
    backend = default_backend()
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA512(),
        length=32,
        salt=salt,
        iterations=100000,
        backend=backend
    )
    key = kdf.derive(password)

    # Initialize cipher with the key and IV for decryption
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    decryptor = cipher.decryptor()

    # Decrypt the data
    decrypted = decryptor.update(encrypted_data) + decryptor.finalize()

    # Unpad the decrypted data
    unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
    unpadded_data = unpadder.update(decrypted) + unpadder.finalize()

    return unpadded_data
    

def encrypt_aes_256_cbc(data, password):

    data = ensure_bytes(data)
    password = ensure_bytes(password)

    # Generate a random salt
    salt = os.urandom(16)
    
    # Key derivation
    backend = default_backend()
    kdf = PBKDF2HMAC(
        algorithm=hashes.SHA512(),
        length=32,
        salt=salt,
        iterations=100000,
        backend=backend
    )
    key = kdf.derive(password)
    
    # Generate a random IV
    iv = os.urandom(16)
    
    # Initialize cipher
    cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=backend)
    encryptor = cipher.encryptor()

    # Pad the data
    padder = padding.PKCS7(algorithms.AES.block_size).padder()
    padded_data = padder.update(data) + padder.finalize()

    # Encrypt data and add padding if necessary
    encrypted = encryptor.update(padded_data) + encryptor.finalize()
    
    # Prepend salt and IV to the encrypted data (to mimic OpenSSL's format)
    encrypted_data_with_salt_iv = b'Salted__' + salt + iv + encrypted
    
    return encrypted_data_with_salt_iv
