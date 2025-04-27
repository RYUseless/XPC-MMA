import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import sys
import os
import socket
import subprocess

import utils_config as json_util

CONFIG_API_PORT = 8090


# Funkce pro výpis do terminálu, který bude okamžitě viditelný v Dart
def print_to_terminal(message):
    # Použití echo příkazu, který je okamžitě viditelný
    subprocess.Popen(['echo', f"\n=== {message} ==="], stdout=sys.stdout)
    # Také použijeme standardní print s flush
    #print(f"\n=== {message} ===", flush=True)
    sys.stdout.flush()


class ConfigAPIHandler(BaseHTTPRequestHandler):
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
        if self.path == "/api/config":
            self._set_headers()
            config = json_util.load_config()
            self.wfile.write(json.dumps(config).encode())
            print_to_terminal(f"GET /api/config - Returning config: {config}")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == "/api/config":
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            try:
                config_data = json.loads(post_data.decode())
                for key in ['MY_PORT', 'PEER_IP', 'OWN_IP', 'SHUTDOWN_MSG']:
                    if key in config_data:
                        json_util.update_config(key, config_data[key])
                self._set_headers()
                self.wfile.write(json.dumps({"status": "success"}).encode())
                print_to_terminal(f"Config updated: {config_data}")
            except Exception as e:
                self._set_headers()
                self.wfile.write(json.dumps({"status": "error", "message": str(e)}).encode())
                print_to_terminal(f"Error updating config: {e}")
        else:
            self.send_response(404)
            self.end_headers()

    # Potlačení logování HTTP requestů
    def log_message(self, format, *args):
        return


def is_port_in_use(port):
    """Zkontroluje, zda je port již používán"""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex(('localhost', port)) == 0


def kill_process_on_port(port):
    """Ukončí proces běžící na daném portu"""
    try:
        # Pro Linux
        subprocess.run(['fuser', '-k', f'{port}/tcp'], stderr=subprocess.DEVNULL)
        print_to_terminal(f"Ukončen proces na portu {port}")
        # Počkáme chvíli, aby se port uvolnil
        import time
        time.sleep(1)
        return True
    except:
        return False


def run_config_api():
    # Kontrola, zda je port již používán
    if is_port_in_use(CONFIG_API_PORT):
        print_to_terminal(f"Port {CONFIG_API_PORT} je již používán, pokus o ukončení...")
        if not kill_process_on_port(CONFIG_API_PORT):
            print_to_terminal(f"Nelze ukončit proces na portu {CONFIG_API_PORT}")
            sys.exit(1)

    # Vytvoříme server s nastavením SO_REUSEADDR
    server = HTTPServer(('localhost', CONFIG_API_PORT), ConfigAPIHandler)
    server.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

    print_to_terminal(f"Backend virtul enviroment setup completed, you may connect to PEER now")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print_to_terminal("Config API server ukončen.")
        server.server_close()
        sys.exit(0)


if __name__ == '__main__':
    run_config_api()
