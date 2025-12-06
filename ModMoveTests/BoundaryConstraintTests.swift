import XCTest
@testable import ModMove

class BoundaryConstraintTests: XCTestCase {

    // MARK: - Movement Constraints - Basic

    func testMoveWithinBounds_NoConstraint() {
        let mouseDelta = CGPoint(x: 50, y: 30)
        let initialPosition = CGPoint(x: 200, y: 200)
        let windowSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let result = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: mouseDelta,
            initialPosition: initialPosition,
            windowSize: windowSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        XCTAssertEqual(result.x, 50, "Move within bounds should not be constrained")
        XCTAssertEqual(result.y, 30, "Move within bounds should not be constrained")
    }

    func testMoveLeftEdgeConstraint() {
        let mouseDelta = CGPoint(x: -300, y: 0)  // Would move window off left edge
        let initialPosition = CGPoint(x: 100, y: 200)
        let windowSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let result = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: mouseDelta,
            initialPosition: initialPosition,
            windowSize: windowSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should constrain to left edge (screenFrame.minX - initialPosition.x = 0 - 100 = -100)
        XCTAssertEqual(result.x, -100, "Move should be constrained to left edge")
        XCTAssertEqual(result.y, 0, "Y should not be constrained")
    }

    func testMoveRightEdgeConstraint() {
        let mouseDelta = CGPoint(x: 500, y: 0)  // Would move window off right edge
        let initialPosition = CGPoint(x: 1600, y: 200)
        let windowSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 0, width: 1920, height: 1080)

