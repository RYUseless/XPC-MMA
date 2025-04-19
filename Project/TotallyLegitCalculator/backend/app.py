from pathlib import Path
# moje moduly:
import src.peer as pr
import src.utils_config as json_utl
import src.utils_cert as cert_utl
import src.peer_ssl as pr_ssl


def check_cert_folder() -> bool:
    cert_dir = Path(__file__).parent / ".cert"

    required_files = ["key.pem", "cert.pem", "san.cnf"]
    missing_files = []
    empty_files = []

    if not cert_dir.exists() or not cert_dir.is_dir():
        print(f"[ERROR] Složka {cert_dir} neexistuje nebo není adresář.")
        return False

    for filename in required_files:
        file_path = cert_dir / filename
        if not file_path.exists():
            missing_files.append(filename)
        else:
            if file_path.stat().st_size == 0:
                empty_files.append(filename)

    if missing_files:
        print(f"[ERROR] Chybí soubory: {', '.join(missing_files)} v {cert_dir}")
    if empty_files:
        print(f"[ERROR] Soubor(y) jsou prázdné: {', '.join(empty_files)} v {cert_dir}")

    if missing_files or empty_files:
        return False

    print(f"[INFO] Složka {cert_dir} obsahuje všechny potřebné a platné soubory.")
    return True


def main():
    cert_ok = check_cert_folder()
    if cert_ok is False:
        cert_utl.Generate().run()


    json_ok = json_utl.check_config()
    if json_ok is False:
        print("There is a possible issue with this code or config.json")
        main()
        exit(1)

    #peer = pr.Peer_connection()
    #peer.start()

    per_ssl = pr_ssl.Peer_connection()
    per_ssl.start()


if __name__ == '__main__':
    main()
    # ssl gen:
    # openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    #   -keyout key.pem -out cert.pem \
    #   -config san.cnf

