import XCTest
@testable import ModMove

class PositionSizeCalculationTests: XCTestCase {

    // MARK: - Size Calculation - TopLeft Corner

    func testCalculateDesiredSize_TopLeft_Shrink() {
        let corner = Corner.TopLeft
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: 50, y: 30)  // Moving corner right and down = shrink

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 350, "TopLeft: width should shrink by delta.x (400 - 50 = 350)")
        XCTAssertEqual(result.height, 270, "TopLeft: height should shrink by delta.y (300 - 30 = 270)")
    }

    func testCalculateDesiredSize_TopLeft_Grow() {
        let corner = Corner.TopLeft
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: -50, y: -30)  // Moving corner left and up = grow

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 450, "TopLeft: width should grow by -delta.x (400 - (-50) = 450)")
        XCTAssertEqual(result.height, 330, "TopLeft: height should grow by -delta.y (300 - (-30) = 330)")
    }

    // MARK: - Size Calculation - TopRight Corner

    func testCalculateDesiredSize_TopRight_Grow() {
        let corner = Corner.TopRight
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: 50, y: -30)  // Moving corner right and up

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 450, "TopRight: width should grow by delta.x (400 + 50 = 450)")
        XCTAssertEqual(result.height, 330, "TopRight: height should grow by -delta.y (300 - (-30) = 330)")
    }

    func testCalculateDesiredSize_TopRight_Shrink() {
        let corner = Corner.TopRight
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: -50, y: 30)  // Moving corner left and down

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 350, "TopRight: width should shrink by -delta.x (400 + (-50) = 350)")
        XCTAssertEqual(result.height, 270, "TopRight: height should shrink by delta.y (300 - 30 = 270)")
    }

    // MARK: - Size Calculation - BottomLeft Corner

    func testCalculateDesiredSize_BottomLeft_Grow() {
        let corner = Corner.BottomLeft
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: -50, y: 30)  // Moving corner left and down

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 450, "BottomLeft: width should grow by -delta.x (400 - (-50) = 450)")
        XCTAssertEqual(result.height, 330, "BottomLeft: height should grow by delta.y (300 + 30 = 330)")
    }

    func testCalculateDesiredSize_BottomLeft_Shrink() {
        let corner = Corner.BottomLeft
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: 50, y: -30)  // Moving corner right and up

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 350, "BottomLeft: width should shrink by delta.x (400 - 50 = 350)")
        XCTAssertEqual(result.height, 270, "BottomLeft: height should shrink by -delta.y (300 + (-30) = 270)")
    }

    // MARK: - Size Calculation - BottomRight Corner

    func testCalculateDesiredSize_BottomRight_Grow() {
        let corner = Corner.BottomRight
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: 50, y: 30)  // Moving corner right and down

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 450, "BottomRight: width should grow by delta.x (400 + 50 = 450)")
        XCTAssertEqual(result.height, 330, "BottomRight: height should grow by delta.y (300 + 30 = 330)")
    }

    func testCalculateDesiredSize_BottomRight_Shrink() {
        let corner = Corner.BottomRight
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: -50, y: -30)  // Moving corner left and up

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 350, "BottomRight: width should shrink by -delta.x (400 + (-50) = 350)")
        XCTAssertEqual(result.height, 270, "BottomRight: height should shrink by -delta.y (300 + (-30) = 270)")
    }

    // MARK: - Position Calculation - TopLeft Corner

    func testCalculateResizedPosition_TopLeft_NoSizeConstraint() {
        let corner = Corner.TopLeft
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 350, height: 270)  // Shrunk

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNotNil(result, "TopLeft should return a position")
        XCTAssertEqual(result?.x, 250, "TopLeft: x should move by size difference (200 + (400 - 350) = 250)")
        XCTAssertEqual(result?.y, 130, "TopLeft: y should move by size difference (100 + (300 - 270) = 130)")
    }

    func testCalculateResizedPosition_TopLeft_WithMinSizeConstraint() {
        let corner = Corner.TopLeft
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        // Desired size was smaller, but macOS enforced minimum
        let actualSize = CGSize(width: 200, height: 150)  // Min size constraint

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNotNil(result, "TopLeft should return a position")
        XCTAssertEqual(result?.x, 400, "TopLeft: x should move by actual size difference (200 + (400 - 200) = 400)")
        XCTAssertEqual(result?.y, 250, "TopLeft: y should move by actual size difference (100 + (300 - 150) = 250)")
    }

    // MARK: - Position Calculation - TopRight Corner

    func testCalculateResizedPosition_TopRight() {
        let corner = Corner.TopRight
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 350, height: 270)

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNotNil(result, "TopRight should return a position")
        XCTAssertEqual(result?.x, 200, "TopRight: x should not change (left edge is anchor)")
        XCTAssertEqual(result?.y, 130, "TopRight: y should move by size difference (100 + (300 - 270) = 130)")
    }

    func testCalculateResizedPosition_TopRight_WithMinSizeConstraint() {
        let corner = Corner.TopRight
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 200, height: 150)

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNotNil(result, "TopRight should return a position")
        XCTAssertEqual(result?.x, 200, "TopRight: x should not change")
        XCTAssertEqual(result?.y, 250, "TopRight: y should move by actual size difference")
    }

    // MARK: - Position Calculation - BottomLeft Corner

    func testCalculateResizedPosition_BottomLeft() {
        let corner = Corner.BottomLeft
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 350, height: 270)

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNotNil(result, "BottomLeft should return a position")
        XCTAssertEqual(result?.x, 250, "BottomLeft: x should move by size difference (200 + (400 - 350) = 250)")
        XCTAssertEqual(result?.y, 100, "BottomLeft: y should not change (top edge is anchor)")
    }

    func testCalculateResizedPosition_BottomLeft_WithMinSizeConstraint() {
        let corner = Corner.BottomLeft
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 200, height: 150)

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNotNil(result, "BottomLeft should return a position")
        XCTAssertEqual(result?.x, 400, "BottomLeft: x should move by actual size difference")
        XCTAssertEqual(result?.y, 100, "BottomLeft: y should not change")
    }

    // MARK: - Position Calculation - BottomRight Corner

    func testCalculateResizedPosition_BottomRight() {
        let corner = Corner.BottomRight
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 350, height: 270)

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNil(result, "BottomRight should return nil (no position adjustment needed)")
    }

    func testCalculateResizedPosition_BottomRight_WithMinSizeConstraint() {
        let corner = Corner.BottomRight
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 200, height: 150)

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNil(result, "BottomRight should return nil even with size constraint")
    }

    // MARK: - Edge Cases

    func testCalculateDesiredSize_ZeroDelta() {
        let corner = Corner.TopLeft
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: 0, y: 0)

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        XCTAssertEqual(result.width, 400, "Zero delta should result in same size")
        XCTAssertEqual(result.height, 300, "Zero delta should result in same size")
    }

    func testCalculateDesiredSize_NegativeResult() {
        let corner = Corner.TopLeft
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: 500, y: 400)  // Would result in negative size

        let result = WindowCalculations.calculateDesiredSize(
            corner: corner,
            initialSize: initialSize,
            delta: delta
        )

        // Function should return negative values - macOS will handle min size constraint
        XCTAssertEqual(result.width, -100, "Function allows negative size (OS will constrain)")
        XCTAssertEqual(result.height, -100, "Function allows negative size (OS will constrain)")
    }

    func testCalculateResizedPosition_SizeIncreased() {
        let corner = Corner.TopLeft
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 500, height: 400)  // Grew instead of shrunk

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNotNil(result, "TopLeft should return a position")
        // actualDx = 400 - 500 = -100, so x = 200 + (-100) = 100
        XCTAssertEqual(result?.x, 100, "TopLeft: x should move left when size increases")
        XCTAssertEqual(result?.y, 0, "TopLeft: y should move up when size increases")
    }

    func testCalculateResizedPosition_SameSizeAsInitial() {
        let corner = Corner.TopLeft
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let actualSize = CGSize(width: 400, height: 300)  // Same as initial

        let result = WindowCalculations.calculateResizedWindowPosition(
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            actualSize: actualSize
        )

        XCTAssertNotNil(result, "TopLeft should return a position")
        XCTAssertEqual(result?.x, 200, "Same size should result in same position")
        XCTAssertEqual(result?.y, 100, "Same size should result in same position")
    }

    // MARK: - All Corners Combined Tests

    func testAllCorners_WidthOnlyChange() {
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: 50, y: 0)  // Only width changes

        // TopLeft: width shrinks, left edge moves right
        let tlSize = WindowCalculations.calculateDesiredSize(corner: .TopLeft, initialSize: initialSize, delta: delta)
        XCTAssertEqual(tlSize.width, 350)
        XCTAssertEqual(tlSize.height, 300)

        // TopRight: width grows, left edge stays
        let trSize = WindowCalculations.calculateDesiredSize(corner: .TopRight, initialSize: initialSize, delta: delta)
        XCTAssertEqual(trSize.width, 450)
        XCTAssertEqual(trSize.height, 300)

        // BottomLeft: width shrinks, left edge moves right
        let blSize = WindowCalculations.calculateDesiredSize(corner: .BottomLeft, initialSize: initialSize, delta: delta)
        XCTAssertEqual(blSize.width, 350)
        XCTAssertEqual(blSize.height, 300)

        // BottomRight: width grows, left edge stays
        let brSize = WindowCalculations.calculateDesiredSize(corner: .BottomRight, initialSize: initialSize, delta: delta)
        XCTAssertEqual(brSize.width, 450)
        XCTAssertEqual(brSize.height, 300)
    }

    func testAllCorners_HeightOnlyChange() {
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let delta = CGPoint(x: 0, y: 40)  // Only height changes

        // TopLeft: height shrinks, top edge moves down
        let tlSize = WindowCalculations.calculateDesiredSize(corner: .TopLeft, initialSize: initialSize, delta: delta)
        XCTAssertEqual(tlSize.width, 400)
        XCTAssertEqual(tlSize.height, 260)

        // TopRight: height shrinks, top edge moves down
        let trSize = WindowCalculations.calculateDesiredSize(corner: .TopRight, initialSize: initialSize, delta: delta)
        XCTAssertEqual(trSize.width, 400)
        XCTAssertEqual(trSize.height, 260)

        // BottomLeft: height grows, top edge stays
        let blSize = WindowCalculations.calculateDesiredSize(corner: .BottomLeft, initialSize: initialSize, delta: delta)
        XCTAssertEqual(blSize.width, 400)
        XCTAssertEqual(blSize.height, 340)

        // BottomRight: height grows, top edge stays
        let brSize = WindowCalculations.calculateDesiredSize(corner: .BottomRight, initialSize: initialSize, delta: delta)
        XCTAssertEqual(brSize.width, 400)
        XCTAssertEqual(brSize.height, 340)
    }
}

