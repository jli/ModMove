import XCTest
@testable import ModMove

/// Tests for converting between NSScreen coordinates and Accessibility coordinates,
/// and for picking the correct physical screen for a window.
///
/// The critical case is a multi-monitor setup with "Displays have separate Spaces"
/// DISABLED, where a secondary screen is stacked ABOVE the primary screen. In that
/// arrangement the Accessibility origin remains the top-left of the primary screen,
/// so the top screen occupies NEGATIVE Accessibility Y values.
class ScreenCoordinateTests: XCTestCase {

    // MARK: - Y Conversion

    func testNsYToAccessibilityY_PrimaryTop() {
        // Primary screen 1080 tall. Top of primary (nsY = 1080) is AX y = 0.
        let axTop = WindowCalculations.nsYToAccessibilityY(nsY: 1080, primaryScreenHeight: 1080)
        XCTAssertEqual(axTop, 0)
        // Bottom of primary (nsY = 0) is AX y = 1080.
        let axBottom = WindowCalculations.nsYToAccessibilityY(nsY: 0, primaryScreenHeight: 1080)
        XCTAssertEqual(axBottom, 1080)
    }

    func testNsYToAccessibilityY_ScreenAbovePrimary_IsNegative() {
        // A screen stacked above the primary has nsY greater than primary height,
        // so its AX Y is negative.
        let axTopOfUpperScreen = WindowCalculations.nsYToAccessibilityY(nsY: 2160, primaryScreenHeight: 1080)
        XCTAssertEqual(axTopOfUpperScreen, -1080)
    }

    // MARK: - Screen Lookup: vertical stack, top screen above primary

    /// Primary (bottom) screen: 1920x1080 at NS origin (0,0).
    /// Top screen: 1920x1080 stacked above, NS frame (0, 1080, 1920, 1080).
    private func verticalStackScreens() -> [ScreenInfo] {
        let primary = ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1055), // dock at bottom
            backingScaleFactor: 2
        )
        let top = ScreenInfo(
            frame: NSRect(x: 0, y: 1080, width: 1920, height: 1080),
            visibleFrame: NSRect(x: 0, y: 1080, width: 1920, height: 1055), // menu bar at top
            backingScaleFactor: 2
        )
        return [primary, top]
    }

    func testFindUsableScreen_WindowOnPrimary() {
        // Window near the top-left of the primary screen: AX y around 10.
        let result = WindowCalculations.findUsableScreen(
            windowPosition: CGPoint(x: 100, y: 10),
            screens: verticalStackScreens(),
            primaryScreenHeight: 1080
        )
        XCTAssertNotNil(result)
        // Primary visible frame in AX coords: nsY visibleFrame.maxY = 1055 -> AX 1080-1055 = 25.
        XCTAssertEqual(result?.frame.minY, 25)
        XCTAssertEqual(result?.frame.height, 1055)
    }

    func testFindUsableScreen_WindowOnTopScreen() {
        // Window on the top (upper) screen lives at NEGATIVE AX Y.
        // Top screen spans AX y from -1080 (its top) to 0 (its bottom).
        let result = WindowCalculations.findUsableScreen(
            windowPosition: CGPoint(x: 100, y: -500),
            screens: verticalStackScreens(),
            primaryScreenHeight: 1080
        )
        XCTAssertNotNil(result)
        // Top screen visible frame in AX coords:
        // visibleFrame.maxY = 2135 -> AX 1080 - 2135 = -1055.
        XCTAssertEqual(result?.frame.minY, -1055)
        XCTAssertEqual(result?.frame.height, 1055)
    }

    func testFindUsableScreen_BottomRightOfTopScreen() {
        // The reported bug: Ghostty at bottom-right corner of the TOP screen.
        // Bottom-right of the top screen is near AX y = 0 (just above the primary),
        // x near the right edge.
        let result = WindowCalculations.findUsableScreen(
            windowPosition: CGPoint(x: 1900, y: -20),
            screens: verticalStackScreens(),
            primaryScreenHeight: 1080
        )
        XCTAssertNotNil(result)
        // Must resolve to the TOP screen, not the primary.
        XCTAssertEqual(result?.frame.minY, -1055)
    }

    func testFindUsableScreen_PositionOffAllScreens_ReturnsNil() {
        let result = WindowCalculations.findUsableScreen(
            windowPosition: CGPoint(x: 5000, y: 5000),
            screens: verticalStackScreens(),
            primaryScreenHeight: 1080
        )
        XCTAssertNil(result)
    }

    // MARK: - Regression: old globalMaxY logic picked the wrong screen

    func testFindUsableScreen_TopScreenNotConfusedWithPrimary() {
        // With the buggy globalMaxY approach, both screens converted to the SAME
        // positive AX Y range (0..1080), so a window on the top screen was resolved
        // against the primary's usable frame -> wrong boundary -> "sinking".
        // Verify the top and primary now resolve to different frames.
        let screens = verticalStackScreens()
        let onPrimary = WindowCalculations.findUsableScreen(
            windowPosition: CGPoint(x: 100, y: 500),
            screens: screens,
            primaryScreenHeight: 1080
        )
        let onTop = WindowCalculations.findUsableScreen(
            windowPosition: CGPoint(x: 100, y: -500),
            screens: screens,
            primaryScreenHeight: 1080
        )
        XCTAssertNotNil(onPrimary)
        XCTAssertNotNil(onTop)
        XCTAssertNotEqual(onPrimary?.frame.minY, onTop?.frame.minY)
    }
}
