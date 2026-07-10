#!/bin/bash
set -e

# Deploys the current build to the CANONICAL location: /Applications/ModMove-jli.app
#
# A stable bundle path means:
#   - Accessibility (TCC) permission is granted once and survives redeploys
#   - Launch-at-login items keep pointing at a valid app
#   - Launch Services doesn't get confused by multiple bundles with the same ID
#
# Building is handled by `make deploy` (see Makefile) - this script only
# kills stale instances, installs, launches, and verifies.
#
# For dev iteration (run from build/ without touching /Applications), use `make run`.

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/ModMove.app"
DEST_PATH="/Applications/ModMove-jli.app"

echo -e "${BLUE}=== Deploying ModMove to ${DEST_PATH} ===${NC}"
echo ""

# Check if build exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Build not found at ${APP_PATH}${NC}"
    echo "Run 'make build' first (or just 'make deploy')"
    exit 1
fi

# Kill ALL running ModMove instances, regardless of bundle name/location.
# NOTE: match by binary name (pkill -x), NOT by bundle path — dated/renamed
# bundles like ModMove-jli-v0705.app would not match a path-based grep.
echo -e "${YELLOW}[1/4] Stopping all ModMove instances...${NC}"
if pgrep -x ModMove > /dev/null; then
    pgrep -lx ModMove | while read -r pid _; do
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
    echo "  No instances running"
fi
echo ""

# Warn about stale dated copies from the old deploy scheme
STALE=$(ls -d /Applications/ModMove-jli-*.app 2>/dev/null || true)
if [ -n "$STALE" ]; then
    echo -e "${YELLOW}Warning: stale dated copies found (old deploy scheme):${NC}"
    echo "$STALE" | sed 's/^/  /'
    echo "  Remove them with: rm -rf /Applications/ModMove-jli-*.app"
    echo ""
fi

# Replace canonical copy
echo -e "${YELLOW}[2/4] Installing to ${DEST_PATH}...${NC}"
rm -rf "$DEST_PATH"
ditto "$APP_PATH" "$DEST_PATH"
echo -e "${GREEN}  Installed${NC}"
echo ""

# Launch
echo -e "${YELLOW}[3/4] Launching...${NC}"
open "$DEST_PATH"
sleep 2

# Verify exactly one instance, running from the canonical path
echo -e "${YELLOW}[4/4] Verifying...${NC}"
PIDS=$(pgrep -x ModMove || true)
if [ -z "$PIDS" ]; then
    echo -e "${RED}  ERROR: No ModMove instance running!${NC}"
    exit 1
fi

PROC_COUNT=$(echo "$PIDS" | wc -l | xargs)
if [ "$PROC_COUNT" -ne 1 ]; then
    echo -e "${RED}  WARNING: ${PROC_COUNT} instances running (expected 1)${NC}"
fi

echo "$PIDS" | while read -r pid; do
    BINARY_PATH=$(ps -p "$pid" -o command= 2>/dev/null)
    if [[ "$BINARY_PATH" == "$DEST_PATH"* ]]; then
        echo -e "  ${GREEN}✓ PID $pid: $BINARY_PATH${NC}"
    else
        echo -e "  ${RED}✗ PID $pid running from UNEXPECTED path: $BINARY_PATH${NC}"
    fi
done

echo ""
echo -e "${GREEN}=== Deploy complete ===${NC}"
echo ""
echo "If move/resize gestures do nothing, check Accessibility permission:"
echo "  System Settings → Privacy & Security → Accessibility → ModMove-jli"
