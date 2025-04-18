import socket
import threading
import struct
import sys
import signal
import select
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
# my modules:
import src.utils_config as json_util

MY_PORT = json_util.load_config()["MY_PORT"]
PEER_IP = json_util.load_config()["PEER_IP"]
KEY = bytes.fromhex(json_util.load_config()["KEY"])
IV = bytes.fromhex(json_util.load_config()["IV"])
SHUTDOWN_MSG = str(json_util.load_config()["SHUTDOWN_MSG"])

def encrypt_payload(data: bytes) -> bytes:
    cipher = AES.new(KEY, AES.MODE_CBC, IV)
    ciphertext = cipher.encrypt(pad(data, AES.block_size))
    return struct.pack('!I', len(ciphertext)) + ciphertext

def recv_all(sock, n):
    data = b''
    while len(data) < n:
        try:
            part = sock.recv(n - len(data))
        except socket.timeout:
            continue
        except Exception:
            return None
        if not part:
            return None
        data += part
    return data

def decrypt_payload(sock) -> bytes:
    raw_len = recv_all(sock, 4)
    if not raw_len:
        return b''
    length = struct.unpack('!I', raw_len)[0]
    encrypted = recv_all(sock, length)
    if not encrypted:
        return b''
    cipher = AES.new(KEY, AES.MODE_CBC, IV)
    return unpad(cipher.decrypt(encrypted), AES.block_size)

class Peer_connection:
    def __init__(self):
        self.sock = None
        self.running = True
        self.lock = threading.Lock()
        signal.signal(signal.SIGINT, self.signal_handler)

    def signal_handler(self, sig, frame):
        print("\n[*] Ctrl+C zachycen, odesílám ukončovací zprávu...")
        self.running = False
        self.send_shutdown()
        self.cleanup()
        sys.exit(0)

    def send_shutdown(self):
        try:
            with self.lock:
                self.sock.sendall(encrypt_payload(SHUTDOWN_MSG.encode()))
        except Exception:
            pass

    def cleanup(self):
        try:
            self.sock.shutdown(socket.SHUT_RDWR)
        except Exception:
            pass
        try:
            self.sock.close()
        except Exception:
            pass

    def connect_or_listen(self):
        try:
            self.sock = socket.create_connection((PEER_IP, MY_PORT), timeout=2)
            self.sock.settimeout(None)
            print(f"[+] Připojeno k {PEER_IP}:{MY_PORT} jako klient")
        except Exception:
            print("[*] Nelze se připojit, spuštěn server...")
            server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server.bind(('', MY_PORT))
            server.listen(1)
            self.sock, addr = server.accept()
            self.sock.settimeout(None)
            server.close()
            print(f"[+] Připojeno od {addr} jako server")

    def receive_loop(self):
        while self.running:
            try:
                data = decrypt_payload(self.sock)
                if not data:
                    # spojení uzavřeno
                    print("\n[*] Spojení ukončeno peerem.")
                    self.running = False
                    break
                msg = data.decode()
                if msg == SHUTDOWN_MSG:
                    print("\n[*] Peer ukončil spojení.")
                    self.running = False
                    break
                print(f"\nREMOTE >> {msg}\n>> ", end='', flush=True)
            except Exception as e:
                if self.running:
                    print(f"\n[!] Chyba příjmu: {e}")
                    self.running = False
                break
        self.cleanup()
        sys.exit(0)

    def send_loop(self):
        print(">> ", end='', flush=True)
        while self.running:
            try:
                rlist, _, _ = select.select([sys.stdin], [], [], 0.1)
                if rlist:
                    line = sys.stdin.readline()
                    if not line:
                        continue
                    line = line.rstrip('\n')
                    if line.lower() == "konec":
                        print("[*] Ukončuji spojení...")
                        self.running = False
                        self.send_shutdown()
                        break
                    with self.lock:
                        self.sock.sendall(encrypt_payload(line.encode()))
                    print(">> ", end='', flush=True)
            except Exception as e:
                if self.running:
                    print(f"\n[!] Chyba odesílání: {e}")
                    self.running = False
                break
        self.cleanup()
        sys.exit(0)

    def start(self):
        self.connect_or_listen()
        threading.Thread(target=self.receive_loop, daemon=True).start()
        self.send_loop()