// MARK: - Resize Orchestration (simulated window server)

/// Simulates the macOS WindowServer behaviors PROBED on macOS 26.5 with two stacked
/// screens (see AGENTS.md). Laws, verified empirically via AX calls on real windows:
/// 1. Size sets are applied faithfully.
/// 2. Position sets are applied ONLY if the resulting rect lies entirely on one screen.
///    Otherwise the window is TELEPORTED somewhere unpredictable (observed: y=31, y=231,
///    snap to the destination screen's edge) -- err is still .success.
final class FakeMacOS26Window: WindowControlling {
    /// Sentinel Y the fake teleports to. Real observed artifacts were y=31, y=231, or a
    /// destination-edge snap; a sentinel makes "an unrepaired teleport leaked to the end
    /// of a frame" trivially detectable in invariants.
    static let teleportY: CGFloat = -7777

    let screens: [NSRect]  // full screen frames, Accessibility coordinates
    let minSize: CGSize    // apps enforce a minimum size (probed: TextEdit 100x82)
    var rect: NSRect
    var teleportCount = 0

    init(rect: NSRect, screens: [NSRect], minSize: CGSize = CGSize(width: 100, height: 82)) {
        self.rect = rect
        self.screens = screens
        self.minSize = minSize
    }

    var position: CGPoint? {
        get { return rect.origin }
        set {
            guard let p = newValue else { return }
            let proposed = NSRect(origin: p, size: rect.size)
            // Sub-pixel tolerance: the real WindowServer doesn't teleport for 1e-13
            // float drift at a screen edge.
            if screens.contains(where: { $0.insetBy(dx: -0.5, dy: -0.5).contains(proposed) }) {
                rect.origin = p
            } else {
                // Straddles displays (or off-desktop): macOS teleports the window.
                teleportCount += 1
                rect.origin = CGPoint(x: p.x, y: FakeMacOS26Window.teleportY)
            }
        }
    }

