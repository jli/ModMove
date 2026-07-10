import AppKit
import Foundation
import QuartzCore

enum Corner {
    case TopLeft
    case TopRight
    case BottomLeft
    case BottomRight
}

/// Minimal window surface the resize orchestration needs. Lets tests drive the
/// orchestration against a fake window that reproduces the macOS WindowServer's
/// observed (mis)behaviors — which pure calculation tests cannot catch.
protocol WindowControlling: AnyObject {
    var position: CGPoint? { get set }
    var size: CGSize? { get set }
}

extension AccessibilityElement: WindowControlling {}

/// Applies one frame of a resize gesture to a window.
///
/// Extracted from Mover so the order-of-operations logic — where every screen-edge bug
/// so far has lived — is unit-testable against a simulated window server.
///
/// Observed macOS behaviors this must survive (probed on macOS 26.5, two stacked screens):
/// - Size sets are applied faithfully (clamped to the app's minimum).
/// - Position sets whose rect would STRADDLE two displays are not applied faithfully:
///   the WindowServer teleports the window somewhere else entirely (sometimes the
///   destination screen's edge, sometimes near the top of the origin screen).
struct ResizeFrameApplier {
    static let epsilon: CGFloat = 0.1
    /// How far the WindowServer may deviate from a requested position before we treat the
    /// result as a teleport. Teleports observed in probing were hundreds to >1600 px.
    static let teleportTolerance: CGFloat = 2.0

    static func apply(
        window: WindowControlling,
        corner: Corner,
        initialPosition: CGPoint,
        initialSize: CGSize,
        desiredSize: CGSize,
        currentPosition: CGPoint,
        currentSize: CGSize,
        positionSetsAreReliable: Bool = true
    ) {
        // A window already straddling two displays can never receive a reliable position
        // set — even a rollback to its pre-frame origin teleports (the restore rect itself
        // straddles). Degrade to size-only resizing: the anchor is wrong for top/left
        // corners, but the window can never be mangled.
        guard positionSetsAreReliable else {
            window.size = desiredSize
            return
        }

        // Track the last position we REQUESTED so we can detect the WindowServer applying
        // something wildly different (teleport) and roll the frame back.
        var lastRequestedPosition: CGPoint? = nil
        func setPosition(_ p: CGPoint) {
            window.position = p
            lastRequestedPosition = p
        }
        defer {
            verifyAndRepair(
                window: window,
                lastRequestedPosition: lastRequestedPosition,
                preFramePosition: currentPosition,
                preFrameSize: currentSize
            )
        }

        let needsPositionUpdate = (corner == .TopLeft || corner == .TopRight || corner == .BottomLeft)

        if needsPositionUpdate {
            let isGrowing = (desiredSize.width > currentSize.width + epsilon ||
                             desiredSize.height > currentSize.height + epsilon)

            if isGrowing {
                // Grow AWAY from the anchor first (size with position untouched), THEN move
                // the origin — see AGENTS.md "Resize order-of-operations at screen edges".
                window.size = desiredSize
                var actualSize = window.size ?? currentSize

                if WindowCalculations.sizeFellShort(of: desiredSize, actual: actualSize, epsilon: epsilon) {
                    // No room to grow away from the anchor (window against an OUTER screen
                    // edge). Fall back to position-first — the 2025-12-06 fix.
                    NSLog("[ModMove] resize: size-first clamped (desired: %@, actual: %@), retrying position-first",
                          NSStringFromSize(desiredSize), NSStringFromSize(actualSize))
                    if let newPosition = WindowCalculations.calculateResizedWindowPosition(
                           corner: corner,
                           initialPosition: initialPosition,
                           initialSize: initialSize,
                           actualSize: desiredSize
                       ) {
                        setPosition(newPosition)
                    }
                    window.size = desiredSize
                    actualSize = window.size ?? actualSize
                }

                // Catastrophic clamp: macOS made an axis SMALLER than BOTH its current and
                // its desired value. (Comparing against current alone misfires on mixed-axis
                // resizes — growing width while deliberately shrinking height — and the bogus
                // rollback emitted an off-screen transient rect. Found by gesture fuzzing.)
                if actualSize.width < min(currentSize.width, desiredSize.width) - epsilon ||
                   actualSize.height < min(currentSize.height, desiredSize.height) - epsilon {
                    NSLog("[ModMove] resize: catastrophic clamp (current: %@, desired: %@, actual: %@), rolling back",
                          NSStringFromSize(currentSize), NSStringFromSize(desiredSize), NSStringFromSize(actualSize))
                    // Restore SIZE first (size sets are reliable), so the position set that
                    // follows describes the true final rect — never a stale-size transient.
                    window.size = currentSize
                    if let restorePosition = WindowCalculations.calculateResizedWindowPosition(
                           corner: corner,
                           initialPosition: initialPosition,
                           initialSize: initialSize,
                           actualSize: window.size ?? currentSize
                       ) {
                        setPosition(restorePosition)
                    }
                    return
                }

                // Keep the anchor corner fixed based on what actually happened.
                if let correctedPosition = WindowCalculations.calculateResizedWindowPosition(
                       corner: corner,
                       initialPosition: initialPosition,
                       initialSize: initialSize,
                       actualSize: actualSize
                   ) {
                    setPosition(correctedPosition)
                }
            } else {
                // Shrinking: set size (macOS may clamp to the window's minimum), then anchor
                // the fixed corner using the size that was actually applied.
                window.size = desiredSize
                if let actualSize = window.size,
                   let correctedPosition = WindowCalculations.calculateResizedWindowPosition(
                       corner: corner,
                       initialPosition: initialPosition,
                       initialSize: initialSize,
                       actualSize: actualSize
                   ) {
                    setPosition(correctedPosition)
                }
            }
        } else {
            // BottomRight: only changes size, no position adjustment needed
            window.size = desiredSize
        }
    }