        let result = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: mouseDelta,
            initialPosition: initialPosition,
            windowSize: windowSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should constrain to right edge
        // maxDx = screenFrame.maxX - (initialPosition.x + windowSize.width) = 1920 - (1600 + 400) = -80
        XCTAssertEqual(result.x, -80, "Move should be constrained to right edge")
        XCTAssertEqual(result.y, 0, "Y should not be constrained")
    }

    func testMoveTopEdgeConstraint() {
        let mouseDelta = CGPoint(x: 0, y: -300)  // Would move window off top edge
        let initialPosition = CGPoint(x: 200, y: 100)
        let windowSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)  // Account for menu bar

        let result = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: mouseDelta,
            initialPosition: initialPosition,
            windowSize: windowSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should constrain to top edge (minDy = 23 - 100 = -77)
        XCTAssertEqual(result.x, 0, "X should not be constrained")
        XCTAssertEqual(result.y, -77, "Move should be constrained to top edge (menu bar)")
    }

    func testMoveBottomEdgeConstraint() {
        let mouseDelta = CGPoint(x: 0, y: 500)  // Would move window off bottom edge
        let initialPosition = CGPoint(x: 200, y: 900)
        let windowSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: mouseDelta,
            initialPosition: initialPosition,
            windowSize: windowSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should constrain to bottom edge
        // maxDy = screenFrame.maxY - (initialPosition.y + windowSize.height) = 1080 - (900 + 300) = -120
        XCTAssertEqual(result.x, 0, "X should not be constrained")
        XCTAssertEqual(result.y, -120, "Move should be constrained to bottom edge")
    }

    func testMoveCornerConstraint() {
        let mouseDelta = CGPoint(x: -500, y: -500)  // Would move window off top-left corner
        let initialPosition = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: mouseDelta,
            initialPosition: initialPosition,
            windowSize: windowSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        XCTAssertEqual(result.x, -100, "X should be constrained to left edge")
        XCTAssertEqual(result.y, -77, "Y should be constrained to top edge")
    }

    func testMoveNoConstraintWhenNotShouldConstrain() {
        let mouseDelta = CGPoint(x: -500, y: -500)  // Would normally be constrained
        let initialPosition = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedMoveDelta(
            mouseDelta: mouseDelta,
            initialPosition: initialPosition,
            windowSize: windowSize,
            screenFrame: screenFrame,
            shouldConstrain: false  // Fast movement
        )

        // Should not constrain
        XCTAssertEqual(result.x, -500, "Fast movement should not be constrained")
        XCTAssertEqual(result.y, -500, "Fast movement should not be constrained")
    }

    // MARK: - Resize Constraints - TopLeft Corner

    func testResizeTopLeftCorner_NoConstraint() {
        let mouseDelta = CGPoint(x: -50, y: -30)
        let corner = Corner.TopLeft
        let initialPosition = CGPoint(x: 200, y: 200)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        XCTAssertEqual(result.x, -50, "Resize within bounds should not be constrained")
        XCTAssertEqual(result.y, -30, "Resize within bounds should not be constrained")
    }

    func testResizeTopLeftCorner_LeftEdgeConstraint() {
        let mouseDelta = CGPoint(x: -300, y: 0)  // Would move corner off left edge
        let corner = Corner.TopLeft
        let initialPosition = CGPoint(x: 100, y: 200)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should constrain to left edge (minX - initialPosition.x = 0 - 100 = -100)
        XCTAssertEqual(result.x, -100, "TopLeft corner should be constrained to left edge")
        XCTAssertEqual(result.y, 0, "Y should not be constrained")
    }

    func testResizeTopLeftCorner_TopEdgeConstraint() {
        let mouseDelta = CGPoint(x: 0, y: -300)  // Would move corner off top edge
        let corner = Corner.TopLeft
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should constrain to top edge (minY - initialPosition.y = 23 - 100 = -77)
        XCTAssertEqual(result.x, 0, "X should not be constrained")
        XCTAssertEqual(result.y, -77, "TopLeft corner should be constrained to top edge")
    }

    // MARK: - Resize Constraints - TopRight Corner

    func testResizeTopRightCorner_RightEdgeConstraint() {
        let mouseDelta = CGPoint(x: 500, y: 0)  // Would move corner off right edge
        let corner = Corner.TopRight
        let initialPosition = CGPoint(x: 1600, y: 200)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should constrain to right edge
        // maxX - (initialPosition.x + initialSize.width) = 1920 - (1600 + 400) = -80
        XCTAssertEqual(result.x, -80, "TopRight corner should be constrained to right edge")
        XCTAssertEqual(result.y, 0, "Y should not be constrained")
    }

    func testResizeTopRightCorner_TopEdgeConstraint() {
        let mouseDelta = CGPoint(x: 0, y: -300)  // Would move corner off top edge
        let corner = Corner.TopRight
        let initialPosition = CGPoint(x: 200, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        XCTAssertEqual(result.x, 0, "X should not be constrained")
        XCTAssertEqual(result.y, -77, "TopRight corner should be constrained to top edge")
    }

    // MARK: - Resize Constraints - BottomLeft Corner

    func testResizeBottomLeftCorner_LeftEdgeConstraint() {
        let mouseDelta = CGPoint(x: -300, y: 0)  // Would move corner off left edge
        let corner = Corner.BottomLeft
        let initialPosition = CGPoint(x: 100, y: 200)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        XCTAssertEqual(result.x, -100, "BottomLeft corner should be constrained to left edge")
        XCTAssertEqual(result.y, 0, "Y should not be constrained")
    }

    func testResizeBottomLeftCorner_BottomEdgeConstraint() {
        let mouseDelta = CGPoint(x: 0, y: 500)  // Would move corner off bottom edge
        let corner = Corner.BottomLeft
        let initialPosition = CGPoint(x: 200, y: 900)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should constrain to bottom edge
        // maxY - (initialPosition.y + initialSize.height) = 1080 - (900 + 300) = -120
        XCTAssertEqual(result.x, 0, "X should not be constrained")
        XCTAssertEqual(result.y, -120, "BottomLeft corner should be constrained to bottom edge")
    }

    // MARK: - Resize Constraints - BottomRight Corner

    func testResizeBottomRightCorner_RightEdgeConstraint() {
        let mouseDelta = CGPoint(x: 500, y: 0)  // Would move corner off right edge
        let corner = Corner.BottomRight
        let initialPosition = CGPoint(x: 1600, y: 200)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        XCTAssertEqual(result.x, -80, "BottomRight corner should be constrained to right edge")
        XCTAssertEqual(result.y, 0, "Y should not be constrained")
    }

    func testResizeBottomRightCorner_BottomEdgeConstraint() {
        let mouseDelta = CGPoint(x: 0, y: 500)  // Would move corner off bottom edge
        let corner = Corner.BottomRight
        let initialPosition = CGPoint(x: 200, y: 900)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        XCTAssertEqual(result.x, 0, "X should not be constrained")
        XCTAssertEqual(result.y, -120, "BottomRight corner should be constrained to bottom edge")
    }

    // MARK: - Resize No Constraint When Fast

    func testResizeNoConstraintWhenFast() {
        let mouseDelta = CGPoint(x: -500, y: -500)  // Would normally be constrained
        let corner = Corner.TopLeft
        let initialPosition = CGPoint(x: 100, y: 100)
        let initialSize = CGSize(width: 400, height: 300)
        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: false  // Fast movement
        )

        XCTAssertEqual(result.x, -500, "Fast resize should not be constrained")
        XCTAssertEqual(result.y, -500, "Fast resize should not be constrained")
    }

    // MARK: - Bug: Window at Screen Edge - Should Allow Growth from Opposite Corner

    func testResizeFromTopLeftCorner_WindowAtRightEdge_ShouldAllowLeftwardGrowth() {
        // Window at top-right screen corner
        let initialPosition = CGPoint(x: 1600, y: 23)  // Top-left of window
        let initialSize = CGSize(width: 320, height: 300)
        // Window's right edge: 1600 + 320 = 1920 (at screen boundary)

        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        // Resizing from top-left corner, moving mouse LEFT to grow window
        let mouseDelta = CGPoint(x: -100, y: 0)  // Move left 100px
        let corner = Corner.TopLeft

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should NOT be constrained - top-left corner is nowhere near left edge
        // Window should be able to grow leftward even though right edge is at screen boundary
        XCTAssertEqual(result.x, -100, "Should allow leftward growth when window is at right edge")
    }

    func testResizeFromBottomLeftCorner_WindowAtRightEdge_ShouldAllowLeftwardGrowth() {
        // Window at bottom-right screen corner
        let initialPosition = CGPoint(x: 1600, y: 780)  // Top-left of window
        let initialSize = CGSize(width: 320, height: 300)
        // Window's right edge: 1600 + 320 = 1920 (at screen boundary)

        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        // Resizing from bottom-left corner, moving mouse LEFT to grow window
        let mouseDelta = CGPoint(x: -100, y: 0)  // Move left 100px
        let corner = Corner.BottomLeft

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should NOT be constrained - bottom-left corner is nowhere near left edge
        XCTAssertEqual(result.x, -100, "Should allow leftward growth when window is at right edge")
    }

    func testResizeFromTopRightCorner_WindowAtBottomEdge_ShouldAllowUpwardGrowth() {
        // Window at bottom-right screen corner
        let initialPosition = CGPoint(x: 1600, y: 780)  // Top-left of window
        let initialSize = CGSize(width: 300, height: 300)
        // Window's bottom edge: 780 + 300 = 1080 (at screen boundary)

        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        // Resizing from top-right corner, moving mouse UP to grow window
        let mouseDelta = CGPoint(x: 0, y: -100)  // Move up 100px
        let corner = Corner.TopRight

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should NOT be constrained - top-right corner is nowhere near top edge
        // Note: -100 should NOT be constrained here, but current logic might constrain it
        XCTAssertEqual(result.y, -100, "Should allow upward growth when window is at bottom edge")
    }

    func testResizeFromTopLeftCorner_WindowAtBottomRightEdge_ShouldAllowUpwardAndLeftwardGrowth() {
        // Window at bottom-right screen corner
        let initialPosition = CGPoint(x: 1600, y: 780)  // Top-left of window
        let initialSize = CGSize(width: 320, height: 300)
        // Window's right edge: 1920, bottom edge: 1080 (both at screen boundaries)

        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        // Resizing from top-left corner, moving mouse UP and LEFT to grow window
        let mouseDelta = CGPoint(x: -100, y: -100)
        let corner = Corner.TopLeft

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should NOT be constrained in either direction
        XCTAssertEqual(result.x, -100, "Should allow leftward growth when window is at right edge")
        XCTAssertEqual(result.y, -100, "Should allow upward growth when window is at bottom edge")
    }

    func testResizeFromBottomLeftCorner_WindowAtBottomRightEdge_ShouldAllowLeftwardGrowth() {
        // Window at bottom-right screen corner
        let initialPosition = CGPoint(x: 1600, y: 780)  // Top-left of window
        let initialSize = CGSize(width: 320, height: 300)

        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        // Resizing from bottom-left corner, moving mouse LEFT to grow window
        let mouseDelta = CGPoint(x: -100, y: 0)
        let corner = Corner.BottomLeft

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should NOT be constrained - bottom-left corner is far from left edge
        XCTAssertEqual(result.x, -100, "Should allow leftward growth when window is at right edge")
    }

    // MARK: - Edge Case: Window Already Partially Off-Screen

    func testResizeFromTopLeftCorner_WindowPastRightEdge_ShouldAllowLeftwardGrowth() {
        // Window extends past right edge (maybe user threw it there with fast movement)
        let initialPosition = CGPoint(x: 1700, y: 23)  // Top-left of window
        let initialSize = CGSize(width: 320, height: 300)
        // Window's right edge: 1700 + 320 = 2020 (past screen boundary of 1920)

        let screenFrame = NSRect(x: 0, y: 23, width: 1920, height: 1057)

        // Resizing from top-left corner, moving mouse LEFT to grow window
        let mouseDelta = CGPoint(x: -100, y: 0)  // Move left 100px
        let corner = Corner.TopLeft

        let result = WindowCalculations.calculateConstrainedResizeDelta(
            mouseDelta: mouseDelta,
            corner: corner,
            initialPosition: initialPosition,
            initialSize: initialSize,
            screenFrame: screenFrame,
            shouldConstrain: true
        )

        // Should NOT be constrained - top-left corner can still move left from x=1700
        XCTAssertEqual(result.x, -100, "Should allow leftward growth even when window extends past right edge")
    }
}
