import struct
import sys
import json
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
import src.utils_config as json_util
"""
two classes:
AES_cipher → encrypts/decrypts sent/received messages (line 13)
aes_key_gen → generates KEY and IV (line 53)
"""

class AES_cipher:
    def __init__(self):
        try:
            config = json_util.load_config()
            self.KEY = bytes.fromhex(config["KEY"])
            self.IV = bytes.fromhex(config["IV"])
        except (KeyError, ValueError, json.JSONDecodeError, FileNotFoundError) as e:
            print(f"[!] Failed to load KEY/IV from config: {e}")
            sys.exit(1)

    # here ide has issue with this method not being static or outside
    # I simply dont want to have this method callabe outside of this class :)
    def recv_all(self, sock, n):
        data = b''
        while len(data) < n:
            try:
                part = sock.recv(n - len(data))
                if not part:
                    return None
                data += part
            except Exception:
                return None
        return data

    def encrypt_payload(self, data: bytes) -> bytes:
        cipher = AES.new(self.KEY, AES.MODE_CBC, self.IV)
        ciphertext = cipher.encrypt(pad(data, AES.block_size))
        return struct.pack('!I', len(ciphertext)) + ciphertext

    def decrypt_payload(self, sock) -> bytes:
        raw_len = self.recv_all(sock, 4)
        if not raw_len:
            return b''
        length = struct.unpack('!I', raw_len)[0]
        encrypted = self.recv_all(sock, length)
        if not encrypted:
            return b''
        cipher = AES.new(self.KEY, AES.MODE_CBC, self.IV)
        return unpad(cipher.decrypt(encrypted), AES.block_size)

class AES_key_gen:
    def __init__(self):
        self.dummy = "dummy"
