import Foundation
import CoreGraphics
import Vision

// MARK: - Hand Skeleton Data
public struct HandSkeletonData: Identifiable {
    public var id = UUID()
    public var isRightHand: Bool
    public var confidence: Float
    
    public var wrist: CGPoint
    public var thumbTip: CGPoint
    public var indexTip: CGPoint
    public var middleTip: CGPoint
    public var ringTip: CGPoint
    public var littleTip: CGPoint
    
    public var thumbIP: CGPoint
    public var indexPIP: CGPoint
    public var middlePIP: CGPoint
    public var ringPIP: CGPoint
    public var littlePIP: CGPoint
    
    public var thumbMP: CGPoint
    public var indexMCP: CGPoint
    public var middleMCP: CGPoint
    public var ringMCP: CGPoint
    public var littleMCP: CGPoint
    
    public var allJoints: [String: CGPoint] = [:]
}

// MARK: - Gesture Types
public enum RecognizedGestureType: String, CaseIterable, Identifiable {
    case none = "None"
    case hoverPointer = "Move Cursor"
    case leftClick = "Left Click"
    case clickAndDrag = "Click & Drag"
    case rightClick = "Right Click"
    case doubleClick = "Double Click"
    case smoothScroll = "Scroll"
    case whisperFlowHold = "Whisper Dictation (Hold ⌘)"
    case returnKey = "Return / Submit"
    case copy = "Copy (⌘C)"
    case paste = "Paste (⌘V)"
    case cut = "Cut (⌘X)"
    case undo = "Undo (⌘Z)"
    case redo = "Redo (⌘⇧Z)"
    case selectAll = "Select All (⌘A)"
    case escape = "Escape / Dismiss"
    case missionControl = "Mission Control"
    case clutch = "Standby (Clutch)"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .none: return "hand.raised"
        case .hoverPointer: return "cursorarrow.motionlines"
        case .leftClick: return "hand.tap.fill"
        case .clickAndDrag: return "hand.draw.fill"
        case .rightClick: return "contextualmenu.and.cursor"
        case .doubleClick: return "arrow.turn.down.right"
        case .smoothScroll: return "arrow.up.and.down"
        case .whisperFlowHold: return "waveform.badge.mic"
        case .returnKey: return "return"
        case .copy: return "doc.on.doc"
        case .paste: return "doc.on.clipboard"
        case .cut: return "scissors"
        case .undo: return "arrow.uturn.backward"
        case .redo: return "arrow.uturn.forward"
        case .selectAll: return "selection.pin.in.out"
        case .escape: return "xmark.circle"
        case .missionControl: return "macwindow.on.rectangle"
        case .clutch: return "pause.circle.fill"
        }
    }
}

// MARK: - Gesture Classifier Engine
public class GestureClassifier {
    public static let shared = GestureClassifier()
    
    public var pinchThreshold: CGFloat = 0.055
    public var scrollSensitivity: CGFloat = 1.0
    
    // Right hand tracking state
    private var isRightPinched: Bool = false
    private var rightPinchStartTime: TimeInterval = 0
    private var isDraggingActive: Bool = false
    private var lastRightPinchReleaseTime: TimeInterval = 0
    private var lastScrollPoint: CGPoint?
    
    // Left hand tracking state
    private var isLeftFistHolding: Bool = false
    private var lastLeftReturnTime: TimeInterval = 0
    private var lastLeftCopyTime: TimeInterval = 0
    private var lastLeftPasteTime: TimeInterval = 0
    private var lastLeftCutTime: TimeInterval = 0
    private var lastLeftUndoTime: TimeInterval = 0
    private var lastLeftEscTime: TimeInterval = 0
    private var lastLeftSelectAllTime: TimeInterval = 0
    private var lastMissionControlTime: TimeInterval = 0
    
    // Hand motion history for swipe detection
    private var leftWristHistory: [(point: CGPoint, time: TimeInterval)] = []
    
    private init() {}
    
