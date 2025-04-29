import socket
import threading
import struct
import sys
import signal
import select
import ssl
import json
from pathlib import Path
from http.server import HTTPServer, BaseHTTPRequestHandler
import time

# Import vašich modulů
import src.utils_crypto as crypto_util
import src.peer_ssl as peer_ssl



class Peer_API(peer_ssl.Peer_connection):
    def __init__(self):
        self.API_PORT = 8080  # port API
        super().__init__()
        # Seznam nových zpráv pro API
        self.new_messages = []
        self.new_messages_lock = threading.Lock()

    def append_chat_history(self, msg, direction):
        # Volání původní metody pro zachování funkcionality
        super().append_chat_history(msg, direction)

        # Přidání zprávy do seznamu nových zpráv pro API
        with self.new_messages_lock:
            self.new_messages.append({
                "text": msg,
                "isSentByMe": direction == "SENT",
                "timestamp": time.time()
            })

    def get_messages(self):
        # získání všech zpráv, které jsou uloženy v .old_mess/history.txt
        messages = []
        if self.chat_history_path.exists():
            with open(self.chat_history_path, "r", encoding="utf-8") as f:
                for line in f:
                    try:
                        direction, encrypted = line.strip().split(" ", 1)
                        decrypted = self.crypto_utils.decrypt_string(encrypted)
                        messages.append({
                            "text": decrypted,
                            "isSentByMe": direction == "[SENT]",
                            "timestamp": time.time()  # Použijeme aktuální čas, protože historie nemá časové razítko
                        })
                    except Exception:
                        pass
        return messages

    def get_new_messages(self):
        # get nových zpráv -- nových od posledního callu
        with self.new_messages_lock:
            # Filtrujeme pouze zprávy, které přišly od druhého uživatele (ne ty, které jsme sami odeslali)
            messages = [msg for msg in self.new_messages if not msg["isSentByMe"]]
            # Vyčistíme seznam nových zpráv
            self.new_messages = [msg for msg in self.new_messages if msg["isSentByMe"]]
        return messages

    def send_message_api(self, message):
        # odeslání zpráv přijaté skrze API:
        try:
            with self.lock:
                self.sock.sendall(self.crypto_utils.encrypt_payload(message.encode()))
            self.append_chat_history(message, "SENT")
            return True
        except Exception as e:
            print(f"[!] Chyba při odesílání zprávy z API: {e}")
            return False

    def start_api_server(self):
        # API pro komunikaci s flutter appkou
        peer_connection = self

        class APIHandler(BaseHTTPRequestHandler):
            def _set_headers(self, content_type="application/json"):
                self.send_response(200)
                self.send_header('Content-type', content_type)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', 'Content-Type')
                self.end_headers()

            def do_OPTIONS(self):
                self._set_headers()

            def do_GET(self):
                if self.path == "/api/messages":
                    self._set_headers()
                    messages = peer_connection.get_messages()
                    self.wfile.write(json.dumps({"status": "success", "messages": messages}).encode())
                elif self.path == "/api/new-messages":
                    self._set_headers()
                    messages = peer_connection.get_new_messages()
                    self.wfile.write(json.dumps({"status": "success", "messages": messages}).encode())
                elif self.path == "/api/status":
                    self._set_headers()
                    # pokud aktivni, vrací se success
                    if peer_connection.running:
                        self.wfile.write(json.dumps({"status": "success"}).encode())
                    else:
                        self.wfile.write(json.dumps({"status": "error", "message": "Connection closed"}).encode())
                else:
                    self.send_response(404)
                    self.end_headers()

            def do_POST(self):
                if self.path == "/api/send":
                    content_length = int(self.headers['Content-Length'])
                    post_data = self.rfile.read(content_length)

                    try:
                        request = json.loads(post_data.decode())
                        message = request.get("message", "")

                        # Odeslání zprávy
                        success = peer_connection.send_message_api(message)

                        self._set_headers()
                        self.wfile.write(json.dumps({"status": "success" if success else "error"}).encode())
                    except Exception as e:
                        self._set_headers()
                        self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode())
                else:
                    self.send_response(404)
                    self.end_headers()

        # Spuštění HTTP serveru v samostatném vlákně -- separátní proces od peer connection
        server = HTTPServer(('localhost', self.API_PORT), APIHandler)
        print(f"[+] API server běží na http://localhost:{self.API_PORT}")

        api_thread = threading.Thread(target=server.serve_forever, daemon=True)
        api_thread.start()

    def start(self):
        self.setup_ssl_contexts()
        self.connect_or_listen()

        # flutter api server
        self.start_api_server()
        # vlakna a takk
        threading.Thread(target=self.receive_loop, daemon=True).start()
        self.send_loop()
