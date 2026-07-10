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
├── Makefile                           # make build/run/test/logs/deploy/clean (single entry point)
├── deploy.sh / run.sh                 # Kill/launch/verify logic used by `make deploy`/`make run`
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
   - Build and run the app: `make run` (see "Manual Testing Protocol" below)
   - Manually verify the fix works as expected
   - Test edge cases and interaction with other features

This workflow ensures:
- Bugs stay fixed (regression prevention)
- Behavior is documented in tests
- Refactoring is safe
- Code quality improves over time

### Building & Running

**Use `make` for everything** — it's the single entry point:

```bash
make build    # Build to build/ModMove.app - only rebuilds if sources changed
make run      # make build, then kill stale instances and launch from build/
make deploy   # make build, then install to /Applications/ModMove-jli.app
make test     # Run the test suite
make logs     # Stream debug logs
make clean    # xcodebuild clean + rm -rf build/

# Or in Xcode: open ModMove.xcodeproj and press Cmd+B
```

`make build` is a real Make dependency rule (depends on every `.swift`/`.h`/`.m`
file + the `.xcodeproj`), so `make run`/`make deploy` only invoke `xcodebuild`
when something is actually stale. `run.sh`/`deploy.sh` remain as separate
scripts (called by `make run`/`make deploy`) because they have real
kill/launch/verify logic; everything simple (building, testing, logs) is
inlined directly in the `Makefile`.

`run.sh` never touches `/Applications`; `deploy.sh` always installs to the **stable
path** `/Applications/ModMove-jli.app` (never dated copies — a stable bundle path
keeps the Accessibility permission grant and launch-at-login item valid across
redeploys).

See `SCRIPTS.md` for the full reference (`Makefile` targets, `deploy.sh`, `run.sh`).

### Running Tests

```bash
# Command line
xcodebuild test -scheme ModMove -destination 'platform=macOS'   # or: make test

# Or in Xcode: open ModMove.xcodeproj and press Cmd+U
```

### Manual Testing Protocol (for agents and humans)

**Multiple running copies cause bugs** (two windows moving at once). Bundle names
vary (`ModMove.app` in build/, `ModMove-jli.app` in /Applications, possibly stale
dated copies), but the binary name is always `ModMove` — so kill/check by binary
name, never by grepping for a bundle path:

```bash
# 1. Kill ALL copies, wherever they live
pkill -x ModMove

# 2. Verify nothing is running
pgrep -lx ModMove          # expect no output

# 3. Build (if needed) and launch (also kills stale instances itself)
make run                   # expect "✓ Exactly 1 instance running"

# 4. Verify which copy is running
pgrep -x ModMove | xargs -I{} ps -p {} -o command=

# 5. Stream logs in another terminal while testing gestures
make logs                  # expect "[ModMove] Got window - app: ..." during gestures
```

Manual gesture test: hold ⌃⌥ + move mouse over a window → it moves;
hold ⌃⌥⇧ → it resizes from the closest corner.

**If gestures do nothing and logs are silent**: Accessibility permission is missing
for this copy (System Settings → Privacy & Security → Accessibility). macOS prompts
on first run; a `build/` copy may need its own grant. This cannot be granted
programmatically — ask the user.

### Accessibility Permissions

The app requires Accessibility API access to manipulate windows. macOS will prompt on first run.

## Key Features & Behavior

### Corner-Based Resizing

- Resizing happens from the corner closest to the mouse cursor
- Makes resize behavior intuitive and predictable
- Implementation: `WindowCalculations.calculateClosestCorner()`

### Screen Boundary Constraints

- Windows stay within the **desktop** boundary during move/resize (respects menu bar and dock)
- Uses `NSScreen.visibleFrame` to determine usable screen area
- Multi-monitor aware
- Implementation: `WindowCalculations.calculateConstrainedMoveDelta()` and `calculateConstrainedResizeDelta()`

