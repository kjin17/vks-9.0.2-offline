#!/bin/bash

# ==============================================================================
# Script: upload-extensions.sh
# Description: Unpacks a tarball of extension images and uploads them to a given OCI registry.
#              This script is intended to be used in an air-gapped environment.
#              It consumes the tarball created by the download-extensions.sh script.
# Requirements:
#     imgpkg - install from here - https://carvel.dev/imgpkg/docs/v0.24.0/install/
#     tar    - install from here - https://www.gnu.org/software/tar/
# Usage:
#     ./upload-extensions.sh <path_to_tarball> <destination_registry>
# Example:
#     ./upload-extensions.sh extensions.tar.gz my.private.registry.com/vksm
# ==============================================================================

set -eou pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <path_to_tarball> <destination_registry>"
    exit 1
fi

TARBALL_PATH=$1
DEST_REGISTRY=$2
TEMP_DIR="temp_image_upload"
IMAGE_DIR_IN_TAR="vksm-extensions"

# Check if imgpkg is installed
if ! command -v imgpkg &> /dev/null; then
    echo "Error: imgpkg is not installed or not in PATH."
    exit 1
fi

echo "Starting VKSM extension image upload..."
echo "Source Tarball:     $TARBALL_PATH"
echo "Destination Registry: $DEST_REGISTRY"
echo "----------------------------------------"

# Cleanup any previous runs
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

echo "Extracting tarball..."
tar -xzf "$TARBALL_PATH" -C "$TEMP_DIR"

# Check if the expected directory is in the tarball
if [ ! -d "$TEMP_DIR/$IMAGE_DIR_IN_TAR" ]; then
    echo "Error: Tarball does not contain the expected '$IMAGE_DIR_IN_TAR' directory."
    rm -rf "$TEMP_DIR"
    exit 1
fi

IMAGE_FILES=$(find "$TEMP_DIR/$IMAGE_DIR_IN_TAR" -type f -name "*.tar")

if [ -z "$IMAGE_FILES" ]; then
    echo "No .tar files found in the archive. Nothing to do."
    rm -rf "$TEMP_DIR"
    exit 0
fi


for TAR_FILE in $IMAGE_FILES; do
    # Reconstruct image name from the file path
    # e.g. temp_image_upload/extension_images/vksm-extensions/ga/9.0.2-1-25370929/vks-agent/repo.9.0.2-1-25370929.tar
    # becomes vksm-extensions/ga/9.0.2-1-25370929/vks-agent/repo:9.0.2-1-25370929

    IMAGE_SUB_PATH=${TAR_FILE#"$TEMP_DIR/$IMAGE_DIR_IN_TAR/"} # remove prefix
    IMAGE_SUB_PATH_NO_EXT=${IMAGE_SUB_PATH%".tar"} # remove .tar suffix
    IMAGE_SUB_PATH_NO_NAME=${IMAGE_SUB_PATH_NO_EXT%/*} # remove repo.9.0.2-1-25370929 suffix
    IMAGE_SUB_PATH_NAME=${IMAGE_SUB_PATH##*/} # get repo.9.0.2-1-25370929 suffix
    IMAGE_NAME=${IMAGE_SUB_PATH_NAME%%.*} # remove .9.0.2-1-25370929 suffix

    IMAGE_PATH="${IMAGE_SUB_PATH_NO_NAME}/${IMAGE_NAME}"

    DESTINATION_REPO="$DEST_REGISTRY/${IMAGE_PATH}"

    echo "Uploading ${TAR_FILE} to ${DESTINATION_REPO}"

    if imgpkg copy  --tar "$TAR_FILE" --to-repo "$DESTINATION_REPO"; then
        echo "[OK] Uploaded successfully to $DESTINATION_REPO"
    else
        echo "[FAIL] Failed to upload."
    fi
    echo ""
done

echo "Cleaning up temporary directory: $TEMP_DIR"
rm -rf "$TEMP_DIR"

echo "----------------------------------------"
echo "Upload completed!"

