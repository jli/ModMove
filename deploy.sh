#!/bin/bash
set -e

VERSION="${1:-v1206}"
APP_NAME="ModMove-jli-${VERSION}"
BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/ModMove.app"
DEST_PATH="/Applications/${APP_NAME}.app"

echo "Deploying ModMove to /Applications as ${APP_NAME}..."

# Check if build exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: Build not found at ${APP_PATH}"
    echo "Run ./build.sh first"
    exit 1
fi

# Remove existing version if it exists
if [ -d "$DEST_PATH" ]; then
    echo "Removing existing ${DEST_PATH}..."
    rm -rf "$DEST_PATH"
fi

# Copy to Applications
echo "Copying to ${DEST_PATH}..."
cp -R "$APP_PATH" "$DEST_PATH"

# Kill any running instances
if pgrep -f "ModMove" > /dev/null; then
    echo "Stopping running ModMove instances..."
    pkill -f "ModMove" || true
    sleep 1
fi

echo "Deploy complete!"
echo "Launch with: open '${DEST_PATH}'"
