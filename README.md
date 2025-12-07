# ModMove (Enhanced Fork)

ModMove is a lightweight macOS utility that brings Linux-style window management to macOS. Move and resize windows using keyboard modifiers and mouse movement, without needing to grab title bars or window edges.

This is an enhanced fork with significant improvements to precision, screen boundary behavior, and performance.

## Features

### Basic Functionality

- **Move windows**: Hold Control (⌃) + Option (⌥), then move the mouse
- **Resize windows**: Hold Control (⌃) + Option (⌥) + Shift (⇧), then move the mouse

### Enhanced Features (This Fork)

- **Corner-based resizing**: Windows resize from the corner closest to your mouse cursor, making resizing more intuitive
- **Smart screen boundaries**:
  - Slow movements keep windows within screen bounds (respects menu bar and dock)
  - Fast movements (>1000 px/sec) let you "throw" windows outside bounds when needed
- **Precision tracking**: Absolute position tracking eliminates drift and jitter
- **Performance optimized**:
  - Cached window positions (eliminates 120-240 API calls/second)
  - Efficient time tracking (eliminates 60-120 allocations/second)
  - Smooth window manipulation with minimal CPU overhead

## Installation

### Build from Source

```bash
# Clone this repository
git clone <your-fork-url>
cd ModMove

# Build and deploy
./build.sh
./deploy.sh v1206

# Launch
open /Applications/ModMove-jli-v1206.app
```

### First Run

On first launch, macOS will prompt you to grant Accessibility permissions:
1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable ModMove in the list

## Development

### Quick Commands (Make)

```bash
make run      # Build and run (debug mode)
make test     # Run test suite
make logs     # Stream debug logs
make deploy   # Deploy to /Applications
make clean    # Clean build artifacts
make help     # Show all commands
```

### Shell Scripts

- `./run.sh` - Build and run with process verification
- `./logs.sh` - Stream debug logs
- `./deploy.sh [version]` - Deploy to `/Applications/ModMove-jli-[version].app`

### Project Structure

- `ModMove/Mover.swift` - Core window manipulation orchestration
- `ModMove/WindowCalculations.swift` - Pure functional core (70+ tests)
- `ModMove/Observer.swift` - Keyboard modifier monitoring
- `ModMove/AccessibilityElement.swift` - Accessibility API wrapper
- `ModMoveTests/` - Test suite (76 tests, TDD workflow)
- See `CLAUDE.md` for detailed developer guide

## Performance

See `PERFORMANCE_ANALYSIS.md` for detailed performance characteristics and optimization notes.

## Original Project

This is a fork of [@keith's ModMove](https://github.com/keith/ModMove), which implements the window manipulation feature from [HyperDock](https://bahoom.com/hyperdock/).

### Changes from Upstream

- Corner-based resizing (resizes from nearest corner instead of fixed corner)
- Screen boundary constraints with speed-based escape behavior
- Absolute position tracking for precision
- Performance optimizations (cached positions, efficient timing)
- Build and deployment scripts
