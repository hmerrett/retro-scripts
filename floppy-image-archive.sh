#!/bin/bash
set -e

SOURCE_DIR="$1"
DEST_DIR="$2"

if [[ -z "$SOURCE_DIR" || -z "$DEST_DIR" ]]; then
    echo "Usage: $0 <source_dir> <destination_dir>"
    exit 1
fi

SOURCE_DIR="$(realpath "$SOURCE_DIR")"
DEST_DIR="$(realpath "$DEST_DIR")"

BUILD_DIR="$(mktemp -d -t floppybuild.XXXXXXXX)"
echo "[*] Using temp build directory: $BUILD_DIR"

cleanup() {
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

echo "[*] Creating split ARJ archive..."
pushd "$SOURCE_DIR" > /dev/null

# Run ARJ
set +e      
arj a -v1400000 -r -y "$BUILD_DIR/archive.arj" *
set -e      
popd > /dev/null

# Get list of parts
PARTS=($(ls "$BUILD_DIR"/archive.a* 2>/dev/null | sort -V))
if [[ ${#PARTS[@]} -eq 0 ]]; then
    echo "[!] No ARJ archive parts found in $BUILD_DIR"
    exit 1
fi

mkdir -p "$DEST_DIR"

i=1
for part in "${PARTS[@]}"; do
    label=$(printf "DISK%02d" "$i")
    imgname=$(printf "%s/disk%03d.img" "$DEST_DIR" "$i")
    echo "[*] Creating image $(basename "$imgname") with label $label containing $(basename "$part")"

    mformat -f 1440 -C -i "$imgname" ::
    mlabel -i "$imgname" ::$label
    mcopy -i "$imgname" "$part" ::

    ((i++))
done
