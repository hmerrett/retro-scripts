#!/bin/bash
#
# ddrescue-all.sh
# Safely ddrescue all partitions from a specified device to a destination directory
#
# Usage: sudo ./ddrescue-all.sh /dev/sda /path/to/output
#

set -e

SRC="$1"
DEST="$2"

if [[ -z "$SRC" || -z "$DEST" ]]; then
    echo "Usage: $0 /dev/sdX /path/to/output"
    exit 1
fi

if [[ ! -b "$SRC" ]]; then
    echo "Error: $SRC is not a valid block device."
    exit 1
fi

if [[ ! -d "$DEST" ]]; then
    echo "Creating output directory: $DEST"
    mkdir -p "$DEST" || { echo "Failed to create directory."; exit 1; }
fi

echo "Detecting partitions on $SRC..."
PARTS=$(lsblk -ln -o NAME "$SRC" | grep -E "$(basename "$SRC")[0-9]+" || true)

if [[ -z "$PARTS" ]]; then
    echo "No partitions found on $SRC."
    exit 1
fi

for PART in $PARTS; do
    SRC_DEV="/dev/$PART"
    IMG_PATH="$DEST/${PART}.img"
    LOG_PATH="$DEST/${PART}.log"

    echo "------------------------------------------------"
    echo "Starting ddrescue for $SRC_DEV"
    echo "Output: $IMG_PATH"
    echo "Log:    $LOG_PATH"
    echo "------------------------------------------------"

    ddrescue -f -n "$SRC_DEV" "$IMG_PATH" "$LOG_PATH"
    ddrescue -d -r3 "$SRC_DEV" "$IMG_PATH" "$LOG_PATH"

    echo "Finished $SRC_DEV"
done

echo "------------------------------------------------"
echo "All partitions from $SRC have been imaged to $DEST."
echo "------------------------------------------------"
