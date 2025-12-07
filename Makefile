.PHONY: run test logs deploy clean help

# Default target
help:
	@echo "ModMove Development Commands:"
	@echo "  make run     - Build and run ModMove (debug mode)"
	@echo "  make test    - Run test suite"
	@echo "  make logs    - Stream debug logs"
	@echo "  make deploy  - Deploy stable version to /Applications"
	@echo "  make clean   - Clean build artifacts"

# Build and run (calls run.sh for nice output)
run:
	./run.sh

# Run tests
test:
	@echo "Running test suite..."
	xcodebuild test -scheme ModMove -destination 'platform=macOS'

# Stream logs (calls logs.sh for nice output)
logs:
	./logs.sh

# Deploy to /Applications (calls deploy.sh for version handling)
deploy:
	./deploy.sh

# Clean build artifacts
clean:
	xcodebuild clean -scheme ModMove
	rm -rf build/
