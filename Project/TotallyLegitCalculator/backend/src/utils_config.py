import json
import os
import sys
import binascii

def get_app_dir():
    """Vrací adresář, kde leží app.py nebo spustitelný soubor."""
    if getattr(sys, 'frozen', False):
        # Běží z PyInstaller EXE
        return os.path.dirname(sys.executable)
    else:
        # Běží jako .py skript
        # Pokud je tento soubor v src/, vrátí nadřazený adresář
        return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

class Metods:
    def __init__(self):
        APP_DIR = get_app_dir()
        CONFIG_DIR = os.path.join(APP_DIR, 'config')
        CONFIG_PATH = os.path.join(CONFIG_DIR, 'config.json')
        BACKUP_PATH = os.path.join(CONFIG_DIR, 'backup.json')
        self.APP_DIR = APP_DIR
        self.CONFIG_DIR = CONFIG_DIR
        self.CONFIG_PATH = CONFIG_PATH
        self.BACKUP_PATH = BACKUP_PATH
        # todo, load keys from utils_crypto -- aes key gen in utils_crypto :)
        KEY_val = b'secretkey1234567'.hex()
        IV_val = b'initialvector123'.hex()
        self.loop_val = 0

        self.DEFAULT_CONFIG = {
            "MY_PORT": 12345,
            "PEER_IP": '127.0.0.1',  # musi byt jako ''
            "OWN_IP": '127.0.0.1',
            "KEY": KEY_val,
            "IV": IV_val,
            "SHUTDOWN_MSG": "==SHUTDOWN=="
        }


    def load_config(self):
        """
        Načte config.json do slovníku a vrátí ho.
        Pokud config.json neexistuje nebo je poškozený, zavolá reset_config().
        """
        # Pokud config neexistuje → reset
        if not os.path.exists(self.CONFIG_PATH):
            self.reset_config()

        try:
            with open(self.CONFIG_PATH, 'r') as f:
                config = json.load(f)
        except (json.JSONDecodeError, ValueError):
            # Pokud JSON je poškozený nebo nevalidní, resetujeme ho
            self.reset_config()
            with open(self.CONFIG_PATH, 'r') as f:
                config = json.load(f)

        return config


    def update_config(self, key, value):
        config = self.load_config()
        # save to backup
        # TODO: udělat ještě check, ze existuje backup.json
        os.makedirs(self.CONFIG_DIR, exist_ok=True)
        with open(self.BACKUP_PATH, 'w') as f:
            json.dump(config, f, indent=4)
        config[key] = value
        with open(self.CONFIG_PATH, 'w') as f:
            json.dump(config, f, indent=4)


    def reset_config(self):
        os.makedirs(self.CONFIG_DIR, exist_ok=True)
        with open(self.CONFIG_PATH, 'w') as f:
            json.dump(self.DEFAULT_CONFIG, f, indent=4)

    # this bullshitery checks if config exists and is valid -- even the values

    def check_config(self):
        required_keys = {
            "MY_PORT": int,
            "PEER_IP": str,
            "KEY": str,
            "IV": str,
            "SHUTDOWN_MSG": str
        }

        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                # Kontrola existence souboru
                if not os.path.exists(self.CONFIG_PATH):
                    print(f"[!] Attempt {attempt}/{max_attempts}: config.json not found")
                    self.reset_config()
                    continue  # Znovu načte nově vytvořený config

                # Načtení a validace obsahu
                with open(self.CONFIG_PATH, 'r') as f:
                    config = json.load(f)

                # Kontrola povinných klíčů a typů
                is_valid = True
                for key, expected_type in required_keys.items():
                    if key not in config:
                        print(f"[!] Attempt {attempt}/{max_attempts}: Missing key {key}")
                        is_valid = False
                        break
                    if not isinstance(config[key], expected_type):
                        print(f"[!] Attempt {attempt}/{max_attempts}: Invalid type for {key}")
                        is_valid = False
                        break

                # Kontrola formátu KEY/IV
                if is_valid:
                    try:
                        key_bytes = bytes.fromhex(config["KEY"])
                        iv_bytes = bytes.fromhex(config["IV"])
                        if len(key_bytes) != 16 or len(iv_bytes) != 16:
                            raise ValueError("Invalid length")
                    except (ValueError, binascii.Error) as e:
                        print(f"[!] Attempt {attempt}/{max_attempts}: Invalid crypto params - {e}")
                        is_valid = False

                # Pokud vše OK
                if is_valid:
                    return True

                # Chyba - reset a nový pokus
                print(f"[!] Attempt {attempt}/{max_attempts}: Resetting invalid config")
                self.reset_config()

            except (json.JSONDecodeError, FileNotFoundError) as e:
                print(f"[!] Attempt {attempt}/{max_attempts}: File error - {e}")
                self.reset_config()

        print("[!] Failed to load valid config after 3 attempts")
        return False


