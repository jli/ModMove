# ModMove - Developer Guide

Team-shared guide for AI-assisted development on ModMove. This file is checked into git and should contain information useful to all developers and coding agents. (`CLAUDE.md` is a pointer to this file.)

## Project Overview

**ModMove** is a lightweight macOS utility that brings Linux-style window management to macOS. It allows users to move and resize windows using keyboard modifiers and mouse movement, without needing to grab title bars or window edges.

### What It Does

- **Move Windows**: Hold Control (⌃) + Option (⌥) + mouse movement → moves the window under cursor
- **Resize Windows**: Hold Control (⌃) + Option (⌥) + Shift (⇧) + mouse movement → resizes the window under cursor

This replicates behavior from Linux window managers (and HyperDock on Mac).

### Technology Stack

- **Language**: Swift 4.0 (with small Objective-C bridging layer)
- **Platform**: macOS 10.13+
- **Build System**: Xcode
- **Key APIs**: macOS Accessibility API (AXUIElement)
- **App Type**: Menu bar utility (no dock icon, runs in background)

### Project Structure

```
ModMove/
├── ModMove/
│   ├── AppDelegate.swift              # App entry point, initialization
│   ├── Observer.swift                 # Keyboard modifier state monitoring
│   ├── Mover.swift                    # Core move/resize orchestration
│   ├── WindowCalculations.swift       # Pure functional core (testable logic)
│   ├── Mouse.swift                    # Mouse position utility
│   ├── AccessibilityElement.swift     # Wrapper for AXUIElement API
│   ├── AccessibilityHelper.swift      # Permission requests
│   ├── AXValue+Helper.swift           # Type conversion helpers
│   ├── LoginController.h/m            # Launch-at-login (Objective-C)
│   ├── LoginAlert.swift               # User prompt for login items
│   └── Resources/                     # App resources
├── ModMoveTests/                      # Test suite (83 tests)
│   ├── CornerDetectionTests.swift
│   ├── BoundaryConstraintTests.swift
│   ├── SpeedBasedBehaviorTests.swift
│   ├── PositionSizeCalculationTests.swift
│   └── ScreenCoordinateTests.swift
├── ModMove.xcodeproj/                 # Xcode build configuration
├── Makefile                           # make run/test/logs/deploy/clean
├── build.sh / deploy.sh / run.sh      # Build & deployment scripts (see SCRIPTS.md)
├── logs.sh                            # Stream debug logs
├── SCRIPTS.md                         # Script reference
├── CHANGELOG.md                       # Fork changelog
├── PERFORMANCE_ANALYSIS.md            # Performance analysis
└── README.md                          # User-facing documentation
```

### Architecture

1. **Observer.swift**: Monitors global keyboard flags via `NSEvent.addGlobalMonitorForEvents`
   - Detects Control+Option (Drag mode)
   - Detects Control+Option+Shift (Resize mode)
   - Notifies Mover when state changes

2. **Mover.swift**: Core window manipulation orchestration
   - Tracks mouse movement via `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)`
   - Uses Accessibility API to get/set window position and size
   - Delegates calculations to WindowCalculations
   - Implements throttling (50fps) for performance

3. **WindowCalculations.swift**: Pure functional core (added 2025-12-06)
   - All calculation logic extracted into pure, testable functions
   - No side effects, no state - easy to reason about and test
   - Functions for corner detection, boundary constraints, size/position calculations
   - See ModMoveTests/ for comprehensive test coverage

4. **AccessibilityElement.swift**: Abstracts macOS Accessibility API
   - Finds window under cursor
   - Gets/sets window position and size
   - Brings windows to front

## Development Workflow

### Test-Driven Development (TDD)

**IMPORTANT**: We practice TDD on this project. When a bug is reported:

1. **Write a failing test first** that reproduces the bug
   - Add test case to appropriate test file in `ModMoveTests/`
   - Run tests to verify it fails: `xcodebuild test -scheme ModMove -destination 'platform=macOS'`
   - This documents the expected behavior and prevents regression

2. **Fix the bug** in the functional core or orchestration code
   - Prefer fixing in `WindowCalculations.swift` when possible (pure functions)
   - Update `Mover.swift` only when necessary (stateful/side effects)

3. **Verify tests pass**
   - Run test suite: `xcodebuild test -scheme ModMove -destination 'platform=macOS'` (or `make test`)
   - All 83+ tests should pass

4. **Only then test in real life**
   - Build, deploy, and run the app: `./run.sh`
   - Manually verify the fix works as expected
   - Test edge cases and interaction with other features

