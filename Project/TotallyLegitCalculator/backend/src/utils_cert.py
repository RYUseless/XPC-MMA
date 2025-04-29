import json
import subprocess
import sys
from pathlib import Path
import src.utils_config as json_util

class Generate:
    @staticmethod
    def run():
        BASE_DIR = Path(sys.executable).parent
        if getattr(sys, 'frozen', False):
            BASE_DIR = Path(sys.executable).parent
        else:
            BASE_DIR = Path(__file__).parent.parent

        CERT_DIR = BASE_DIR / ".cert"
        CERT_DIR.mkdir(parents=True, exist_ok=True)

        key_path = CERT_DIR / "key.pem"
        cert_path = CERT_DIR / "cert.pem"

        # OPRAVA: Pokud certifikát i klíč existují, přeskoč generování!
        if key_path.exists() and cert_path.exists():
            print(f"Certifikát a klíč už existují v {CERT_DIR}, generování přeskočeno.")
            return

        ip_address = json_util.load_config()["OWN_IP"]

        san_conf = f"""
        [req]
        distinguished_name = req_distinguished_name
        x509_extensions = v3_req
        prompt = no

        [req_distinguished_name]
        CN = {ip_address}

        [v3_req]
        keyUsage = keyEncipherment, dataEncipherment
        extendedKeyUsage = serverAuth
        subjectAltName = @alt_names

        [alt_names]
        IP.1 = {ip_address}
        """

        san_conf_path = CERT_DIR / "san.cnf"
        with open(san_conf_path, "w") as f:
            f.write(san_conf.strip())

        print(f"san.cnf vytvořen v {san_conf_path}")

        cmd = [
            "openssl", "req", "-x509", "-nodes", "-days", "365",
            "-newkey", "rsa:2048",
            "-keyout", str(key_path),
            "-out", str(cert_path),
            "-config", str(san_conf_path)
        ]

        print("Spouštím OpenSSL příkaz...")
        result = subprocess.run(cmd, capture_output=True, text=True)

        if result.returncode == 0:
            print(f"Certifikát a klíč vygenerovány v {CERT_DIR}")
        else:
            print("Chyba při generování certifikátu:")
            print(result.stderr)