    public func reset() {
        if isDraggingActive {
            MouseCursorController.shared.endDrag()
            isDraggingActive = false
        }
        if isLeftFistHolding {
            KeyboardShortcutController.shared.setWhisperModifierHold(active: false)
            isLeftFistHolding = false
        }
        isRightPinched = false
        lastScrollPoint = nil
        leftWristHistory.removeAll()
    }
    
    // MARK: - Euclidean Geometry Helpers
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func isFingerExtended(tip: CGPoint, pip: CGPoint, wrist: CGPoint, factor: CGFloat = 1.15) -> Bool {
        return distance(wrist, tip) > distance(wrist, pip) * factor
    }
    
    private func isThumbExtended(tip: CGPoint, ip: CGPoint, wrist: CGPoint) -> Bool {
        return distance(wrist, tip) > distance(wrist, ip) * 1.12
    }
    
    // MARK: - Process Hands Frame
    public func processHands(
        hands: [HandSkeletonData],
        onGestureDetected: ((RecognizedGestureType, String) -> Void)?
    ) {
        let now = Date().timeIntervalSince1970
        
        // Find right and left hands
        let rightHand = hands.first(where: { $0.isRightHand })
        let leftHand = hands.first(where: { !$0.isRightHand })
        
        // 1. Process Right Hand (Mouse & Pointer Operations)
        if let right = rightHand {
            processRightHand(right, now: now, onGestureDetected: onGestureDetected)
        } else {
            if isDraggingActive {
                MouseCursorController.shared.endDrag()
                isDraggingActive = false
            }
            isRightPinched = false
            lastScrollPoint = nil
        }
        
        // 2. Process Left Hand (Shortcuts, Modifiers & Dictation Flow)
        if let left = leftHand {
            processLeftHand(left, now: now, onGestureDetected: onGestureDetected)
        } else {
            if isLeftFistHolding {
                KeyboardShortcutController.shared.setWhisperModifierHold(active: false)
                isLeftFistHolding = false
                onGestureDetected?(.whisperFlowHold, "Whisper Command Released")
            }
        }
    }
    
