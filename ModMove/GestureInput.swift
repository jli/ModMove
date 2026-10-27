import AppKit
import QuartzCore

/// Observes mouse-moved events and, while a gesture is active, SWALLOWS them so the app under
/// the cursor never sees them — the same thing a native title-bar drag or live resize does.
///
/// Why (measured 2026-10-27, macOS 26.7, see AGENTS.md "Gesture smoothness"): an app that
/// receives the gesture's mouse moves does hover/cursor work on its main thread for each one.
/// Chrome re-sets the cursor on every move, which is expensive when the pointer is customized
/// (Accessibility → Display → Pointer). Our AX position/size sets are serviced on that same
/// main thread, so they queued behind this work: frames were late and irregular.
///
/// Falls back to a passive global monitor (no swallowing) if the tap can't be created.
final class MouseMoveTap {
    /// Called for every mouse move. Return true to swallow it.
    ///
    /// Read the location and modifiers from the EVENT, not from global state. Once the tap swallows
    /// hardware moves, `CGEvent(source: nil).location` stops advancing and `NSEvent.modifierFlags`
    /// goes stale (synthetic events posted by a bench script don't show this — they warp the
    /// cursor directly).
    private let onMouseMoved: (_ location: CGPoint, _ flags: CGEventFlags) -> Bool
    private var tap: CFMachPort?
    private var fallbackMonitor: Any?

    init(onMouseMoved: @escaping (_ location: CGPoint, _ flags: CGEventFlags) -> Bool) {
        self.onMouseMoved = onMouseMoved

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let this = Unmanaged<MouseMoveTap>.fromOpaque(refcon!).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                // The WindowServer disables slow taps; a missed re-enable would silently
                // stop all gestures.
                if let tap = this.tap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }
            return this.onMouseMoved(event.location, event.flags) ? nil : Unmanaged.passUnretained(event)
        }

        self.tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.mouseMoved.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        if let tap = self.tap {
            CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        } else {
            NSLog("[ModMove] Could not create mouse event tap; falling back to a passive monitor")
            self.fallbackMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { event in
                _ = onMouseMoved(event.cgEvent?.location ?? Mouse.currentPosition(), event.cgEvent?.flags ?? [])
            }
        }
    }

    deinit {
        if let tap = self.tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let monitor = self.fallbackMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// Runs the most recently submitted frame once per display refresh.
///
/// Replaces a fixed 20ms throttle, which quantized against the mouse's event rate: with
/// events every ~10ms, timing jitter made it skip two events out of three, so windows
/// updated at ~30fps on a 60Hz display and judder against the refresh.
final class FramePacer {
    private var pending: (() -> Void)?
    private var link: AnyObject?

    /// Replaces any frame not yet applied — only the latest mouse position matters.
    func submit(_ frame: @escaping () -> Void) {
        self.pending = frame
        if self.link == nil {
            self.start()
        }
    }

    func stop() {
        if #available(macOS 14.0, *), let link = self.link as? CADisplayLink {
            link.invalidate()
        } else if let timer = self.link as? Timer {
            timer.invalidate()
        }
        self.link = nil
        self.pending = nil
    }

    @objc private func tick(_ sender: Any) {
        guard let frame = self.pending else {
            return
        }
        self.pending = nil
        frame()
    }

    private func start() {
        if #available(macOS 14.0, *) {
            let mouse = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main {
                let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
                link.add(to: .main, forMode: .commonModes)
                self.link = link
                return
            }
        }
        let timer = Timer(timeInterval: 1.0 / 60.0, target: self, selector: #selector(tick(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .commonModes)
        self.link = timer
    }
}