    /// Detects the WindowServer applying a position wildly different from what we requested
    /// (teleport — observed on macOS 26.5 for rects straddling two displays) and restores
    /// the pre-frame rect. The pre-frame rect was achievable (the window WAS there), so
    /// restoring it is safe: set position first (a valid on-screen origin), then size.
    private static func verifyAndRepair(
        window: WindowControlling,
        lastRequestedPosition: CGPoint?,
        preFramePosition: CGPoint,
        preFrameSize: CGSize
    ) {
        guard let requested = lastRequestedPosition, let actual = window.position else { return }
        if abs(actual.x - requested.x) > teleportTolerance ||
           abs(actual.y - requested.y) > teleportTolerance {
            NSLog("[ModMove] resize: WindowServer teleported window (requested: %@, actual: %@), restoring pre-frame rect %@ %@",
                  NSStringFromPoint(requested), NSStringFromPoint(actual),
                  NSStringFromPoint(preFramePosition), NSStringFromSize(preFrameSize))
            window.position = preFramePosition
            window.size = preFrameSize
            window.position = preFramePosition
        }
    }
}

final class Mover {
    var state: FlagState = .Ignore {
        didSet {
            if self.state != oldValue {
                self.changed(state: self.state)
            }
        }
    }

    private var monitor: Any?
    private var initialMousePosition: CGPoint?
    private var initialWindowPosition: CGPoint?
    private var initialWindowSize: CGSize?
    private var closestCorner: Corner?
    private var window: AccessibilityElement?
    private var frame: NSRect?        // Constraint frame for MOVES (desktop bounding frame)
    private var resizeFrame: NSRect?  // Constraint frame for RESIZES (single screen when Displays-have-separate-Spaces)
    private var scaleFactor: CGFloat?

    private var prevMousePosition: CGPoint?
    private var prevTime: CFTimeInterval = CACurrentMediaTime()
    // Mouse speed is in pixels/second.
    private var mouseSpeed: CGFloat = 0
    private let FAST_MOUSE_SPEED_THRESHOLD: CGFloat = 1000
    // Weight given to latest mouse speed for averaging.
    private let MOUSE_SPEED_WEIGHT: CGFloat = 0.1

    // Throttle position updates to 50fps for better performance with heavy apps
    private var lastUpdateTime: CFTimeInterval = 0
    private let UPDATE_INTERVAL: CFTimeInterval = 0.020  // ~50fps (20ms)