    var size: CGSize? {
        get { return rect.size }
        set {
            if let s = newValue {
                rect.size = CGSize(width: max(s.width, minSize.width),
                                   height: max(s.height, minSize.height))
            }
        }
    }
}

/// Runs one frame of the REAL production pipeline (constraint frame -> gate -> delta ->
/// desired size -> ResizeFrameApplier) against a fake window, exactly as Mover does.
struct GestureSimulator {
    let screens: [ScreenInfo]
    let primaryHeight: CGFloat

    /// Full screen frames in AX coordinates (what the fake window server checks against).
    var axScreenFrames: [NSRect] {
        return screens.map {
            NSRect(x: $0.frame.minX,
                   y: primaryHeight - $0.frame.maxY,
                   width: $0.frame.width,
                   height: $0.frame.height)
        }
    }

    func runFrame(
        fake: FakeMacOS26Window,
        corner: Corner,
        initialPosition: CGPoint,
        initialSize: CGSize,
        mouseDelta: CGPoint,
        mouseSpeed: CGFloat = 0
    ) {
        let currentPos = fake.position!
        let currentSize = fake.size!
        let currentRect = NSRect(origin: currentPos, size: currentSize)

        let frame = WindowCalculations.resizeConstraintFrame(
            windowRect: NSRect(origin: initialPosition, size: initialSize),
            screens: screens,
            primaryScreenHeight: primaryHeight
        )
        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: mouseSpeed,
            speedThreshold: 1000,
            currentWindowRect: currentRect,
            screenFrame: frame
        )
        let delta = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: frame,
            shouldConstrain: shouldConstrain
        )
        let desired = WindowCalculations.calculateDesiredSize(
            corner: corner, initialSize: initialSize, delta: delta
        )
        let positionSetsAreReliable = WindowCalculations.isEntirelyOnOneScreen(
            windowRect: currentRect,
            screens: screens,
            primaryScreenHeight: primaryHeight
        )
        ResizeFrameApplier.apply(
            window: fake,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            desiredSize: desired,
            currentPosition: currentPos,
            currentSize: currentSize,
            positionSetsAreReliable: positionSetsAreReliable
        )
    }
}

