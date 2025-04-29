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
            reset_config()

        try:
            with open(self.CONFIG_PATH, 'r') as f:
                config = json.load(f)
        except (json.JSONDecodeError, ValueError):
            # Pokud JSON je poškozený nebo nevalidní, resetujeme ho
            reset_config()
            with open(self.CONFIG_PATH, 'r') as f:
                config = json.load(f)

        return config


    def update_config(self, key, value):
        config = load_config()
        # save to backup
        # TODO: udělat ještě check, ze existuje backup.json
        os.makedirs(CONFIG_DIR, exist_ok=True)
        with open(self.BACKUP_PATH, 'w') as f:
            json.dump(config, f, indent=4)
        config[key] = value
        with open(self.CONFIG_PATH, 'w') as f:
            json.dump(config, f, indent=4)


    def reset_config(self):
        os.makedirs(CONFIG_DIR, exist_ok=True)
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

        if not os.path.exists(self.CONFIG_PATH):
            print("[!] config.json not found, resetting to default.")
            # TODO: add create function, that creates config.json and the folder if needed
            reset_config()
            check_config()
            return False

        try:
            with open(self.CONFIG_PATH, 'r') as f:
                config = json.load(f)

            for key, expected_type in required_keys.items():
                if key not in config:
                    print(f"[!] Missing key: {key}, resetting config.")
                    reset_config()
                    check_config()
                    return False
                if not isinstance(config[key], expected_type):
                    print(f"[!] Invalid type for key: {key}, resetting config.")
                    reset_config()
                    # TODO: it goes to endles loop, fix later:
                    value = check_config()
                    if value is False:
                        exit(0)
                    print("key could not be restored, lmao?")
                    return False

            #  HEX formát a délka check
            try:
                key_bytes = bytes.fromhex(config["KEY"])
                iv_bytes = bytes.fromhex(config["IV"])
                if len(key_bytes) != 16 or len(iv_bytes) != 16:
                    raise ValueError("Invalid KEY/IV length")
            except (ValueError, binascii.Error):
                print("[!] KEY or IV is not valid hex or has wrong length. Resetting config.")
                reset_config()
                return False

        except (json.JSONDecodeError, FileNotFoundError) as e:
            print(f"[!] Failed to read config: {e}, resetting.")
            reset_config()
            return False  # big oopsie