    // MARK: - Right Hand Processing (Pointer, Click, Drag, Scroll)
    private func processRightHand(
        _ hand: HandSkeletonData,
        now: TimeInterval,
        onGestureDetected: ((RecognizedGestureType, String) -> Void)?
    ) {
        let indexExt = isFingerExtended(tip: hand.indexTip, pip: hand.indexPIP, wrist: hand.wrist)
        let middleExt = isFingerExtended(tip: hand.middleTip, pip: hand.middlePIP, wrist: hand.wrist)
        let ringExt = isFingerExtended(tip: hand.ringTip, pip: hand.ringPIP, wrist: hand.wrist)
        let littleExt = isFingerExtended(tip: hand.littleTip, pip: hand.littlePIP, wrist: hand.wrist)
        let thumbExt = isThumbExtended(tip: hand.thumbTip, ip: hand.thumbIP, wrist: hand.wrist)
        
        let indexThumbDist = distance(hand.thumbTip, hand.indexTip)
        let middleThumbDist = distance(hand.thumbTip, hand.middleTip)
        
        // Safety Clutch: If thumb is tightly tucked inside a closed fist, pause tracking
        if !indexExt && !middleExt && !ringExt && !littleExt && !thumbExt {
            onGestureDetected?(.clutch, "Right Hand Standby")
            return
        }
        
        // A. Smooth Two-Finger Scroll: Both Index and Middle extended side-by-side, Ring & Pinky curled
        if indexExt && middleExt && !ringExt && !littleExt && distance(hand.indexTip, hand.middleTip) < 0.08 {
            let currentPoint = CGPoint(x: (hand.indexTip.x + hand.middleTip.x) / 2.0,
                                       y: (hand.indexTip.y + hand.middleTip.y) / 2.0)
            if let prev = lastScrollPoint {
                let dx = (currentPoint.x - prev.x) * scrollSensitivity
                let dy = (currentPoint.y - prev.y) * scrollSensitivity
                MouseCursorController.shared.scroll(deltaX: dx, deltaY: dy)
                onGestureDetected?(.smoothScroll, "Scrolling")
            }
            lastScrollPoint = currentPoint
            return
        } else {
            lastScrollPoint = nil
        }
        
        // Map target screen coordinates from index tip
        let screenPoint = MouseCursorController.shared.mapCameraPointToScreen(
            normX: hand.indexTip.x,
            normY: hand.indexTip.y
        )
        
        // B. Right Click: Middle Finger + Thumb Pinch
        if middleThumbDist < pinchThreshold && indexExt {
            if now - lastRightPinchReleaseTime > 0.45 {
                MouseCursorController.shared.rightClick(at: screenPoint)
                lastRightPinchReleaseTime = now
                onGestureDetected?(.rightClick, "Right Click")
            }
            return
        }
        
        // C. Left Click & Drag State Machine (Index + Thumb Pinch)
        let isCurrentlyPinched = (indexThumbDist < pinchThreshold)
        
        if isCurrentlyPinched {
            if !isRightPinched {
                // Pinch just started
                isRightPinched = true
                rightPinchStartTime = now
            } else {
                // Pinch is being held
                let holdDuration = now - rightPinchStartTime
                if holdDuration > 0.22 && !isDraggingActive {
                    // Transition to Drag & Drop
                    isDraggingActive = true
                    MouseCursorController.shared.startDrag(at: screenPoint)
                    onGestureDetected?(.clickAndDrag, "Drag Started")
                }
            }
            
            if isDraggingActive {
                MouseCursorController.shared.moveCursor(to: screenPoint)
                onGestureDetected?(.clickAndDrag, "Dragging...")
            }
        } else {
            if isRightPinched {
                // Pinch just released
                let pinchDuration = now - rightPinchStartTime
                if isDraggingActive {
                    MouseCursorController.shared.endDrag(at: screenPoint)
                    isDraggingActive = false
                    onGestureDetected?(.clickAndDrag, "Drag Released")
                } else if pinchDuration < 0.28 {
                    // Quick release -> Single or Double Left Click
                    MouseCursorController.shared.leftClick(at: screenPoint)
                    onGestureDetected?(.leftClick, "Left Click")
                }
                isRightPinched = false
                lastRightPinchReleaseTime = now
            } else {
                // Free Pointer Movement
                MouseCursorController.shared.moveCursor(to: screenPoint)
                onGestureDetected?(.hoverPointer, "Hover")
            }
        }
    }
    