This workflow ensures:
- Bugs stay fixed (regression prevention)
- Behavior is documented in tests
- Refactoring is safe
- Code quality improves over time

### Building & Running

```bash
# Recommended: build, deploy, and run in one step (kills stale instances)
./run.sh

# Build only
xcodebuild -scheme ModMove build   # or ./build.sh (Release)

# Or in Xcode: open ModMove.xcodeproj and press Cmd+B
```

See `SCRIPTS.md` for the full script reference (`build.sh`, `deploy.sh`, `run.sh`, `logs.sh`, `Makefile` targets).

### Running Tests

```bash
# Command line
xcodebuild test -scheme ModMove -destination 'platform=macOS'   # or: make test

# Or in Xcode: open ModMove.xcodeproj and press Cmd+U
```

### Accessibility Permissions

The app requires Accessibility API access to manipulate windows. macOS will prompt on first run.

## Key Features & Behavior

### Corner-Based Resizing

- Resizing happens from the corner closest to the mouse cursor
- Makes resize behavior intuitive and predictable
- Implementation: `WindowCalculations.calculateClosestCorner()`

### Screen Boundary Constraints

- Windows stay within screen boundaries during move/resize (respects menu bar and dock)
- Uses `NSScreen.visibleFrame` to determine usable screen area
- Multi-monitor aware
- Implementation: `WindowCalculations.calculateConstrainedMoveDelta()` and `calculateConstrainedResizeDelta()`

### Multi-Monitor Coordinate Conversion (single-Space setups)

macOS Accessibility/CoreGraphics global coordinates use the **top-left of the primary
screen** as the origin (Y increases downward). NSScreen uses bottom-left origin of the
primary screen (Y increases upward). Screens physically **above** the primary have
**negative** Accessibility Y values.

This matters most when *"Displays have separate Spaces"* is DISABLED in
System Settings → Desktop & Dock (all screens share one Space). A screen stacked above
the primary then has a larger NSScreen `maxY` than the primary's height.

- **Bug (fixed 2026-07-05)**: `getUsableScreen()` converted coordinates relative to
  `globalMaxY` (max `maxY` across all screens) instead of the primary screen height.
  With a screen above the primary this shifted every screen, so the window→screen lookup
  picked the wrong physical screen. Windows on the top screen were constrained against the
  wrong frame and "sank" past the real boundary during move/resize.
- **Fix**: Convert relative to the primary screen height
  (`WindowCalculations.nsYToAccessibilityY`) and select the containing screen with
  `WindowCalculations.findUsableScreen()` (pure, tested in `ScreenCoordinateTests.swift`).

### "Sticky Edge" / Fast Movement Escape

- **Slow movements** (<1000 px/sec): Keep windows within screen bounds
- **Fast movements** (≥1000 px/sec): Allow escaping screen bounds ("throwing" windows)
- Mouse speed tracked using exponential moving average (10% weight on latest sample)
- Once escaped, window stays out even if you slow down
- Implementation: `WindowCalculations.shouldConstrainMovement()` and `shouldConstrainResize()`

### Precision & Smoothness

- Absolute position tracking (not frame-to-frame delta)
- Stores initial state and calculates relative to start position
- Eliminates cumulative drift and jitter
- Throttled to 50fps for performance

### Minimum Size Constraints

- macOS enforces minimum window sizes
- Resize operations handle this by reading back actual size after setting
- Position adjusted to keep anchor corner fixed
- Implementation: `WindowCalculations.calculateResizedWindowPosition()`

## Upstream & Fork History

- **Original Author**: Keith Smiley (@keith)
- **Upstream Repo**: https://github.com/keith/ModMove
- **This Fork**: Adds corner-based resizing, boundary constraints, speed-based escape, functional core, and comprehensive tests

### Key Enhancement Commits

```
06787d4 - extract functional core and add comprehensive test suite (2025-12-06)
2152881 - fix resize jitter by calculating position from actual window size
6100453 - bump throttle from 40fps to 50fps for smoother movement
dca013f - handle window minimum size constraints during resize
d5e95ee - sticky edge behavior to allow moves/resizes outside screen boundary
8c20c56 - also restrict movement to window boundaries
88ea9ab - restrict resizing to screen boundaries
fbccf3a - use enum for corner
37e0874 - improve behavior when transitioning between moves/resizes
107c349 - improve precision/smoothness of move and resize
168b8a0 - change ModMove to resize from the closest corner
```

## Performance Considerations

See `PERFORMANCE_ANALYSIS.md` for detailed analysis.

### Current Performance Profile

- Throttled to 50fps (20ms update interval)
- Minimal Accessibility API calls during normal operation
- Screen bounds calculated once per move/resize operation
- Mouse speed tracking uses efficient exponential moving average

