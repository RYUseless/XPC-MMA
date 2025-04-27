#!/system/bin/sh
# Místo #!/bin/bash

echo "Starting config API..."
cd "$(dirname "$0")"

# Na Androidu většinou nemůžeme vytvořit venv standardním způsobem
# Místo toho použijeme přímo Python, pokud je nainstalovaný

# Kontrola a ukončení existujících instancí na portu 8090
# (Toto nemusí na Androidu fungovat, záleží na dostupných nástrojích)

# Spuštění config API
python3 src/config_api.py
# nebo
# python src/config_api.py