    private func mouseMoved(handler: (_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Void) {
        // Defensive check: verify modifier keys are still pressed
        // This prevents stuck drag/resize if flagsChanged event is missed
        // IMPORTANT: Only check this AFTER we've grabbed a window, not before
        // Otherwise we might reset mid-gesture and grab a different window
        if self.window != nil {
            let currentFlags = NSEvent.modifierFlags
            let hasControl = currentFlags.contains(.control)
            let hasOption = currentFlags.contains(.option)

            // If modifiers were released, stop immediately
            if !hasControl || !hasOption {
                self.removeMonitor()
                self.resetState()
                return
            }
        }

        // On first call: grab window and initial mouse position atomically
        // This prevents race condition where mouse moves before we grab the window
        if self.window == nil {
            let initialMousePos = Mouse.currentPosition()
            self.window = AccessibilityElement.systemWideElement.element(at: initialMousePos)?.window()

            if let window = self.window {
                let appName = window.pid().flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName } ?? "unknown"
                NSLog("[ModMove] Got window - app: %@, pid: %d, pos: %@, size: %@, mouse: %@",
                      appName,
                      window.pid() ?? -1,
                      NSStringFromPoint(window.position ?? .zero),
                      NSStringFromSize(window.size ?? .zero),
                      NSStringFromPoint(initialMousePos))

                // Initialize all state atomically with the same mouse position
                self.prevMousePosition = initialMousePos
                self.initialMousePosition = initialMousePos
                self.initialWindowPosition = window.position
                self.initialWindowSize = window.size
                self.closestCorner = self.getClosestCorner(window: window, mouse: initialMousePos)
                (self.frame, self.resizeFrame, self.scaleFactor) = getUsableScreen()

                let currentPid = NSRunningApplication.current.processIdentifier
                if let pid = window.pid(), pid != currentPid {
                    NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
                }
                window.bringToFront()
            } else {
                NSLog("[ModMove] Failed to get window at mouse position: %@", NSStringFromPoint(initialMousePos))
            }
            return
        }

        guard let window = self.window, let initMousePos = self.initialMousePosition else {
            return
        }

        // On subsequent calls: track mouse movement and update window
        let curMousePos = Mouse.currentPosition()
        self.trackMouseSpeed(curMousePos: curMousePos)
        let mouseDelta = CGPoint(x: curMousePos.x - initMousePos.x, y: curMousePos.y - initMousePos.y)
        handler(window, mouseDelta)
    }

    private func trackMouseSpeed(curMousePos: CGPoint) {
        if let prevMousePos = self.prevMousePosition, let scale = self.scaleFactor {
            let mouseDist: CGFloat = sqrt(
                pow((curMousePos.x - prevMousePos.x) / scale, 2)
                + pow((curMousePos.y - prevMousePos.y) / scale, 2))
            let now = CACurrentMediaTime()
            let timeDiff: CGFloat = CGFloat(now - prevTime)
            let latestMouseSpeed = mouseDist / timeDiff
            self.mouseSpeed = latestMouseSpeed * MOUSE_SPEED_WEIGHT + self.mouseSpeed * (1 - MOUSE_SPEED_WEIGHT)
            self.prevMousePosition = curMousePos
            self.prevTime = now
            // NSLog("mouseSpeed: %.1f (threshold: %.1f)", self.mouseSpeed, FAST_MOUSE_SPEED_THRESHOLD)
        }
    }