### Optimization Opportunities

Priority 1 (identified but not yet implemented):
- Eliminate redundant `window.position` and `window.size` calls in `shouldConstrainMouseDelta()`
- Could save 120-240 Accessibility API calls/second during slow movements
- Use cached values from last update instead

## Testing

### Test Coverage

83 tests organized into 5 suites:

1. **CornerDetectionTests** (11 tests)
   - All corner quadrants
   - Edge cases: center point, midlines, small/large windows
   - Various window positions

2. **BoundaryConstraintTests** (23 tests)
   - All edges and corners for move operations
   - All edges for resize operations (per corner)
   - Fast movement bypass behavior

3. **SpeedBasedBehaviorTests** (20 tests)
   - Threshold detection (slow/fast/exact)
   - Window inside/outside detection
   - Edge touching vs. off-screen
   - Resize constraint decisions

4. **PositionSizeCalculationTests** (22 tests)
   - Size calculations for all corners (grow/shrink)
   - Position calculations with and without size constraints
   - Handling of macOS minimum size enforcement
   - Zero delta and negative size edge cases

5. **ScreenCoordinateTests** (7 tests)
   - NSScreen ↔ Accessibility Y-coordinate conversion
   - Screen selection for windows on multi-monitor setups
   - Screens above the primary (negative Accessibility Y)

### Test Philosophy

- **Pure functions are easy to test**: WindowCalculations.swift has no state or side effects
- **Comprehensive coverage**: All behavior documented in tests
- **Fast execution**: full suite runs in <0.1 seconds
- **Regression prevention**: Tests ensure bugs stay fixed

### Testing Limitations & Lessons Learned

**Lesson from 2025-12-06 resize bug**: Pure functional tests are necessary but not sufficient.

**What our tests CAN catch:**
- Calculation errors in pure functions
- Logic bugs in WindowCalculations.swift
- Regressions in mathematical behavior
- Edge cases in algorithms

**What our tests CANNOT catch:**
- Order of operations bugs in side effects
- External system behavior (macOS Accessibility API constraints)
- Integration issues between components
- Real-world system interactions

**Example Bug**: Window at screen edge couldn't resize to grow leftward
- ✅ All calculation tests passed (logic was correct)
- ❌ Bug was in `Mover.swift` - wrong order of API calls:
  ```swift
  // BROKEN: macOS rejects size change because current position + new size > screen
  window.size = desiredSize
  window.position = newPosition

  // FIXED: Set position first so macOS allows the size change
  window.position = newPosition
  window.size = desiredSize
  ```

**How we found it:**
- Debug logging revealed `actualSize ≠ desiredSize`
- Showed macOS was rejecting our size changes
- No amount of pure function testing could have caught this

**Takeaway**:
- Keep the functional core / imperative shell architecture
- Test the functional core exhaustively (prevents 90% of bugs)
- Use debug logging + manual testing for orchestration bugs
- External system behavior must be observed, not just calculated

## Build Configuration

### Deployment Target

- **Current**: macOS 10.13 (High Sierra, 2017)
- **Reasoning**: Updated from 10.11 to match Xcode's minimum supported version
- **Impact**: Maintains excellent backwards compatibility (8+ years) while ensuring clean builds
- **Changed**: 2025-12-06 - No code changes required, Info.plist uses `$(MACOSX_DEPLOYMENT_TARGET)` variable

## Known Issues & Debugging

### Multiple Instance Bug

**Symptom:** Multiple windows resize/move simultaneously during a single gesture.

**Cause:** Multiple ModMove instances running (e.g., one in `/Applications`, one in `build/`).

**Fix:**
```bash
# Kill ALL ModMove instances
ps aux | grep "ModMove\.app/Contents/MacOS/ModMove" | grep -v grep | awk '{print $2}' | xargs kill
```

**Prevention:** Use `./run.sh` which now kills ALL instances before launching a new one.

**Why it happens:**
- Each instance monitors keyboard shortcuts independently
- When you trigger the gesture, multiple instances each grab a different window
- Both windows appear to move together, but it's actually two separate instances

## Future Work

### Potential Enhancements

- Customizable keyboard shortcuts
- Configurable speed threshold for boundary escape
- Visual feedback during move/resize
- Snap-to-edge behavior
- Window history/undo

## Code Style & Conventions

- Pure logic in WindowCalculations.swift (testable functions)
- Stateful orchestration in Mover.swift (side effects, API calls)
- Clear separation of concerns
- Comments explain "why", not "what"
- Test names describe behavior: `test<Scenario>_<Expected>`
