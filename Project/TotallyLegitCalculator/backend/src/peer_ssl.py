import socket
import threading
import struct
import sys
import signal
import select
import ssl
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad
from pathlib import Path
# my modules:
import src.utils_config as json_util
import src.utils_crypto as crypto_util

MY_PORT = json_util.load_config()["MY_PORT"]
PEER_IP = json_util.load_config()["PEER_IP"]
KEY = bytes.fromhex(json_util.load_config()["KEY"])
IV = bytes.fromhex(json_util.load_config()["IV"])
SHUTDOWN_MSG = str(json_util.load_config()["SHUTDOWN_MSG"])

class Peer_connection:
    def __init__(self):
        """Hovadiny pro komunikaci:"""
        self.sock = None
        self.running = True
        self.lock = threading.Lock()
        signal.signal(signal.SIGINT, self.signal_handler)
        """CRYPTO MODUL"""
        self.crypto_utils = crypto_util.AES_cipher()
        """SSL CERTIFIKATY SHINANIGGANS"""
        # relativní cesta k ssl certům → z /src do /.cert
        base_dir = Path(__file__).resolve().parent
        cert_dir = base_dir.parent / ".cert"
        cert_path = cert_dir / "cert.pem"
        key_path = cert_dir / "key.pem"
        # pridani ssl certu do tls
        self.ssl_context_server = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        self.ssl_context_client = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        # nacteni self signed certifikatu
        self.ssl_context_server.load_cert_chain(certfile=str(cert_path), keyfile=str(key_path))
        # TLS klient: povinne overeni certu a hostname
        self.ssl_context_client.check_hostname = True
        self.ssl_context_client.verify_mode = ssl.CERT_REQUIRED
        # nacteni certifikatu
        self.ssl_context_client.load_verify_locations(cafile=str(cert_path))

    def signal_handler(self, _, __): #  sig, frame values removed, cause unused
        print("\n[*] Ctrl+C zachycen, odesílám ukončovací zprávu...")
        self.running = False
        self.send_shutdown()
        self.cleanup()
        sys.exit(0)

    def send_shutdown(self):
        try:
            with self.lock:
                #self.sock.sendall(encrypt_payload(SHUTDOWN_MSG.encode()))
                self.sock.sendall(self.crypto_utils.encrypt_payload(SHUTDOWN_MSG.encode()))
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
                # data = decrypt_payload(self.sock)
                data = self.crypto_utils.decrypt_payload(self.sock)
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
                        #self.sock.sendall(encrypt_payload(line.encode()))
                        self.sock.sendall(self.crypto_utils.encrypt_payload(line.encode()))
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
