#!/bin/bash

# Set base directory to the current directory
BASE_DIR=$(pwd)

# Setting permissions for directories
find "$BASE_DIR" -type d -exec chmod 755 {} \;

# Setting permissions for files
find "$BASE_DIR" -type f -exec chmod 644 {} \;

# Setting executable permissions for specific scripts
find "$BASE_DIR" -type f \( -name "*.sh" -o -name "*.pl" -o -name "*.py" -o -name "*.awk" -o -name "Makefile" -o -name "configure" \) -exec chmod 755 {} \;

# Setting executable permissions for scripts in scripts directory
find "$BASE_DIR/scripts" -type f -exec chmod 755 {} \;

# Setting special permissions for feeds
find "$BASE_DIR/feeds" -type f -exec chmod 755 {} \;
find "$BASE_DIR/package" -type f -exec chmod 755 {} \;

# Setting special permissions for the build system scripts
chmod 755 "$BASE_DIR/scripts/feeds"
chmod 755 "$BASE_DIR/scripts/feeds/update"
chmod 755 "$BASE_DIR/scripts/feeds/install"

echo "Permissions have been fixed."
