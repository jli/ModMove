# ModMove Performance Analysis

Analysis of performance characteristics and optimization opportunities in the custom `jli-resize-restrictmove` branch.

## Executive Summary

The code is well-optimized for smooth, responsive window manipulation. This document tracks the performance characteristics and optimization history.

### ✅ Implemented Optimizations

- **Priority 1**: Fixed `windowInsideFrame` to use cached values (eliminates 120-240 API calls/sec)
- **Priority 2**: Replaced `Date()` with `CACurrentMediaTime()` (eliminates 60-120 allocations/sec)
- **State management**: Proper cleanup of tracking variables between operations

### Remaining Opportunities

- **Priority 3** (optional): Skip speed tracking when window is outside frame
- **Priority 4** (optional): Throttle Accessibility API setters to ~60fps

## Performance Hotspots

### 1. Mouse Movement Handler (Critical Path)

**Location**: `Mover.swift:37-64` (`mouseMoved` function)

**Call Frequency**: Every mouse movement event (potentially 60-120+ times per second)

**Current Behavior**:
```swift
private func mouseMoved(handler: ...) {
    let curMousePos = Mouse.currentPosition()  // ✓ Fast: CoreGraphics call

    if self.window == nil {
        // ⚠️ EXPENSIVE: Accessibility API system call
        self.window = AccessibilityElement.systemWideElement.element(at: curMousePos)?.window()
    }

    if self.initialMousePosition == nil {
        // ⚠️ MODERATE: Multiple Accessibility API getters
        self.initialWindowPosition = window.position  // AXUIElementCopyAttributeValue
        self.initialWindowSize = window.size          // AXUIElementCopyAttributeValue
        // ... more setup
    } else {
        self.trackMouseSpeed(curMousePos: curMousePos)  // ✓ Fast: Math operations
        let mouseDelta = CGPoint(x: curMousePos.x - initMousePos.x, ...)
        handler(window, mouseDelta)  // → moveWindow or resizeWindow
    }
}
```

**Performance**:
- First call: Expensive (window lookup + multiple API calls)
- Subsequent calls: Moderate (depends on move/resize logic)

### 2. Constraint Checking (High Frequency Issue)

**Location**: `Mover.swift:158-171` (`shouldConstrainMouseDelta` and `windowInsideFrame`)

**Call Frequency**: Every mouse movement event after initialization

**Current Implementation**:
```swift
private func shouldConstrainMouseDelta(_ window: AccessibilityElement, _ mouseDelta: CGPoint) -> Bool {
    if let frame = self.frame {
        return self.mouseSpeed < FAST_MOUSE_SPEED_THRESHOLD && windowInsideFrame(window, frame)
    }
    return false
}

private func windowInsideFrame(_ window: AccessibilityElement, _ frame: CGRect) -> Bool {
    if let pos = window.position, let size = window.size {  // ⚠️ TWO ACCESSIBILITY API CALLS!
        return frame.contains(NSMakeRect(pos.x, pos.y, size.width, size.height))
    }
    return true
}
```

**Problem**: `windowInsideFrame` queries `window.position` and `window.size` on **every mouse move**. These trigger expensive Accessibility API calls via getters in `AccessibilityElement.swift:7-23`.

**Impact**:
- **HIGH**: Called 60-120+ times per second during slow moves
- Each call makes 2 Accessibility API system calls
- These are the most expensive operations in the critical path

**Fix**: Use cached `initialWindowPosition` + `mouseDelta` to calculate current position without API calls.

### 3. Accessibility API Setters in Move/Resize

**Locations**:
- `moveWindow` (Mover.swift:144-156): 1 setter call per frame
- `resizeWindow` (Mover.swift:107-142): 2 setter calls per frame (position + size)

**Call Frequency**: Every mouse movement event after initialization

**Current Implementation**:
```swift
// resizeWindow - called on every mouse move during resize
case .TopLeft:
    window.position = CGPoint(...)  // ⚠️ AXUIElementSetAttributeValue
    window.size = CGSize(...)       // ⚠️ AXUIElementSetAttributeValue
```

