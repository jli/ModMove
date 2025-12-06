#!/bin/bash
set -e

echo "Building ModMove..."

# Clean build
xcodebuild -project ModMove.xcodeproj \
    -scheme ModMove \
    -configuration Release \
    clean build \
    CONFIGURATION_BUILD_DIR="$(pwd)/build"

echo "Build complete! App is at: $(pwd)/build/ModMove.app"
