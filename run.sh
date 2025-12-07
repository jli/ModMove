#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/ModMove.app"

echo -e "${BLUE}=== ModMove Debug Run ===${NC}"
echo -e "${BLUE}(Runs from build directory - use ./deploy.sh for stable releases)${NC}"
echo ""

# Step 1: Check for running instances
echo -e "${YELLOW}[1/4] Checking for existing ModMove instances...${NC}"
EXISTING_PROCS=$(ps aux | grep "ModMove\.app/Contents/MacOS/ModMove" | grep -v grep || true)
if [ -n "$EXISTING_PROCS" ]; then
    echo "Found running instances:"
    echo "$EXISTING_PROCS" | awk '{print "  PID " $2 ": " $11}'
    echo ""
else
    echo "  No instances running"
    echo ""
fi

# Step 2: Build
echo -e "${YELLOW}[2/4] Building ModMove (Release configuration)...${NC}"
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

# Step 3: Kill ALL existing ModMove instances (everywhere)
echo -e "${YELLOW}[3/4] Stopping all ModMove instances...${NC}"
MODMOVE_PIDS=$(ps aux | grep "ModMove\.app/Contents/MacOS/ModMove" | grep -v grep | awk '{print $2}')
if [ -n "$MODMOVE_PIDS" ]; then
    echo "$MODMOVE_PIDS" | while read -r pid; do
        BINARY_PATH=$(ps -p "$pid" -o command= 2>/dev/null | awk '{print $1}')
        echo "  Killing PID $pid: $BINARY_PATH"
        kill "$pid" 2>/dev/null || true
    done
    sleep 1

    # Verify all are stopped, force kill if needed
    REMAINING=$(ps aux | grep "ModMove\.app/Contents/MacOS/ModMove" | grep -v grep | awk '{print $2}')
    if [ -n "$REMAINING" ]; then
        echo -e "${YELLOW}  Force killing remaining instances...${NC}"
        echo "$REMAINING" | while read -r pid; do
            echo "    Force killing PID $pid"
            kill -9 "$pid" 2>/dev/null || true
        done
        sleep 1
    fi
    echo -e "${GREEN}  Stopped all instances${NC}"
else
    echo "  No instances to stop"
fi
echo ""

# Step 4: Launch from build directory and verify
echo -e "${YELLOW}[4/4] Launching ModMove from ${APP_PATH}...${NC}"
open "$APP_PATH"
sleep 2

# Verify exactly one instance is running
echo ""
echo -e "${BLUE}Process verification:${NC}"
RUNNING_PROCS=$(ps aux | grep "ModMove\.app/Contents/MacOS/ModMove" | grep -v grep || true)

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
    BINARY_PATH=$(echo "$line" | awk '{print $11}')
    echo -e "  ${GREEN}PID $PID: $BINARY_PATH${NC}"
done

echo ""
echo -e "${GREEN}=== Complete! ===${NC}"
echo ""
echo "Running from: ${APP_PATH}"
echo ""
echo "Tips:"
echo "  ./logs.sh               - Stream debug logs"
echo "  ./deploy.sh [version]   - Deploy stable version to /Applications"
