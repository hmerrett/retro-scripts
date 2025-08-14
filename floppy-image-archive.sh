#!/bin/bash
set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <source_directory> <output_directory>"
    exit 1
fi

SOURCE_DIR="$1"
FINAL_OUTDIR="$2"
ZIP_BASENAME="archive"
ZIP_SPLIT_SIZE=1400000  # Safe split size under 1.44MB
TMP_BUILD_DIR=$(mktemp -d /tmp/floppybuild.XXXXXX)

# Check tools
for cmd in zip mkfs.vfat mcopy; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd"
        exit 1
    fi
done

# Create final output dir if it doesn't exist
mkdir -p "$FINAL_OUTDIR"

echo "[*] Using temp build directory: $TMP_BUILD_DIR"

# Create split archive
echo "[*] Creating split zip archive..."
cd "$SOURCE_DIR"
zip -r -s "$ZIP_SPLIT_SIZE" "$TMP_BUILD_DIR/$ZIP_BASENAME.zip" ./*

# Create disk images
echo "[*] Creating disk images..."
cd "$TMP_BUILD_DIR"

# Enable extended globbing
shopt -s nocaseglob
PART_FILES=(archive.z[0-9][0-9] archive.zip)
shopt -u nocaseglob

# Natural sort
IFS=$'\n' PART_FILES=($(ls -1v ${PART_FILES[@]}))
unset IFS

if [ ${#PART_FILES[@]} -eq 0 ]; then
    echo "No zip parts found in $TMP_BUILD_DIR"
    exit 1
fi

echo "[*] Found ${#PART_FILES[@]} parts:"
for f in "${PART_FILES[@]}"; do
    echo " - $f"
done

set +e  # Allow errors (e.g. mcopy fails on long filename)
PART_NUM=0
for PART_FILE in "${PART_FILES[@]}"; do
    IMG_NAME=$(printf "$TMP_BUILD_DIR/disk%03d.img" "$PART_NUM")
    echo " - Creating $IMG_NAME with label DISK%02d containing $PART_FILE" "$((PART_NUM + 1))"

    mkfs.vfat -C "$IMG_NAME" 1440 > /dev/null
    if ! MTOOLS_SKIP_CHECK=1 mcopy -i "$IMG_NAME" "$PART_FILE" ::; then
        echo "   Warning: Failed to copy $PART_FILE (might not be 8.3 format)"
    fi

    ((PART_NUM++))
done
set -e

echo "[*] Moving disk images to $FINAL_OUTDIR"
mv "$TMP_BUILD_DIR"/disk*.img "$FINAL_OUTDIR"

echo "[v] Done. $PART_NUM disk image(s) written to $FINAL_OUTDIR"
