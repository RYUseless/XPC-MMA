import socket
import threading
import struct
import sys
import signal
import select
import ssl
from pathlib import Path

import src.utils_config as json_util
import src.utils_crypto as crypto_util

MY_PORT = json_util.load_config()["MY_PORT"]
PEER_IP = json_util.load_config()["PEER_IP"]
SHUTDOWN_MSG = str(json_util.load_config()["SHUTDOWN_MSG"])

class Peer_connection:
    def __init__(self):
        self.sock = None
        self.running = True
        self.lock = threading.Lock()
        signal.signal(signal.SIGINT, self.signal_handler)

        self.crypto_utils = crypto_util.AES_cipher()

        self.ssl_context_server = None
        self.ssl_context_client = None

        # Cesta k souboru s historií chatu
        self.chat_history_path = Path(__file__).resolve().parent.parent / ".old_mess" / "chat_history.txt"

    def setup_ssl_contexts(self):
        base_dir = Path(__file__).resolve().parent
        cert_dir = base_dir.parent / ".cert"
        cert_path = cert_dir / "cert.pem"
        key_path = cert_dir / "key.pem"

        print(f"[DEBUG] Načítám certifikáty ze složky: {cert_dir}")

        # Server TLS kontext
        self.ssl_context_server = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        self.ssl_context_server.load_cert_chain(certfile=str(cert_path), keyfile=str(key_path))

        # Klient TLS kontext - vypnuto ověřování certifikátu (self-signed)
        self.ssl_context_client = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        self.ssl_context_client.check_hostname = False
        self.ssl_context_client.verify_mode = ssl.CERT_NONE

    def signal_handler(self, _, __):
        print("\n[*] Ctrl+C zachycen, odesílám ukončovací zprávu...")
        self.running = False
        self.send_shutdown()
        self.cleanup()
        sys.exit(0)

    def send_shutdown(self):
        try:
            with self.lock:
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

    def recv_all(self, sock, n):
        data = b''
        while len(data) < n:
            part = sock.recv(n - len(data))
            if not part:
                return None
            data += part
        return data

    def send_cert(self):
        cert_path = Path(__file__).resolve().parent.parent / ".cert" / "cert.pem"
        with open(cert_path, "rb") as f:
            cert_data = f.read()
        length = struct.pack('!I', len(cert_data))
        self.sock.sendall(length + cert_data)

    def recv_cert(self):
        raw_len = self.recv_all(self.sock, 4)
        if not raw_len:
            raise ConnectionError("Nelze přečíst délku certifikátu")
        length = struct.unpack('!I', raw_len)[0]
        cert_data = self.recv_all(self.sock, length)
        if not cert_data:
            raise ConnectionError("Nelze přečíst certifikát")
        return cert_data

    @staticmethod
    def verify_and_update_peer_cert(peer_cert_bytes):
        peer_cert_path = Path(__file__).resolve().parent.parent / ".cert" / f"peer_{PEER_IP.replace('.', '_')}.pem"

        if peer_cert_path.exists():
            with open(peer_cert_path, "rb") as f:
                saved_cert = f.read()
            if saved_cert != peer_cert_bytes:
                print("[*] Detekována změna certifikátu protistrany, aktualizuji...")
                with open(peer_cert_path, "wb") as f:
                    f.write(peer_cert_bytes)
                print(f"[*] Certifikát peeru aktualizován: {peer_cert_path}")
            else:
                print("[*] Certifikát peeru je aktuální.")
        else:
            with open(peer_cert_path, "wb") as f:
                f.write(peer_cert_bytes)
            print(f"[*] Certifikát peeru uložen: {peer_cert_path}")

    def load_chat_history(self):
        if self.chat_history_path.exists():
            print("[*] Načítám uloženou konverzaci:")
            with open(self.chat_history_path, "r", encoding="utf-8") as f:
                for line in f:
                    try:
                        direction, encrypted = line.strip().split(" ", 1)
                        decrypted = self.crypto_utils.decrypt_string(encrypted)
                        print(f"{direction} {decrypted}")
                    except Exception as e:
                        print(f"[!] Chyba při dešifrování zprávy: {e}")
            print("[*] --- konec historie ---\n")
        else:
            print("[*] Žádná uložená historie konverzace.")

    def append_chat_history(self, msg, direction):
        try:
            encrypted = self.crypto_utils.encrypt_string(msg)
            with open(self.chat_history_path, "a", encoding="utf-8") as f:
                f.write(f"[{direction}] {encrypted}\n")
        except Exception as e:
            print(f"[!] Chyba při ukládání šifrované zprávy: {e}")

    def connect_or_listen(self):
        try:
            raw_sock = socket.create_connection((PEER_IP, MY_PORT), timeout=2)
            raw_sock.settimeout(None)
            self.sock = self.ssl_context_client.wrap_socket(raw_sock, server_hostname=PEER_IP)
            print(f"[+] Připojeno k {PEER_IP}:{MY_PORT} jako klient (TLS)")

            # Jako klient přijmu certifikát serveru, pak pošlu svůj
            server_cert = self.recv_cert()
            self.send_cert()
            self.verify_and_update_peer_cert(server_cert)

        except Exception:
            print("[*] Nelze se připojit, spuštěn server...")
            server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            server_sock.bind(('', MY_PORT))
            server_sock.listen(1)
            raw_conn, addr = server_sock.accept()
            server_sock.close()
            self.sock = self.ssl_context_server.wrap_socket(raw_conn, server_side=True)
            print(f"[+] Připojeno od {addr} jako server (TLS)")

            # Jako server pošlu certifikát, pak přijmu klientův
            self.send_cert()
            client_cert = self.recv_cert()
            self.verify_and_update_peer_cert(client_cert)

    def receive_loop(self):
        while self.running:
            try:
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
                self.append_chat_history(msg, "RECV")
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
                        self.sock.sendall(self.crypto_utils.encrypt_payload(line.encode()))
                    self.append_chat_history(line, "SENT")
                    print(">> ", end='', flush=True)
            except Exception as e:
                if self.running:
                    print(f"\n[!] Chyba odesílání: {e}")
                    self.running = False
                break
        self.cleanup()
        sys.exit(0)

    def start(self):
        self.setup_ssl_contexts()
        self.load_chat_history()  # Načteme historii před připojením
        self.connect_or_listen()
        threading.Thread(target=self.receive_loop, daemon=True).start()
        self.send_loop()