/// Drives the REAL production pipeline (constraint frame -> gate -> delta -> desired size
/// -> ResizeFrameApplier) against the fake window server, frame by frame, exactly as
/// Mover.resizeWindow does.
class ResizeOrchestrationTests: XCTestCase {

    // The user's real screen arrangement (measured):
    // top primary 3008x1692 (menu bar 31px), bottom 1440x900 at x-offset 657.
    let primaryHeight: CGFloat = 1692
    let axScreens = [
        NSRect(x: 0, y: 0, width: 3008, height: 1692),      // top (primary)
        NSRect(x: 657, y: 1692, width: 1440, height: 900),   // bottom
    ]
    let screenInfos = [
        ScreenInfo(frame: NSRect(x: 0, y: 0, width: 3008, height: 1692),
                   visibleFrame: NSRect(x: 0, y: 0, width: 3008, height: 1661),
                   backingScaleFactor: 2),
        ScreenInfo(frame: NSRect(x: 657, y: -900, width: 1440, height: 900),
                   visibleFrame: NSRect(x: 657, y: -900, width: 1440, height: 900),
                   backingScaleFactor: 2),
    ]

    var simulator: GestureSimulator {
        return GestureSimulator(screens: screenInfos, primaryHeight: primaryHeight)
    }

    private func runFrame(
        fake: FakeMacOS26Window,
        corner: Corner,
        initialPosition: CGPoint,
        initialSize: CGSize,
        mouseDelta: CGPoint,
        mouseSpeed: CGFloat = 0
    ) {
        simulator.runFrame(fake: fake, corner: corner,
                           initialPosition: initialPosition, initialSize: initialSize,
                           mouseDelta: mouseDelta, mouseSpeed: mouseSpeed)
    }

    /// THE bug: window at the top edge of the bottom screen, slow drag UP with a top
    /// corner. The window must never be teleported / mangled -- macOS cannot move a
    /// window's origin through the shared-edge strip, so the top edge must stay pinned
    /// and the window must remain exactly usable.
    func testSlowGrowUpAtSharedEdge_WindowIsNeverTeleported() {
        let initPos = CGPoint(x: 800, y: 1692)
        let initSize = CGSize(width: 800, height: 600)
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: axScreens)

        // Slow upward drag, 10px per frame for 10 frames (mouseSpeed 0 = constrained)
        for i in 1...10 {
            runFrame(fake: fake, corner: .TopRight,
                     initialPosition: initPos, initialSize: initSize,
                     mouseDelta: CGPoint(x: 0, y: CGFloat(-10 * i)))
        }

