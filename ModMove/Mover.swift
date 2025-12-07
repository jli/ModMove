import AppKit
import Foundation
import QuartzCore

enum Corner {
    case TopLeft
    case TopRight
    case BottomLeft
    case BottomRight
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
    private var frame: NSRect?
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
                (self.frame, self.scaleFactor) = getUsableScreen()

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

    private func getUsableScreen(windowPos: CGPoint? = nil) -> (NSRect, CGFloat) {
        // Find the screen that contains the window (supports multi-monitor setups)
        // Use provided position or fall back to initial position
        guard let pos = windowPos ?? self.initialWindowPosition else {
            // Fallback to main screen if we don't have window position yet
            if let main = NSScreen.main {
                return (main.visibleFrame, main.backingScaleFactor)
            }
            return (NSRect.zero, 1)
        }

        // Convert window position from Accessibility API coordinates (top-left origin)
        // to NSScreen coordinates (bottom-left origin)
        // The Accessibility API uses Cocoa flipped coordinates where y=0 is at the top
        // NSScreen uses standard Cocoa coordinates where y=0 is at the bottom

        // Find the global max Y to convert NSScreen coords to Accessibility coords
        // In NSScreen: origin is bottom-left, Y increases upward
        // In Accessibility: origin is top-left, Y increases downward
        // We need to find the highest point across all screens
        let globalMaxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0

        // Find which screen contains the window by checking in Accessibility coords
        for screen in NSScreen.screens {
            // Convert this screen's NSScreen frame to Accessibility coords
            // For a screen at NSScreen Y from minY to maxY:
            // - The top in Accessibility is: globalMaxY - maxY
            // - The bottom in Accessibility is: globalMaxY - minY
            let accessibilityScreenMinY = globalMaxY - screen.frame.maxY  // Top
            let accessibilityScreenMaxY = globalMaxY - screen.frame.minY  // Bottom

            // Check if window position is within this screen's bounds
            if pos.x >= screen.frame.minX && pos.x <= screen.frame.maxX &&
               pos.y >= accessibilityScreenMinY && pos.y <= accessibilityScreenMaxY {
                // Convert visibleFrame from NSScreen coords to Accessibility coords
                let accessibilityVisibleMinY = globalMaxY - screen.visibleFrame.maxY
                let accessibilityFrame = NSRect(
                    x: screen.visibleFrame.minX,
                    y: accessibilityVisibleMinY,
                    width: screen.visibleFrame.width,
                    height: screen.visibleFrame.height
                )
                return (accessibilityFrame, screen.backingScaleFactor)
            }
        }

        // Fallback to main screen if window position isn't on any screen
        if let main = NSScreen.main {
            let globalMaxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
            let accessibilityVisibleMinY = globalMaxY - main.visibleFrame.maxY
            let accessibilityFrame = NSRect(
                x: main.visibleFrame.minX,
                y: accessibilityVisibleMinY,
                width: main.visibleFrame.width,
                height: main.visibleFrame.height
            )
            return (accessibilityFrame, main.backingScaleFactor)
        }
        return (NSRect.zero, 1)
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
              let frame = self.frame else {
            return
        }

        // Throttle updates to 50fps for better performance
        let now = CACurrentMediaTime()
        if now - lastUpdateTime < UPDATE_INTERVAL {
            return
        }
        lastUpdateTime = now

        // Determine if we should constrain based on speed
        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: self.mouseSpeed,
            speedThreshold: FAST_MOUSE_SPEED_THRESHOLD
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

        // CRITICAL: Avoid stutter at minimum size by only updating position when size actually changes
        // Strategy: Try size change first, then update position based on what actually happened

        let needsPositionUpdate = (corner == .TopLeft || corner == .TopRight || corner == .BottomLeft)
        let currentSize = window.size ?? initWinSize

        // Special handling for corners that need position updates
        if needsPositionUpdate {
            // For screen-edge resize bug: optimistically set position first
            // But ONLY if we're not already stuck at minimum size
            let epsilon: CGFloat = 0.1

            // Check if this resize would make the window smaller
            let isGrowing = (desiredSize.width > currentSize.width || desiredSize.height > currentSize.height)

            if isGrowing {
                // Growing: safe to update position first (no minimum size constraint)
                if let newPosition = WindowCalculations.calculateResizedWindowPosition(
                       corner: corner,
                       initialPosition: initWinPos,
                       initialSize: initWinSize,
                       actualSize: desiredSize
                   ) {
                    window.position = newPosition
                }
            }

            // Set size - macOS may clamp to minimum
            window.size = desiredSize

            // Read back actual size and adjust position if needed
            if let actualSize = window.size {
                let sizeChanged = abs(actualSize.width - currentSize.width) > epsilon ||
                                abs(actualSize.height - currentSize.height) > epsilon

                // If shrinking or size changed, recalculate position based on actual size
                if !isGrowing || sizeChanged {
                    if let correctedPosition = WindowCalculations.calculateResizedWindowPosition(
                           corner: corner,
                           initialPosition: initWinPos,
                           initialSize: initWinSize,
                           actualSize: actualSize
                       ) {
                        window.position = correctedPosition
                    }
                }
            }
        } else {
            // BottomRight: only changes size, no position adjustment needed
            window.size = desiredSize
        }
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
                (self.frame, self.scaleFactor) = getUsableScreen(windowPos: window.position)
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
