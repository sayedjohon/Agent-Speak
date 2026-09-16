import Cocoa
import CoreGraphics
import Carbon
import AVFoundation

// MARK: - MacBook Fn (Globe) Key Push-to-Talk Dictation Controller
public class FnDictationController {
    public static let shared = FnDictationController()
    
    // Keycode 63 is the Fn / Globe key on Apple MacBook and Magic Keyboards
    public static let keyFn: Int64 = 63
    
    // Minimum hold threshold before dictation is confirmed (prevents accidental taps)
    public let minimumHoldDuration: TimeInterval = 0.28
    
    // State tracking
    public private(set) var isHoldingFn: Bool = false
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
        NSLog("[FnDictation] Push-to-Talk controller initialized.")
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
        
        // Listen to modifier key changes (flagsChanged) and regular key presses (keyDown)
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
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
        NSLog("[FnDictation] CGEventTap active for Fn key push-to-talk.")
    }
    
    // MARK: - Passive NSEvent Monitors Fallback
    private func setupNSEventMonitors() {
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
                guard let self = self, self.eventTap == nil else { return }
                self.processNSEvent(event)
            }
        }
        
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
                guard let self = self, self.eventTap == nil else { return event }
                self.processNSEvent(event)
                return event
            }
        }
    }
    
    private func processNSEvent(_ event: NSEvent) {
        guard GroqWhisperManager.shared.fnHoldDictationEnabled else { return }
        
        if event.type == .keyDown {
            if isHoldingFn {
                wasShortcutCombination = true
                cancelDictation()
            }
        } else if event.type == .flagsChanged {
            let isFnActive = event.modifierFlags.contains(.function)
            let keyCode = Int64(event.keyCode)
            
            if (keyCode == Self.keyFn || isFnActive != isHoldingFn) {
                if isFnActive && !isHoldingFn {
                    handleFnDown()
                } else if !isFnActive && isHoldingFn {
                    _ = handleFnUp()
                }
            }
        }
    }
    
    // MARK: - Event Dispatcher
    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard GroqWhisperManager.shared.fnHoldDictationEnabled else {
            return Unmanaged.passUnretained(event)
        }
        
        // 1. If any standard key is pressed down while holding Fn:
        // (e.g. Fn + Backspace for Forward Delete, Fn + Arrows, Fn + F1-F12)
        // Abort dictation immediately and let the keyboard shortcut fire normally!
        if type == .keyDown {
            if isHoldingFn {
                wasShortcutCombination = true
                cancelDictation()
            }
            return Unmanaged.passUnretained(event)
        }
        
        // 2. Modifier keys changed
        if type == .flagsChanged {
            let flags = event.flags
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isSecondaryFnActive = flags.contains(.maskSecondaryFn)
            
            // Validate if this event pertains to the Fn / Globe key
            let isTargetKey = (keyCode == Self.keyFn) || (isSecondaryFnActive != isHoldingFn)
            guard isTargetKey else {
                return Unmanaged.passUnretained(event)
            }
            
            // KEY DOWN: Fn pressed
            if isSecondaryFnActive && !isHoldingFn {
                handleFnDown()
                return Unmanaged.passUnretained(event)
            }
            
            // KEY UP: Fn released
            if !isSecondaryFnActive && isHoldingFn {
                let shouldSuppress = handleFnUp()
                if shouldSuppress {
                    // Swallow the release event so macOS does NOT open the Emoji picker or switch input source!
                    return nil
                } else {
                    return Unmanaged.passUnretained(event)
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - Actions
    private func handleFnDown() {
        isHoldingFn = true
        pressStartTime = CACurrentMediaTime()
        wasShortcutCombination = false
        isDictationActive = true
        
        DispatchQueue.main.async {
            // Interruption / Barge-in: If agent is currently speaking, reading observations, or queued, stop it immediately!
            if SpeechQueueManager.shared.isSpeaking || SpeechQueueManager.shared.queueCount > 0 || NotchWindowController.shared.isPresenting {
                NSLog("[FnDictation] Barge-in triggered: cancelling speech playback and starting dictation.")
                SpeechQueueManager.shared.stopCurrent()
            }
            
            KeyboardShortcutController.shared.releaseAllHeldModifiers()
            GroqWhisperManager.shared.startRecording()
            GestureHUDState.shared.showGesture(
                .whisperFlowHold,
                label: "Listening... (Release Fn to Paste)"
            )
        }
        NSLog("[FnDictation] Fn button pressed down. Recording voice...")
    }
    
    private func handleFnUp() -> Bool {
        isHoldingFn = false
        let holdDuration = CACurrentMediaTime() - pressStartTime
        
        // If part of a shortcut combination, do nothing (already cancelled)
        if wasShortcutCombination {
            isDictationActive = false
            return false
        }
        
        // Accidental tap guard (< 280ms)
        if holdDuration < minimumHoldDuration {
            NSLog("[FnDictation] Fn tap duration too short (%.2fs < %.2fs). Discarding.", holdDuration, minimumHoldDuration)
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
        NSLog("[FnDictation] Fn button released after %.2fs. Transcribing & auto-pasting...", holdDuration)
        
        // Suppress this event to block macOS Emoji picker popup
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
