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
