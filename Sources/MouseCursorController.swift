import Cocoa
import CoreGraphics
import AudioToolbox

// MARK: - One-Euro Filter for Jitter-Free Cursor Motion
public class OneEuroFilter {
    private var minCutoff: Double
    private var beta: Double
    private var dCutoff: Double
    
    private var xPrev: Double?
    private var dxPrev: Double = 0.0
    private var tPrev: TimeInterval?
    
    public init(minCutoff: Double = 1.0, beta: Double = 0.007, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    private func alpha(rate: Double, cutoff: Double) -> Double {
        let tau = 1.0 / (2.0 * Double.pi * cutoff)
        let te = 1.0 / rate
        return 1.0 / (1.0 + tau / te)
    }
    
    public func filter(value: Double, timestamp: TimeInterval) -> Double {
        guard let xPrev = xPrev, let tPrev = tPrev else {
            self.xPrev = value
            self.tPrev = timestamp
            return value
        }
        
        let dt = max(timestamp - tPrev, 0.001)
        let rate = 1.0 / dt
        
        let dx = (value - xPrev) / dt
        let aD = alpha(rate: rate, cutoff: dCutoff)
        let edx = aD * dx + (1.0 - aD) * dxPrev
        dxPrev = edx
        
        let cutoff = minCutoff + beta * abs(edx)
        let a = alpha(rate: rate, cutoff: cutoff)
        let filteredValue = a * value + (1.0 - a) * xPrev
        
        self.xPrev = filteredValue
        self.tPrev = timestamp
        return filteredValue
    }
    
    public func reset() {
        xPrev = nil
        dxPrev = 0.0
        tPrev = nil
    }
    
    public func updateParameters(minCutoff: Double, beta: Double) {
        self.minCutoff = minCutoff
        self.beta = beta
    }
}

// MARK: - Mouse Cursor Controller
public class MouseCursorController {
    public static let shared = MouseCursorController()
    
    private let filterX = OneEuroFilter(minCutoff: 0.35, beta: 0.0022)
    private let filterY = OneEuroFilter(minCutoff: 0.35, beta: 0.0022)
    
    // Landmark pre-filter history for sensor noise suppression
    private var rawXPrev: CGFloat?
    private var rawYPrev: CGFloat?
    
    public var cursorSpeed: CGFloat = 1.2
    public var smoothingFactor: Double = 0.85 {
        didSet {
            let minC = max(0.15, (1.0 - smoothingFactor) * 2.2)
            let betaVal = max(0.0005, (1.0 - smoothingFactor) * 0.012)
            filterX.updateParameters(minCutoff: minC, beta: betaVal)
            filterY.updateParameters(minCutoff: minC, beta: betaVal)
        }
    }
    
    public private(set) var isDragging: Bool = false
    public private(set) var currentCursorPoint: CGPoint = .zero
    private var deltaEMA_X: CGFloat = 0.0
    private var deltaEMA_Y: CGFloat = 0.0
    private var lastClickTime: TimeInterval = 0
    private var clickCount: Int64 = 1
    
    // Interaction active zone boundaries (expanded for natural arm comfort)
    private let minNormX: CGFloat = 0.14
    private let maxNormX: CGFloat = 0.86
    private let minNormY: CGFloat = 0.12
    private let maxNormY: CGFloat = 0.86
    
    private init() {
        currentCursorPoint = NSEvent.mouseLocation
    }
    
    public func resetSmoothing() {
        filterX.reset()
        filterY.reset()
        rawXPrev = nil
        rawYPrev = nil
    }
    
    // Organic curved acceleration: precision near center, smooth reach to screen edges
    private func curvedAcceleration(_ val: CGFloat, speed: CGFloat) -> CGFloat {
        let sign: CGFloat = val >= 0 ? 1.0 : -1.0
        let mag = abs(val) // 0.0 ... 0.5
        let norm = mag * 2.0 // 0.0 ... 1.0
        let accelerated = (0.70 * norm + 0.30 * pow(norm, 1.4)) * 0.5 * speed
        return 0.5 + (sign * accelerated)
    }
    
