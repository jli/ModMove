// Gesture smoothness benchmark: drives a REAL ModMove gesture with synthetic input (⌃⌥ / ⌃⌥⇧ +
// mouse moves, never clicks) and samples the WindowServer's view of the target window at ~2kHz.
//
//   swiftc -O scripts/gesture-bench.swift -o /tmp/gesture-bench
//   /tmp/gesture-bench "Google Chrome" <titleSubstring> move|resize <amplitudePx> <durationSec> [eventHz]
//   /tmp/gesture-bench TextEdit Untitled native <amplitudePx> <durationSec>   # titlebar-drag baseline
//
// Run exactly ONE ModMove instance. The terminal needs Accessibility permission. The target window
// is moved to (100,150) and raised first; keep it clear of screen edges so sticky edges don't
// interfere. Env: NOACT=1 leaves Finder active (target app inactive), DUMP=1 prints the timeline.
//
// Output: updates/s (ideal = display refresh), interval between WindowServer frame changes,
// stalls (>2 refreshes), and lag (time from mouse reaching an offset to the window reaching it).
// Results on 2026-10-27 are in AGENTS.md "Gesture smoothness".
import AppKit
import ApplicationServices
import QuartzCore

@_silgen_name("_AXUIElementGetWindow") func _AXUIElementGetWindow(_ e: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError
func attr(_ e: AXUIElement, _ a: String) -> CFTypeRef? { var v: CFTypeRef?; return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil }
func getP(_ w: AXUIElement) -> CGPoint { var p = CGPoint.zero; if let v = attr(w, kAXPositionAttribute) { AXValueGetValue(v as! AXValue, .cgPoint, &p) }; return p }
func getS(_ w: AXUIElement) -> CGSize { var s = CGSize.zero; if let v = attr(w, kAXSizeAttribute) { AXValueGetValue(v as! AXValue, .cgSize, &s) }; return s }
func setP(_ w: AXUIElement, _ p: CGPoint) { var p = p; AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!) }
func setS(_ w: AXUIElement, _ s: CGSize) { var s = s; AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &s)!) }
func wsBounds(_ id: CGWindowID) -> CGRect {
    let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as! [[String: Any]]
    return CGRect(dictionaryRepresentation: info[0][kCGWindowBounds as String] as! CFDictionary)!
}
let a = CommandLine.arguments
let (name, key, mode) = (a[1], a[2], a[3])
let amp = CGFloat(Double(a[4])!), dur = Double(a[5])!, hz = a.count > 6 ? Double(a[6])! : 125
let r = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name })!
let w = (attr(AXUIElementCreateApplication(r.processIdentifier), kAXWindowsAttribute) as! [AXUIElement]).first { (attr($0, kAXTitleAttribute) as? String ?? "").contains(key) }!
var wid: CGWindowID = 0; _ = _AXUIElementGetWindow(w, &wid)
setP(w, CGPoint(x: 100, y: 150)); r.activate(options: .activateIgnoringOtherApps); AXUIElementPerformAction(w, kAXRaiseAction as CFString); usleep(200_000)
if ProcessInfo.processInfo.environment["NOACT"] != nil { NSWorkspace.shared.runningApplications.first { $0.localizedName == "Finder" }!.activate(options: .activateIgnoringOtherApps) }; usleep(200_000)
let p0 = getP(w), s0 = getS(w)
// "native" = a real titlebar drag (mouse down/drag/up, no ModMove) as the smoothness baseline.
// It CLICKS, so it's restricted to TextEdit — never click into a browser.
let native = mode == "native"
if native && name != "TextEdit" { print("native mode clicks the title bar; TextEdit only"); exit(1) }
let mouseStart = native ? CGPoint(x: p0.x + s0.width / 2, y: p0.y + 12)
               : mode == "move" ? CGPoint(x: p0.x + s0.width / 4, y: p0.y + s0.height / 2)
                                : CGPoint(x: p0.x + s0.width - 30, y: p0.y + s0.height - 30)

