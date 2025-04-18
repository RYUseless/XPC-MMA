import json
import os

CONFIG_PATH = os.path.join(os.path.dirname(__file__), '../config/config.json')
##TODO: dodelat if none config.json, tak reset
##TODO: nejake dalsi try catche


KEY_val = b'secretkey1234567'.hex()
IV_val = b'initialvector123'.hex()

DEFAULT_CONFIG = {
    "MY_PORT": 12345,
    "PEER_IP": '127.0.0.1', # musi byt jako ''
    "KEY": KEY_val,
    "IV": IV_val,
    "SHUTDOWN_MSG": "==SHUTDOWN=="
}

def load_config():
    """
    Načte config.json do slovníku a vrátí ho.
    Pokud config.json neexistuje nebo je poškozený, zavolá reset_config().
    """
    # Pokud config neexistuje, resetujeme ho
    if not os.path.exists(CONFIG_PATH):
        reset_config()

    try:
        with open(CONFIG_PATH, 'r') as f:
            config = json.load(f)
    except (json.JSONDecodeError, ValueError):
        # Pokud JSON je poškozený nebo nevalidní, resetujeme ho
        reset_config()
        with open(CONFIG_PATH, 'r') as f:
            config = json.load(f)

    return config

def update_config(key, value):
    config = load_config()
    config[key] = value
    with open(CONFIG_PATH, 'w') as f:
        json.dump(config, f, indent=4)

def reset_config():
    with open(CONFIG_PATH, 'w') as f:
        json.dump(DEFAULT_CONFIG, f, indent=4)

