#!/bin/bash

# Zjistit cestu k adresáři skriptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Zjistit cestu k projektu (o úroveň výš než backend)
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Kontrola, zda jsme ve správném adresáři
if [[ "$(basename "$PROJECT_DIR")" != "TotallyLegitCalculator" ]]; then
    echo "Skript musí být spuštěn z adresáře backend v projektu TotallyLegitCalculator"
    echo "Aktuální adresář: $SCRIPT_DIR"
    echo "Nadřazený adresář: $PROJECT_DIR"
    exit 1
fi

# Přejít do adresáře backend
cd "$SCRIPT_DIR"

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
