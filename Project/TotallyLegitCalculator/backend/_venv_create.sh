#!/bin/bash

if ! python3 -m venv .venv; then
  echo "Failed to create virtual environment"
  exit 1
fi

#!/bin/bash

if [[ -f ./_activate_venv.sh ]]; then
    source ./_activate_venv.sh
else
    echo "There is no activate_venv.sh file in this working dir, please double-check."
    exit 1
fi



echo "Done I hope :)"