        XCTAssertEqual(fake.teleportCount, 0,
                       "Orchestration must never emit a position the WindowServer teleports")
        XCTAssertEqual(fake.rect.origin.y, 1692,
                       "Top edge must stay pinned at the shared edge (macOS forbids crossing)")
        XCTAssertEqual(fake.rect.size.height, 600,
                       "Height must not change when growth direction is blocked by the shared edge")
    }

    /// Same position, dragging DOWN with a top corner must shrink normally.
    func testSlowShrinkAtSharedEdge_Works() {
        let initPos = CGPoint(x: 800, y: 1692)
        let initSize = CGSize(width: 800, height: 600)
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: axScreens)

        for i in 1...5 {
            runFrame(fake: fake, corner: .TopRight,
                     initialPosition: initPos, initialSize: initSize,
                     mouseDelta: CGPoint(x: 0, y: CGFloat(10 * i)))
        }

        XCTAssertEqual(fake.teleportCount, 0)
        XCTAssertEqual(fake.rect.size.height, 550, "Shrink by 50 should be applied")
        XCTAssertEqual(fake.rect.origin.y, 1742, "Top edge follows the mouse down")
    }

    /// Bottom corner resize at the same spot must work freely within the screen.
    func testSlowGrowDownAtSharedEdge_BottomCorner_Works() {
        let initPos = CGPoint(x: 800, y: 1692)
        let initSize = CGSize(width: 800, height: 600)
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: axScreens)

        for i in 1...5 {
            runFrame(fake: fake, corner: .BottomRight,
                     initialPosition: initPos, initialSize: initSize,
                     mouseDelta: CGPoint(x: 0, y: CGFloat(10 * i)))
        }

        XCTAssertEqual(fake.teleportCount, 0)
        XCTAssertEqual(fake.rect.size.height, 650, "Bottom edge grows down freely")
        XCTAssertEqual(fake.rect.origin.y, 1692)
    }

    /// Fast (unconstrained) drag up: the constraint gate is off, so the applier WILL ask
    /// for a straddling position -- the window server teleports it. The applier must
    /// detect this and repair, leaving the window in a sane state (never at y=31).
    func testFastGrowUpAtSharedEdge_TeleportIsRepaired() {
        let initPos = CGPoint(x: 800, y: 1692)
        let initSize = CGSize(width: 800, height: 600)
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: axScreens)

        runFrame(fake: fake, corner: .TopRight,
                 initialPosition: initPos, initialSize: initSize,
                 mouseDelta: CGPoint(x: 0, y: -50),
                 mouseSpeed: 2000)  // fast: constraints off

        XCTAssertEqual(fake.rect.origin, initPos,
                       "Teleported frame must be rolled back to the pre-frame rect")
        XCTAssertEqual(fake.rect.size, initSize,
                       "Teleported frame must be rolled back to the pre-frame rect")
    }

    /// A window ALREADY straddling two screens (thrown there by a fast move, or
    /// grandfathered — probing showed spanning windows can exist). For such a window
    /// EVERY position set is unreliable — including our repair, whose restore target is
    /// itself a straddling rect. The applier must not emit position sets at all: resize
    /// degrades to size-only, and the window's origin must never move.
    func testStraddlingWindow_ResizeNeverEmitsPositionSets() {
        // Window straddling the shared edge: top half on the top screen.
        let initPos = CGPoint(x: 800, y: 1492)
        let initSize = CGSize(width: 800, height: 600) // y 1492...2092 spans y=1692
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: axScreens)

        for i in 1...8 {
            runFrame(fake: fake, corner: .TopRight,
                     initialPosition: initPos, initialSize: initSize,
                     mouseDelta: CGPoint(x: 0, y: CGFloat(-10 * i)))
        }

        XCTAssertEqual(fake.teleportCount, 0,
                       "No position set may be emitted for a straddling window — all are unreliable")
        XCTAssertEqual(fake.rect.origin, initPos,
                       "Straddling window's origin must never move during resize")
        XCTAssertNotEqual(fake.rect.origin.y, FakeMacOS26Window.teleportY,
                          "Window must never end a frame teleported")
    }
}

// MARK: - Property-based gesture fuzzing

/// Deterministic RNG (SplitMix64) so every generated scenario is reproducible from its
/// seed. Failures print the seed; re-run with that seed to debug.
struct SeededRNG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func int(_ range: ClosedRange<Int>) -> Int {
        return range.lowerBound + Int(next() % UInt64(range.count))
    }
    mutating func cg(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        guard hi > lo else { return lo }
        return lo + CGFloat(Double(next() % 100_000) / 100_000.0) * (hi - lo)
    }
    mutating func chance(_ p: Double) -> Bool {
        return Double(next() % 1000) / 1000.0 < p
    }
}

/// Generates random multi-monitor layouts + windows + resize gestures and checks
/// invariants that must hold for EVERY frame of EVERY gesture:
///
///  I1. A frame never ends with the window teleported (sentinel position).
///  I2. The window never shrinks below the app's minimum size.
///  I3. Slow (constrained) gestures never emit a single teleporting position set, and the
///      window stays within its screen's visible frame.
///  I4. The anchor corner (opposite the grabbed corner) never drifts - for any speed -
///      as long as the window started fully on one screen.
class ResizePropertyTests: XCTestCase {

