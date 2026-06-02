#!/bin/bash

# ==============================================================================
# Script: download-extensions.sh
# Description: Downloads VKSM extension images from broadcom's public registry and bundles them into a tarball.
#              This script must be executed from a host that has access to the public registry.
#              The output of this script is a tarball that can be used with the upload_extensions.sh script
#              on an air-gapped environment.
# Requirements:
#     imgpkg - install from here - https://carvel.dev/imgpkg/docs/v0.24.0/install/
#     tar    - install from here - https://www.gnu.org/software/tar/
# ==============================================================================
set -eou pipefail

# The directory where individual image tarballs will be stored.
IMAGE_DIR="vksm-extensions"

# The final output tarball name.
OUTPUT_TARBALL="extensions.tar.gz"

# Source registry
SOURCE_REGISTRY="projects.packages.broadcom.com/vsphere/vksm"

# From 9.1, there is only one extension image published, but named to 9.0.2
IMAGE_LIST=(
  "/vksm-extensions/ga/9.0.2-1-25370929/vks-agent/repo:9.0.2-1-25370929"
)


# Check if imgpkg is installed
if ! command -v imgpkg &> /dev/null; then
    echo "Error: imgpkg is not installed or not in PATH."
    exit 1
fi

echo "Starting VKSM extension image download..."
echo "Source Registry: $SOURCE_REGISTRY"
echo "Total Images:    ${#IMAGE_LIST[@]}"
echo "Output Tarball:  $OUTPUT_TARBALL"
echo "----------------------------------------"

# Cleanup any previous runs
rm -rf "$IMAGE_DIR" "$OUTPUT_TARBALL"
mkdir -p "$IMAGE_DIR"

for IMAGE in "${IMAGE_LIST[@]}"; do
    echo "Processing: $IMAGE"

    SOURCE="$SOURCE_REGISTRY$IMAGE"

    # Sanitize the image name to use as a file path
    # Replace ':' with '.' for the tag, and create directories for the path
    IMAGE_PATH="${IMAGE#*/}" # Remove leading slash if any
    IMAGE_PATH_NO_TAG="${IMAGE_PATH%:*}"
    IMAGE_TAG="${IMAGE_PATH##*:}"
    TAR_FILENAME="${IMAGE_PATH_NO_TAG}.${IMAGE_TAG}.tar"
    DEST_TAR_PATH="$IMAGE_DIR/$TAR_FILENAME"

    mkdir -p "$(dirname "$DEST_TAR_PATH")"

    if imgpkg copy -b "$SOURCE" --to-tar "$DEST_TAR_PATH"; then
        echo "[OK] Downloaded successfully."
    else
        echo "[FAIL] Failed to download."
    fi
    echo ""
done

echo "----------------------------------------"
echo "All images downloaded. Creating tarball: $OUTPUT_TARBALL"
tar -czf "$OUTPUT_TARBALL" "$IMAGE_DIR"
echo "Cleaning up temporary directory: $IMAGE_DIR"
rm -rf "$IMAGE_DIR"

echo "----------------------------------------"
echo "Download and bundling completed!"
echo "You can now move '$OUTPUT_TARBALL' to your air-gapped environment and use 'upload-extensions.sh'." 
