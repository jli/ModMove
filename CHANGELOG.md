# Changelog

All notable changes to this fork of ModMove.

## [Unreleased]

### Bug Fixes (2026-07-07)

- Fixed windows being pinned at the edge shared between vertically/horizontally adjacent
  screens. A window at the top edge of a bottom screen could not be resized taller or
  slow-dragged into the screen above, because move/resize were constrained to the single
  screen the window sat on (turning the shared edge into a hard wall).
  - Move constraints now apply against the whole desktop (`WindowCalculations.desktopBoundingFrame`,
    the union of all screens' visible frames), so internal shared edges are never walls;
    only the desktop's outer perimeter constrains.
  - Resize constraints use the desktop frame when all displays share one Space, but the
    single containing screen when "Displays have separate Spaces" is enabled — macOS
    refuses display-spanning windows in that mode (`WindowCalculations.resizeConstraintFrame`).
- Fixed windows collapsing to near-zero height when growing across a shared screen edge:
  the old position-first resize order moved the origin across the edge before growing, and
  macOS clamped the size to the sliver of the destination screen. Growing now sets size
  first (away from the anchor), falls back to position-first only when clamped at an outer
  edge (the 2025-12-06 case), and rolls back the frame on a catastrophic clamp instead of
  anchoring around a sliver. Clamp events are logged (see `./logs.sh`).
- Fixed windows snapping to their minimum ("half") height when resized at the edge shared
  by two screens — the root cause of the original shared-edge report:
  - Screen lookup matched the window's top-left POINT with inclusive bounds; an origin
    exactly on the shared edge is contained by BOTH screens, and the first-listed screen
    won. With the wrong screen selected, the sticky-edge cap forced the resize delta to
    `-height`, driving the desired height to 0 (macOS then clamps to the app minimum).
  - Screen selection is now by largest window-rect overlap
    (`WindowCalculations.screenContaining`), which is unambiguous and order-independent.
  - Resize constraints now require the window to be inside the constraint frame (same
    semantics as move constraints): they can prevent leaving, but never yank a window
    that is already outside — so any future wrong-frame bug degrades to "unconstrained"
    instead of a violent snap.
  - Suite now 98 tests.
- Fixed windows being TELEPORTED ("snaps to half height") when resized at the edge shared
  by two screens — root cause found by empirically probing the WindowServer
  (`scripts/ax-probe.swift`) on macOS 26.5:
  - AX position sets whose rect would straddle two displays are not applied; the
    WindowServer teleports the window elsewhere (still returning success). Per-frame
    anchor-fix position sets during upward growth at the shared edge hit this constantly.
  - Resize constraints now always use the single screen containing the window: shared
    edges are honest walls for resizes (moves still cross screens fine).
  - The per-frame resize orchestration was extracted into `ResizeFrameApplier` (over a
    `WindowControlling` protocol) with a verify-and-repair guard: any teleport is detected
    and the pre-frame rect restored.
  - Orchestration is now unit-tested against a simulated WindowServer implementing the
    probed teleport laws (`ResizeOrchestrationTests`); tests were confirmed failing
    against the old logic before the fix. Suite now 102 tests.

### Property-Based Gesture Fuzzing & Edge-Case Hardening (2026-07-09)

- Added `ResizePropertyTests`: seeded (reproducible) fuzzing of ~550 random screen
  layouts / windows / corners / speeds / multi-frame gestures per run, checking
  frame-by-frame invariants (no teleports, no sub-minimum sizes, anchor corner never
  drifts, constrained gestures stay on screen). Plus deterministic edge cases
  (`ResizeEdgeCaseTests`): screen-corner pinning, full-height windows, reversal gestures,
  shrink-past-minimum, mixed-axis drags.
- Bugs found by the fuzzer and fixed:
  - Mixed-axis resizes (grow one axis, shrink the other) misfired the catastrophic-clamp
    rollback and emitted an off-screen transient position; the check now compares against
    min(current, desired) per axis and the rollback restores size before position.
  - Float drift (1e-14) at an exact screen edge disabled the constraint gates via exact
    containment; gates now use 0.5px tolerance.
- Straddling windows (spanning two screens) now resize size-only: every position set —
  including rollbacks — is unreliable for them (verified failing before the guard).
- Suite now 110 tests.

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