    private func makeLayout(_ rng: inout SeededRNG) -> (screens: [ScreenInfo], primaryHeight: CGFloat) {
        let pw = CGFloat(rng.int(1600...3200))
        let ph = CGFloat(rng.int(900...1800))
        let primary = ScreenInfo(
            frame: NSRect(x: 0, y: 0, width: pw, height: ph),
            visibleFrame: NSRect(x: 0, y: 0, width: pw, height: ph - 25), // menu bar
            backingScaleFactor: 2
        )
        let kind = rng.int(0...3)
        if kind == 0 { return ([primary], ph) } // single screen

        let sw = min(CGFloat(rng.int(1000...2000)), pw)
        let sh = CGFloat(rng.int(700...1200))
        let secFrame: NSRect
        switch kind {
        case 1: // stacked BELOW primary (the user's real arrangement), random x offset
            secFrame = NSRect(x: rng.cg(0, pw - sw), y: -sh, width: sw, height: sh)
        case 2: // stacked ABOVE primary
            secFrame = NSRect(x: rng.cg(0, pw - sw), y: ph, width: sw, height: sh)
        default: // side by side, RIGHT of primary, random y offset
            secFrame = NSRect(x: pw, y: rng.cg(-sh / 2, ph - sh / 2), width: sw, height: sh)
        }
        let secondary = ScreenInfo(frame: secFrame, visibleFrame: secFrame, backingScaleFactor: 2)
        return ([primary, secondary], ph)
    }

    private func anchorPoint(_ corner: Corner, _ rect: NSRect) -> CGPoint {
        switch corner {
        case .TopLeft: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .TopRight: return CGPoint(x: rect.minX, y: rect.maxY)
        case .BottomLeft: return CGPoint(x: rect.maxX, y: rect.minY)
        case .BottomRight: return CGPoint(x: rect.minX, y: rect.minY)
        }
    }

    func testRandomGestures_InvariantsHold() {
        let corners: [Corner] = [.TopLeft, .TopRight, .BottomLeft, .BottomRight]

        for seed in 0..<400 {
            var rng = SeededRNG(state: UInt64(seed))
            let (screens, primaryHeight) = makeLayout(&rng)
            let sim = GestureSimulator(screens: screens, primaryHeight: primaryHeight)

            // Place a window fully within a random screen's visible frame.
            let screen = screens[rng.int(0...(screens.count - 1))]
            let vis = WindowCalculations.accessibilityVisibleFrame(for: screen, primaryScreenHeight: primaryHeight)
            let w = rng.cg(200, min(700, vis.width))
            let h = rng.cg(150, min(500, vis.height))
            let initPos = CGPoint(x: rng.cg(vis.minX, vis.maxX - w), y: rng.cg(vis.minY, vis.maxY - h))
            let initSize = CGSize(width: w, height: h)
            let initRect = NSRect(origin: initPos, size: initSize)

            let fake = FakeMacOS26Window(rect: initRect, screens: sim.axScreenFrames)
            let corner = corners[rng.int(0...3)]
            let speed: CGFloat = rng.chance(0.15) ? 2000 : 0  // 15% fast gestures
            let initialAnchor = anchorPoint(corner, initRect)

            // Random-walk gesture: cumulative mouse delta over 12 frames.
            var total = CGPoint.zero
            for frame in 1...12 {
                total.x += rng.cg(-70, 70)
                total.y += rng.cg(-70, 70)
                sim.runFrame(fake: fake, corner: corner,
                             initialPosition: initPos, initialSize: initSize,
                             mouseDelta: total, mouseSpeed: speed)

                let ctx = "seed=\(seed) frame=\(frame) corner=\(corner) speed=\(speed) init=\(initRect) delta=\(total) rect=\(fake.rect)"

                // I1: never end a frame teleported
                XCTAssertNotEqual(fake.rect.origin.y, FakeMacOS26Window.teleportY,
                                  "I1 unrepaired teleport: \(ctx)")
                // I2: never below the app minimum size
                XCTAssertGreaterThanOrEqual(fake.rect.width, fake.minSize.width - 0.5, "I2: \(ctx)")
                XCTAssertGreaterThanOrEqual(fake.rect.height, fake.minSize.height - 0.5, "I2: \(ctx)")
                // I3: slow gestures are fully constrained - zero teleports, window on screen
                if speed < 1000 {
                    XCTAssertEqual(fake.teleportCount, 0, "I3 teleporting set emitted: \(ctx)")
                    XCTAssertTrue(vis.insetBy(dx: -0.5, dy: -0.5).contains(fake.rect),
                                  "I3 window left its screen's visible frame: \(ctx)")
                }
                // I4: the anchor corner never drifts (any speed; on-screen start)
                let anchor = anchorPoint(corner, fake.rect)
                XCTAssertEqual(anchor.x, initialAnchor.x, accuracy: 0.5, "I4 anchor drift: \(ctx)")
                XCTAssertEqual(anchor.y, initialAnchor.y, accuracy: 0.5, "I4 anchor drift: \(ctx)")
            }
        }
    }

