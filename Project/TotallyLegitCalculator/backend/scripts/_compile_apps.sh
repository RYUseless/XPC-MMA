#!/bin/bash

# Absolutní cesta ke složce /backend (tj. o úroveň výš než tento skript)
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

if [[ "$(basename "$BACKEND_DIR")" != "backend" ]]; then
    echo "Skript musí být uložen v adresáři scripts uvnitř složky backend!"
    echo "Detekovaný backend adresář: $BACKEND_DIR"
    exit 1
fi

cd "$BACKEND_DIR" || exit 1

# i guess if the src exists, the .py in it should too
if [[ -d ./src && -f ./app.py && -f ./app_console.py && ./src/config_api.py && -f ./_activate_venv.sh ]]; then
    echo "=== ULTRA MIGA ŠMIGA ==="
    source ./_venv_create.sh
    pyinstaller -F --paths=src/ --paths=config/ --paths=.cert/ --paths=.old_mess/  app.py || echo "what"
    pyinstaller -F --paths=src/ --paths=config/ --paths=.cert/ --paths=.old_mess/  app_console.py || echo "what2"
    pyinstaller -F --paths=src/ --paths=config/ src/config_api.py || echo "what3"
else
   echo "DAAAAAAAAAAAAAAAAAAAMM DANIEL UH UH UH UH!"
fi

