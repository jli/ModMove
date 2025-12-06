# Changelog

All notable changes to this fork of ModMove.

## [Unreleased]

### Performance Optimizations (2024-12-06)

- Optimized `windowInsideFrame()` to use cached values instead of Accessibility API queries
  - Eliminates 120-240 expensive API calls per second during window moves
  - Commit: e1b663a
- Replaced `Date()` with `CACurrentMediaTime()` for mouse speed tracking
  - Eliminates 60-120 object allocations per second
  - More accurate timing with monotonic clock
  - Commit: f3b3d85
- Improved state cleanup between move/resize operations
  - Properly resets tracking variables (prevMousePosition, mouseSpeed, prevTime)
  - Ensures clean transitions between operations

### Build & Development

- Added `build.sh` script for Release builds
- Added `deploy.sh` script for easy installation to /Applications
- Fixed build issues with missing ApplicationServices import

## Enhanced Features

### Corner-Based Resizing

- Windows now resize from the corner closest to the mouse cursor
- Makes resize behavior more intuitive and natural
- Commit: 168b8a0

### Precision Tracking

- Changed from frame-to-frame delta to absolute position tracking
- Tracks initial mouse position, window position, and window size
- Eliminates cumulative drift and jitter during moves/resizes
- Commits: 107c349, 37e0874

### Screen Boundary Constraints

- Windows stay within visible screen bounds during slow movements
- Respects macOS menu bar and dock (uses NSScreen.visibleFrame)
- Added to both move and resize operations
- Commits: 88ea9ab, 8c20c56

### "Sticky Edge" Behavior

- Mouse speed tracking using exponential moving average
- Fast movements (>1000 px/sec) bypass boundary constraints
- Allows "throwing" windows outside screen bounds when needed
- Slow movements remain constrained for precision
- Commit: d5e95ee

## Upstream

Based on [@keith's ModMove](https://github.com/keith/ModMove) - a lightweight macOS utility implementing the window manipulation feature from HyperDock.
