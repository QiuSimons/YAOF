#!/bin/bash

# Set base directory to the current directory
BASE_DIR=$(pwd)

# Setting permissions for directories, excluding staging_dir
find "$BASE_DIR" -path "$BASE_DIR/staging_dir" -prune -o -type d -exec chmod 755 {} \;

# Setting permissions for files, excluding staging_dir
find "$BASE_DIR" -path "$BASE_DIR/staging_dir" -prune -o -type f -exec chmod 644 {} \;

# Setting executable permissions for specific scripts, excluding staging_dir
find "$BASE_DIR" -path "$BASE_DIR/staging_dir" -prune -o -type f \( -name "*.sh" -o -name "*.pl" -o -name "*.py" -o -name "*.awk" -o -name "*bin*" -o -name "Makefile" -o -name "configure" \) -exec chmod 755 {} \;

# Setting executable permissions for scripts in scripts directory, excluding staging_dir
find "$BASE_DIR/scripts" -path "$BASE_DIR/staging_dir" -prune -o -type f -exec chmod 755 {} \;

# Setting special permissions for feeds, excluding staging_dir
find "$BASE_DIR/feeds" -path "$BASE_DIR/staging_dir" -prune -o -type f -exec chmod 755 {} \;

# Setting executable permissions for init scripts in package, excluding staging_dir
find "$BASE_DIR" -path "$BASE_DIR/staging_dir" -prune -o -type f -exec grep -l 'sh' {} \; | xargs chmod 755
find "$BASE_DIR" -path "$BASE_DIR/staging_dir" -prune -o -type f -exec grep -l 'PKG' {} \; | xargs chmod 755
find "$BASE_DIR" -path "$BASE_DIR/staging_dir" -prune -o -type f -exec grep -l 'uci' {} \; | xargs chmod 755

# Setting special permissions for the build system scripts
chmod 755 "$BASE_DIR/scripts/feeds"

echo "Permissions have been fixed."
