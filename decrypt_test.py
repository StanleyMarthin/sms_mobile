import os
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import padding as sym_padding

# Use the keys from sm_countdown/app/main.py
hexKey = "8382ba6b8159105f6a2ac820463a9cc46cf48af7d0c18d4f0f1c1ff4e6612e8d"
ivHex  = "7a7b8b54d7c6fe8e0a9b04b812064fa6"

def decryptAes(ciphertextHex: str) -> str:
    key        = bytes.fromhex(hexKey)
    iv         = bytes.fromhex(ivHex)
    ciphertext = bytes.fromhex(ciphertextHex)
    cipher     = Cipher(algorithms.AES(key), modes.CBC(iv), backend=default_backend())
    decryptor  = cipher.decryptor()
    padded     = decryptor.update(ciphertext) + decryptor.finalize()
    unpadder   = sym_padding.PKCS7(128).unpadder()
    return (unpadder.update(padded) + unpadder.finalize()).decode()

old_ip = decryptAes("356e8ac1170cf7cc917989145e0b8c20")
print("OLD DB_IP:", old_ip)
# And let's decrypt all the others from the old sm_countdown env
print("OLD DB_PORT:", decryptAes("717d3b01ab24d68a411dcfd2afdf7d06"))
print("OLD DB_USR:", decryptAes("65daeb14abe1c6137ddba6a382259628"))
print("OLD DB_PWD:", decryptAes("bc450b837b2a2b42420070a4e86df68a"))
print("OLD DB_NM:", decryptAes("8cc80df1250de155e45e08beea178e0f"))

