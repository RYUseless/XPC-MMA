#!/bin/bash

echo "hopefully bullshit, which should set up window resolution to desired size."
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if the 'linux' folder exists and is not empty
if [ ! -d "$SCRIPT_DIR/../linux" ] || [ -z "$(ls -A $SCRIPT_DIR/../linux)" ]; then
    echo "The 'linux' folder does not exist or is empty, attempting to recreate it."
    cd $SCRIPT_DIR/.. 
    flutter create .
    
    # Re-check if the 'linux' folder exists and is not empty after creation
    if [ ! -d "$SCRIPT_DIR/../linux" ] || [ -z "$(ls -A $SCRIPT_DIR/../linux)" ]; then
        echo "The 'linux' folder still does not exist or is empty. Cannot proceed."
        exit 1
    fi
fi

# If the 'linux' folder exists, continue with the build
cd $SCRIPT_DIR/.. 
echo "Building for Linux"
flutter build linux || echo "oiiii"

# Set the window resolution in the my_application.cc file
perl -pi.bak -e "s|1280, 720|450, 700|" "$SCRIPT_DIR/../linux/runner/my_application.cc"


