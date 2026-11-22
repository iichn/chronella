# backend/app/core/security.py

from cryptography.fernet import Fernet
import os
import base64

# ==============================================================================
# НАСТРОЙКА КЛЮЧА ШИФРОВАНИЯ
# ==============================================================================

ENCRYPTION_KEY = os.getenv("ENCRYPTION_KEY")
if not ENCRYPTION_KEY:
    raise RuntimeError("ENCRYPTION_KEY is not set")

try:
    CIPHER_SUITE = Fernet(ENCRYPTION_KEY)
except Exception as exc:
    raise RuntimeError("Invalid ENCRYPTION_KEY") from exc

def get_cipher_suite():
    return CIPHER_SUITE

# ==============================================================================
# ФУНКЦИИ ШИФРОВАНИЯ
# ==============================================================================

def encrypt_password(password: str) -> str:
    """
    Принимает обычный пароль, возвращает зашифрованную строку.
    """
    if not password:
        return ""
    
    cipher = get_cipher_suite()
    # Fernet работает с байтами, поэтому encode() -> encrypt() -> decode()
    encrypted_bytes = cipher.encrypt(password.encode('utf-8'))
    return encrypted_bytes.decode('utf-8')

def decrypt_password(encrypted_password: str) -> str:
    """
    Принимает зашифрованную строку, возвращает обычный пароль.
    """
    if not encrypted_password:
        return ""
        
    cipher = get_cipher_suite()
    try:
        decrypted_bytes = cipher.decrypt(encrypted_password.encode('utf-8'))
        return decrypted_bytes.decode('utf-8')
    except Exception as e:
        print(f"Ошибка расшифровки: {e}")
        return ""