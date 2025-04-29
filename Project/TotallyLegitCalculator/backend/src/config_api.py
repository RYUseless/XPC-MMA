import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import sys
import os
import socket
import subprocess

import utils_config as js_utl

# Funkce pro výpis do terminálu, který bude okamžitě viditelný v Dart
def print_to_terminal(message):
    print(f"\n=== {message} ===", flush=True)
    sys.stdout.flush()


class ConfigAPIHandler(BaseHTTPRequestHandler):
    def _set_headers(self, content_type="application/json"):
        self.json_util = js_utl.Metods()
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
            config = self.json_util.load_config()
            self.wfile.write(json.dumps(config).encode())
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
                        self.json_util.update_config(key, config_data[key])
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


class Starter:
    def __init__(self):
        self.lmao = "lmao"
        self.json_util = js_utl.Metods()
        self.CONFIG_API_PORT = 8090


    def is_port_in_use(self, port):
        """Zkontroluje, zda je port již používán"""
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            return s.connect_ex(('localhost', port)) == 0


    def kill_process_on_port(self, port):
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


    def run_config_api(self):
        json_ok = self.json_util.check_config()
        if json_ok is False:
            print_to_terminal("There is a possible issue with this code or config.json")
            exit(1)
        # kontrola, pokud nejaka instance frčí na portu, kdyžtak kill!!!!!!
        if self.is_port_in_use(self.CONFIG_API_PORT):
            print_to_terminal(f"Port {self.CONFIG_API_PORT} je již používán, pokus o ukončení...")
            if not self.kill_process_on_port(self.CONFIG_API_PORT):
                print_to_terminal(f"Nelze ukončit proces na portu {self.CONFIG_API_PORT}")
                sys.exit(1)

        # Vytvoříme server s nastavením SO_REUSEADDR
        server = HTTPServer(('localhost', self.CONFIG_API_PORT), ConfigAPIHandler)
        server.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        print_to_terminal(f"Backend vrtual enviroment setup completed, you may connect to PEER now")

        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print_to_terminal("Config API server ukončen.")
            server.server_close()
            sys.exit(0)

def main():
    instance = Starter()
    instance.run_config_api()

if __name__ == '__main__':
    main()
