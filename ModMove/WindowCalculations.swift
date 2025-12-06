import Foundation

/// Pure functions for window manipulation calculations.
/// These functions have no side effects and are fully testable.
struct WindowCalculations {

    // MARK: - Corner Detection

    /// Determines which corner of the window is closest to the mouse position.
    static func calculateClosestCorner(
        windowPosition: CGPoint,
        windowSize: CGSize,
        mousePosition: CGPoint
    ) -> Corner {
        let xmid = windowPosition.x + windowSize.width / 2
        let ymid = windowPosition.y + windowSize.height / 2

        if mousePosition.x < xmid && mousePosition.y < ymid {
            return .TopLeft
        } else if mousePosition.x >= xmid && mousePosition.y < ymid {
            return .TopRight
        } else if mousePosition.x < xmid && mousePosition.y >= ymid {
            return .BottomLeft
        } else {
            return .BottomRight
        }
    }

    // MARK: - Movement Constraints

    /// Calculates constrained mouse delta for window movement.
    /// Returns the delta that keeps the window within screen bounds (if constrained).
    static func calculateConstrainedMoveDelta(
        mouseDelta: CGPoint,
        initialPosition: CGPoint,
        windowSize: CGSize,
        screenFrame: NSRect,
        shouldConstrain: Bool
    ) -> CGPoint {
        guard shouldConstrain else {
            return mouseDelta
        }

        let minDx = screenFrame.minX - initialPosition.x
        let maxDx = screenFrame.maxX - (initialPosition.x + windowSize.width)
        let minDy = screenFrame.minY - initialPosition.y
        let maxDy = screenFrame.maxY - (initialPosition.y + windowSize.height)

        let constrainedDx = min(max(mouseDelta.x, minDx), maxDx)
        let constrainedDy = min(max(mouseDelta.y, minDy), maxDy)

        return CGPoint(x: constrainedDx, y: constrainedDy)
    }

    /// Determines if movement should be constrained based on speed and current position.
    static func shouldConstrainMovement(
        mouseSpeed: CGFloat,
        speedThreshold: CGFloat,
        currentWindowRect: NSRect,
        screenFrame: NSRect
    ) -> Bool {
        // Fast movements are never constrained
        if mouseSpeed >= speedThreshold {
            return false
        }

        // Slow movements only constrained if window is inside screen bounds
        return screenFrame.contains(currentWindowRect)
    }

    // MARK: - Resize Constraints

    /// Calculates constrained mouse delta for window resizing.
    /// Constrains the moving corner from going off screen.
    static func calculateConstrainedResizeDelta(
        mouseDelta: CGPoint,
        corner: Corner,
        initialPosition: CGPoint,
        initialSize: CGSize,
        screenFrame: NSRect,
        shouldConstrain: Bool
    ) -> CGPoint {
        guard shouldConstrain else {
            return mouseDelta
        }

        var constrainedDx = mouseDelta.x
        var constrainedDy = mouseDelta.y

        switch corner {
        case .TopLeft:
            // Moving corner: top left - constrain from going off left/top edges
            constrainedDx = max(mouseDelta.x, screenFrame.minX - initialPosition.x)
            constrainedDy = max(mouseDelta.y, screenFrame.minY - initialPosition.y)

        case .TopRight:
            // Moving corner: top right - constrain from going off right/top edges
            constrainedDx = min(mouseDelta.x, screenFrame.maxX - (initialPosition.x + initialSize.width))
            constrainedDy = max(mouseDelta.y, screenFrame.minY - initialPosition.y)

        case .BottomLeft:
            // Moving corner: bottom left - constrain from going off left/bottom edges
            constrainedDx = max(mouseDelta.x, screenFrame.minX - initialPosition.x)
            constrainedDy = min(mouseDelta.y, screenFrame.maxY - (initialPosition.y + initialSize.height))

        case .BottomRight:
            // Moving corner: bottom right - constrain from going off right/bottom edges
            constrainedDx = min(mouseDelta.x, screenFrame.maxX - (initialPosition.x + initialSize.width))
            constrainedDy = min(mouseDelta.y, screenFrame.maxY - (initialPosition.y + initialSize.height))
        }

        return CGPoint(x: constrainedDx, y: constrainedDy)
    }

    /// Determines if resize should be constrained based on speed.
    /// Note: Resize only checks speed, not window position.
    static func shouldConstrainResize(
        mouseSpeed: CGFloat,
        speedThreshold: CGFloat
    ) -> Bool {
        return mouseSpeed < speedThreshold
    }

    // MARK: - Resize Size Calculations

    /// Calculates the desired window size based on corner and mouse delta.
    static func calculateDesiredSize(
        corner: Corner,
        initialSize: CGSize,
        delta: CGPoint
    ) -> CGSize {
        let desiredWidth: CGFloat
        let desiredHeight: CGFloat

        switch corner {
        case .TopLeft, .BottomLeft:
            desiredWidth = initialSize.width - delta.x
        case .TopRight, .BottomRight:
            desiredWidth = initialSize.width + delta.x
        }

        switch corner {
        case .TopLeft, .TopRight:
            desiredHeight = initialSize.height - delta.y
        case .BottomLeft, .BottomRight:
            desiredHeight = initialSize.height + delta.y
        }

        return CGSize(width: desiredWidth, height: desiredHeight)
    }

    /// Calculates the new window position after resizing, ensuring the anchor corner stays fixed.
    /// Takes the actual size (which may differ from desired due to min size constraints).
    static func calculateResizedWindowPosition(
        corner: Corner,
        initialPosition: CGPoint,
        initialSize: CGSize,
        actualSize: CGSize
    ) -> CGPoint? {
        switch corner {
        case .TopLeft:
            let actualDx = initialSize.width - actualSize.width
            let actualDy = initialSize.height - actualSize.height
            return CGPoint(x: initialPosition.x + actualDx, y: initialPosition.y + actualDy)

        case .TopRight:
            let actualDy = initialSize.height - actualSize.height
            return CGPoint(x: initialPosition.x, y: initialPosition.y + actualDy)

        case .BottomLeft:
            let actualDx = initialSize.width - actualSize.width
            return CGPoint(x: initialPosition.x + actualDx, y: initialPosition.y)

        case .BottomRight:
            // BottomRight only changes size, no position adjustment needed
            return nil
        }
    }
}
