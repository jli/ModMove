#!/bin/bash
set -e

# Dev workflow: build and run from ./build/ WITHOUT touching /Applications.
# Use ./deploy.sh to install the canonical copy to /Applications/ModMove-jli.app
#
# NOTE: if the deployed copy has launch-at-login enabled, it will come back at
# next login even while you're testing a build/ copy. Kill with: pkill -x ModMove

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/ModMove.app"

echo -e "${BLUE}=== ModMove Debug Run ===${NC}"
echo -e "${BLUE}(Runs from build directory - use ./deploy.sh for the canonical install)${NC}"
echo ""

# Step 1: Build
echo -e "${YELLOW}[1/3] Building ModMove (Release configuration)...${NC}"
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

# Step 2: Kill ALL existing ModMove instances, regardless of bundle name/location.
# NOTE: match by binary name (pkill -x), NOT by bundle path — dated/renamed
# bundles like ModMove-jli-v0705.app would not match a path-based grep.
echo -e "${YELLOW}[2/3] Stopping all ModMove instances...${NC}"
if pgrep -x ModMove > /dev/null; then
    pgrep -x ModMove | while read -r pid; do
        echo "  Killing PID $pid: $(ps -p "$pid" -o command= 2>/dev/null || echo '?')"
    done
    pkill -x ModMove || true
    sleep 1
    if pgrep -x ModMove > /dev/null; then
        echo -e "${YELLOW}  Force killing remaining instances...${NC}"
        pkill -9 -x ModMove || true
        sleep 1
    fi
    echo -e "${GREEN}  Stopped all instances${NC}"
else
    echo "  No instances to stop"
fi
echo ""

# Step 3: Launch from build directory and verify
echo -e "${YELLOW}[3/3] Launching ModMove from ${APP_PATH}...${NC}"
open "$APP_PATH"
sleep 2

echo ""
echo -e "${BLUE}Process verification:${NC}"
PIDS=$(pgrep -x ModMove || true)

if [ -z "$PIDS" ]; then
    echo -e "${RED}  ERROR: No ModMove instances running!${NC}"
    exit 1
fi

PROC_COUNT=$(echo "$PIDS" | wc -l | xargs)
if [ "$PROC_COUNT" -eq 1 ]; then
    echo -e "${GREEN}  ✓ Exactly 1 instance running (correct)${NC}"
else
    echo -e "${RED}  WARNING: ${PROC_COUNT} instances running (expected 1)${NC}"
fi

echo ""
echo "Running instances:"
echo "$PIDS" | while read -r pid; do
    BINARY_PATH=$(ps -p "$pid" -o command= 2>/dev/null)
    echo -e "  ${GREEN}PID $pid: $BINARY_PATH${NC}"
done

echo ""
echo -e "${GREEN}=== Complete! ===${NC}"
echo ""
echo "Running from: ${APP_PATH}"
echo ""
echo "Tips:"
echo "  ./logs.sh     - Stream debug logs"
echo "  ./deploy.sh   - Install canonical copy to /Applications/ModMove-jli.app"
echo ""
echo "If gestures do nothing and logs are silent, the build/ copy may need"
echo "Accessibility permission: System Settings → Privacy & Security → Accessibility"