    /// Straddling starts. Frame-local contract:
    ///  - While the window straddles two screens, resize is size-only: the origin must not
    ///    move and no (teleportable) position set may be emitted.
    ///  - If a gesture shrinks the window back onto ONE screen, normal resizing (with
    ///    position sets and teleport-repair) legitimately resumes.
    ///  - At no point may a frame end teleported or below the app's minimum size.
    func testRandomGestures_StraddlingStart_OriginFrozen() {
        let corners: [Corner] = [.TopLeft, .TopRight, .BottomLeft, .BottomRight]

        for seed in 1000..<1150 {
            var rng = SeededRNG(state: UInt64(seed))
            // The user's real layout, window straddling the shared edge at y=1692.
            let screens = [
                ScreenInfo(frame: NSRect(x: 0, y: 0, width: 3008, height: 1692),
                           visibleFrame: NSRect(x: 0, y: 0, width: 3008, height: 1661),
                           backingScaleFactor: 2),
                ScreenInfo(frame: NSRect(x: 657, y: -900, width: 1440, height: 900),
                           visibleFrame: NSRect(x: 657, y: -900, width: 1440, height: 900),
                           backingScaleFactor: 2),
            ]
            let sim = GestureSimulator(screens: screens, primaryHeight: 1692)
            let h = rng.cg(200, 600)
            let initPos = CGPoint(x: rng.cg(657, 2097 - 500), y: 1692 - rng.cg(50, h - 50))
            let initSize = CGSize(width: rng.cg(300, 500), height: h)
            let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize),
                                         screens: sim.axScreenFrames)
            let corner = corners[rng.int(0...3)]
            let speed: CGFloat = rng.chance(0.3) ? 2000 : 0

            func onOneScreen(_ rect: NSRect) -> Bool {
                return sim.axScreenFrames.contains { $0.insetBy(dx: -0.5, dy: -0.5).contains(rect) }
            }

            var total = CGPoint.zero
            var prevRect = fake.rect
            var prevTeleports = 0
            for frame in 1...8 {
                total.x += rng.cg(-70, 70)
                total.y += rng.cg(-70, 70)
                let wasStraddling = !onOneScreen(prevRect)
                sim.runFrame(fake: fake, corner: corner,
                             initialPosition: initPos, initialSize: initSize,
                             mouseDelta: total, mouseSpeed: speed)

                let ctx = "seed=\(seed) frame=\(frame) corner=\(corner) rect=\(fake.rect)"
                // Never end a frame teleported; never below min size.
                XCTAssertNotEqual(fake.rect.origin.y, FakeMacOS26Window.teleportY,
                                  "unrepaired teleport: \(ctx)")
                XCTAssertGreaterThanOrEqual(fake.rect.height, fake.minSize.height - 0.5, ctx)
                XCTAssertGreaterThanOrEqual(fake.rect.width, fake.minSize.width - 0.5, ctx)
                if wasStraddling {
                    // Size-only regime: origin frozen, zero position sets emitted.
                    XCTAssertEqual(fake.rect.origin, prevRect.origin,
                                   "straddling origin moved: \(ctx)")
                    XCTAssertEqual(fake.teleportCount, prevTeleports,
                                   "straddling window got a position set: \(ctx)")
                }
                prevRect = fake.rect
                prevTeleports = fake.teleportCount
            }
        }
    }
}

// MARK: - Deterministic edge cases (user's real layout)

class ResizeEdgeCaseTests: XCTestCase {
    // The user's measured arrangement.
    let screens = [
        ScreenInfo(frame: NSRect(x: 0, y: 0, width: 3008, height: 1692),
                   visibleFrame: NSRect(x: 0, y: 0, width: 3008, height: 1661),
                   backingScaleFactor: 2),
        ScreenInfo(frame: NSRect(x: 657, y: -900, width: 1440, height: 900),
                   visibleFrame: NSRect(x: 657, y: -900, width: 1440, height: 900),
                   backingScaleFactor: 2),
    ]
    var sim: GestureSimulator { return GestureSimulator(screens: screens, primaryHeight: 1692) }

    /// Growing into the bottom-right corner of the bottom screen pins BOTH axes at the
    /// outer walls (x=2097, y=2592).
    func testGrowIntoScreenCorner_PinsBothAxes() {
        let initPos = CGPoint(x: 1800, y: 2200)
        let initSize = CGSize(width: 250, height: 300)
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: sim.axScreenFrames)

