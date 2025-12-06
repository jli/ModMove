import XCTest
@testable import ModMove

class SpeedBasedBehaviorTests: XCTestCase {

    let speedThreshold: CGFloat = 1000  // pixels/second

    // MARK: - Movement Constraint Decision

    func testSlowMovement_WindowInside_ShouldConstrain() {
        let mouseSpeed: CGFloat = 500  // Below threshold
        let currentWindowRect = NSRect(x: 100, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertTrue(shouldConstrain, "Slow movement with window inside should constrain")
    }

    func testFastMovement_WindowInside_ShouldNotConstrain() {
        let mouseSpeed: CGFloat = 1500  // Above threshold
        let currentWindowRect = NSRect(x: 100, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Fast movement should not constrain regardless of position")
    }

    func testSlowMovement_WindowOutside_ShouldNotConstrain() {
        let mouseSpeed: CGFloat = 500  // Below threshold
        // Window partially outside screen bounds
        let currentWindowRect = NSRect(x: -50, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Slow movement with window outside should not constrain (already escaped)")
    }

    func testFastMovement_WindowOutside_ShouldNotConstrain() {
        let mouseSpeed: CGFloat = 1500  // Above threshold
        // Window partially outside screen bounds
        let currentWindowRect = NSRect(x: -50, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Fast movement should never constrain")
    }

    func testExactThresholdSpeed_ShouldNotConstrain() {
        let mouseSpeed: CGFloat = 1000  // Exactly at threshold
        let currentWindowRect = NSRect(x: 100, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Movement at exact threshold should not constrain (speed >= threshold)")
    }

    func testJustBelowThresholdSpeed_ShouldConstrain() {
        let mouseSpeed: CGFloat = 999.9  // Just below threshold
        let currentWindowRect = NSRect(x: 100, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertTrue(shouldConstrain, "Movement just below threshold should constrain if window inside")
    }

    // MARK: - Window Inside/Outside Detection

    func testWindowCompletelyInside() {
        let mouseSpeed: CGFloat = 500
        let currentWindowRect = NSRect(x: 100, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertTrue(shouldConstrain, "Window completely inside should be detected correctly")
    }

    func testWindowTouchingLeftEdge() {
        let mouseSpeed: CGFloat = 500
        let currentWindowRect = NSRect(x: 0, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertTrue(shouldConstrain, "Window touching left edge is still inside")
    }

    func testWindowTouchingTopEdge() {
        let mouseSpeed: CGFloat = 500
        let currentWindowRect = NSRect(x: 100, y: 23, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertTrue(shouldConstrain, "Window touching top edge is still inside")
    }

    func testWindowPartiallyOffLeftEdge() {
        let mouseSpeed: CGFloat = 500
        let currentWindowRect = NSRect(x: -50, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Window partially off left edge is outside")
    }

    func testWindowPartiallyOffRightEdge() {
        let mouseSpeed: CGFloat = 500
        let currentWindowRect = NSRect(x: 1700, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Window partially off right edge is outside (1700 + 400 = 2100 > 1920)")
    }

    func testWindowPartiallyOffTopEdge() {
        let mouseSpeed: CGFloat = 500
        let currentWindowRect = NSRect(x: 100, y: 0, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Window partially off top edge is outside (y=0 < frame.minY=23)")
    }

    func testWindowPartiallyOffBottomEdge() {
        let mouseSpeed: CGFloat = 500
        let currentWindowRect = NSRect(x: 100, y: 900, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Window partially off bottom edge is outside (900 + 300 = 1200 > 1080)")
    }

    // MARK: - Resize Constraint Decision

    func testResizeSlowSpeed_ShouldConstrain() {
        let mouseSpeed: CGFloat = 500  // Below threshold

        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold
        )

        XCTAssertTrue(shouldConstrain, "Slow resize should constrain")
    }

    func testResizeFastSpeed_ShouldNotConstrain() {
        let mouseSpeed: CGFloat = 1500  // Above threshold

        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold
        )

        XCTAssertFalse(shouldConstrain, "Fast resize should not constrain")
    }

    func testResizeExactThreshold_ShouldNotConstrain() {
        let mouseSpeed: CGFloat = 1000  // Exactly at threshold

        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold
        )

        XCTAssertFalse(shouldConstrain, "Resize at exact threshold should not constrain")
    }

    func testResizeZeroSpeed_ShouldConstrain() {
        let mouseSpeed: CGFloat = 0

        let shouldConstrain = WindowCalculations.shouldConstrainResize(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold
        )

        XCTAssertTrue(shouldConstrain, "Zero speed resize should constrain")
    }

    // MARK: - Edge Cases

    func testVeryHighSpeed() {
        let mouseSpeed: CGFloat = 10000  // Very high speed
        let currentWindowRect = NSRect(x: 100, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        XCTAssertFalse(shouldConstrain, "Very high speed should not constrain")
    }

    func testNegativeSpeed_ShouldConstrain() {
        // This shouldn't happen in practice, but test defensive behavior
        let mouseSpeed: CGFloat = -100
        let currentWindowRect = NSRect(x: 100, y: 100, width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        // Negative speed < threshold, so should constrain if inside
        XCTAssertTrue(shouldConstrain, "Negative speed should be treated as slow (< threshold)")
    }

    func testWindowLargerThanScreen() {
        let mouseSpeed: CGFloat = 500
        // Huge window larger than screen
        let currentWindowRect = NSRect(x: -100, y: -100, width: 3000, height: 2000)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let shouldConstrain = WindowCalculations.shouldConstrainMovement(
            mouseSpeed: mouseSpeed,
            speedThreshold: speedThreshold,
            currentWindowRect: currentWindowRect,
            screenFrame: screenFrame
        )

        // Window is not contained by screen frame, so should not constrain
        XCTAssertFalse(shouldConstrain, "Window larger than screen is not inside")
    }
}
