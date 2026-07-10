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

    // MARK: - Desktop bounding frame (multi-screen constraints)

    func testDesktopBoundingFrame_VerticalStack_SpansBothScreens() {
        // The constraining frame for a stacked setup must cover BOTH screens so the
        // shared edge between them is interior (not a wall).
        let frame = WindowCalculations.desktopBoundingFrame(
            screens: verticalStackScreens(),
            primaryScreenHeight: 1080
        )
        XCTAssertEqual(frame.minY, -1055, "Top of desktop = top screen's visible top")
        XCTAssertEqual(frame.maxY, 1080, "Bottom of desktop = primary screen's visible bottom")
        XCTAssertEqual(frame.minX, 0)
        XCTAssertEqual(frame.maxX, 1920)
    }

    func testDesktopBoundingFrame_SingleScreen_EqualsThatScreen() {
        let single = [ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: NSRect(x: 0, y: 23, width: 1920, height: 1057), // menu bar at top
            backingScaleFactor: 2
        )]
        let frame = WindowCalculations.desktopBoundingFrame(screens: single, primaryScreenHeight: 1080)
        // visibleFrame.maxY = 1080 -> AX minY = 0; height 1057.
        XCTAssertEqual(frame.minY, 0)
        XCTAssertEqual(frame.height, 1057)
    }

    // MARK: - Resize constraint frame depends on "Displays have separate Spaces"

    func testResizeConstraintFrame_UsesSingleContainingScreen() {
        // Resizes always constrain to the single screen containing the window: the
        // WindowServer teleports windows whose origin is set into the strip straddling
        // two displays (probed on macOS 26.5), so shared edges are real walls for resize.
        let frame = WindowCalculations.resizeConstraintFrame(
            windowRect: NSRect(x: 100, y: 500, width: 400, height: 300), // on primary (bottom) screen
            screens: verticalStackScreens(),
            primaryScreenHeight: 1080
        )
        XCTAssertEqual(frame.minY, 25, "Should be the primary screen's visible frame only")
        XCTAssertEqual(frame.height, 1055)
    }

    func testResizeConstraintFrame_WindowOnTopScreen_UsesTopScreen() {
        let frame = WindowCalculations.resizeConstraintFrame(
            windowRect: NSRect(x: 100, y: -500, width: 400, height: 300),
            screens: verticalStackScreens(),
            primaryScreenHeight: 1080
        )
        XCTAssertEqual(frame.minY, -1055)
        XCTAssertEqual(frame.maxY, 0)
    }

    // MARK: - Overlap-based screen selection

    /// TOP screen is the primary (menu bar, NS origin (0,0)) and is listed FIRST — the
    /// ordering that made point-based lookup pick the wrong screen for a window whose
    /// origin sits exactly on the shared edge.
    /// AX coords: top screen y ∈ [0, 1080] (visible [25, 1080]), bottom screen y ∈ [1080, 2160].
    private func stackWithTopPrimaryListedFirst() -> [ScreenInfo] {
        let topPrimary = ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: NSRect(x: 0, y: 0, width: 1920, height: 1055), // menu bar at top
            backingScaleFactor: 2
        )
        let bottom = ScreenInfo(
            frame: NSRect(x: 0, y: -1080, width: 1920, height: 1080),
            visibleFrame: NSRect(x: 0, y: -1080, width: 1920, height: 1080),
            backingScaleFactor: 2
        )
        return [topPrimary, bottom]
    }

    func testScreenContaining_WindowFullyOnOneScreen() {
        let result = WindowCalculations.screenContaining(
            windowRect: NSRect(x: 100, y: 200, width: 400, height: 300), // on top (primary) screen
            screens: stackWithTopPrimaryListedFirst(),
            primaryScreenHeight: 1080
        )
        XCTAssertEqual(result?.frame.minY, 25, "Should pick the top (primary) screen")
    }

    func testScreenContaining_OriginExactlyOnSharedEdge_PicksScreenWithWindowBody() {
        // THE half-height regression. Window at the top edge of the bottom screen: its
        // origin y == 1080 is contained by BOTH screens' closed ranges, and point-based
        // lookup returned whichever screen is listed first (the top one). The window's
        // BODY (y 1080...1680) is 100% on the bottom screen — selection must be unambiguous.
        let result = WindowCalculations.screenContaining(
            windowRect: NSRect(x: 100, y: 1080, width: 800, height: 600),
            screens: stackWithTopPrimaryListedFirst(),
            primaryScreenHeight: 1080
        )
        XCTAssertEqual(result?.frame.minY, 1080, "Must pick the BOTTOM screen (window body), not the first-listed top screen")
        XCTAssertEqual(result?.frame.height, 1080)
    }

    func testScreenContaining_StraddlingWindow_PicksLargerOverlap() {
        // Window straddling the shared edge, 2/3 of it on the bottom screen.
        let result = WindowCalculations.screenContaining(
            windowRect: NSRect(x: 100, y: 880, width: 800, height: 600), // 200px above edge, 400px below
            screens: stackWithTopPrimaryListedFirst(),
            primaryScreenHeight: 1080
        )
        XCTAssertEqual(result?.frame.minY, 1080, "Should pick the screen with the larger overlap")
    }

    func testScreenContaining_OffDesktop_ReturnsNil() {
        let result = WindowCalculations.screenContaining(
            windowRect: NSRect(x: 5000, y: 5000, width: 400, height: 300),
            screens: stackWithTopPrimaryListedFirst(),
            primaryScreenHeight: 1080
        )
        XCTAssertNil(result)
    }

    // MARK: - End-to-end regression: "snaps to half height" at the shared edge

    func testResizeAtSharedEdge_BottomCornerDelta_NotYanked() {
        // Window at the top edge of the bottom screen, height 600. With the WRONG screen
        // selected (top screen, maxY = shared edge = 1080), the bottom-corner cap was
        //   min(dy, 1080 - (1080 + 600)) = -600
        // which FORCED desiredHeight to 0 regardless of the mouse; macOS then clamped to
        // the app's minimum height ("snaps to half height").
        let screens = stackWithTopPrimaryListedFirst()
        let windowRect = NSRect(x: 100, y: 1080, width: 800, height: 600)

        // 1. Overlap-based selection returns the BOTTOM screen.
        let frame = WindowCalculations.resizeConstraintFrame(
            windowRect: windowRect,
            screens: screens,
            primaryScreenHeight: 1080
        )
        XCTAssertEqual(frame.minY, 1080)
        XCTAssertEqual(frame.maxY, 2160)

        // 2. The window is inside that frame, so slow resizes constrain normally...
        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: 0,
            speedThreshold: 1000,
            currentWindowRect: windowRect,
            screenFrame: frame
        )
        XCTAssertTrue(shouldConstrain)

        // ...and a small bottom-corner drag passes through un-yanked.
        let delta = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: CGPoint(x: 0, y: 40),
            corner: .BottomRight,
            initialPosition: windowRect.origin,
            initialSize: windowRect.size,
            screenFrame: frame,
            shouldConstrain: shouldConstrain
        )
        XCTAssertEqual(delta.y, 40, "Small resize must track the mouse, not be forced to -height")
    }

    func testResizeAtSharedEdge_EvenWithWrongFrame_ConstraintGateRefusesToYank() {
        // Belt and suspenders: even if screen selection ever regresses to the top screen,
        // the containment gate must refuse to constrain (the window isn't inside that
        // frame), so the caps can never force a huge delta again.
        let wrongFrame = NSRect(x: 0, y: 25, width: 1920, height: 1055) // top screen's visible frame
        let windowRect = NSRect(x: 100, y: 1080, width: 800, height: 600)

        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: 0,
            speedThreshold: 1000,
            currentWindowRect: windowRect,
            screenFrame: wrongFrame
        )
        XCTAssertFalse(shouldConstrain, "A window outside the constraint frame must never be yanked")

        let delta = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: CGPoint(x: 0, y: 40),
            corner: .BottomRight,
            initialPosition: windowRect.origin,
            initialSize: windowRect.size,
            screenFrame: wrongFrame,
            shouldConstrain: shouldConstrain
        )
        XCTAssertEqual(delta.y, 40)
    }

    // MARK: - Clamp detection

    func testSizeFellShort_DetectsClampedHeight() {
        XCTAssertTrue(WindowCalculations.sizeFellShort(
            of: CGSize(width: 400, height: 350),
            actual: CGSize(width: 400, height: 25), // WindowServer clamped at a screen edge
            epsilon: 0.1
        ))
    }

    func testSizeFellShort_FalseWhenSizeApplied() {
        XCTAssertFalse(WindowCalculations.sizeFellShort(
            of: CGSize(width: 400, height: 350),
            actual: CGSize(width: 400, height: 350),
            epsilon: 0.1
        ))
    }

    // MARK: - Moves may cross shared edges (desktop frame); resizes may not

    func testMoveAcrossSharedEdge_DesktopFrameAllowsIt() {
        // MOVES use the desktop bounding frame: a slow drag from the bottom screen toward
        // the top screen is not walled at the shared edge (the WindowServer snaps the
        // window onto the destination screen — that's how cross-screen moves work).
        let desktop = WindowCalculations.desktopBoundingFrame(
            screens: verticalStackScreens(),
            primaryScreenHeight: 1080
        )
        let result = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: CGPoint(x: 0, y: -600),
            initialPosition: CGPoint(x: 100, y: 200),
            windowSize: CGSize(width: 400, height: 300),
            screenFrame: desktop,
            shouldConstrain: true
        )
        XCTAssertEqual(result.y, -600, "Move toward the screen above must not be walled at the shared edge")
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
