# Build & Deployment Scripts

Quick reference for ModMove build and deployment scripts.

## Quick Start

**Recommended: Use `run.sh` for development**

```bash
./run.sh            # Build, deploy, and run (auto-versioned)
./run.sh v1234      # Build, deploy, and run with specific version
```

This single command:
1. Checks for existing ModMove processes
2. Builds the app (Release configuration)
3. Stops all running instances
4. Deploys to `/Applications/ModMove-jli-<version>.app`
5. Launches the app
6. Verifies exactly one instance is running
7. Shows which version is running

## Individual Scripts

### `build.sh` - Build only

```bash
./build.sh
```

Builds ModMove in Release configuration to `./build/ModMove.app`.

Use this when you want to build without deploying.

### `deploy.sh` - Deploy only

```bash
./deploy.sh            # Auto-versioned (timestamp)
./deploy.sh v1234      # Specific version
```

Deploys an existing build to `/Applications/ModMove-jli-<version>.app`.

- Stops any running ModMove instances
- Cleans up old versions (keeps last 3)
- Requires `./build.sh` to be run first

### `run.sh` - Build, deploy, and run (ALL-IN-ONE)

```bash
./run.sh               # Auto-versioned (timestamp: vMMDD-HHMM)
./run.sh v1234         # Specific version
```

Does everything in one command:
- Builds from scratch
- Deploys to /Applications
- Launches the app
- Verifies process state

**This is the recommended script for development.**

## Process Verification

All scripts now include process verification with `ps` and `grep`:

- Shows running ModMove instances before/after operations
- Identifies which version is running (checks binary path)
- Warns if multiple instances are running
- Color-coded output for easy scanning

Example output:
```
Process verification:
  ✓ Exactly 1 instance running (correct)

Running instances:
  PID 12345: /Applications/ModMove-jli-v1206-1755.app/Contents/MacOS/ModMove [CURRENT VERSION]
```

## Version Management

- **Auto-versioning**: If no version specified, uses timestamp (e.g., `v1206-1755`)
- **Named versions**: Pass version as argument (e.g., `v1.0`, `v-beta`, `v-stable`)
- **Cleanup**: Automatically keeps only last 3 versions in /Applications

## Examples

```bash
# Development workflow (quick iteration)
./run.sh                    # Quick build-deploy-run with timestamp version

# Release workflow
./run.sh v1.0.0            # Build and deploy release version
./run.sh v1.0.0-beta1      # Build and deploy beta version

# Manual control
./build.sh                 # Build only
./deploy.sh v-test         # Deploy with specific version
open /Applications/ModMove-jli-v-test.app   # Launch manually

# Check what's running
ps aux | grep -i modmove
```

## Color Coding

Scripts use color output for clarity:
- 🔵 **Blue**: Section headers
- 🟡 **Yellow**: Operations in progress
- 🟢 **Green**: Success/current version
- 🔴 **Red**: Errors/warnings

## Tips

- Use `./run.sh` for most development work
- Use versioned names for releases: `./run.sh v1.0.0`
- Scripts verify only one instance is running
- Old versions auto-cleaned (keeps last 3)
- All scripts stop existing instances before deploying
