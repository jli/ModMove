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
        let currentFlags = NSEvent.modifierFlags
        let hasControl = currentFlags.contains(.control)
        let hasOption = currentFlags.contains(.option)

        // If modifiers were released, stop immediately
        if !hasControl || !hasOption {
            self.removeMonitor()
            self.resetState()
            return
        }

        let curMousePos = Mouse.currentPosition()
        if self.window == nil {
            self.window = AccessibilityElement.systemWideElement.element(at: curMousePos)?.window()
        }
        guard let window = self.window else {
            return
        }

        if self.initialMousePosition == nil {
            self.prevMousePosition = curMousePos
            self.initialMousePosition = curMousePos
            self.initialWindowPosition = window.position
            self.initialWindowSize = window.size
            self.closestCorner = self.getClosestCorner(window: window, mouse: curMousePos)
            (self.frame, self.scaleFactor) = getUsableScreen()

            let currentPid = NSRunningApplication.current.processIdentifier
            if let pid = window.pid(), pid != currentPid {
                NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
            }
            window.bringToFront()
        } else if let initMousePos = self.initialMousePosition {
            self.trackMouseSpeed(curMousePos: curMousePos)
            let mouseDelta = CGPoint(x: curMousePos.x - initMousePos.x, y: curMousePos.y - initMousePos.y)
            handler(window, mouseDelta)
        }
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

        // Find which screen contains the window by checking in Accessibility coords
        // We need to check each screen individually with its own coordinate space
        for screen in NSScreen.screens {
            // Convert this screen's frame to Accessibility coords for comparison
            let screenTop = screen.frame.maxY
            let screenBottom = screen.frame.minY
            let accessibilityScreenMinY = screenTop - screen.frame.height  // Top in Accessibility
            let accessibilityScreenMaxY = screenTop  // Bottom in Accessibility

            // Check if window position is within this screen's Accessibility Y range
            if pos.x >= screen.frame.minX && pos.x <= screen.frame.maxX &&
               pos.y >= accessibilityScreenMinY && pos.y <= accessibilityScreenMaxY {
                // Convert visibleFrame from NSScreen coords (bottom-left) to Accessibility coords (top-left)
                // Use THIS screen's frame for conversion, not a global value
                let accessibilityFrame = NSRect(
                    x: screen.visibleFrame.minX,
                    y: screen.frame.maxY - screen.visibleFrame.maxY,  // Top edge in Accessibility coords
                    width: screen.visibleFrame.width,
                    height: screen.visibleFrame.height
                )
                return (accessibilityFrame, screen.backingScaleFactor)
            }
        }

        // Fallback to main screen if window position isn't on any screen
        if let main = NSScreen.main {
            let accessibilityFrame = NSRect(
                x: main.visibleFrame.minX,
                y: main.frame.maxY - main.visibleFrame.maxY,
                width: main.visibleFrame.width,
                height: main.visibleFrame.height
            )
            return (accessibilityFrame, main.backingScaleFactor)
        }
        return (NSRect.zero, 1)
    }

    private func getClosestCorner(window: AccessibilityElement, mouse: CGPoint) -> Corner {
        if let size = window.size, let position = window.position {
            let xmid = position.x + size.width / 2
            let ymid = position.y + size.height / 2
            if mouse.x < xmid && mouse.y < ymid {
                return .TopLeft
            } else if mouse.x >= xmid && mouse.y < ymid {
                return .TopRight
            } else if mouse.x < xmid && mouse.y >= ymid {
                return .BottomLeft
            } else {
                return .BottomRight
            }
        }
        return .BottomRight
    }

    private func resizeWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let initWinSize = self.initialWindowSize, let initWinPos = self.initialWindowPosition,
            let corner = self.closestCorner, let frame = self.frame {

            // Throttle updates to 60fps for better performance
            let now = CACurrentMediaTime()
            if now - lastUpdateTime < UPDATE_INTERVAL {
                return
            }
            lastUpdateTime = now

            var mdx = mouseDelta.x
            var mdy = mouseDelta.y

            if shouldConstrainMouseDelta(window, mouseDelta) {
                switch corner {
                case .TopLeft:
                    mdx = max(mouseDelta.x, frame.minX - initWinPos.x)
                    mdy = max(mouseDelta.y, frame.minY - initWinPos.y)
                case .TopRight:
                    mdx = min(mouseDelta.x, frame.maxX - (initWinPos.x + initWinSize.width))
                    mdy = max(mouseDelta.y, frame.minY - initWinPos.y)
                case .BottomLeft:
                    mdx = max(mouseDelta.x, frame.minX - initWinPos.x)
                    mdy = min(mouseDelta.y, frame.maxY - (initWinPos.y + initWinSize.height))
                case .BottomRight:
                    mdx = min(mouseDelta.x, frame.maxX - (initWinPos.x + initWinSize.width))
                    mdy = min(mouseDelta.y, frame.maxY - (initWinPos.y + initWinSize.height))
                }
            }

            switch corner {
            case .TopLeft:
                window.size = CGSize(width: initWinSize.width - mdx, height: initWinSize.height - mdy)
                // Only use read-back when shrinking (might hit minimum size constraints)
                if mdx > 0 || mdy > 0 {
                    // Shrinking: check actual size in case it hit minimum
                    if let actualSize = window.size {
                        let actualDx = initWinSize.width - actualSize.width
                        let actualDy = initWinSize.height - actualSize.height
                        window.position = CGPoint(x: initWinPos.x + actualDx, y: initWinPos.y + actualDy)
                    } else {
                        window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y + mdy)
                    }
                } else {
                    // Growing: use simple calculation
                    window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y + mdy)
                }
            case .TopRight:
                window.size = CGSize(width: initWinSize.width + mdx, height: initWinSize.height - mdy)
                // Only use read-back when shrinking height
                if mdy > 0 {
                    // Shrinking height: check actual size
                    if let actualSize = window.size {
                        let actualDy = initWinSize.height - actualSize.height
                        window.position = CGPoint(x: initWinPos.x, y: initWinPos.y + actualDy)
                    } else {
                        window.position = CGPoint(x: initWinPos.x, y: initWinPos.y + mdy)
                    }
                } else {
                    // Growing height: use simple calculation
                    window.position = CGPoint(x: initWinPos.x, y: initWinPos.y + mdy)
                }
            case .BottomLeft:
                window.size = CGSize(width: initWinSize.width - mdx, height: initWinSize.height + mdy)
                // Only use read-back when shrinking width
                if mdx > 0 {
                    // Shrinking width: check actual size
                    if let actualSize = window.size {
                        let actualDx = initWinSize.width - actualSize.width
                        window.position = CGPoint(x: initWinPos.x + actualDx, y: initWinPos.y)
                    } else {
                        window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y)
                    }
                } else {
                    // Growing width: use simple calculation
                    window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y)
                }
            case .BottomRight:
                // BottomRight only changes size, no position adjustment needed
                window.size = CGSize(width: initWinSize.width + mdx, height: initWinSize.height + mdy)
            }
        }
    }

    private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let initWinPos = self.initialWindowPosition, let initWinSize = self.initialWindowSize, let frame = self.frame {

            // Throttle updates to 60fps for better performance
            let now = CACurrentMediaTime()
            if now - lastUpdateTime < UPDATE_INTERVAL {
                return
            }
            lastUpdateTime = now

            var mdx = mouseDelta.x
            var mdy = mouseDelta.y

            if shouldConstrainMouseDelta(window, mouseDelta) {
                let minDx = frame.minX - initWinPos.x
                let maxDx = frame.maxX - (initWinPos.x + initWinSize.width)
                let minDy = frame.minY - initWinPos.y
                let maxDy = frame.maxY - (initWinPos.y + initWinSize.height)

                mdx = min(max(mouseDelta.x, minDx), maxDx)
                mdy = min(max(mouseDelta.y, minDy), maxDy)
            }
            window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y + mdy)
        }
    }

    private func shouldConstrainMouseDelta(_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Bool {
        // Slow moves get constrained ONLY if window is currently inside
        // Once you escape (via fast movement), you stay out even if you slow down
        let isSlow = self.mouseSpeed < FAST_MOUSE_SPEED_THRESHOLD
        if !isSlow {
            return false  // Fast movements are never constrained
        }

        // Check actual current window position (using API, but only for slow movements)
        // This is acceptable since we only check during slow movements, not constantly
        guard let frame = self.frame, let currentPos = window.position, let currentSize = window.size else {
            return false
        }
        let currentRect = NSMakeRect(currentPos.x, currentPos.y, currentSize.width, currentSize.height)
        return frame.contains(currentRect)
    }

    private func changed(state: FlagState) {
        self.removeMonitor()
        self.resetState()

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