    /// Returns (moveFrame, resizeFrame, scaleFactor).
    ///
    /// - moveFrame: desktop bounding frame. Windows can always be MOVED between displays,
    ///   so shared screen edges never constrain moves; only the outer desktop perimeter does.
    /// - resizeFrame: same desktop frame when all displays share one Space, but the SINGLE
    ///   containing screen when "Displays have separate Spaces" is enabled — macOS refuses
    ///   display-spanning windows in that mode, so the shared edge is a real wall for resizes.
    private func getUsableScreen(windowPos: CGPoint? = nil, windowSize: CGSize? = nil) -> (NSRect, NSRect, CGFloat) {
        // Find the screen that contains the window (supports multi-monitor setups)
        // Use provided position or fall back to initial position
        guard let pos = windowPos ?? self.initialWindowPosition else {
            // Fallback to main screen if we don't have window position yet
            if let main = NSScreen.main {
                return (main.visibleFrame, main.visibleFrame, main.backingScaleFactor)
            }
            return (NSRect.zero, NSRect.zero, 1)
        }

        // Convert window position from Accessibility API coordinates (top-left origin)
        // to NSScreen coordinates (bottom-left origin).
        //
        // The Accessibility/CoreGraphics global coordinate origin is the TOP-LEFT of the
        // PRIMARY screen (the one whose NSScreen frame origin is (0, 0) — it owns the menu
        // bar). Screens physically above the primary have NEGATIVE AX Y values.
        //
        // This matters most when "Displays have separate Spaces" is DISABLED: all screens
        // share a single coordinate space, and a screen stacked above the primary can have
        // a larger NSScreen maxY than the primary's height. Converting relative to the
        // global maximum Y (instead of the primary height) would shift every screen and
        // make the window→screen lookup pick the wrong physical screen, causing windows
        // to "sink" past the real screen boundary during move/resize.

        // The primary screen is the one anchored at the NSScreen origin (0, 0).
        let (screenInfos, primaryScreenHeight) = self.screenConfiguration()

        // Constrain moves against the WHOLE desktop, not the single screen the window
        // sits on. Constraining to one screen turns the edge shared with an adjacent
        // screen into a hard wall — that's what pins a window at the top edge of a
        // bottom screen. See WindowCalculations.desktopBoundingFrame.
        let desktopFrame = WindowCalculations.desktopBoundingFrame(
            screens: screenInfos,
            primaryScreenHeight: primaryScreenHeight
        )

        // Screen lookups use the window's RECT (overlap-based), not its origin point:
        // an origin exactly on a shared screen edge is ambiguous between two screens,
        // and picking the wrong one made the sticky-edge caps yank the window
        // (the "snaps to half height" bug).
        let size = windowSize ?? self.initialWindowSize ?? CGSize(width: 1, height: 1)
        let windowRect = NSRect(origin: pos, size: size)

        // Resizes treat shared screen edges as walls (the WindowServer teleports windows
        // whose origin is set into the straddling strip — see resizeConstraintFrame docs).
        let resizeFrame = WindowCalculations.resizeConstraintFrame(
            windowRect: windowRect,
            screens: screenInfos,
            primaryScreenHeight: primaryScreenHeight
        )

        // Mouse-speed normalization uses the scale factor of the screen the window is on.
        let scaleFactor = WindowCalculations.screenContaining(
            windowRect: windowRect,
            screens: screenInfos,
            primaryScreenHeight: primaryScreenHeight
        )?.scaleFactor ?? NSScreen.main?.backingScaleFactor ?? 1

        if desktopFrame != .zero {
            return (desktopFrame, resizeFrame, scaleFactor)
        }

        // Fallback to main screen if we somehow have no screens
        if let main = NSScreen.main {
            let mainInfo = ScreenInfo(frame: main.frame, visibleFrame: main.visibleFrame, backingScaleFactor: main.backingScaleFactor)
            let accessibilityFrame = WindowCalculations.accessibilityVisibleFrame(for: mainInfo, primaryScreenHeight: primaryScreenHeight)
            return (accessibilityFrame, accessibilityFrame, main.backingScaleFactor)
        }
        return (NSRect.zero, NSRect.zero, 1)
    }

    private func getClosestCorner(window: AccessibilityElement, mouse: CGPoint) -> Corner {
        if let size = window.size, let position = window.position {
            return WindowCalculations.calculateClosestCorner(
                windowPosition: position,
                windowSize: size,
                mousePosition: mouse
            )
        }
        return .BottomRight
    }

    private func resizeWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        guard let initWinSize = self.initialWindowSize,
              let initWinPos = self.initialWindowPosition,
              let corner = self.closestCorner,
              let frame = self.resizeFrame else {
            return
        }

        // Throttle updates to 50fps for better performance
        let now = CACurrentMediaTime()
        if now - lastUpdateTime < UPDATE_INTERVAL {
            return
        }
        lastUpdateTime = now

