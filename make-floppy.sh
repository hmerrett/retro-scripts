#!/bin/bash
set -euo pipefail

# Supported floppy sizes: label -> bytes
declare -A FLOPPY_SIZES=(
    [180k]=184320
    [360k]=368640
    [720k]=737280
    [1.2m]=1228800
    [1.44m]=1474560
)

IMAGE_SIZE=${FLOPPY_SIZES[1.44m]}
SIZE_LABEL="1.44m"

# Parse optional flag
if [ "$#" -gt 1 ]; then
    echo "Usage: $0 [--size=180k|360k|720k|1.2m|1.44m]"
    exit 1
fi

for arg in "$@"; do
    case $arg in
        --size=*)
            label="${arg#--size=}"
            label="${label,,}"   # lowercase
            if [[ -v FLOPPY_SIZES["$label"] ]]; then
                IMAGE_SIZE=${FLOPPY_SIZES[$label]}
                SIZE_LABEL="$label"
            else
                echo "Error: Unknown size '$label'."
                echo "Usage: $0 [--size=180k|360k|720k|1.2m|1.44m]"
                exit 1
            fi
            ;;
        *)
            echo "Usage: $0 [--size=180k|360k|720k|1.2m|1.44m]"
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
AVAIL_BYTES=$(df -B1 --output=avail . | tail -1)
if [ "$AVAIL_BYTES" -lt "$IMAGE_SIZE" ]; then
    echo "Error: Not enough free space on filesystem to create floppy image."
    exit 1
fi

# Get list of regular files
mapfile -d '' FILES < <(find . -maxdepth 1 -type f -not -name "*.img" -print0)

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

echo "Floppy image '$IMAGE_NAME' created successfully (${SIZE_LABEL} / ${IMAGE_SIZE} bytes)"
