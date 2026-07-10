import Foundation

/// Describes a physical screen in NSScreen coordinates (bottom-left origin).
/// Used by the pure screen-lookup logic so it can be unit tested without a live
/// display configuration.
struct ScreenInfo {
    let frame: NSRect         // Full screen frame (NSScreen coords)
    let visibleFrame: NSRect  // Usable area, excludes menu bar / dock (NSScreen coords)
    let backingScaleFactor: CGFloat
}

/// Pure functions for window manipulation calculations.
/// These functions have no side effects and are fully testable.
struct WindowCalculations {

    // MARK: - Screen Coordinate Conversion

    /// Converts a Y coordinate from NSScreen space (bottom-left origin, Y up) to
    /// Accessibility/CoreGraphics space (top-left origin of the PRIMARY screen, Y down).
    ///
    /// The AX/CG global coordinate origin is the top-left of the primary screen
    /// (the screen whose NSScreen frame origin is (0, 0)). Screens physically above
    /// the primary therefore have NEGATIVE AX Y values. This is why we must convert
    /// relative to the primary screen height and NOT relative to the global maximum Y
    /// across all screens.
    static func nsYToAccessibilityY(nsY: CGFloat, primaryScreenHeight: CGFloat) -> CGFloat {
        return primaryScreenHeight - nsY
    }

    /// Finds the screen that contains the given window position and returns its usable
    /// (visible) frame converted to Accessibility coordinates, along with its scale factor.
    ///
    /// SUPERSEDED for constraint decisions by `screenContaining(windowRect:...)`: a point
    /// exactly on the edge shared by two screens is contained by BOTH closed ranges, so this
    /// returns whichever screen is listed first — ambiguous and order-dependent. Prefer
    /// rect-overlap selection anywhere the result feeds sticky-edge constraints.
    ///
    /// - Parameters:
    ///   - windowPosition: Window top-left in Accessibility coordinates.
    ///   - screens: All screens, in NSScreen coordinates.
    ///   - primaryScreenHeight: Height of the primary screen (defines the AX origin).
    /// - Returns: The visible frame in Accessibility coordinates and the scale factor,
    ///   or nil if the position isn't contained by any screen.
    static func findUsableScreen(
        windowPosition: CGPoint,
        screens: [ScreenInfo],
        primaryScreenHeight: CGFloat
    ) -> (frame: NSRect, scaleFactor: CGFloat)? {
        for screen in screens {
            // Convert this screen's vertical bounds into Accessibility coordinates.
            // NSScreen maxY (top of screen) maps to the smaller AX Y value.
            let accessibilityScreenMinY = nsYToAccessibilityY(nsY: screen.frame.maxY, primaryScreenHeight: primaryScreenHeight)  // Top
            let accessibilityScreenMaxY = nsYToAccessibilityY(nsY: screen.frame.minY, primaryScreenHeight: primaryScreenHeight)  // Bottom

            if windowPosition.x >= screen.frame.minX && windowPosition.x <= screen.frame.maxX &&
               windowPosition.y >= accessibilityScreenMinY && windowPosition.y <= accessibilityScreenMaxY {
                let accessibilityVisibleMinY = nsYToAccessibilityY(nsY: screen.visibleFrame.maxY, primaryScreenHeight: primaryScreenHeight)
                let accessibilityFrame = NSRect(
                    x: screen.visibleFrame.minX,
                    y: accessibilityVisibleMinY,
                    width: screen.visibleFrame.width,
                    height: screen.visibleFrame.height
                )
                return (accessibilityFrame, screen.backingScaleFactor)
            }
        }
        return nil
    }

    /// Converts a screen's visible frame (NSScreen coords) into Accessibility coordinates.
    static func accessibilityVisibleFrame(
        for screen: ScreenInfo,
        primaryScreenHeight: CGFloat
    ) -> NSRect {
        let accessibilityVisibleMinY = nsYToAccessibilityY(nsY: screen.visibleFrame.maxY, primaryScreenHeight: primaryScreenHeight)
        return NSRect(
            x: screen.visibleFrame.minX,
            y: accessibilityVisibleMinY,
            width: screen.visibleFrame.width,
            height: screen.visibleFrame.height
        )
    }

    /// The bounding frame of the entire desktop (union of every screen's visible frame),
    /// in Accessibility coordinates.
    ///
    /// Sticky-edge constraints for move/resize are applied against THIS frame rather than
    /// a single screen. Constraining to one screen turns the edge shared with an adjacent
    /// screen into a hard wall, which pins windows at internal boundaries (e.g. a window at
    /// the top edge of a bottom screen can't be resized taller into the screen above, and a
    /// window can't be slow-dragged from one monitor to another). Constraining to the desktop
    /// bounding frame makes internal shared edges free; only the true outer perimeter of the
    /// combined desktop constrains.
    static func desktopBoundingFrame(
        screens: [ScreenInfo],
        primaryScreenHeight: CGFloat
    ) -> NSRect {
        var result: NSRect? = nil
        for screen in screens {
            let frame = accessibilityVisibleFrame(for: screen, primaryScreenHeight: primaryScreenHeight)
            result = result.map { $0.union(frame) } ?? frame
        }
        return result ?? .zero
    }

