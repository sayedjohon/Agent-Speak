import Cocoa
import CoreGraphics
import Carbon
import AVFoundation

// MARK: - Universal Push-to-Talk Dictation Controller (Supports Fn, Option, Command, Control, Function & Custom Keys)
public class FnDictationController {
    public static let shared = FnDictationController()
    
    // Minimum hold threshold before dictation is confirmed (prevents accidental taps)
    public let minimumHoldDuration: TimeInterval = 0.28
    
    // State tracking
    public private(set) var isHoldingKey: Bool = false
    private var pressStartTime: TimeInterval = 0.0
    private var wasShortcutCombination: Bool = false
    private var isDictationActive: Bool = false
    
    // Event tap and monitors
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    private let soundQueue = DispatchQueue(label: "com.agentspeak.fndictation.sound", qos: .userInteractive)
    
    private init() {}
    
    // MARK: - Lifecycle
    public func start() {
        setupEventTap()
        setupNSEventMonitors()
        NSLog("[FnDictation] Push-to-Talk controller initialized for key: %@", GroqWhisperManager.shared.dictationTriggerName)
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            runLoopSource = nil
        }
        eventTap = nil
        
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
        
        if isDictationActive {
            cancelDictation()
        }
    }
    
    // MARK: - CoreGraphics Event Tap (Active interceptor)
    private func setupEventTap() {
        guard eventTap == nil else { return }
        
        // Listen to modifier key changes (flagsChanged), key presses (keyDown), and releases (keyUp)
        let mask = (1 << CGEventType.flagsChanged.rawValue) | 
                   (1 << CGEventType.keyDown.rawValue) | 
                   (1 << CGEventType.keyUp.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let controller = Unmanaged<FnDictationController>.fromOpaque(refcon).takeUnretainedValue()
                
                // Auto-recovery if macOS temporarily suspends the tap
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let t = controller.eventTap {
                        CGEvent.tapEnable(tap: t, enable: true)
                    }
                    return nil
                }
                
                return controller.handleEvent(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            NSLog("[FnDictation] Warning: CGEventTap could not be created. Using NSEvent fallback.")
            return
        }
        
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        self.eventTap = tap
        self.runLoopSource = source
        NSLog("[FnDictation] CGEventTap active for push-to-talk trigger.")
    }
    
    // MARK: - Passive NSEvent Monitors Fallback
    private func setupNSEventMonitors() {
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
                guard let self = self else { return }
                if self.eventTap == nil {
                    self.setupEventTap()
                }
                guard self.eventTap == nil else { return }
                self.processNSEvent(event)
            }
        }
        
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { [weak self] event in
                guard let self = self else { return event }
                if self.eventTap == nil {
                    self.setupEventTap()
                }
                guard self.eventTap == nil else { return event }
                self.processNSEvent(event)
                return event
            }
        }
    }
    
    private func processNSEvent(_ event: NSEvent) {
        guard GroqWhisperManager.shared.fnHoldDictationEnabled else { return }
        let targetCode = GroqWhisperManager.shared.dictationTriggerKeyCode
        let isModifier = GroqWhisperManager.shared.dictationTriggerIsModifier
        let keyCode = Int64(event.keyCode)
        
        if isModifier {
            if event.type == .keyDown {
                if isHoldingKey {
                    wasShortcutCombination = true
                    cancelDictation()
                }
            } else if event.type == .flagsChanged {
                guard keyCode == targetCode else { return }
                let flags = event.modifierFlags
                let isDown: Bool
                switch targetCode {
                case 63:
                    isDown = flags.contains(.function)
                case 61, 58:
                    isDown = flags.contains(.option)
                case 54, 55:
                    isDown = flags.contains(.command)
                case 62, 59:
                    isDown = flags.contains(.control)
                case 60, 56:
                    isDown = flags.contains(.shift)
                case 57:
                    isDown = flags.contains(.capsLock)
                default:
                    isDown = !isHoldingKey
                }
                
                if isDown && !isHoldingKey {
                    handleKeyDown()
                } else if !isDown && isHoldingKey {
                    _ = handleKeyUp()
                }
            }
        } else {
            if event.type == .keyDown {
                if keyCode == targetCode && !isHoldingKey {
                    handleKeyDown()
                } else if isHoldingKey && keyCode != targetCode {
                    wasShortcutCombination = true
                    cancelDictation()
                }
            } else if event.type == .keyUp {
                if keyCode == targetCode && isHoldingKey {
                    _ = handleKeyUp()
                }
            }
        }
    }
    
    // MARK: - Event Dispatcher
    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard GroqWhisperManager.shared.fnHoldDictationEnabled else {
            return Unmanaged.passUnretained(event)
        }
        
        let targetCode = GroqWhisperManager.shared.dictationTriggerKeyCode
        let isModifier = GroqWhisperManager.shared.dictationTriggerIsModifier
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        if isModifier {
            // 1. If any standard key is pressed down while holding modifier:
            // Abort dictation immediately and let shortcut fire normally!
            if type == .keyDown {
                if isHoldingKey {
                    wasShortcutCombination = true
                    cancelDictation()
                }
                return Unmanaged.passUnretained(event)
            }
            
            // 2. Modifier keys changed
            if type == .flagsChanged {
                guard keyCode == targetCode else {
                    return Unmanaged.passUnretained(event)
                }
                
                let flags = event.flags
                let isDown: Bool
                switch targetCode {
                case 63:
                    isDown = flags.contains(.maskSecondaryFn)
                case 61, 58:
                    isDown = flags.contains(.maskAlternate)
                case 54, 55:
                    isDown = flags.contains(.maskCommand)
                case 62, 59:
                    isDown = flags.contains(.maskControl)
                case 60, 56:
                    isDown = flags.contains(.maskShift)
                case 57:
                    isDown = flags.contains(.maskAlphaShift)
                default:
                    isDown = !isHoldingKey
                }
                
                // KEY DOWN: Trigger pressed
                if isDown && !isHoldingKey {
                    handleKeyDown()
                    return Unmanaged.passUnretained(event)
                }
                
                // KEY UP: Trigger released
                if !isDown && isHoldingKey {
                    let shouldSuppress = handleKeyUp()
                    if shouldSuppress && targetCode == 63 {
                        // Swallow release event ONLY for Fn / Globe key (63) so macOS does not pop up Emoji picker
                        return nil
                    } else {
                        // For Right Control, Option, Shift, Command, pass the release through so macOS clears modifier flags!
                        return Unmanaged.passUnretained(event)
                    }
                }
            }
        } else {
            // Standard non-modifier key (e.g. F12, F6, Grave, etc.)
            if type == .keyDown {
                if keyCode == targetCode {
                    if !isHoldingKey {
                        handleKeyDown()
                    }
                    return nil // Swallow target key so it does not type characters or trigger system actions
                } else if isHoldingKey {
                    wasShortcutCombination = true
                    cancelDictation()
                    return Unmanaged.passUnretained(event)
                }
            } else if type == .keyUp {
                if keyCode == targetCode {
                    if isHoldingKey {
                        _ = handleKeyUp()
                    }
                    return nil // Swallow keyUp
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - Actions
    private func handleKeyDown() {
        isHoldingKey = true
        pressStartTime = CACurrentMediaTime()
        wasShortcutCombination = false
        isDictationActive = true
        
        DispatchQueue.main.async {
            // Interruption / Barge-in: If agent is speaking, reading observations, or queued, stop immediately!
            if SpeechQueueManager.shared.isSpeaking || SpeechQueueManager.shared.queueCount > 0 || NotchWindowController.shared.isPresenting {
                NSLog("[FnDictation] Barge-in triggered: cancelling speech playback and starting dictation.")
                SpeechQueueManager.shared.stopCurrent()
            }
            
            KeyboardShortcutController.shared.releaseAllHeldModifiers()
            GroqWhisperManager.shared.startRecording()
            let triggerName = GroqWhisperManager.shared.dictationTriggerName
            GestureHUDState.shared.showGesture(
                .whisperFlowHold,
                label: "Listening... (Release \(triggerName) to Paste)"
            )
        }
        NSLog("[FnDictation] Push-to-talk trigger pressed down. Recording voice...")
    }
    
    private func handleKeyUp() -> Bool {
        isHoldingKey = false
        let holdDuration = CACurrentMediaTime() - pressStartTime
        
        // If part of a shortcut combination, do nothing (already cancelled)
        if wasShortcutCombination {
            isDictationActive = false
            return false
        }
        
        // Accidental tap guard (< 280ms)
        if holdDuration < minimumHoldDuration {
            NSLog("[FnDictation] Push-to-talk tap duration too short (%.2fs < %.2fs). Discarding.", holdDuration, minimumHoldDuration)
            cancelDictation()
            return false
        }
        
        // Genuine push-to-talk speech dictation
        isDictationActive = false
        
        // Audio earcon feedback: gentle completion pop
        soundQueue.async {
            NSSound(named: "Pop")?.play()
        }
        
        DispatchQueue.main.async {
            KeyboardShortcutController.shared.releaseAllHeldModifiers()
            GroqWhisperManager.shared.stopRecordingAndTranscribe()
            GestureHUDState.shared.showGesture(.whisperFlowHold, label: "Transcribing with Groq Whisper...")
        }
        NSLog("[FnDictation] Push-to-talk trigger released after %.2fs. Transcribing & auto-pasting...", holdDuration)
        
        return true
    }
    
    private func cancelDictation() {
        isDictationActive = false
        DispatchQueue.main.async {
            GroqWhisperManager.shared.cancelRecording()
        }
        NSLog("[FnDictation] Voice recording cancelled.")
    }
}

