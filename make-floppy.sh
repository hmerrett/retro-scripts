#!/bin/bash
set -euo pipefail

# Constants
SIZE_144=1474560
SIZE_720=737280
IMAGE_SIZE=$SIZE_144

# Parse optional flag
for arg in "$@"; do
    case $arg in
        --size=1.44)
            IMAGE_SIZE=$SIZE_144
            ;;
        --size=720k)
            IMAGE_SIZE=$SIZE_720
            ;;
        *)
            echo "Usage: $0 [--size=1.44|--size=720k]"
            exit 1
            ;;
    esac
done

# Image name = current directory
DIRNAME="$(basename "$PWD")"
IMAGE_NAME="${DIRNAME}.img"

# Check tools
for tool in mkfs.fat mcopy df truncate stat find; do
    if ! command -v "$tool" >/dev/null; then
        echo "Error: Required tool '$tool' is not installed."
        exit 1
    fi
done

# Check free space
#AVAIL_BYTES=$(df -P . | awk 'NR==2 {print $4 * 1024}')
AVAIL_BYTES=$(df -B1 --output=avail . | tail -1)
if [ "$AVAIL_BYTES" -lt "$IMAGE_SIZE" ]; then
    echo "Error: Not enough free space on filesystem to create floppy image."
    exit 1
fi

# Get list of regular files
mapfile -d '' FILES < <(find . -maxdepth 1 -type f -print0)

if [ "${#FILES[@]}" -eq 0 ]; then
    echo "Error: No regular files found in current directory."
    exit 1
fi

# Calculate total size
TOTAL_BYTES=0
for file in "${FILES[@]}"; do
    size=$(stat -c %s "$file")
    TOTAL_BYTES=$((TOTAL_BYTES + size))
done

if [ "$TOTAL_BYTES" -gt "$IMAGE_SIZE" ]; then
    echo "Error: Files total $TOTAL_BYTES bytes, which exceeds floppy capacity of $IMAGE_SIZE bytes."
    exit 1
fi

# Create and format image
truncate -s "$IMAGE_SIZE" "$IMAGE_NAME"
mkfs.fat -F 12 "$IMAGE_NAME" > /dev/null

# Copy files into image
for file in "${FILES[@]}"; do
    if ! mcopy -i "$IMAGE_NAME" -n -- "$file" ::; then
        echo "Error: Failed to copy '$file' into floppy image."
        rm -f "$IMAGE_NAME"
        exit 1
    fi
done

echo "Floppy image '$IMAGE_NAME' created successfully (${IMAGE_SIZE} bytes)"
