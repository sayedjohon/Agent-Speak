import Foundation
import CoreGraphics
import Vision

// MARK: - Hand Skeleton Data
public struct HandSkeletonData: Identifiable {
    public var id = UUID()
    public var isRightHand: Bool
    public var isIntentional: Bool = true
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

// MARK: - Granular Gesture Toggles
public struct GestureToggles: Codable, Equatable {
    public var airMouse: Bool = true        // Right: Point index finger to move cursor
    public var leftClick: Bool = true       // Right: Quick pinch index & thumb
    public var clickAndDrag: Bool = false   // Right: Pinch and hold to drag
    public var rightClick: Bool = false     // Right: Middle finger extended tap
    public var smoothScroll: Bool = false   // Right: Two fingers extended scroll
    public var leftDictation: Bool = false  // Left: Closed fist hold for Groq Whisper dictation
    public var leftReturn: Bool = false     // Left: Index-thumb pinch for Enter ↵
    public var leftShortcuts: Bool = false  // Left: Peace / V-sign for Paste ⌘V
    
    public init(
        airMouse: Bool = true,
        leftClick: Bool = true,
        clickAndDrag: Bool = false,
        rightClick: Bool = false,
        smoothScroll: Bool = false,
        leftDictation: Bool = false,
        leftReturn: Bool = false,
        leftShortcuts: Bool = false
    ) {
        self.airMouse = airMouse
        self.leftClick = leftClick
        self.clickAndDrag = clickAndDrag
        self.rightClick = rightClick
        self.smoothScroll = smoothScroll
        self.leftDictation = leftDictation
        self.leftReturn = leftReturn
        self.leftShortcuts = leftShortcuts
    }
}

// MARK: - Gesture Classifier Engine
public class GestureClassifier: ObservableObject {
    public static let shared = GestureClassifier()
    
    @Published public var toggles: GestureToggles = GestureToggles()
    
    public var pinchThreshold: CGFloat = 0.055
    public var scrollSensitivity: CGFloat = 1.0
    public var trackingAnchor: String = "wrist" // "wrist", "indexMCP", "indexTip"
    public var wristElevationThreshold: CGFloat = 0.0 // Lower area cutoff removed
    
    // Right hand tracking state
    private var isRightPinched: Bool = false
    private var rightPinchStartTime: TimeInterval = 0
    private var isDraggingActive: Bool = false
    private var lastRightPinchReleaseTime: TimeInterval = 0
    private var lastScrollPoint: CGPoint?
    private var lastRelativeAnchor: CGPoint?
    private var smoothedAnchorPt: CGPoint = .zero
    private var hasAnchorHistory: Bool = false
    
    // Left hand tracking state
    private var isLeftFistHolding: Bool = false
    private var lastDictationEndTime: TimeInterval = 0
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
    
    private init() {
        loadToggles()
    }
    
    public func loadToggles() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gestures = json["gestures"] as? [String: Any] else {
            return
        }
        guard let t = gestures["toggles"] as? [String: Any] else {
            saveToggles()
            return
        }
        if let v = t["air_mouse"] as? Bool { toggles.airMouse = v }
        if let v = t["left_click"] as? Bool { toggles.leftClick = v }
        if let v = t["click_and_drag"] as? Bool { toggles.clickAndDrag = v }
        if let v = t["right_click"] as? Bool { toggles.rightClick = v }
        if let v = t["smooth_scroll"] as? Bool { toggles.smoothScroll = v }
        if let v = t["left_dictation"] as? Bool { toggles.leftDictation = v }
        if let v = t["left_return"] as? Bool { toggles.leftReturn = v }
        if let v = t["left_shortcuts"] as? Bool { toggles.leftShortcuts = v }
    }
    