    // MARK: - Coordinate Transformation
    public func mapCameraPointToScreen(normX: CGFloat, normY: CGFloat) -> CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 500, y: 500)
        }
        
        let screenFrame = screen.frame
        let screenW = screenFrame.width
        let screenH = screenFrame.height
        
        // 1. Smooth raw camera landmark input to discard single-frame camera sensor pop
        let smoothNormX: CGFloat
        let smoothNormY: CGFloat
        if let prevX = rawXPrev, let prevY = rawYPrev {
            smoothNormX = 0.70 * normX + 0.30 * prevX
            smoothNormY = 0.70 * normY + 0.30 * prevY
        } else {
            smoothNormX = normX
            smoothNormY = normY
        }
        rawXPrev = smoothNormX
        rawYPrev = smoothNormY
        
        // 2. Mirror horizontally so moving right hand right moves cursor right
        let mirroredX = 1.0 - smoothNormX
        
        // 3. Clamp to active interaction zone
        let clampedX = max(minNormX, min(maxNormX, mirroredX))
        let clampedY = max(minNormY, min(maxNormY, smoothNormY))
        
        // 4. Normalize 0.0...1.0 inside active zone (Vision Y: 0.0 bottom, 1.0 top)
        let relativeX = (clampedX - minNormX) / (maxNormX - minNormX)
        let relativeY = (clampedY - minNormY) / (maxNormY - minNormY)
        
        // 5. Apply smooth organic acceleration curve
        let centeredX = relativeX - 0.5
        let centeredY = relativeY - 0.5
        let acceleratedX = curvedAcceleration(centeredX, speed: cursorSpeed)
        let acceleratedY = curvedAcceleration(centeredY, speed: cursorSpeed)
        
        let rawTargetX = max(0.0, min(1.0, acceleratedX)) * screenW
        let rawTargetY = max(0.0, min(1.0, acceleratedY)) * screenH
        
        // 6. Apply One-Euro Adaptive Filter on screen coordinates
        let now = Date().timeIntervalSince1970
        let filteredX = filterX.filter(value: Double(rawTargetX), timestamp: now)
        let filteredY = filterY.filter(value: Double(rawTargetY), timestamp: now)
        
        // CGEvent uses top-left origin (Y=0 is top of screen).
        // Since Vision Y is bottom-up (1.0 is top), screenH - filteredY maps hand-up to screen-top!
        let cgY = screenH - CGFloat(filteredY)
        return CGPoint(x: CGFloat(filteredX), y: cgY)
    }
    
    // MARK: - Zero-Drift Pinch Click Anchor Lock
    public private(set) var isCursorLocked: Bool = false
    private var lockedPoint: CGPoint?
    
    public func lockCursorAtCurrentPosition() {
        isCursorLocked = true
        lockedPoint = currentCursorPoint
    }
    
    public func unlockCursor() {
        isCursorLocked = false
        lockedPoint = nil
    }
    
    // MARK: - Movement
    public func moveCursor(to targetPoint: CGPoint) {
        if isCursorLocked && !isDragging, let lock = lockedPoint {
            currentCursorPoint = lock
            return
        }
        
        let dx = targetPoint.x - currentCursorPoint.x
        let dy = targetPoint.y - currentCursorPoint.y
        let dist = sqrt(dx * dx + dy * dy)
        
        // Micro-tremor suppression deadzone:
        // If movement is under 2.2 screen points and not dragging,
        // lock the cursor completely so hovering and clicking are rock-solid!
        if !isDragging && dist < 2.2 {
            return
        }
        
        currentCursorPoint = targetPoint
        
        if isDragging {
            let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: targetPoint, mouseButton: .left)
            event?.post(tap: .cghidEventTap)
        } else {
            let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: targetPoint, mouseButton: .left)
            event?.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Relative Optical Air Mouse Engine
    public func clutchEngaged() {
        if let livePos = CGEvent(source: nil)?.location {
            currentCursorPoint = livePos
        }
        deltaEMA_X = 0.0
        deltaEMA_Y = 0.0
        filterX.reset()
        filterY.reset()
    }
    
    public func clutchDisengaged() {
        deltaEMA_X = 0.0
        deltaEMA_Y = 0.0
        filterX.reset()
        filterY.reset()
    }
    
    public func moveRelative(deltaX: CGFloat, deltaY: CGFloat) {
        if isCursorLocked && !isDragging, let lock = lockedPoint {
            currentCursorPoint = lock
            return
        }
        
        let rawMag = sqrt(deltaX * deltaX + deltaY * deltaY)
        // Adaptive deadzone: completely eliminates webcam landmark tremor (< 0.0012)
        guard rawMag > 0.0012 else { return }
        
        // Double EMA smoothing for silky-smooth motion without lag
        let smoothDx = 0.55 * deltaX + 0.45 * deltaEMA_X
        let smoothDy = 0.55 * deltaY + 0.45 * deltaEMA_Y
        deltaEMA_X = smoothDx
        deltaEMA_Y = smoothDy
        
        let mag = sqrt(smoothDx * smoothDx + smoothDy * smoothDy)
        
        // Dynamic velocity curve:
        // Slow precision targeting: 1400.0 multiplier
        // Fast traversal: smooth ramp up to 2.2x
        let baseMultiplier: CGFloat = 1600.0 * cursorSpeed
        let accel = 1.0 + min(max(0, mag - 0.003) * 20.0, 1.8)
        let screenDx = smoothDx * baseMultiplier * accel
        let screenDy = smoothDy * baseMultiplier * accel
        
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let targetX = max(0, min(screenFrame.width - 1, currentCursorPoint.x + screenDx))
        let targetY = max(0, min(screenFrame.height - 1, currentCursorPoint.y + screenDy))
        let targetPoint = CGPoint(x: targetX, y: targetY)
        
        currentCursorPoint = targetPoint
        
        if isDragging {
            let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: targetPoint, mouseButton: .left)
            event?.post(tap: .cghidEventTap)
        } else {
            let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: targetPoint, mouseButton: .left)
            event?.post(tap: .cghidEventTap)
        }
    }
    
    // MARK: - Left Click & Double Click
    public func leftClick(at point: CGPoint? = nil) {
        let pos = point ?? currentCursorPoint
        let now = Date().timeIntervalSince1970
        
        if now - lastClickTime < 0.35 {
            clickCount = 2
        } else {
            clickCount = 1
        }
        lastClickTime = now
        
        // Subtle acoustic click feedback (native macOS system tick)
        AudioServicesPlaySystemSound(1104)
        
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left)
        down?.setIntegerValueField(.mouseEventClickState, value: clickCount)
        down?.post(tap: .cghidEventTap)
        
        usleep(15000) // 15ms hold
        
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left)
        up?.setIntegerValueField(.mouseEventClickState, value: clickCount)
        up?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Drag & Drop
    public func startDrag(at point: CGPoint? = nil) {
        guard !isDragging else { return }
        let pos = point ?? currentCursorPoint
        isDragging = true
        
        let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: pos, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
    }
    
    public func endDrag(at point: CGPoint? = nil) {
        guard isDragging else { return }
        let pos = point ?? currentCursorPoint
        isDragging = false
        
        let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: pos, mouseButton: .left)
        up?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Right Click
    public func rightClick(at point: CGPoint? = nil) {
        let pos = point ?? currentCursorPoint
        AudioServicesPlaySystemSound(1104)
        
        let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: pos, mouseButton: .right)
        down?.post(tap: .cghidEventTap)
        
        usleep(15000)
        
        let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: pos, mouseButton: .right)
        up?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Smooth Scroll
    private var scrollAccumulatorX: CGFloat = 0.0
    private var scrollAccumulatorY: CGFloat = 0.0
    
    public func resetScroll() {
        scrollAccumulatorX = 0.0
        scrollAccumulatorY = 0.0
    }
    
    public func scroll(deltaX: CGFloat, deltaY: CGFloat) {
        // Multiplier: 1600.0 converts normalized camera deltas (0.002-0.02) to standard macOS scroll pixels (3-35px)
        let multiplier: CGFloat = 1600.0
        
        // Sub-pixel accumulator: Preserves micro-movements across frames so slow gestures never stall
        // In Vision coordinates, dy > 0 is hand moving up -> negative wheel1 scrolls page down (natural scrolling)
        // Camera image is mirrored, dx < 0 is hand moving to user's right -> negative wheel2 scrolls page right
        scrollAccumulatorY += -deltaY * multiplier
        scrollAccumulatorX += deltaX * multiplier
        
        let stepY = Int32(scrollAccumulatorY)
        let stepX = Int32(scrollAccumulatorX)
        
        guard stepY != 0 || stepX != 0 else { return }
        
        scrollAccumulatorY -= CGFloat(stepY)
        scrollAccumulatorX -= CGFloat(stepX)
        
        if stepX == 0 {
            let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 1,
                wheel1: stepY,
                wheel2: 0,
                wheel3: 0
            )
            scrollEvent?.post(tap: .cghidEventTap)
        } else {
            let scrollEvent = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .pixel,
                wheelCount: 2,
                wheel1: stepY,
                wheel2: stepX,
                wheel3: 0
            )
            scrollEvent?.post(tap: .cghidEventTap)
        }
    }
}
