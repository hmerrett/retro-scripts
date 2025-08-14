#!/bin/bash

# Exit immediately on errors unless disabled later
set -e

# Check usage
if [ $# -ne 2 ]; then
    echo "Usage: $0 <source_directory> <output_directory>"
    exit 1
fi

SOURCE_DIR="$1"
OUTPUT_DIR="$2"
TMP_DIR="$OUTPUT_DIR/tmp"
ZIP_BASENAME="archive"
ZIP_SPLIT_SIZE=1440000  # Slightly under 1.44MB for FAT overhead

# Ensure required tools exist
for cmd in zip mkfs.vfat mcopy; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "Missing required command: $cmd"
        exit 1
    fi
done

# Create temp dir
mkdir -p "$TMP_DIR"

# Create split zip archive
echo "[*] Creating split zip archive..."
cd "$SOURCE_DIR"
zip -r -s ${ZIP_SPLIT_SIZE} "$TMP_DIR/${ZIP_BASENAME}.zip" ./*

# Prepare to create disk images
echo "[*] Creating disk images..."
cd "$TMP_DIR"

# Case-insensitive glob for archive.z01, z02, ..., archive.zip
shopt -s nocaseglob
PART_FILES=(archive.z[0-9][0-9] archive.zip)
shopt -u nocaseglob

# Natural sort (z01, z02, ..., zip)
IFS=$'\n' PART_FILES=($(ls -1v ${PART_FILES[@]}))
unset IFS

if [ ${#PART_FILES[@]} -eq 0 ]; then
    echo "No zip parts found in $TMP_DIR"
    exit 1
fi

echo "[*] Found ${#PART_FILES[@]} parts:"
for f in "${PART_FILES[@]}"; do
    echo "  - $f"
done

# Disable automatic exit on failure inside the loop
set +e

PART_NUM=0
for PART_FILE in "${PART_FILES[@]}"; do
    IMG_NAME=$(printf "$OUTPUT_DIR/disk%03d.img" "$PART_NUM")
    echo "  - Writing $PART_FILE to $IMG_NAME..."

    mkfs.vfat -C "$IMG_NAME" 1440 > /dev/null
    if ! MTOOLS_SKIP_CHECK=1 mcopy -i "$IMG_NAME" "$PART_FILE" ::; then
        echo "    ⚠️  Warning: Failed to copy $PART_FILE (check for 8.3 filename issue)"
    fi

    ((PART_NUM++))
done

# Re-enable exit on error
set -e

echo "[✓] Created $PART_NUM floppy disk images in $OUTPUT_DIR."
