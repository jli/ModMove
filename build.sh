#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BUILD_DIR="$(pwd)/build"

echo -e "${BLUE}=== Building ModMove ===${NC}"
echo ""

echo -e "${YELLOW}Building (Release configuration)...${NC}"
xcodebuild -project ModMove.xcodeproj \
    -scheme ModMove \
    -configuration Release \
    clean build \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    2>&1 | grep -E '(Building|Compiling|Linking|CodeSign|BUILD SUCCEEDED|BUILD FAILED|error:)' || true

echo ""
if [ -d "${BUILD_DIR}/ModMove.app" ]; then
    echo -e "${GREEN}Build complete!${NC}"
    echo "App is at: ${BUILD_DIR}/ModMove.app"
else
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi
echo ""
echo "Next steps:"
echo "  ./deploy.sh [version]  - Deploy to /Applications"
echo "  ./run.sh [version]     - Build, deploy, and run"