**Constrain against the whole desktop, not a single screen** (fixed 2026-07-07):
Sticky-edge constraints for MOVES are applied against `WindowCalculations.desktopBoundingFrame()`
(the union of every screen's visible frame in Accessibility coords), NOT the single screen
the window happens to sit on. Constraining to one screen turns the edge *shared* with an
adjacent screen into a hard wall.

- **Bug**: On a vertically stacked two-screen setup, a window at the top edge of the bottom
  screen could not be resized taller (dragging the top edge up was clamped to ~0) and could
  not be slow-dragged up into the screen above. Its top-left sat at the bottom screen's
  `minY`, so the per-screen clamp floor was ~0.
- **Fix (moves)**: Constrain against the desktop bounding frame so internal shared edges are
  interior (never walls); only the true outer perimeter of the combined desktop constrains.
- **Fix (resizes)**: `WindowCalculations.resizeConstraintFrame()` — ALWAYS the single screen
  containing (most of) the window. See "WindowServer teleports" below for why resizes can
  never cross a shared edge on modern macOS.
- **Tradeoff**: For screens that aren't the same size/aligned, the bounding box can include
  small "dead zones" not covered by any screen; a slow drag may enter them. This is minor and
  far preferable to the wall bug (and fast-movement escape already allows going anywhere).
- Pure + tested in `ScreenCoordinateTests.swift`.

**Resize order-of-operations at screen edges** (fixed 2026-07-07 — another instance of the
2025-12-06 lesson that AX call ORDER matters):

- **Bug**: When growing a window across the shared edge between two screens, the old
  "optimistically set position first, then size" flow moved the window's origin across the
  edge BEFORE growing. macOS then clamped the size change to the sliver of the destination
  screen, and the position "correction" anchored around that sliver — the window collapsed
  to near-zero height.
- **Fix** (`Mover.resizeWindow`, growing path):
  1. Grow AWAY from the anchor first (`window.size` with the origin untouched — always
     within the current screen).
  2. If macOS clamped that (window against an OUTER edge — the 2025-12-06 case,
     detected via `WindowCalculations.sizeFellShort`), retry position-first.
  3. Then anchor-fix the position from the actual applied size.
  4. If the applied size REGRESSED below the pre-frame size (catastrophic clamp, e.g.
     macOS refusing a spanning window), roll the frame back (restore from `initWinPos`,
     which is always on-screen) instead of anchoring around a sliver.
- Clamp/fallback/rollback events are NSLogged — use `make logs` when diagnosing resize
  behavior at screen edges.

**Screen selection is by window-rect overlap; constraints never yank** (fixed 2026-07-08 —
root cause of the original "can't resize at the shared edge" report AND the "snaps to half
height" regression):

- **Bug**: `findUsableScreen()` matched the window's top-left POINT with INCLUSIVE bounds.
  A window at the top edge of the bottom screen has its origin EXACTLY on the shared edge —
  contained by BOTH screens' closed ranges — so whichever screen `NSScreen.screens` lists
  first won. When the TOP screen won, the constraint frame's `maxY` was the shared edge, and
  the bottom-corner resize cap `min(dy, maxY - (pos.y + height))` FORCED `dy = -height`
  regardless of the mouse → desiredHeight 0 → macOS clamped to the app's minimum height
  ("snaps to half height").
- **Fix 1**: `WindowCalculations.screenContaining(windowRect:)` selects the screen with the
  LARGEST overlap with the window's rect — a window's body is unambiguous even when its
  origin sits on an edge. All constraint/scale lookups use it.
- **Fix 2 (defense in depth)**: `shouldConstrainResize` now takes the current window rect and
  frame, symmetric with `shouldConstrainMovement`: constraints may PREVENT a window from
  leaving the frame but never YANK a window already (partially) outside it. Even a wrongly
  selected frame now degrades to "unconstrained", never to a forced delta.
- Regression tests in `ScreenCoordinateTests.swift`
  (`testResizeAtSharedEdge_BottomCornerDelta_NotYanked` and friends).

**WindowServer teleports: resizes never cross shared screen edges** (fixed 2026-07-08, the
final fix for the shared-edge saga — PROBED empirically, see `scripts/ax-probe.swift`):

- **Measured OS behavior (macOS 26.5)**: AX size sets apply faithfully, but AX position sets
  whose rect would STRADDLE two displays are NOT applied — the WindowServer TELEPORTS the
  window somewhere unpredictable (observed: y=31 or y=231 on the origin screen, or a snap to
  the destination screen's edge) while still returning `.success`. Position sets fully on a
  DIFFERENT screen also bounce. Only same-screen position sets are reliable. This holds even
  with "Displays have separate Spaces" DISABLED.
- **Consequence**: growing a window's top/left edge across a shared screen edge is impossible
  to do smoothly. Attempting it (per-frame anchor-fix position sets in the straddling strip)
  is what teleported/mangled windows at the shared edge ("snaps to half height" — the window
  was literally teleported to the other screen and then fought over).
- **Fix 1**: resize constraint frame is always the single containing screen — the shared edge
  is an honest wall for resizes. (Moves still cross edges: the WindowServer's snap conveniently
  lands the window on the destination screen.)
- **Fix 2 (defense in depth)**: `ResizeFrameApplier.verifyAndRepair` — after each frame, if the
  applied position deviates from the requested one by > 2px (teleport), restore the pre-frame
  rect (which was achievable). Protects the unconstrained fast-resize path too.
- **Architecture**: the per-frame resize orchestration now lives in `ResizeFrameApplier`
  operating on the `WindowControlling` protocol, so it is unit-tested against
  `FakeMacOS26Window` — a simulated WindowServer implementing the PROBED teleport laws
  (`ResizeOrchestrationTests` in `PositionSizeCalculationTests.swift`). These tests were
  verified to FAIL against the previous logic (10 teleports, window flung to y=31) before
  the fix was applied.
- **Diagnosing OS behavior**: don't guess — probe. `scripts/ax-probe.swift` drives AX
  position/size sets against a real TextEdit window and prints what the WindowServer actually
  did. Re-run it when a new macOS version changes window management behavior.
- **Straddling windows** (already spanning two screens, e.g. thrown there): EVERY position
  set is unreliable for them — including a rollback. Resize degrades to size-only
  (`positionSetsAreReliable` in `ResizeFrameApplier.apply`); if a gesture shrinks the window
  back onto one screen, normal resizing resumes.

### Property-Based Gesture Fuzzing (added 2026-07-09)

`ResizePropertyTests` is a test GENERATOR: a seeded deterministic RNG (SplitMix64) creates
hundreds of random screen layouts (single / stacked above / stacked below / side-by-side),
window placements, corners, speeds, and 12-frame random-walk gestures, then runs the REAL
production pipeline against `FakeMacOS26Window` and checks frame-by-frame invariants:

- **I1**: a frame never ends with the window teleported (sentinel position).
- **I2**: the window never shrinks below the app's minimum size.
- **I3**: slow (constrained) gestures emit ZERO teleporting position sets and keep the
  window inside its screen's visible frame.
- **I4**: the anchor corner (opposite the grabbed corner) never drifts, at any speed.
- Straddling starts: while straddling, resize is size-only (origin frozen, no position
  sets); normal resizing may resume once the window is back on one screen.

Failures print the seed — re-run with that seed to reproduce exactly. Bugs found by the
fuzzer on day one (each then fixed + pinned with a deterministic regression test):

1. **Mixed-axis catastrophic-clamp misfire**: growing width while shrinking height (a
   normal diagonal drag) tripped the "macOS clamped us" rollback because the check compared
   only against the CURRENT size. Fix: an axis is catastrophic only if actual <
   min(current, desired). Rollback also now restores size BEFORE position so no stale-size
   transient rect is ever emitted.
2. **Float-drift gate escape**: anchor-fix arithmetic can land a window 1e-14 outside the
   visible frame; exact `contains()` then silently DISABLED constraints, letting
   unconstrained growth emit teleporting position sets. Fix: containment gates
   (`shouldConstrainResize`, `shouldConstrainMovement`, `isEntirelyOnOneScreen`) use 0.5px
   tolerance.

When adding resize/move behavior, extend the invariants (or add a new generator) rather
than only writing example-based tests — the fuzzer found in seconds what three rounds of
example-based testing missed.

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

110 tests organized into 8 suites (incl. `ResizeOrchestrationTests`, `ResizeEdgeCaseTests`
and `ResizePropertyTests`, which run the real constraint→gate→delta→apply pipeline against
a simulated WindowServer):

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
# Kill ALL ModMove instances by binary name (bundle names vary!)
pkill -x ModMove
```

Do NOT grep the process list for `ModMove.app` — renamed bundles (e.g.
`ModMove-jli.app`) won't match, and you'll miss exactly the instances causing
the bug.

**Prevention:** Use `make run` or `make deploy`, which kill ALL instances (by
binary name) before launching.

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
