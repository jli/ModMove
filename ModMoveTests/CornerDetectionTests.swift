import XCTest
@testable import ModMove

class CornerDetectionTests: XCTestCase {

    // MARK: - Basic Corner Detection

    func testTopLeftCorner() {
        let windowPos = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)

        // Mouse in top-left quadrant
        let mousePos = CGPoint(x: 200, y: 150)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        XCTAssertEqual(corner, .TopLeft, "Mouse at (\(mousePos.x), \(mousePos.y)) should be closest to TopLeft corner")
    }

    func testTopRightCorner() {
        let windowPos = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)

        // Mouse in top-right quadrant
        let mousePos = CGPoint(x: 350, y: 150)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        XCTAssertEqual(corner, .TopRight, "Mouse at (\(mousePos.x), \(mousePos.y)) should be closest to TopRight corner")
    }

    func testBottomLeftCorner() {
        let windowPos = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)

        // Mouse in bottom-left quadrant
        let mousePos = CGPoint(x: 200, y: 300)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        XCTAssertEqual(corner, .BottomLeft, "Mouse at (\(mousePos.x), \(mousePos.y)) should be closest to BottomLeft corner")
    }

    func testBottomRightCorner() {
        let windowPos = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)

        // Mouse in bottom-right quadrant
        let mousePos = CGPoint(x: 350, y: 300)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        XCTAssertEqual(corner, .BottomRight, "Mouse at (\(mousePos.x), \(mousePos.y)) should be closest to BottomRight corner")
    }

    // MARK: - Edge Cases

    func testCenterPoint() {
        let windowPos = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)

        // Mouse exactly at center
        let mousePos = CGPoint(x: 300, y: 250)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        // At exact midpoint, should go to bottom-right (x >= xmid && y >= ymid)
        XCTAssertEqual(corner, .BottomRight, "Mouse at exact center should be BottomRight")
    }

    func testVerticalMidline() {
        let windowPos = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)

        // Mouse on vertical midline, top half
        let mousePos = CGPoint(x: 300, y: 150)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        // On vertical midline (x >= xmid), top half (y < ymid)
        XCTAssertEqual(corner, .TopRight, "Mouse on vertical midline, top half should be TopRight")
    }

    func testHorizontalMidline() {
        let windowPos = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 400, height: 300)

        // Mouse on horizontal midline, left half
        let mousePos = CGPoint(x: 200, y: 250)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        // On horizontal midline (y >= ymid), left half (x < xmid)
        XCTAssertEqual(corner, .BottomLeft, "Mouse on horizontal midline, left half should be BottomLeft")
    }

    // MARK: - Small Window

    func testSmallWindow() {
        let windowPos = CGPoint(x: 100, y: 100)
        let windowSize = CGSize(width: 50, height: 50)

        // Mouse in top-left quadrant
        let mousePos = CGPoint(x: 110, y: 110)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        XCTAssertEqual(corner, .TopLeft, "Small window should still correctly detect corners")
    }

    // MARK: - Large Window

    func testLargeWindow() {
        let windowPos = CGPoint(x: 0, y: 0)
        let windowSize = CGSize(width: 2560, height: 1440)

        // Mouse near top-left
        let mousePos = CGPoint(x: 500, y: 300)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        XCTAssertEqual(corner, .TopLeft, "Large window should still correctly detect corners")
    }

    // MARK: - Various Positions

    func testWindowAtOrigin() {
        let windowPos = CGPoint(x: 0, y: 0)
        let windowSize = CGSize(width: 400, height: 300)

        let mousePos = CGPoint(x: 10, y: 10)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        XCTAssertEqual(corner, .TopLeft, "Window at origin should work correctly")
    }

    func testWindowFarFromOrigin() {
        let windowPos = CGPoint(x: 1920, y: 1080)
        let windowSize = CGSize(width: 400, height: 300)

        let mousePos = CGPoint(x: 2200, y: 1300)

        let corner = WindowCalculations.calculateClosestCorner(
            windowPosition: windowPos,
            windowSize: windowSize,
            mousePosition: mousePos
        )

        XCTAssertEqual(corner, .BottomRight, "Window far from origin should work correctly")
    }
}
