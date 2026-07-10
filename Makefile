.PHONY: build run test logs deploy clean help

# Colors
GREEN  := \033[0;32m
YELLOW := \033[1;33m
BLUE   := \033[0;34m
RED    := \033[0;31m
NC     := \033[0m

BUILD_DIR := $(CURDIR)/build
APP       := $(BUILD_DIR)/ModMove.app
SOURCES   := $(shell find ModMove -type f \( -name '*.swift' -o -name '*.h' -o -name '*.m' \)) \
             ModMove.xcodeproj/project.pbxproj

# Default target
help:
	@echo "ModMove Development Commands:"
	@echo "  make build   - Build ModMove to build/ (incremental; only rebuilds if stale)"
	@echo "  make run     - Build (if needed) and run from build/ (dev iteration)"
	@echo "  make test    - Run test suite"
	@echo "  make logs    - Stream debug logs"
	@echo "  make deploy  - Build (if needed) and install to /Applications/ModMove-jli.app"
	@echo "  make clean   - Clean build artifacts"

# Build only if sources changed since the last build (real make dependency,
# not a shell script check) - `make run`/`make deploy` depend on this.
build: $(APP)

$(APP): $(SOURCES)
	@echo -e "$(BLUE)=== Building ModMove ===$(NC)"
	xcodebuild -project ModMove.xcodeproj \
	    -scheme ModMove \
	    -configuration Release \
	    build \
	    CONFIGURATION_BUILD_DIR="$(BUILD_DIR)" \
	    2>&1 | grep -E '(Building|Compiling|Linking|CodeSign|BUILD SUCCEEDED|BUILD FAILED|error:)' || true
	@test -d "$(APP)" || (echo -e "$(RED)Build failed! App not found at $(APP)$(NC)" && exit 1)
	@touch "$(APP)"
	@echo -e "$(GREEN)Build complete: $(APP)$(NC)"

# Run tests
test:
	@echo "Running test suite..."
	xcodebuild test -scheme ModMove -destination 'platform=macOS'

# Build (if needed) and run from build/ - see run.sh for kill/launch/verify logic
run: build
	./run.sh

# Stream debug logs (trivial enough to inline)
logs:
	@echo "Streaming ModMove logs (press Ctrl+C to stop)..."
	@echo "Logs also saved to: $(CURDIR)/modmove.log"
	@> modmove.log
	log stream --predicate 'process == "ModMove"' --level debug | tee modmove.log

# Build (if needed) and install the canonical copy - see deploy.sh for
# kill/install/launch/verify logic
deploy: build
	./deploy.sh

# Clean build artifacts
clean:
	xcodebuild clean -scheme ModMove
	rm -rf build/