let flags: CGEventFlags = native ? [] : mode == "move" ? [.maskControl, .maskAlternate] : [.maskControl, .maskAlternate, .maskShift]
let keys: [CGKeyCode] = native ? [] : mode == "move" ? [0x3B, 0x3A] : [0x3B, 0x3A, 0x38]
func key(_ k: CGKeyCode, _ down: Bool, _ f: CGEventFlags) { let e = CGEvent(keyboardEventSource: nil, virtualKey: k, keyDown: down)!; e.flags = f; e.post(tap: .cghidEventTap) }
func button(_ type: CGEventType, _ p: CGPoint) { CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!.post(tap: .cghidEventTap) }
func mouse(_ p: CGPoint, _ f: CGEventFlags) { let e = CGEvent(mouseEventSource: nil, mouseType: native ? .leftMouseDragged : .mouseMoved, mouseCursorPosition: p, mouseButton: .left)!; e.flags = f; e.post(tap: .cghidEventTap) }
func releaseKeys() { for k in keys.reversed() { key(k, false, []) } }
signal(SIGINT) { _ in releaseKeys(); exit(1) }

// Sampler thread
var samples: [(Double, CGRect)] = []
var sampling = true
let lock = NSLock()
let sampler = Thread {
    var last = CGRect.null
    while sampling {
        let b = wsBounds(wid); let t = CACurrentMediaTime()
        if b != last { lock.lock(); samples.append((t, b)); lock.unlock(); last = b }
        usleep(500)
    }
}

mouse(mouseStart, [])
usleep(100_000)
var acc: CGEventFlags = []
for (i, k) in keys.enumerated() { acc.insert([CGEventFlags.maskControl, .maskAlternate, .maskShift][i]); key(k, true, acc); usleep(20_000) }
usleep(80_000)
if native { button(.leftMouseDown, mouseStart) }
mouse(CGPoint(x: mouseStart.x, y: mouseStart.y + 1), flags)  // first event grabs the window
usleep(80_000)
sampler.start()
var targets: [(Double, CGFloat)] = []
let t0 = CACurrentMediaTime()
while true {
    let t = CACurrentMediaTime() - t0
    if t > dur { break }
    let off = amp * CGFloat((1 - cos(2 * Double.pi * t / dur)) / 2)  // out and back
    targets.append((t0 + t, off))
    mouse(CGPoint(x: mouseStart.x + off, y: mouseStart.y + 1 + off * (mode == "resize" ? 0.6 : 0)), flags)
    usleep(UInt32(1_000_000 / hz))
}
usleep(200_000)
if native { button(.leftMouseUp, CGPoint(x: mouseStart.x, y: mouseStart.y + 1)) }
releaseKeys()
usleep(100_000)
sampling = false
usleep(10_000)
setS(w, s0); setP(w, p0)

// Analysis: the window coordinate that tracks the mouse
func coord(_ r: CGRect) -> CGFloat { mode == "resize" ? r.width : r.minX }
let base = coord(CGRect(origin: p0, size: s0))
let upd = samples.filter { $0.0 >= t0 && $0.0 <= t0 + dur }
let intervals = zip(upd.dropFirst(), upd).map { ($0.0 - $1.0) * 1000 }.sorted()
func pct(_ xs: [Double], _ p: Double) -> Double { xs.isEmpty ? .nan : xs[min(xs.count - 1, Int(Double(xs.count) * p))] }
// Lag: for each window update, find when the mouse target was at that offset (on the same leg).
var lags: [Double] = []
for (t, b) in upd {
    let off = coord(b) - base
    let leg = t - t0 < dur / 2
    if let m = targets.last(where: { ($0.0 - t0 < dur / 2) == leg && $0.0 <= t && abs($0.1 - off) < 3 }) { lags.append((t - m.0) * 1000) }
}
lags.sort()
let fps = Double(upd.count) / dur
print(String(format: "%@ %@ amp=%.0f dur=%.1fs: updates/s=%.1f  interval med=%.1f p90=%.1f max=%.1f ms  stalls>34ms=%d  lag med=%.1f p90=%.1f ms",
             name, mode, Double(amp), dur, fps, pct(intervals, 0.5), pct(intervals, 0.9), intervals.last ?? .nan,
             intervals.filter { $0 > 34 }.count, pct(lags, 0.5), pct(lags, 0.9)))
if ProcessInfo.processInfo.environment["DUMP"] != nil {
    let evInt = zip(targets.dropFirst(), targets).map { ($0.0 - $1.0) * 1000 }.sorted()
    print(String(format: "event interval med=%.2f p90=%.2f", pct(evInt, 0.5), pct(evInt, 0.9)))
    for (t, b) in samples { print(String(format: "%8.1f  x=%.0f w=%.0f", (t - t0) * 1000, b.minX, b.width)) }
}