**Performance**:
- Resize: 2 API calls per mouse event (120-240 calls/second)
- Move: 1 API call per mouse event (60-120 calls/second)

**Potential Optimization**:
- Medium priority (API calls are necessary for functionality)
- Could throttle updates to every other frame or every 16ms
- Trade-off: Slightly less responsive for significant CPU reduction

### 4. Mouse Speed Tracking

**Location**: `Mover.swift:66-79` (`trackMouseSpeed`)

**Call Frequency**: Every mouse movement event after first move

**Current Implementation**:
```swift
private func trackMouseSpeed(curMousePos: CGPoint) {
    if let prevMousePos = self.prevMousePosition, let scale = self.scaleFactor {
        let mouseDist: CGFloat = sqrt(                           // ✓ Fast
            pow((curMousePos.x - prevMousePos.x) / scale, 2) +   // ✓ Fast
            pow((curMousePos.y - prevMousePos.y) / scale, 2))
        let now = Date()                                          // ⚠️ Minor: Allocation
        let timeDiff: CGFloat = CGFloat(now.timeIntervalSince(prevDate))
        let latestMouseSpeed = mouseDist / timeDiff
        self.mouseSpeed = latestMouseSpeed * 0.1 + self.mouseSpeed * 0.9
        self.prevMousePosition = curMousePos
        self.prevDate = now
    }
}
```

**Issues**:
1. **Date() allocation** on every call (minor)
2. **Unnecessary calculation** when window is already outside frame (minor)

**Potential Optimizations**:
- Use `CACurrentMediaTime()` instead of `Date()` (no allocation, monotonic)
- Skip tracking if window is already outside frame and `mouseSpeed > threshold`

### 5. Window Lookup via Element Traversal

**Location**: `AccessibilityElement.swift:37-48` (`window()`)

**Call Frequency**: Once per drag/resize operation (when `self.window == nil`)

**Current Implementation**:
```swift
func window() -> Self? {
    var element = self
    while element.role() != kAXWindowRole {  // ⚠️ API call per iteration
        if let nextElement = element.parent() {  // ⚠️ API call
            element = nextElement
        } else {
            return nil
        }
    }
    return element
}
```

**Performance**: Depends on element hierarchy depth. Typically 2-5 iterations.

**Impact**: Low (only called once per operation, not in tight loop)

## Optimization History

### ✅ Priority 1: Fix `windowInsideFrame` (IMPLEMENTED)

**Problem**: Made 2 Accessibility API calls per mouse event

**Solution**: Use cached values + mouseDelta to calculate current bounds

```swift
private func windowInsideFrame(_ window: AccessibilityElement, _ frame: CGRect) -> Bool {
    // Use cached initial values instead of querying API
    if let initPos = self.initialWindowPosition, let initSize = self.initialWindowSize,
       let initMouse = self.initialMousePosition {
        let currentMousePos = Mouse.currentPosition()
        let mouseDelta = CGPoint(x: currentMousePos.x - initMouse.x,
                                 y: currentMousePos.y - initMouse.y)
        let currentPos = CGPoint(x: initPos.x + mouseDelta.x,
                                 y: initPos.y + mouseDelta.y)
        return frame.contains(NSMakeRect(currentPos.x, currentPos.y,
                                        initSize.width, initSize.height))
    }
    return true
}
```

**Impact**: Eliminated 120-240 Accessibility API calls per second during slow moves

**Commit**: e1b663a

### ✅ Priority 2: Replace Date() with CACurrentMediaTime() (IMPLEMENTED)

**Problem**: Allocated Date object on every mouse move

**Solution**: Use Core Animation's monotonic timer

```swift
import QuartzCore  // Added to imports

// In Mover class:
private var prevTime: CFTimeInterval = CACurrentMediaTime()

// In trackMouseSpeed:
let now = CACurrentMediaTime()
let timeDiff: CGFloat = CGFloat(now - prevTime)
// ... rest of calculation
self.prevTime = now
```

