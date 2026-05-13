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

# The list of required extensions for a build can be taken from "publish/vksm/extensions.map" file in the buildweb
# eg. for released build 9.0.2-0-25145732 it's here https://build-squid.vcfd.broadcom.net/build/mts/release/bora-24965341/publish/vksm/extensions.map
IMAGE_LIST=(
  "/extensions/9.0.2-0-25145732/agent-updater/agent-updater:latest"
  "/extensions/9.0.2-0-25145732/agent-updater/manifest:latest"
  "/extensions/9.0.2-0-25145732/agent-updater/agentupdater-workload:latest"
  "/extensions/9.0.2-0-25145732/cluster-health-extension/manager:latest"
  "/extensions/9.0.2-0-25145732/cluster-sync-extension/cluster-sync-extension:latest"
  "/extensions/9.0.2-0-25145732/cluster-health-extension/manifest:latest"
  "/extensions/9.0.2-0-25145732/cluster-sync-extension/manifest:latest"
  "/extensions/9.0.2-0-25145732/extension-manager/extension-manager:latest"
  "/extensions/9.0.2-0-25145732/extension-updater/extension-updater:latest"
  "/extensions/9.0.2-0-25145732/extension-manager/manifest:latest"
  "/extensions/9.0.2-0-25145732/extension-updater/manifest:latest"
  "/extensions/9.0.2-0-25145732/gatekeeper:latest"
  "/extensions/9.0.2-0-25145732/gatekeeper-operator/manifest:latest"
  "/extensions/9.0.2-0-25145732/gatekeeper-operator:latest"
  "/extensions/9.0.2-0-25145732/intent-agent/intent-agent:latest"
  "/extensions/9.0.2-0-25145732/intent-agent/manifest:latest"
  "/extensions/9.0.2-0-25145732/policy-insight-extension:latest"
  "/extensions/9.0.2-0-25145732/policy-insight-extension/manifest:latest"
  "/extensions/9.0.2-0-25145732/fleet-mgmt/policy-sync-extension:latest"
  "/extensions/9.0.2-0-25145732/fleet-mgmt/policy-sync-extension/manifest:latest"
  "/extensions/9.0.2-0-25145732/tmc-bootstrapper/manager:latest"
  "/extensions/9.0.2-0-25145732/tmc-bootstrapper/manifest:latest"
  "/extensions/9.0.2-0-25145732/tmc-observer/tmc-observer:latest"
  "/extensions/9.0.2-0-25145732/tmc-observer/logs-collector:latest"
  "/extensions/9.0.2-0-25145732/tmc-observer/manifest:latest"
  "/extensions/9.0.2-0-25145732/dataprotection/extension:latest"
  "/extensions/9.0.2-0-25145732/dataprotection/manifest:latest"
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

    if imgpkg copy -i "$SOURCE" --to-tar "$DEST_TAR_PATH"; then
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
