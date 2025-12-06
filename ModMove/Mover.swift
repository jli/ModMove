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

    private func mouseMoved(handler: (_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Void) {
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

    private func getUsableScreen() -> (NSRect, CGFloat) {
        // Find the screen that contains the window (supports multi-monitor setups)
        guard let windowPos = self.initialWindowPosition else {
            // Fallback to main screen if we don't have window position yet
            if let main = NSScreen.main {
                return (main.visibleFrame, main.backingScaleFactor)
            }
            return (NSRect.zero, 1)
        }

        // Find which screen contains the window's position
        for screen in NSScreen.screens {
            if screen.frame.contains(windowPos) {
                return (screen.visibleFrame, screen.backingScaleFactor)
            }
        }

        // Fallback to main screen if window position isn't on any screen
        if let main = NSScreen.main {
            return (main.visibleFrame, main.backingScaleFactor)
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
            var mdx = mouseDelta.x
            var mdy = mouseDelta.y
            switch corner {
            case .TopLeft:
                if shouldConstrainMouseDelta(window, mouseDelta) {
                    mdx = max(mouseDelta.x, frame.minX - initWinPos.x)
                    mdy = max(mouseDelta.y, frame.minY - initWinPos.y)
                }
                window.position =  CGPoint(x: initWinPos.x + mdx, y: initWinPos.y + mdy)
                window.size = CGSize(width: initWinSize.width - mdx, height: initWinSize.height - mdy)
            case .TopRight:
                if shouldConstrainMouseDelta(window, mouseDelta) {
                    mdx = min(mouseDelta.x, frame.maxX - (initWinPos.x + initWinSize.width))
                    mdy = max(mouseDelta.y, frame.minY - initWinPos.y)
                }
                window.position = CGPoint(x: initWinPos.x, y: initWinPos.y + mdy)
                window.size = CGSize(width: initWinSize.width + mdx, height: initWinSize.height - mdy )
            case .BottomLeft:
                if shouldConstrainMouseDelta(window, mouseDelta) {
                    mdx = max(mouseDelta.x, frame.minX - initWinPos.x)
                    mdy = min(mouseDelta.y, frame.maxY - (initWinPos.y + initWinSize.height))
                }
                window.position = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y)
                window.size = CGSize(width: initWinSize.width - mdx, height: initWinSize.height + mdy)
            case .BottomRight:
                if shouldConstrainMouseDelta(window, mouseDelta) {
                    mdx = min(mouseDelta.x, frame.maxX - (initWinPos.x + initWinSize.width))
                    mdy = min(mouseDelta.y, frame.maxY - (initWinPos.y + initWinSize.height))
                }
                window.size = CGSize(width: initWinSize.width + mdx, height: initWinSize.height + mdy)
            }
        }
    }

    private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
        if let initWinPos = self.initialWindowPosition, let initWinSize = self.initialWindowSize, let frame = self.frame {
            var mdx = mouseDelta.x
            var mdy = mouseDelta.y
            if shouldConstrainMouseDelta(window, mouseDelta) {
                let oldMdx = mdx
                let oldMdy = mdy
                mdx = min(max(mouseDelta.x, frame.minX - initWinPos.x),
                          frame.maxX - (initWinPos.x + initWinSize.width))
                mdy = min(max(mouseDelta.y, frame.minY - initWinPos.y),
                          frame.maxY - (initWinPos.y + initWinSize.height))
                // NSLog("CONSTRAINT APPLIED: mdx: %.1f -> %.1f, mdy: %.1f -> %.1f", oldMdx, mdx, oldMdy, mdy)
            }
            let newPos = CGPoint(x: initWinPos.x + mdx, y: initWinPos.y + mdy)
            // NSLog("Setting position to: %@", NSStringFromPoint(newPos))
            window.position = newPos
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

    private func windowInsideFrame(_ window: AccessibilityElement, _ frame: CGRect) -> Bool {
        // Use cached values instead of querying Accessibility API
        // This eliminates 120-240 expensive API calls per second during slow moves
        if let initPos = self.initialWindowPosition, let initSize = self.initialWindowSize,
           let initMouse = self.initialMousePosition {
            let currentMousePos = Mouse.currentPosition()
            let mouseDelta = CGPoint(x: currentMousePos.x - initMouse.x,
                                     y: currentMousePos.y - initMouse.y)
            let currentPos = CGPoint(x: initPos.x + mouseDelta.x,
                                     y: initPos.y + mouseDelta.y)
            let windowRect = NSMakeRect(currentPos.x, currentPos.y, initSize.width, initSize.height)
            return frame.contains(windowRect)
        }
        return true
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
