#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERSION="${1:-v$(date +%m%d-%H%M)}"
APP_NAME="ModMove-jli-${VERSION}"
BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/ModMove.app"
DEST_PATH="/Applications/${APP_NAME}.app"

echo -e "${BLUE}=== Deploying ModMove ===${NC}"
echo ""

# Check if build exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Build not found at ${APP_PATH}${NC}"
    echo "Run ./build.sh first"
    exit 1
fi

# Check for running instances (only actual app binary, not terminals/editors)
echo -e "${YELLOW}Checking for running instances...${NC}"
EXISTING_PROCS=$(ps aux | grep "/Applications/ModMove.*\.app/Contents/MacOS/ModMove" | grep -v grep || true)
if [ -n "$EXISTING_PROCS" ]; then
    echo "Found running instances:"
    echo "$EXISTING_PROCS" | awk '{print "  PID " $2 ": " $11}'
    echo ""
    echo -e "${YELLOW}Stopping all ModMove instances...${NC}"
    MODMOVE_PIDS=$(echo "$EXISTING_PROCS" | awk '{print $2}')
    echo "$MODMOVE_PIDS" | while read -r pid; do
        echo "  Killing PID $pid"
        kill "$pid" 2>/dev/null || true
    done
    sleep 1
    echo -e "${GREEN}  Stopped existing instances${NC}"
else
    echo "  No instances running"
fi
echo ""

# Clean up old versions (keep only last 3)
echo -e "${YELLOW}Cleaning up old versions...${NC}"
OLD_VERSIONS=$(ls -dt /Applications/ModMove-jli-*.app 2>/dev/null | tail -n +4 || true)
if [ -n "$OLD_VERSIONS" ]; then
    echo "$OLD_VERSIONS" | while read -r old_app; do
        echo "  Removing: $(basename "$old_app")"
        rm -rf "$old_app"
    done
else
    echo "  No old versions to clean up"
fi
echo ""

# Remove existing version if it exists
if [ -d "$DEST_PATH" ]; then
    echo "Removing existing ${DEST_PATH}..."
    rm -rf "$DEST_PATH"
fi

# Copy to Applications
echo -e "${YELLOW}Copying to ${DEST_PATH}...${NC}"
cp -R "$APP_PATH" "$DEST_PATH"
echo -e "${GREEN}Deploy complete!${NC}"
echo ""

echo "Deployed version: ${APP_NAME}"
echo "Location: ${DEST_PATH}"
echo ""
echo "Launch with: open '${DEST_PATH}'"
echo "Or use: ./run.sh to build, deploy, and launch in one step"