        sim.runFrame(fake: fake, corner: .BottomRight,
                     initialPosition: initPos, initialSize: initSize,
                     mouseDelta: CGPoint(x: 200, y: 200))

        XCTAssertEqual(fake.rect.origin, initPos)
        XCTAssertEqual(fake.rect.width, 297, "width capped at right wall: 2097 - 1800")
        XCTAssertEqual(fake.rect.height, 392, "height capped at bottom wall: 2592 - 2200")
        XCTAssertEqual(fake.teleportCount, 0)
    }

    /// A window filling the full height of the bottom screen (the Slack case): a top-corner
    /// upward drag can go nowhere - shared edge above, screen bottom below. Must be a no-op.
    func testFullHeightWindow_TopCornerDragUp_IsNoOp() {
        let initPos = CGPoint(x: 757, y: 1692)
        let initSize = CGSize(width: 1200, height: 900) // full screen height
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: sim.axScreenFrames)

        for i in 1...6 {
            sim.runFrame(fake: fake, corner: .TopLeft,
                         initialPosition: initPos, initialSize: initSize,
                         mouseDelta: CGPoint(x: 0, y: CGFloat(-50 * i)))
        }

        XCTAssertEqual(fake.rect, NSRect(origin: initPos, size: initSize), "must be a perfect no-op")
        XCTAssertEqual(fake.teleportCount, 0)
    }

    /// Drag up (pinned), then reverse down: the window must track the mouse's TOTAL delta,
    /// not accumulate error from the pinned phase.
    func testDragUpThenDown_TracksTotalDelta() {
        let initPos = CGPoint(x: 800, y: 1692)
        let initSize = CGSize(width: 800, height: 600)
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: sim.axScreenFrames)

        // Up 100 (pinned at shared edge), then net +80 below start.
        for delta in [-50, -100, -40, 20, 80] {
            sim.runFrame(fake: fake, corner: .TopRight,
                         initialPosition: initPos, initialSize: initSize,
                         mouseDelta: CGPoint(x: 0, y: CGFloat(delta)))
        }

        XCTAssertEqual(fake.rect.origin.y, 1772, "top edge ends at initial + 80")
        XCTAssertEqual(fake.rect.height, 520, "height ends at initial - 80")
        XCTAssertEqual(fake.teleportCount, 0)
    }

    /// Mixed-axis resize (grow width while shrinking height in the same frame — a normal
    /// diagonal drag). Found by gesture fuzzing (seed 29): the deliberate height shrink
    /// misfired the catastrophic-clamp check, triggering a bogus rollback that emitted an
    /// off-screen transient position (a teleporting set). Must apply cleanly instead.
    func testMixedGrowWidthShrinkHeight_AppliesCleanly() {
        let initPos = CGPoint(x: 1400, y: 300) // on the top (primary) screen
        let initSize = CGSize(width: 300, height: 400)
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: sim.axScreenFrames)

        sim.runFrame(fake: fake, corner: .TopLeft,
                     initialPosition: initPos, initialSize: initSize,
                     mouseDelta: CGPoint(x: -30, y: 90)) // left = grow width, down = shrink height

        XCTAssertEqual(fake.teleportCount, 0, "mixed-axis resize must not emit teleporting sets")
        XCTAssertEqual(fake.rect, NSRect(x: 1370, y: 390, width: 330, height: 310),
                       "both axes track the mouse; anchor (bottom-right) fixed")
    }

    /// Shrinking far past the app's minimum size (desired height would be NEGATIVE): size
    /// clamps at the minimum and the anchor corner must still not move.
    func testShrinkPastMinimum_AnchorPreserved() {
        let initPos = CGPoint(x: 800, y: 1800)
        let initSize = CGSize(width: 400, height: 300)
        let fake = FakeMacOS26Window(rect: NSRect(origin: initPos, size: initSize), screens: sim.axScreenFrames)

        sim.runFrame(fake: fake, corner: .TopLeft,
                     initialPosition: initPos, initialSize: initSize,
                     mouseDelta: CGPoint(x: 350, y: 380)) // desired: 50 x -80

        XCTAssertEqual(fake.rect.size, CGSize(width: 100, height: 82), "clamped at app minimum")
        // Anchor = initial bottom-right corner (1200, 2100)
        XCTAssertEqual(fake.rect.maxX, 1200, "anchor X preserved at minimum size")
        XCTAssertEqual(fake.rect.maxY, 2100, "anchor Y preserved at minimum size")
        XCTAssertEqual(fake.teleportCount, 0)
    }
}
