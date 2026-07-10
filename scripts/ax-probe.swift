import AppKit
import ApplicationServices

func winOf(app: String) -> AXUIElement? {
    guard let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == app }) else { return nil }
    let ax = AXUIElementCreateApplication(running.processIdentifier)
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &v) == .success,
          let arr = v as? [AXUIElement] else { return nil }
    for w in arr {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(w, kAXSubroleAttribute as CFString, &role)
        if (role as? String) == "AXStandardWindow" { return w }
    }
    return arr.first
}
func getP(_ w: AXUIElement) -> CGPoint { var v: CFTypeRef?; AXUIElementCopyAttributeValue(w, kAXPositionAttribute as CFString, &v); var p = CGPoint.zero; AXValueGetValue(v as! AXValue, .cgPoint, &p); return p }
func getS(_ w: AXUIElement) -> CGSize { var v: CFTypeRef?; AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &v); var s = CGSize.zero; AXValueGetValue(v as! AXValue, .cgSize, &s); return s }
@discardableResult func setP(_ w: AXUIElement, _ p: CGPoint) -> AXError { var p = p; let v = AXValueCreate(.cgPoint, &p)!; return AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, v) }
@discardableResult func setS(_ w: AXUIElement, _ s: CGSize) -> AXError { var s = s; let v = AXValueCreate(.cgSize, &s)!; return AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, v) }

guard let w = winOf(app: "TextEdit") else { print("no window"); exit(1) }
func report(_ label: String, _ e1: AXError = .success, _ e2: AXError = .success) {
    usleep(250000)
    print("\(label): pos=\(getP(w)) size=\(getS(w)) err=(\(e1.rawValue),\(e2.rawValue))")
}

// Baseline: top edge of bottom screen (shared edge y=1692), x=800
report("B0", setP(w, CGPoint(x: 800, y: 1692)), setS(w, CGSize(width: 800, height: 600)))

// E1: position-first cross edge by 50, then grow
report("E1a setP y=1642", setP(w, CGPoint(x: 800, y: 1642)))
report("E1b setS h=650", setS(w, CGSize(width: 800, height: 650)))

report("R1 reset", setP(w, CGPoint(x: 800, y: 1692)), setS(w, CGSize(width: 800, height: 600)))

// E2: size-first grow down, then position up (current order)
report("E2a setS h=650", setS(w, CGSize(width: 800, height: 650)))
report("E2b setP y=1642", setP(w, CGPoint(x: 800, y: 1642)))

// E3: grow again while (possibly) spanning
report("E3a setS h=660", setS(w, CGSize(width: 800, height: 660)))
report("E3b setP y=1632", setP(w, CGPoint(x: 800, y: 1632)))

report("R2 reset", setP(w, CGPoint(x: 800, y: 1692)), setS(w, CGSize(width: 800, height: 600)))

// E4: single-step small: mimic one 20ms frame: size+2 then pos-2
report("E4a setS h=602", setS(w, CGSize(width: 800, height: 602)))
report("E4b setP y=1690", setP(w, CGPoint(x: 800, y: 1690)))

// E5: min size probe
report("E5 setS 100x10", setS(w, CGSize(width: 100, height: 10)))

// ---------------------------------------------------------------------------
// Diagnostic probe for macOS WindowServer AX behavior (run: swift scripts/ax-probe.swift)
// Requires a TextEdit document window and Accessibility permission for the terminal.
//
// Findings on macOS 26.5 (2026-07-08), two stacked displays, separate Spaces DISABLED:
// - Size sets are applied faithfully (clamped to the app's min size).
// - Position sets whose rect would STRADDLE two displays are NOT applied faithfully:
//   the window TELEPORTS (observed: bounce to y=31 / y=231 on the origin screen, or a
//   snap to the destination screen's edge). AXError is still .success.
// - Position sets fully on ANOTHER screen also bounce unpredictably.
// - Only same-screen position sets are reliable.
// => Resize must treat shared screen edges as hard walls and verify position sets.
// ---------------------------------------------------------------------------
