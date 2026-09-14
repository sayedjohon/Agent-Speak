import Cocoa
import CoreGraphics

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
    
    private let filterX = OneEuroFilter(minCutoff: 1.2, beta: 0.008)
    private let filterY = OneEuroFilter(minCutoff: 1.2, beta: 0.008)
    
    public var cursorSpeed: CGFloat = 1.2
    public var smoothingFactor: Double = 0.85 {
        didSet {
            let betaVal = max(0.001, (1.0 - smoothingFactor) * 0.05)
            filterX.updateParameters(minCutoff: 1.0, beta: betaVal)
            filterY.updateParameters(minCutoff: 1.0, beta: betaVal)
        }
    }
    
    public private(set) var isDragging: Bool = false
    public private(set) var currentCursorPoint: CGPoint = .zero
    private var lastClickTime: TimeInterval = 0
    private var clickCount: Int64 = 1
    
    // Interaction active zone boundaries (center 65% of camera FOV)
    private let minNormX: CGFloat = 0.18
    private let maxNormX: CGFloat = 0.82
    private let minNormY: CGFloat = 0.18
    private let maxNormY: CGFloat = 0.82
    
    private init() {
        currentCursorPoint = NSEvent.mouseLocation
    }
    
    public func resetSmoothing() {
        filterX.reset()
        filterY.reset()
    }
    
    // MARK: - Coordinate Transformation
    public func mapCameraPointToScreen(normX: CGFloat, normY: CGFloat) -> CGPoint {
        guard let screen = NSScreen.main else {
            return CGPoint(x: 500, y: 500)
        }
        
        let screenFrame = screen.frame
        let screenW = screenFrame.width
        let screenH = screenFrame.height
        
        // Mirror horizontally so moving right hand right moves cursor right
        let mirroredX = 1.0 - normX
        
        // Clamp to active interaction zone
        let clampedX = max(minNormX, min(maxNormX, mirroredX))
        let clampedY = max(minNormY, min(maxNormY, normY))
        
        // Normalize 0.0...1.0 inside active zone
        let relativeX = (clampedX - minNormX) / (maxNormX - minNormX)
        var relativeY = (clampedY - minNormY) / (maxNormY - minNormY)
        
        // Vision Y coordinates are 0 at bottom, 1 at top. macOS coordinates have 0 at bottom.
        // Invert Y for standard top-down cursor feel
        relativeY = 1.0 - relativeY
        
        // Apply smooth acceleration curve
        let centeredX = relativeX - 0.5
        let centeredY = relativeY - 0.5
        let acceleratedX = 0.5 + (centeredX * cursorSpeed)
        let acceleratedY = 0.5 + (centeredY * cursorSpeed)
        
        let rawTargetX = max(0.0, min(1.0, acceleratedX)) * screenW
        let rawTargetY = max(0.0, min(1.0, acceleratedY)) * screenH
        
        // Apply One-Euro Adaptive Filter
        let now = Date().timeIntervalSince1970
        let filteredX = filterX.filter(value: Double(rawTargetX), timestamp: now)
        let filteredY = filterY.filter(value: Double(rawTargetY), timestamp: now)
        
        // Flip target Y for CGEvent (CGEvent uses top-left origin = 0,0)
        let cgY = screenH - CGFloat(filteredY)
        return CGPoint(x: CGFloat(filteredX), y: cgY)
    }
    
    // MARK: - Movement
    public func moveCursor(to targetPoint: CGPoint) {
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
        let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: pos, mouseButton: .right)
        down?.post(tap: .cghidEventTap)
        
        usleep(15000)
        
        let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: pos, mouseButton: .right)
        up?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Smooth Scroll
    public func scroll(deltaX: CGFloat, deltaY: CGFloat) {
        let scaledY = Int32(-deltaY * 18.0)
        let scaledX = Int32(-deltaX * 18.0)
        
        guard scaledY != 0 || scaledX != 0 else { return }
        
        let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 2,
            wheel1: scaledY,
            wheel2: scaledX,
            wheel3: 0
        )
        scrollEvent?.post(tap: .cghidEventTap)
    }
}