    // MARK: - Left Hand Processing (Whisper Flow, Return, Shortcuts)
    private func processLeftHand(
        _ hand: HandSkeletonData,
        now: TimeInterval,
        onGestureDetected: ((RecognizedGestureType, String) -> Void)?
    ) {
        let indexExt = isFingerExtended(tip: hand.indexTip, pip: hand.indexPIP, wrist: hand.wrist)
        let middleExt = isFingerExtended(tip: hand.middleTip, pip: hand.middlePIP, wrist: hand.wrist)
        let ringExt = isFingerExtended(tip: hand.ringTip, pip: hand.ringPIP, wrist: hand.wrist)
        let littleExt = isFingerExtended(tip: hand.littleTip, pip: hand.littlePIP, wrist: hand.wrist)
        let thumbExt = isThumbExtended(tip: hand.thumbTip, ip: hand.thumbIP, wrist: hand.wrist)
        
        let indexThumbDist = distance(hand.thumbTip, hand.indexTip)
        
        // Track wrist history for swipe velocity (last 0.4 seconds)
        leftWristHistory.append((point: hand.wrist, time: now))
        leftWristHistory.removeAll(where: { now - $0.time > 0.4 })
        
        var swipeDx: CGFloat = 0.0
        var swipeDy: CGFloat = 0.0
        if let oldest = leftWristHistory.first {
            swipeDx = hand.wrist.x - oldest.point.x
            swipeDy = hand.wrist.y - oldest.point.y
        }
        
        // 1. Mission Control: 4 or 5 fingers extended, rapid upward swipe
        if indexExt && middleExt && ringExt && littleExt && swipeDy > 0.16 && now - lastMissionControlTime > 1.2 {
            KeyboardShortcutController.shared.sendMissionControl()
            lastMissionControlTime = now
            onGestureDetected?(.missionControl, "Mission Control")
            return
        }
        
        // 2. Escape: Open Palm Stop Gesture (all 5 fingers extended, facing forward, stationary)
        if indexExt && middleExt && ringExt && littleExt && thumbExt && abs(swipeDx) < 0.05 && abs(swipeDy) < 0.05 {
            if now - lastLeftEscTime > 1.0 {
                KeyboardShortcutController.shared.sendEscape()
                lastLeftEscTime = now
                onGestureDetected?(.escape, "Escape / Dismiss")
            }
            return
        }
        
        // 3. Whisper Flow Dictation Hold: CLOSED FIST (all 4 fingers curled)
        let isClosedFist = (!indexExt && !middleExt && !ringExt && !littleExt)
        if isClosedFist {
            if !isLeftFistHolding {
                isLeftFistHolding = true
                KeyboardShortcutController.shared.setWhisperModifierHold(active: true)
                onGestureDetected?(.whisperFlowHold, "Holding ⌘ (Whisper Dictation)")
            } else {
                onGestureDetected?(.whisperFlowHold, "Dictating...")
            }
            return
        } else {
            if isLeftFistHolding {
                // Released fist -> release Command key immediately!
                isLeftFistHolding = false
                KeyboardShortcutController.shared.setWhisperModifierHold(active: false)
                onGestureDetected?(.whisperFlowHold, "Released ⌘ (Transcription Pasting)")
            }
        }
        
        // 4. Return / Enter Key: Quick Left Index-Thumb Pinch OR Index Point Down
        if indexThumbDist < pinchThreshold && !middleExt && !ringExt && !littleExt {
            if now - lastLeftReturnTime > 0.5 {
                KeyboardShortcutController.shared.sendReturn()
                lastLeftReturnTime = now
                onGestureDetected?(.returnKey, "Return ↵ (Sent Query)")
            }
            return
        }
        
        // 5. Paste (Cmd + V): Peace / V-Sign (Index + Middle extended, Ring + Pinky curled, fingers separated)
        if indexExt && middleExt && !ringExt && !littleExt && distance(hand.indexTip, hand.middleTip) > 0.06 {
            if now - lastLeftPasteTime > 0.6 {
                KeyboardShortcutController.shared.sendPaste()
                lastLeftPasteTime = now
                onGestureDetected?(.paste, "Paste (⌘V)")
            }
            return
        }
        
        // 6. Undo (Cmd + Z) & Redo (Cmd + Shift + Z) via Horizontal Swipe
        if (indexExt || thumbExt) && !ringExt && !littleExt {
            if swipeDx > 0.18 && now - lastLeftUndoTime > 0.8 {
                // Left camera swipe right = mirrored left movement -> Undo
                KeyboardShortcutController.shared.sendUndo()
                lastLeftUndoTime = now
                onGestureDetected?(.undo, "Undo (⌘Z)")
                return
            } else if swipeDx < -0.18 && now - lastLeftUndoTime > 0.8 {
                // Redo
                KeyboardShortcutController.shared.sendRedo()
                lastLeftUndoTime = now
                onGestureDetected?(.redo, "Redo (⌘⇧Z)")
                return
            }
        }
        
        // 7. Select All (Cmd + A): 3 Fingers Extended (Thumb, Index, Middle)
        if thumbExt && indexExt && middleExt && !ringExt && !littleExt && indexThumbDist > 0.10 {
            if now - lastLeftSelectAllTime > 0.8 {
                KeyboardShortcutController.shared.sendSelectAll()
                lastLeftSelectAllTime = now
                onGestureDetected?(.selectAll, "Select All (⌘A)")
            }
            return
        }
        
        // 8. Copy (Cmd + C): Left Hand "C" Shape (Thumb & Index curved towards each other, distance ~ 0.07...0.12)
        if indexExt && thumbExt && !ringExt && !littleExt && indexThumbDist >= 0.065 && indexThumbDist <= 0.13 {
            if now - lastLeftCopyTime > 0.8 {
                KeyboardShortcutController.shared.sendCopy()
                lastLeftCopyTime = now
                onGestureDetected?(.copy, "Copy (⌘C)")
            }
            return
        }
    }
}
