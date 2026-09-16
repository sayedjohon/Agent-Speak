import Cocoa
import CoreGraphics
import Carbon

// MARK: - Keyboard Shortcut Controller
public class KeyboardShortcutController {
    public static let shared = KeyboardShortcutController()
    
    // Virtual key codes from Carbon HIToolbox Events.h
    public static let keyReturn: UInt16 = 36
    public static let keyTab: UInt16 = 48
    public static let keySpace: UInt16 = 49
    public static let keyDelete: UInt16 = 51
    public static let keyEscape: UInt16 = 53
    public static let keyCommand: UInt16 = 55
    public static let keyShift: UInt16 = 56
    public static let keyOption: UInt16 = 58
    public static let keyControl: UInt16 = 59
    public static let keyUpArrow: UInt16 = 126
    public static let keyDownArrow: UInt16 = 125
    public static let keyLeftArrow: UInt16 = 123
    public static let keyRightArrow: UInt16 = 124
    
    public static let keyA: UInt16 = 0
    public static let keyS: UInt16 = 1
    public static let keyC: UInt16 = 8
    public static let keyV: UInt16 = 9
    public static let keyX: UInt16 = 7
    public static let keyZ: UInt16 = 6
    public static let keyEqual: UInt16 = 24
    public static let keyMinus: UInt16 = 27
    
    // Active modifier hold tracking (e.g. Whisper Flow dictation)
    public private(set) var isHoldingCommand: Bool = false
    public private(set) var isHoldingOption: Bool = false
    public private(set) var isHoldingControl: Bool = false
    public private(set) var isHoldingShift: Bool = false
    
    public var whisperModifierKey: String = "command"
    
    private init() {}
    
    // MARK: - Modifier Hold Management (Continuous Dictation)
    public func setWhisperModifierHold(active: Bool) {
        let targetKey: UInt16
        let flag: CGEventFlags
        
        switch whisperModifierKey.lowercased() {
        case "option", "alt":
            targetKey = Self.keyOption
            flag = .maskAlternate
            if isHoldingOption == active { return }
            isHoldingOption = active
        case "control", "ctrl":
            targetKey = Self.keyControl
            flag = .maskControl
            if isHoldingControl == active { return }
            isHoldingControl = active
        case "shift":
            targetKey = Self.keyShift
            flag = .maskShift
            if isHoldingShift == active { return }
            isHoldingShift = active
        default:
            targetKey = Self.keyCommand
            flag = .maskCommand
            if isHoldingCommand == active { return }
            isHoldingCommand = active
        }
        
        let event = CGEvent(keyboardEventSource: nil, virtualKey: targetKey, keyDown: active)
        if active {
            event?.flags = flag
        } else {
            event?.flags = []
        }
        event?.post(tap: .cghidEventTap)
        NSLog("[KeyboardController] Whisper modifier '%@' held: %@", whisperModifierKey, active ? "ACTIVE" : "RELEASED")
    }
    
    public func releaseAllHeldModifiers() {
        if isHoldingCommand {
            setWhisperModifierHold(active: false)
        }
        if isHoldingOption {
            let ev = CGEvent(keyboardEventSource: nil, virtualKey: Self.keyOption, keyDown: false)
            ev?.flags = []
            ev?.post(tap: .cghidEventTap)
            isHoldingOption = false
        }
        if isHoldingControl {
            let ev = CGEvent(keyboardEventSource: nil, virtualKey: Self.keyControl, keyDown: false)
            ev?.flags = []
            ev?.post(tap: .cghidEventTap)
            isHoldingControl = false
        }
        if isHoldingShift {
            let ev = CGEvent(keyboardEventSource: nil, virtualKey: Self.keyShift, keyDown: false)
            ev?.flags = []
            ev?.post(tap: .cghidEventTap)
            isHoldingShift = false
        }
    }
    
    // MARK: - Single Key Pulse
    public func sendKeyPulse(keyCode: UInt16, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)
        
        usleep(25000) // 25ms hold
        
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)
    }
    
    // MARK: - Productivity Shortcuts
    public func sendReturn() {
        sendKeyPulse(keyCode: Self.keyReturn)
        NSLog("[KeyboardController] Sent RETURN / ENTER key")
    }
    
    public func sendEscape() {
        sendKeyPulse(keyCode: Self.keyEscape)
        NSLog("[KeyboardController] Sent ESCAPE key")
    }
    
    public func sendTab(reverse: Bool = false) {
        if reverse {
            sendKeyPulse(keyCode: Self.keyTab, flags: .maskShift)
        } else {
            sendKeyPulse(keyCode: Self.keyTab)
        }
    }
    
    public func sendSpace() {
        sendKeyPulse(keyCode: Self.keySpace)
    }
    
    public func sendBackspace() {
        sendKeyPulse(keyCode: Self.keyDelete)
    }
    
    public func sendCopy() {
        sendKeyPulse(keyCode: Self.keyC, flags: .maskCommand)
        NSLog("[KeyboardController] Sent COPY (Cmd + C)")
    }
    
    public func sendPaste() {
        releaseAllHeldModifiers()
        sendKeyPulse(keyCode: Self.keyV, flags: .maskCommand)
        NSLog("[KeyboardController] Sent PASTE (Cmd + V)")
    }
    
    public func sendCut() {
        sendKeyPulse(keyCode: Self.keyX, flags: .maskCommand)
        NSLog("[KeyboardController] Sent CUT (Cmd + X)")
    }
    
    public func sendUndo() {
        sendKeyPulse(keyCode: Self.keyZ, flags: .maskCommand)
        NSLog("[KeyboardController] Sent UNDO (Cmd + Z)")
    }
    
    public func sendRedo() {
        sendKeyPulse(keyCode: Self.keyZ, flags: [.maskCommand, .maskShift])
        NSLog("[KeyboardController] Sent REDO (Cmd + Shift + Z)")
    }
    
    public func sendSelectAll() {
        sendKeyPulse(keyCode: Self.keyA, flags: .maskCommand)
        NSLog("[KeyboardController] Sent SELECT ALL (Cmd + A)")
    }
    
    public func sendMissionControl() {
        sendKeyPulse(keyCode: Self.keyUpArrow, flags: .maskControl)
        NSLog("[KeyboardController] Sent MISSION CONTROL (Ctrl + Up)")
    }
    
    public func sendAppSwitch() {
        sendKeyPulse(keyCode: Self.keyTab, flags: .maskCommand)
        NSLog("[KeyboardController] Sent APP SWITCH (Cmd + Tab)")
    }
    
    public func sendZoom(zoomIn: Bool) {
        if zoomIn {
            sendKeyPulse(keyCode: Self.keyEqual, flags: .maskCommand)
        } else {
            sendKeyPulse(keyCode: Self.keyMinus, flags: .maskCommand)
        }
    }
}
