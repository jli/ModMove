#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Generate version from current date/time (e.g., v1206-1755)
VERSION="${1:-v$(date +%m%d-%H%M)}"
APP_NAME="ModMove-jli-${VERSION}"
BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/ModMove.app"
DEST_PATH="/Applications/${APP_NAME}.app"

echo -e "${BLUE}=== ModMove Build, Deploy & Run ===${NC}"
echo ""

# Step 1: Check for running instances BEFORE building
echo -e "${YELLOW}[1/5] Checking for existing ModMove instances...${NC}"
EXISTING_PROCS=$(ps aux | grep -i "[M]odMove" || true)
if [ -n "$EXISTING_PROCS" ]; then
    echo "Found running instances:"
    echo "$EXISTING_PROCS" | awk '{print "  PID " $2 ": " $11 " " $12 " " $13}'
    echo ""
else
    echo "  No instances running"
    echo ""
fi

# Step 2: Build
echo -e "${YELLOW}[2/5] Building ModMove (Release configuration)...${NC}"
xcodebuild -project ModMove.xcodeproj \
    -scheme ModMove \
    -configuration Release \
    clean build \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    2>&1 | grep -E '(Building|Compiling|Linking|CodeSign|BUILD SUCCEEDED|BUILD FAILED|error:)' || true

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Build failed! App not found at ${APP_PATH}${NC}"
    exit 1
fi
echo -e "${GREEN}  Build complete!${NC}"
echo ""

# Step 3: Kill existing instances
echo -e "${YELLOW}[3/5] Stopping all ModMove instances...${NC}"
if pgrep -f "[M]odMove" > /dev/null; then
    pkill -f "[M]odMove" || true
    sleep 1
    echo -e "${GREEN}  Stopped existing instances${NC}"
else
    echo "  No instances to stop"
fi
echo ""

# Step 4: Deploy
echo -e "${YELLOW}[4/5] Deploying to /Applications/${APP_NAME}.app...${NC}"

# Clean up old versions (keep only last 3)
OLD_VERSIONS=$(ls -dt /Applications/ModMove-jli-*.app 2>/dev/null | tail -n +4 || true)
if [ -n "$OLD_VERSIONS" ]; then
    echo "  Cleaning up old versions..."
    echo "$OLD_VERSIONS" | while read -r old_app; do
        echo "    Removing: $(basename "$old_app")"
        rm -rf "$old_app"
    done
fi

# Remove existing version if it exists
if [ -d "$DEST_PATH" ]; then
    rm -rf "$DEST_PATH"
fi

# Copy to Applications
cp -R "$APP_PATH" "$DEST_PATH"
echo -e "${GREEN}  Deployed to ${DEST_PATH}${NC}"
echo ""

# Step 5: Launch and verify
echo -e "${YELLOW}[5/5] Launching ModMove and verifying...${NC}"
open "$DEST_PATH"
sleep 2

# Verify exactly one instance is running
echo ""
echo -e "${BLUE}Process verification:${NC}"
RUNNING_PROCS=$(ps aux | grep -i "[M]odMove" || true)

if [ -z "$RUNNING_PROCS" ]; then
    echo -e "${RED}  ERROR: No ModMove instances running!${NC}"
    exit 1
fi

PROC_COUNT=$(echo "$RUNNING_PROCS" | wc -l | xargs)
if [ "$PROC_COUNT" -eq 1 ]; then
    echo -e "${GREEN}  ✓ Exactly 1 instance running (correct)${NC}"
else
    echo -e "${RED}  WARNING: ${PROC_COUNT} instances running (expected 1)${NC}"
fi

echo ""
echo "Running instances:"
echo "$RUNNING_PROCS" | while read -r line; do
    PID=$(echo "$line" | awk '{print $2}')
    EXEC_PATH=$(echo "$line" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')
    BINARY_PATH=$(echo "$EXEC_PATH" | sed 's/ -.*$//')  # Strip arguments

    # Check if it's our version
    if [[ "$BINARY_PATH" == *"$APP_NAME"* ]]; then
        echo -e "  ${GREEN}PID $PID: $EXEC_PATH [CURRENT VERSION]${NC}"
    else
        echo -e "  ${YELLOW}PID $PID: $EXEC_PATH [OLD VERSION]${NC}"
    fi
done

echo ""
echo -e "${GREEN}=== Complete! ===${NC}"
echo ""
echo "Deployed version: ${APP_NAME}"
echo "Location: ${DEST_PATH}"
echo ""

# Show running versions summary
ALL_VERSIONS=$(ls -t /Applications/ModMove-jli-*.app 2>/dev/null || true)
if [ -n "$ALL_VERSIONS" ]; then
    echo "Installed versions in /Applications:"
    echo "$ALL_VERSIONS" | while read -r app_path; do
        app_name=$(basename "$app_path" .app)
        if [ "$app_path" = "$DEST_PATH" ]; then
            echo -e "  ${GREEN}$app_name [LATEST]${NC}"
        else
            echo "  $app_name"
        fi
    done
fi
