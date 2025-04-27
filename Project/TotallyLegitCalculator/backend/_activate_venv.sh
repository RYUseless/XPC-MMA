#!/bin/bash

# Zjistit cestu k adresáři skriptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# Aktivace virtuálního prostředí
if ! source "$SCRIPT_DIR/.venv/bin/activate"; then
  echo "Failed to activate virtual environment"
  exit 2
fi