        // Determine if we should constrain based on speed and current position.
        // A window outside (or straddling an edge of) the constraint frame is never
        // yanked back — same semantics as moves.
        let currentPosition = window.position ?? initWinPos
        let currentWindowSize = window.size ?? initWinSize
        let currentRect = NSRect(origin: currentPosition, size: currentWindowSize)
        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: self.mouseSpeed,
            speedThreshold: FAST_MOUSE_SPEED_THRESHOLD,
            currentWindowRect: currentRect,
            screenFrame: frame
        )

        // Calculate constrained delta
        let constrainedDelta = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initWinPos,
            initialSize: initWinSize,
            screenFrame: frame,
            shouldConstrain: shouldConstrain
        )

        // Calculate desired size
        let desiredSize = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initWinSize,
            delta: constrainedDelta
        )

        // Position sets are only reliable for windows entirely on one screen (probed:
        // straddling/cross-screen position sets get teleported by the WindowServer).
        let (screenInfos, primaryScreenHeight) = self.screenConfiguration()
        let positionSetsAreReliable = WindowCalculations.isEntirelyOnOneScreen(
            windowRect: currentRect,
            screens: screenInfos,
            primaryScreenHeight: primaryScreenHeight
        )

        ResizeFrameApplier.apply(
            window: window,
            corner: corner,
            initialPosition: initWinPos,
            initialSize: initWinSize,
            desiredSize: desiredSize,
            currentPosition: currentPosition,
            currentSize: currentWindowSize,
            positionSetsAreReliable: positionSetsAreReliable
        )
    }

    /// Current screen configuration in the form the pure calculation layer consumes.
    private func screenConfiguration() -> ([ScreenInfo], CGFloat) {
        let primaryScreen = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first
        let primaryScreenHeight = primaryScreen?.frame.height ?? 0
        let screenInfos = NSScreen.screens.map {
            ScreenInfo(frame: $0.frame, visibleFrame: $0.visibleFrame, backingScaleFactor: $0.backingScaleFactor)
        }
        return (screenInfos, primaryScreenHeight)
    }

    private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        guard let initWinPos = self.initialWindowPosition,
              let initWinSize = self.initialWindowSize,
              let frame = self.frame else {
            return
        }

        // Throttle updates to 50fps for better performance
        let now = CACurrentMediaTime()
        if now - lastUpdateTime < UPDATE_INTERVAL {
            return
        }
        lastUpdateTime = now

        // Determine if we should constrain based on speed and current position
        let shouldConstrain = self.shouldConstrainMouseDelta(window)

        // Calculate constrained delta
        let constrainedDelta = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: mouseDelta,
            initialPosition: initWinPos,
            windowSize: initWinSize,
            screenFrame: frame,
            shouldConstrain: shouldConstrain
        )

        window.position = CGPoint(x: initWinPos.x + constrainedDelta.x, y: initWinPos.y + constrainedDelta.y)
    }

    private func shouldConstrainMouseDelta(_ window: AccessibilityElement) -> Bool {
        // Check actual current window position
        guard let frame = self.frame,
              let currentPos = window.position,
              let currentSize = window.size else {
            return false
        }

        let currentRect = NSMakeRect(currentPos.x, currentPos.y, currentSize.width, currentSize.height)

        return WindowCalculations.shouldConstrainMovement(
            mouseSpeed: self.mouseSpeed,
            speedThreshold: FAST_MOUSE_SPEED_THRESHOLD,
            currentWindowRect: currentRect,
            screenFrame: frame
        )
    }

    private func changed(state: FlagState) {
        // Allow mode switching mid-gesture (e.g., shift key pressed/released while dragging)
        // But keep the same window
        let shouldKeepWindow = (self.window != nil && state != .Ignore)

        // Always remove old monitor
        self.removeMonitor()

        // If switching modes mid-gesture, reset initial positions to current state
        // This prevents jump because our reference point is now where the window currently is
        if shouldKeepWindow && state != .Ignore {
            if let window = self.window {
                let currentMousePos = Mouse.currentPosition()

                // Update all initial values to current state
                self.initialMousePosition = currentMousePos
                self.initialWindowPosition = window.position
                self.initialWindowSize = window.size

                // Recalculate closest corner based on current mouse position
                self.closestCorner = self.getClosestCorner(window: window, mouse: currentMousePos)

                // Update screen frame in case we moved to a different monitor
                (self.frame, self.resizeFrame, self.scaleFactor) = getUsableScreen(windowPos: window.position, windowSize: window.size)
            }
        }

        // Only reset state if releasing keys (going to .Ignore)
        if !shouldKeepWindow {
            self.resetState()
        }

        switch state {
        case .Resize:
            self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                self.mouseMoved(handler: self.resizeWindow)
            }
        case .Drag:
            self.monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { _ in
                self.mouseMoved(handler: self.moveWindow)
            }
        case .Ignore:
            break
        }
    }

    private func resetState() {
        self.initialMousePosition = nil
        self.initialWindowPosition = nil
        self.initialWindowSize = nil
        self.closestCorner = nil
        self.window = nil
        self.prevMousePosition = nil
        self.mouseSpeed = 0
        self.prevTime = CACurrentMediaTime()
        self.frame = nil
        self.resizeFrame = nil
        self.scaleFactor = nil
        self.lastUpdateTime = 0
    }

    private func removeMonitor() {
        if let monitor = self.monitor {
            NSEvent.removeMonitor(monitor)
        }
        self.monitor = nil
    }

    deinit {
        self.removeMonitor()
    }
}
