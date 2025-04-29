#!/bin/bash

# Absolutní cesta ke složce /backend (tj. o úroveň výš než tento skript)
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

# Kontrola, že jsme opravdu v backend složce
if [[ "$(basename "$BACKEND_DIR")" != "backend" ]]; then
    echo "Skript musí být uložen v adresáři scripts uvnitř složky backend!"
    echo "Detekovaný backend adresář: $BACKEND_DIR"
    exit 1
fi

cd "$BACKEND_DIR" || exit 1

# Vytvoření virtuálního prostředí
if ! python3 -m venv .venv; then
  echo "Failed to create virtual environment"
  exit 1
fi

if [[ -f ./_activate_venv.sh ]]; then
    source ./_activate_venv.sh
else
    echo "There is no _activate_venv.sh file in this working dir, please double-check."
    exit 1
fi

# Pokud existuje requirements.txt, nainstaluj balíčky
if [[ -f requirements.txt ]]; then
    echo "Installing packages from requirements.txt..."
    pip install -r requirements.txt
else
    echo "requirements.txt not found, skipping package installation."
fi

python3 ./app.py