**Impact**: Eliminated 60-120 allocations per second

**Commit**: f3b3d85

## Remaining Optimization Opportunities

### Priority 3: Skip Speed Tracking When Unnecessary (LOW-MEDIUM IMPACT)

**Current Problem**: Tracks speed even when window is outside frame and moving fast

**Solution**: Add early return

```swift
private func trackMouseSpeed(curMousePos: CGPoint) {
    // Skip if we're already outside and moving fast (constraint won't apply anyway)
    if self.mouseSpeed > FAST_MOUSE_SPEED_THRESHOLD,
       let frame = self.frame, let window = self.window,
       !windowInsideFrame(window, frame) {
        return
    }

    // ... existing tracking code
}
```

**Expected Impact**: Reduces CPU usage during fast movements outside screen

**Trade-off**: Speed tracking stops once outside, preventing re-constraint if you slow down outside

### Priority 4: Throttle Accessibility API Setters (OPTIONAL)

**Current Problem**: Sets window position/size on every mouse event (60-120+ times/sec)

**Solution**: Throttle to every Nth frame or every 16ms

```swift
private var lastUpdateTime: CFTimeInterval = 0
private let UPDATE_INTERVAL: CFTimeInterval = 0.016  // ~60fps

private func moveWindow(window: AccessibilityElement, mouseDelta: CGPoint) {
    let now = CACurrentMediaTime()
    guard now - lastUpdateTime >= UPDATE_INTERVAL else { return }
    lastUpdateTime = now

    // ... existing move logic
}
```

**Expected Impact**: Reduces API calls by 50-90% depending on mouse polling rate

**Trade-off**: Slightly less responsive window movement (not recommended unless CPU usage is critical)

## Performance Measurement Recommendations

To validate optimizations, add instrumentation:

```swift
import os.signpost

let performanceLog = OSLog(subsystem: "com.keithsmiley.ModMove", category: "Performance")

// In mouseMoved:
os_signpost(.begin, log: performanceLog, name: "MouseMove")
// ... existing code
os_signpost(.end, log: performanceLog, name: "MouseMove")
```

Then use Instruments (Time Profiler or os_signpost) to measure before/after.

## Implementation Status

| Optimization | Status | Impact | Improvement |
|-------------|--------|--------|-------------|
| Fix `windowInsideFrame` | ✅ Implemented (e1b663a) | **HIGH** | 120-240 fewer API calls/sec |
| Use `CACurrentMediaTime()` | ✅ Implemented (f3b3d85) | Medium | 60-120 fewer allocations/sec |
| Skip speed tracking | ⏸️ Not implemented | Low-Medium | Would reduce math ops |
| Throttle setters | ⏸️ Not implemented | Medium | Would save 60-120 API calls/sec |

**Notes**:
- Priorities 1 and 2 provide significant performance improvements with no downsides
- Priority 3 has behavioral tradeoffs (no re-constraint when slowing down outside screen)
- Priority 4 would reduce responsiveness slightly, only worth it if CPU usage is still an issue

## Code Quality Notes

**Strengths**:
- Clean separation of concerns
- Good use of Swift optionals for safety
- Proper state management and cleanup

**Potential Improvements**:
- Add performance instrumentation points
- Consider caching screen frame (currently recalculated on every operation)
- Could extract constraint logic into separate struct for testability

## Additional Observations

1. **Screen frame calculation** (line 81-88): Called once per operation, negligible impact
2. **Corner detection** (line 90-105): Called once per operation, negligible impact
3. **Observer.swift**: Efficient, no optimizations needed
4. **AccessibilityElement.swift**: Wrapper is thin and efficient

The custom changes John made (corner-based resize, speed tracking, boundary constraints) are well-implemented. The main optimization opportunity is reducing redundant Accessibility API calls in the hot path.
