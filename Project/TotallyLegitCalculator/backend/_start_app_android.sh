#!/system/bin/sh
# Místo #!/bin/bash

echo "Starting app..."
cd "$(dirname "$0")"

# Spuštění aplikace
python ./app.py
# nebo
# python ./app.py
