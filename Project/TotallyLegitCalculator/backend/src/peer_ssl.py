import socket
import threading
import struct
import sys
import signal
import select
import ssl
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
# my modules:
import utils_config as json_util

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
        # Přidání SSL kontextů pro TLS
        self.ssl_context_server = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        self.ssl_context_client = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        # načtení certifikátu a klíče (pro self signed)
        self.ssl_context_server.load_cert_chain(certfile="cert.pem", keyfile="key.pem")
        # TLS klient: povinné ověření certifikátu a hostname
        self.ssl_context_client.check_hostname = True
        self.ssl_context_client.verify_mode = ssl.CERT_REQUIRED
        # načtení certifikátu serveruu (nebo CA), kterému klient důvěřuje hopefully
        self.ssl_context_client.load_verify_locations(cafile="cert.pem")

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
            # Pokus o připojení jako klient
            raw_sock = socket.create_connection((PEER_IP, MY_PORT), timeout=2)
            raw_sock.settimeout(None)
            # encapsulation pro socket do TLS klienta
            self.sock = self.ssl_context_client.wrap_socket(raw_sock, server_hostname=PEER_IP)
            print(f"[+] Připojeno k {PEER_IP}:{MY_PORT} jako klient (TLS)")
        except Exception:
            print("[*] Nelze se připojit, spuštěn server...")
            # spuštění serveru
            server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server_sock.bind(('', MY_PORT))
            server_sock.listen(1)
            raw_conn, addr = server_sock.accept()
            server_sock.close()
            # encapsulation pro socket do TLS serveru
            self.sock = self.ssl_context_server.wrap_socket(raw_conn, server_side=True)
            print(f"[+] Připojeno od {addr} jako server (TLS)")

    def receive_loop(self):
        while self.running:
            try:
                data = decrypt_payload(self.sock)
                if not data:
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

# pro nyní spouštěno jen z tudma
# ssl gen:
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
#   -keyout key.pem -out cert.pem \
#   -config san.cnf
if __name__ == '__main__':
    peer = Peer_connection()
    peer.start()