    /// Finds the screen with the LARGEST overlap with the window's rect and returns its
    /// visible frame in Accessibility coordinates plus its scale factor.
    ///
    /// This intentionally replaces point-based lookup (`findUsableScreen`) for constraint
    /// decisions. Point-based lookup is ambiguous when the window's top-left sits EXACTLY on
    /// the edge shared by two adjacent screens (both closed ranges contain it, and whichever
    /// screen `NSScreen.screens` lists first wins). Picking the wrong screen put the window
    /// "outside" the constraint frame and the sticky-edge caps yanked it violently (e.g. a
    /// bottom-corner resize forced desiredHeight to 0 → the window snapped to its minimum
    /// height). A window's BODY overlap is unambiguous.
    static func screenContaining(
        windowRect: NSRect,
        screens: [ScreenInfo],
        primaryScreenHeight: CGFloat
    ) -> (frame: NSRect, scaleFactor: CGFloat)? {
        var bestArea: CGFloat = 0
        var best: (frame: NSRect, scaleFactor: CGFloat)? = nil
        for screen in screens {
            // Full screen frame in Accessibility coordinates.
            let axTop = nsYToAccessibilityY(nsY: screen.frame.maxY, primaryScreenHeight: primaryScreenHeight)
            let axFrame = NSRect(x: screen.frame.minX, y: axTop, width: screen.frame.width, height: screen.frame.height)
            let overlap = axFrame.intersection(windowRect)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            // Strictly greater: on an exact tie the earlier screen wins (deterministic).
            if area > bestArea {
                bestArea = area
                best = (
                    accessibilityVisibleFrame(for: screen, primaryScreenHeight: primaryScreenHeight),
                    screen.backingScaleFactor
                )
            }
        }
        return best
    }

    /// Chooses the frame that resize constraints are applied against: ALWAYS the single
    /// screen containing (most of) the window.
    ///
    /// Resizes must treat the edge shared with an adjacent screen as a REAL wall. Probed on
    /// macOS 26.5 (see AGENTS.md): AX position sets whose rect would straddle two displays
    /// are not applied faithfully — the WindowServer TELEPORTS the window (observed bounces
    /// to y=31, y=231, or a snap to the destination screen edge), even with "Displays have
    /// separate Spaces" disabled. Growing a window's top/left edge across a shared edge is
    /// therefore impossible to do smoothly; attempting it is what mangled windows at the
    /// shared edge ("snaps to half height"). Moves still use the desktop bounding frame —
    /// cross-screen moves work because the WindowServer's snap lands the window on the
    /// destination screen.
    static func resizeConstraintFrame(
        windowRect: NSRect,
        screens: [ScreenInfo],
        primaryScreenHeight: CGFloat
    ) -> NSRect {
        if let single = screenContaining(
            windowRect: windowRect,
            screens: screens,
            primaryScreenHeight: primaryScreenHeight
        ) {
            return single.frame
        }
        return desktopBoundingFrame(screens: screens, primaryScreenHeight: primaryScreenHeight)
    }

    /// True if the window's rect lies entirely within a single screen's FULL frame.
    ///
    /// Position sets are only reliable for such windows (probed on macOS 26.5): setting a
    /// position whose rect straddles displays — or moving a window between displays — makes
    /// the WindowServer teleport it unpredictably. Windows already straddling screens must
    /// therefore never receive position sets during resize.
    static func isEntirelyOnOneScreen(
        windowRect: NSRect,
        screens: [ScreenInfo],
        primaryScreenHeight: CGFloat
    ) -> Bool {
        return screens.contains { screen in
            let axTop = nsYToAccessibilityY(nsY: screen.frame.maxY, primaryScreenHeight: primaryScreenHeight)
            let axFrame = NSRect(x: screen.frame.minX, y: axTop, width: screen.frame.width, height: screen.frame.height)
            // Sub-pixel tolerance: float drift at an exact edge must not flip a window
            // into "straddling" (size-only) mode.
            return axFrame.insetBy(dx: -0.5, dy: -0.5).contains(windowRect)
        }
    }

    /// True if the actual size that macOS applied fell short of what we asked for in either
    /// dimension. Used to detect the WindowServer clamping a resize (min window size, screen
    /// edge, or refusing a display-spanning window).
    static func sizeFellShort(of desired: CGSize, actual: CGSize, epsilon: CGFloat) -> Bool {
        return actual.width < desired.width - epsilon || actual.height < desired.height - epsilon
    }

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

        // Slow movements only constrained if window is inside screen bounds.
        // Tolerance: anchor-fix arithmetic can leave a window a few 1e-14 outside the
        // frame; exact containment would silently disable constraints (found by fuzzing).
        return screenFrame.insetBy(dx: -0.5, dy: -0.5).contains(currentWindowRect)
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

    /// Determines if resize should be constrained based on speed and current position.
    ///
    /// Symmetric with `shouldConstrainMovement`: constraints may PREVENT a window from
    /// leaving the frame, but must never YANK a window that is already (partially) outside
    /// it. Without the containment check, a wrong or straddled constraint frame produces
    /// forced deltas far beyond the mouse movement (e.g. desiredHeight driven to 0 → the
    /// window snaps to its minimum height).
    static func shouldConstrainResize(
        mouseSpeed: CGFloat,
        speedThreshold: CGFloat,
        currentWindowRect: NSRect,
        screenFrame: NSRect
    ) -> Bool {
        // Fast movements are never constrained
        if mouseSpeed >= speedThreshold {
            return false
        }

        // Slow movements only constrained if the window is inside the frame;
        // a window outside (or straddling an edge) is never yanked back.
        // Tolerance: anchor-fix arithmetic can leave a window a few 1e-14 outside the
        // frame; exact containment would silently disable constraints (found by fuzzing:
        // an "escaped" gate let unconstrained growth emit teleporting position sets).
        return screenFrame.insetBy(dx: -0.5, dy: -0.5).contains(currentWindowRect)
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