    public func saveToggles() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }
        var gestures: [String: Any] = json["gestures"] as? [String: Any] ?? [:]
        var t: [String: Any] = [:]
        t["air_mouse"] = toggles.airMouse
        t["left_click"] = toggles.leftClick
        t["click_and_drag"] = toggles.clickAndDrag
        t["right_click"] = toggles.rightClick
        t["smooth_scroll"] = toggles.smoothScroll
        t["left_dictation"] = toggles.leftDictation
        t["left_return"] = toggles.leftReturn
        t["left_shortcuts"] = toggles.leftShortcuts
        gestures["toggles"] = t
        json["gestures"] = gestures
        
        if let outData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) {
            try? outData.write(to: configPath)
        }
    }
    
    public func resetToDefaults() {
        toggles = GestureToggles(
            airMouse: true,
            leftClick: true,
            clickAndDrag: false,
            rightClick: false,
            smoothScroll: false,
            leftDictation: false,
            leftReturn: false,
            leftShortcuts: false
        )
        saveToggles()
    }
    
    public func reset() {
        if isDraggingActive {
            MouseCursorController.shared.endDrag()
            isDraggingActive = false
        }
        if isRightPinched {
            isRightPinched = false
            MouseCursorController.shared.unlockCursor()
        }
        if isLeftFistHolding {
            KeyboardShortcutController.shared.releaseAllHeldModifiers()
            GroqWhisperManager.shared.stopRecordingAndTranscribe()
            isLeftFistHolding = false
            lastDictationEndTime = Date().timeIntervalSince1970
        }
        lastScrollPoint = nil
        lastRelativeAnchor = nil
        MouseCursorController.shared.resetScroll()
        MouseCursorController.shared.clutchDisengaged()
        hasAnchorHistory = false
        smoothedAnchorPt = .zero
        leftWristHistory.removeAll()
        MouseCursorController.shared.resetSmoothing()
    }
    
    // MARK: - Hand Intentionality & Verification
    public func isIntentionalHand(_ hand: HandSkeletonData) -> Bool {
        // 1. Overall confidence check: Ignore low-confidence camera noise
        guard hand.confidence >= 0.30 else { return false }
        
        // 2. Hand Span / Perspective Sanity: Ignore tiny background specks
        let handSpan = distance(hand.wrist, hand.middleMCP)
        guard handSpan >= 0.04 && handSpan <= 0.70 else { return false }
        
        return true
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
        
        // Strict Gating: Reject hands resting on the keyboard or in downward typing postures
        let activeHands = hands.filter { isIntentionalHand($0) }
        
        // If no intentional hands are in view, immediately dismiss any floating HUD
        if activeHands.isEmpty {
            GestureHUDState.shared.hide()
        }
        
        // Spatially separated hands: Right hand on camera-left, Left hand on camera-right
        let rightHand = activeHands.first(where: { $0.isRightHand })
        let leftHand = activeHands.first(where: { !$0.isRightHand })
        
        // 1. Process Left Hand FIRST (Dictation & Shortcuts ONLY - Never moves mouse or clicks)
        if let left = leftHand {
            processLeftHand(left, now: now, onGestureDetected: onGestureDetected)
        } else {
            if isLeftFistHolding {
                isLeftFistHolding = false
                lastDictationEndTime = now
                KeyboardShortcutController.shared.releaseAllHeldModifiers()
                GroqWhisperManager.shared.stopRecordingAndTranscribe()
                onGestureDetected?(.whisperFlowHold, "Transcribing speech...")
            }
            leftWristHistory.removeAll()
        }
        
        // 2. CRITICAL DICTATION IMMUNITY GUARD:
        // When left hand is dictating (fist held) or transcribing, OR during the 1.5s post-dictation cooldown,
        // completely FREEZE and ignore all right-hand cursor movements, clicks, and drags!
        // This guarantees that the user's active edit cursor is NEVER deselected or moved!
        if isLeftFistHolding || GroqWhisperManager.shared.isRecording || GroqWhisperManager.shared.isTranscribing || (now - lastDictationEndTime < 1.5) {
            if isDraggingActive {
                MouseCursorController.shared.endDrag()
                isDraggingActive = false
            }
            if isRightPinched {
                isRightPinched = false
                MouseCursorController.shared.unlockCursor()
            }
            lastScrollPoint = nil
            lastRelativeAnchor = nil
            MouseCursorController.shared.clutchDisengaged()
            return
        }
        
        // 3. Process Right Hand (Optical Air Mouse - Pointing Pose ONLY)
        if let right = rightHand {
            processRightHand(right, now: now, onGestureDetected: onGestureDetected)
        } else {
            if isDraggingActive {
                MouseCursorController.shared.endDrag()
                isDraggingActive = false
            }
            if isRightPinched {
                isRightPinched = false
                MouseCursorController.shared.unlockCursor()
            }
            if lastScrollPoint != nil {
                MouseCursorController.shared.resetScroll()
            }
            lastScrollPoint = nil
            lastRelativeAnchor = nil
            MouseCursorController.shared.clutchDisengaged()
            MouseCursorController.shared.resetSmoothing()
        }
    }
    
    // MARK: - Right Hand Processing (Point-to-Move, Pinch Click, Scroll)
    private func processRightHand(
        _ hand: HandSkeletonData,
        now: TimeInterval,
        onGestureDetected: ((RecognizedGestureType, String) -> Void)?
    ) {
        let indexLen = distance(hand.wrist, hand.indexTip)
        let middleLen = distance(hand.wrist, hand.middleTip)
        let ringLen = distance(hand.wrist, hand.ringTip)
        let littleLen = distance(hand.wrist, hand.littleTip)
        
        let indexExt = isFingerExtended(tip: hand.indexTip, pip: hand.indexPIP, wrist: hand.wrist, factor: 1.15)
        let middleExt = isFingerExtended(tip: hand.middleTip, pip: hand.middlePIP, wrist: hand.wrist, factor: 1.05)
        let ringExt = isFingerExtended(tip: hand.ringTip, pip: hand.ringPIP, wrist: hand.wrist, factor: 1.05)
        let littleExt = isFingerExtended(tip: hand.littleTip, pip: hand.littlePIP, wrist: hand.wrist, factor: 1.05)
        
        let indexThumbDist = distance(hand.thumbTip, hand.indexTip)
        let middleThumbDist = distance(hand.thumbTip, hand.middleTip)
        
        // A. Two-Finger Scroll: Both Index and Middle extended side-by-side, Ring + Pinky curled
        let isScrollPose = indexExt && middleExt && !ringExt && !littleExt &&
                           (distance(hand.indexTip, hand.middleTip) < 0.16) &&
                           (indexThumbDist > 0.050)
        
        if isScrollPose && toggles.smoothScroll {
            if isDraggingActive {
                MouseCursorController.shared.endDrag()
                isDraggingActive = false
            }
            if isRightPinched {
                isRightPinched = false
                MouseCursorController.shared.unlockCursor()
            }
            if lastRelativeAnchor != nil {
                lastRelativeAnchor = nil
                MouseCursorController.shared.clutchDisengaged()
            }
            
            let currentPoint = CGPoint(
                x: (hand.indexTip.x + hand.middleTip.x) / 2.0,
                y: (hand.indexTip.y + hand.middleTip.y) / 2.0
            )
            if let prev = lastScrollPoint {
                let rawDx = (currentPoint.x - prev.x) * scrollSensitivity
                let rawDy = (currentPoint.y - prev.y) * scrollSensitivity
                
                let dx = abs(rawDx) > 0.0010 ? rawDx : 0.0
                let dy = abs(rawDy) > 0.0010 ? rawDy : 0.0
                
                if dx != 0.0 || dy != 0.0 {
                    MouseCursorController.shared.scroll(deltaX: dx, deltaY: dy)
                }
                onGestureDetected?(.smoothScroll, "Scrolling")
            }
            lastScrollPoint = currentPoint
            return
        } else {
            if lastScrollPoint != nil {
                MouseCursorController.shared.resetScroll()
            }
            lastScrollPoint = nil
        }
        
        // B. Right Click: Deliberate gesture only!
        // Middle finger extended alone, while index, ring, pinky curled, and thumb touches middle tip
        let isMiddlePinch = middleExt && !indexExt && !ringExt && !littleExt && (middleThumbDist < 0.038)
        if isMiddlePinch && toggles.rightClick {
            if now - lastRightPinchReleaseTime > 0.65 {
                MouseCursorController.shared.rightClick()
                lastRightPinchReleaseTime = now
                onGestureDetected?(.rightClick, "Right Click")
            }
            return
        }
        
        // C. USER CORE RULE: POINTING POSE ONLY!
        // Mouse cursor ONLY moves when index finger is pointing AND all other fingers (middle, ring, pinky) are fisted/curled!
        // If 5 fingers are showing, or hand is relaxed/flat: ZERO MOUSE MOVEMENT!
        let isPointingPose = indexExt && !middleExt && !ringExt && !littleExt &&
                             (indexLen > middleLen * 1.20) &&
                             (indexLen > ringLen * 1.25) &&
                             (indexLen > littleLen * 1.25)
        
        guard isPointingPose else {
            // Hand is not pointing: Freeze cursor instantly!
            if isDraggingActive {
                MouseCursorController.shared.endDrag()
                isDraggingActive = false
                MouseCursorController.shared.unlockCursor()
            }
            if isRightPinched {
                isRightPinched = false
                MouseCursorController.shared.unlockCursor()
            }
            if lastRelativeAnchor != nil {
                lastRelativeAnchor = nil
                MouseCursorController.shared.clutchDisengaged()
            }
            hasAnchorHistory = false
            return
        }
        
        // Rock-solid tracking anchor: Index Knuckle (indexMCP)
        // Does NOT twitch when finger bends or taps!
        let rawAnchor = hand.indexMCP
        let anchorPt: CGPoint
        if !hasAnchorHistory {
            anchorPt = rawAnchor
            smoothedAnchorPt = rawAnchor
            hasAnchorHistory = true
        } else {
            anchorPt = CGPoint(
                x: 0.65 * rawAnchor.x + 0.35 * smoothedAnchorPt.x,
                y: 0.65 * rawAnchor.y + 0.35 * smoothedAnchorPt.y
            )
            smoothedAnchorPt = anchorPt
        }
        
        // D. Left Click & Drag State Machine (Index + Thumb Pinch)
        let isCurrentlyPinched = (indexThumbDist < 0.038)
        
        if isCurrentlyPinched {
            if !isRightPinched {
                // Pinch started: Freeze cursor immediately so click has zero drift!
                isRightPinched = true
                rightPinchStartTime = now
                MouseCursorController.shared.lockCursorAtCurrentPosition()
            } else {
                let holdDuration = now - rightPinchStartTime
                // Require a deliberate hold (> 0.55s) to convert to drag
                if toggles.clickAndDrag && holdDuration > 0.55 && !isDraggingActive {
                    isDraggingActive = true
                    MouseCursorController.shared.unlockCursor()
                    MouseCursorController.shared.startDrag()
                    onGestureDetected?(.clickAndDrag, "Drag Started")
                }
            }
            
            if isDraggingActive && toggles.clickAndDrag {
                if let prev = lastRelativeAnchor {
                    let dx = -(anchorPt.x - prev.x)
                    let dy = -(anchorPt.y - prev.y)
                    MouseCursorController.shared.moveRelative(deltaX: dx, deltaY: dy)
                }
                lastRelativeAnchor = anchorPt
                onGestureDetected?(.clickAndDrag, "Dragging...")
            }
        } else {
            if isRightPinched {
                // Pinch released
                let pinchDuration = now - rightPinchStartTime
                if isDraggingActive {
                    MouseCursorController.shared.endDrag()
                    isDraggingActive = false
                    MouseCursorController.shared.unlockCursor()
                    onGestureDetected?(.clickAndDrag, "Drag Released")
                } else if pinchDuration < 0.45 && toggles.leftClick {
                    // Quick release: Clean Left Click at locked cursor position!
                    MouseCursorController.shared.leftClick()
                    MouseCursorController.shared.unlockCursor()
                    onGestureDetected?(.leftClick, "Left Click")
                } else {
                    MouseCursorController.shared.unlockCursor()
                }
                isRightPinched = false
                lastRightPinchReleaseTime = now
                lastRelativeAnchor = anchorPt
            } else {
                // Touchscreen-like Relative Air Mouse Active:
                if toggles.airMouse {
                    if let prev = lastRelativeAnchor {
                        let dx = -(anchorPt.x - prev.x)
                        let dy = -(anchorPt.y - prev.y)
                        MouseCursorController.shared.moveRelative(deltaX: dx, deltaY: dy)
                        onGestureDetected?(.hoverPointer, "Pointing")
                    } else {
                        // First frame of pointing: Anchor initial hand position with ZERO cursor jump!
                        MouseCursorController.shared.clutchEngaged()
                        onGestureDetected?(.hoverPointer, "Pointing")
                    }
                }
                lastRelativeAnchor = anchorPt
            }
        }
    }
    
    // MARK: - Left Hand Processing (Whisper Dictation & Safe Shortcuts)
    private func processLeftHand(
        _ hand: HandSkeletonData,
        now: TimeInterval,
        onGestureDetected: ((RecognizedGestureType, String) -> Void)?
    ) {
        let indexExt = isFingerExtended(tip: hand.indexTip, pip: hand.indexPIP, wrist: hand.wrist, factor: 1.15)
        let middleExt = isFingerExtended(tip: hand.middleTip, pip: hand.middlePIP, wrist: hand.wrist, factor: 1.05)
        let ringExt = isFingerExtended(tip: hand.ringTip, pip: hand.ringPIP, wrist: hand.wrist, factor: 1.05)
        let littleExt = isFingerExtended(tip: hand.littleTip, pip: hand.littlePIP, wrist: hand.wrist, factor: 1.05)
        
        let indexThumbDist = distance(hand.thumbTip, hand.indexTip)
        
        // 1. PRIMARY PRIORITY: Whisper Dictation: CLOSED FIST (all 4 fingers curled)
        let isClosedFist = (!indexExt && !middleExt && !ringExt && !littleExt)
        if isClosedFist {
            if toggles.leftDictation {
                if !isLeftFistHolding {
                    isLeftFistHolding = true
                    KeyboardShortcutController.shared.releaseAllHeldModifiers()
                    GroqWhisperManager.shared.startRecording()
                    onGestureDetected?(.whisperFlowHold, "Dictating (\(GroqWhisperManager.shared.selectedModel))...")
                }
            }
            return
        } else {
            if isLeftFistHolding {
                isLeftFistHolding = false
                lastDictationEndTime = now // Start 1.5s gesture immunity cooldown
                KeyboardShortcutController.shared.releaseAllHeldModifiers()
                GroqWhisperManager.shared.stopRecordingAndTranscribe()
                onGestureDetected?(.whisperFlowHold, "Transcribing speech...")
                return
            }
        }
        
        // 2. GESTURE IMMUNITY COOLDOWN:
        // When uncurling fingers after dictation, DO NOT trigger any shortcuts!
        guard (now - lastDictationEndTime > 1.5) && !GroqWhisperManager.shared.isRecording && !GroqWhisperManager.shared.isTranscribing else {
            return
        }
        
        // 3. Return / Enter Key: Quick Left Index-Thumb Pinch (with middle, ring, pinky curled)
        if toggles.leftReturn && indexThumbDist < pinchThreshold && indexExt && !middleExt && !ringExt && !littleExt {
            if now - lastLeftReturnTime > 0.8 {
                KeyboardShortcutController.shared.sendReturn()
                lastLeftReturnTime = now
                onGestureDetected?(.returnKey, "Return ↵")
            }
            return
        }
        
        // 4. Paste (Cmd + V): Peace / V-Sign (Index + Middle extended, Ring + Pinky curled)
        if toggles.leftShortcuts && indexExt && middleExt && !ringExt && !littleExt && distance(hand.indexTip, hand.middleTip) > 0.06 {
            if now - lastLeftPasteTime > 1.0 {
                KeyboardShortcutController.shared.sendPaste()
                lastLeftPasteTime = now
                onGestureDetected?(.paste, "Paste (⌘V)")
            }
            return
        }
    }
}
