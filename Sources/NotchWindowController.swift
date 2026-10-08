import Cocoa
import SwiftUI
import AVFoundation
import Carbon
import NaturalLanguage
import QuartzCore



// MARK: - Keyable Floating Panel
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    override func mouseDown(with event: NSEvent) {
        self.makeKey()
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            DispatchQueue.main.async {
                SpeechQueueManager.shared.stopCurrent()
            }
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Notch Window Controller
public class NotchWindowController {
    public static let shared = NotchWindowController()
    
    private var window: KeyablePanel?
    private var dictationWindow: KeyablePanel?
    private var audioManager: StreamingAudioManager?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    public var isPresenting: Bool {
        return window != nil || dictationWindow != nil || (audioManager?.isPlaying == true)
    }
    
    private init() {}
    
    public func presentSpeech(text: String, project: String = "Agent Speak", onFinished: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismiss()
            
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
            
            let hasNotch: Bool
            if #available(macOS 12.0, *) {
                hasNotch = targetScreen.safeAreaInsets.top > 0 || targetScreen.auxiliaryTopLeftArea != nil
            } else {
                hasNotch = false
            }
            
            let notchWidth: CGFloat = 185.0
            let barHeight: CGFloat = 30.0
            let windowWidth = notchWidth + 24.0
            let windowHeight = barHeight + 20.0
            
            let x = targetScreen.frame.origin.x + (targetScreen.frame.width - windowWidth) / 2
            let topOfScreen = targetScreen.frame.origin.y + targetScreen.frame.height
            let topOfVisible = targetScreen.visibleFrame.origin.y + targetScreen.visibleFrame.height
            
            let y: CGFloat
            if hasNotch {
                let notchHeight: CGFloat = targetScreen.safeAreaInsets.top > 0 ? targetScreen.safeAreaInsets.top : 32.0
                y = topOfScreen - notchHeight - windowHeight
            } else {
                if topOfVisible < topOfScreen - 5 {
                    y = topOfVisible - windowHeight - 4.0
                } else {
                    y = topOfScreen - windowHeight - 8.0
                }
            }
            
            let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
            let panel = KeyablePanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar + 1
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            
            self.audioManager = StreamingAudioManager(text: text) { [weak self] in
                self?.dismissNotchBarOnly()
                onFinished?()
            }
            
            let hosting = NSHostingView(
                rootView: PointyTopNotchBarView(state: self.audioManager!, hasNotch: hasNotch)
            )
            hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
            hosting.wantsLayer = true
            panel.contentView = hosting
            panel.orderFront(nil)
            self.window = panel
            
            HologramManager.shared.showHologram(targetScreen: targetScreen, audioManager: self.audioManager!)
            
            // Watchdog: dismiss if speech synthesis fails completely after timeout
            let targetMgr = self.audioManager
            DispatchQueue.main.asyncAfter(deadline: .now() + 25.0) { [weak self] in
                guard let self = self, let mgr = self.audioManager, mgr === targetMgr else { return }
                if !mgr.isPlaying && mgr.currentChunkIndex == 0 && mgr.chunks.first?.player == nil {
                    self.dismiss()
                }
            }
            
            self.setupEscapeKeyTap()
            self.registerGlobalEscapeHotKey()
        }
    }
    
    public func presentAudioFile(filePath: String, project: String = "Jarvis", onFinished: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismiss()
            
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
            
            let hasNotch: Bool
            if #available(macOS 12.0, *) {
                hasNotch = targetScreen.safeAreaInsets.top > 0 || targetScreen.auxiliaryTopLeftArea != nil
            } else {
                hasNotch = false
            }
            
            let notchWidth: CGFloat = 185.0
            let barHeight: CGFloat = 30.0
            let windowWidth = notchWidth + 24.0
            let windowHeight = barHeight + 20.0
            
            let x = targetScreen.frame.origin.x + (targetScreen.frame.width - windowWidth) / 2
            let topOfScreen = targetScreen.frame.origin.y + targetScreen.frame.height
            let topOfVisible = targetScreen.visibleFrame.origin.y + targetScreen.visibleFrame.height
            
            let y: CGFloat
            if hasNotch {
                let notchHeight: CGFloat = targetScreen.safeAreaInsets.top > 0 ? targetScreen.safeAreaInsets.top : 32.0
                y = topOfScreen - notchHeight - windowHeight
            } else {
                if topOfVisible < topOfScreen - 5 {
                    y = topOfVisible - windowHeight - 4.0
                } else {
                    y = topOfScreen - windowHeight - 8.0
                }
            }
            
            let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
            let panel = KeyablePanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar + 1
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            
            self.audioManager = StreamingAudioManager(audioFilePath: filePath) { [weak self] in
                self?.dismissNotchBarOnly()
                onFinished?()
            }
            
            let hosting = NSHostingView(
                rootView: PointyTopNotchBarView(state: self.audioManager!, hasNotch: hasNotch)
            )
            hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
            hosting.wantsLayer = true
            panel.contentView = hosting
            panel.orderFront(nil)
            self.window = panel
            
            HologramManager.shared.showHologram(targetScreen: targetScreen, audioManager: self.audioManager!)
            
            // Instant Autoplay Verification
            let targetMgr = self.audioManager
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self, let mgr = self.audioManager, mgr === targetMgr else { return }
                if !mgr.isPlaying {
                    if let p = mgr.chunks.first?.player {
                        p.play()
                        mgr.isPlaying = true
                        mgr.startTimer()
                    } else {
                        self.dismiss()
                    }
                }
            }
            
            self.setupEscapeKeyTap()
            self.registerGlobalEscapeHotKey()
        }
    }
    
    public static func hasNotch(screen: NSScreen? = nil) -> Bool {
        let target = screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let s = target else { return false }
        if #available(macOS 12.0, *) {
            return s.safeAreaInsets.top > 0 || s.auxiliaryTopLeftArea != nil
        }
        return false
    }
    
    public func presentDictationBar(hasNotch: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let panel = self.dictationWindow {
                panel.orderFront(nil)
                return
            }
            
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
            
            let hasScreenNotch = Self.hasNotch(screen: targetScreen)
            let barWidth: CGFloat = 300.0
            let barHeight: CGFloat = 32.0
            let windowWidth = barWidth + 24.0
            let windowHeight = barHeight + 20.0
            
            let x = targetScreen.frame.origin.x + (targetScreen.frame.width - windowWidth) / 2
            let topOfScreen = targetScreen.frame.origin.y + targetScreen.frame.height
            let topOfVisible = targetScreen.visibleFrame.origin.y + targetScreen.visibleFrame.height
            
            let y: CGFloat
            if hasScreenNotch {
                let notchHeight: CGFloat = targetScreen.safeAreaInsets.top > 0 ? targetScreen.safeAreaInsets.top : 32.0
                y = topOfScreen - notchHeight - windowHeight
            } else {
                if topOfVisible < topOfScreen - 5 {
                    y = topOfVisible - windowHeight - 4.0
                } else {
                    y = topOfScreen - windowHeight - 8.0
                }
            }
            
            let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
            let panel = KeyablePanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar + 1
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            
            let hosting = NSHostingView(
                rootView: DictationNotchBarView(hasNotch: hasScreenNotch)
            )
            hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
            hosting.wantsLayer = true
            panel.contentView = hosting
            panel.orderFront(nil)
            self.dictationWindow = panel
            
            self.setupEscapeKeyTap()
            self.registerGlobalEscapeHotKey()
        }
    }
    
    public func dismissDictationBarOnly() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dictationWindow?.orderOut(nil)
            self.dictationWindow = nil
        }
    }
    
    public func dismissNotchBarOnly() {
        unregisterGlobalEscapeHotKey()
        window?.orderOut(nil)
        window = nil
        audioManager = nil
        HologramManager.shared.onSpeechFinished()
    }
    
    private var isDismissing = false
    public func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        defer { isDismissing = false }
        
        unregisterGlobalEscapeHotKey()
        
        let mgr = audioManager
        audioManager = nil
        mgr?.close()
        
        window?.orderOut(nil)
        window = nil
        
        dictationWindow?.orderOut(nil)
        dictationWindow = nil
        
        if BackgroundMusicManager.shared.isPlaying || BackgroundMusicManager.shared.isFadingOut {
            // Start smooth 3.0s window fade in lockstep with background music
            HologramManager.shared.startWindowFadeOut(duration: BackgroundMusicManager.shared.fadeOutDuration)
        } else {
            HologramManager.shared.dismissHologramWithFade(duration: 3.0)
        }
    }
    
    public func updateVolume() {
        DispatchQueue.main.async { [weak self] in
            self?.audioManager?.updateVolume()
        }
    }
    
    public func setupEscapeKeyTap() {
        // 1. CoreGraphics Global Event Tap (Active interceptor)
        if eventTap == nil {
            let eventMask = (1 << CGEventType.keyDown.rawValue)
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            
            if let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        if let refcon = refcon {
                            let controller = Unmanaged<NotchWindowController>.fromOpaque(refcon).takeUnretainedValue()
                            if let t = controller.eventTap {
                                CGEvent.tapEnable(tap: t, enable: true)
                            }
                        }
                        return nil
                    }
                    
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    if keyCode == 53 { // Escape
                        if let refcon = refcon {
                            let controller = Unmanaged<NotchWindowController>.fromOpaque(refcon).takeUnretainedValue()
                            if controller.dictationWindow != nil {
                                DispatchQueue.main.async {
                                    DictationNotchState.shared.dismiss()
                                }
                                return nil
                            }
                            if controller.window != nil || SpeechQueueManager.shared.isSpeaking {
                                DispatchQueue.main.async {
                                    SpeechQueueManager.shared.stopCurrent()
                                }
                                return nil // Swallows Escape so background windows aren't affected
                            }
                        }
                    }
                    return Unmanaged.passUnretained(event)
                },
                userInfo: refcon
            ) {
                let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                self.eventTap = tap
                self.runLoopSource = source
                NSLog("[AgentSpeak] CGEventTap for Escape key installed.")
            } else {
                NSLog("[AgentSpeak] Warning: CGEventTap could not be created. Using NSEvent monitors.")
            }
        } else if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        
        // 2. Global Event Monitor (Passive fallback for when active tap is bypassed)
        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // Escape
                    guard let self = self else { return }
                    if self.dictationWindow != nil {
                        DispatchQueue.main.async {
                            DictationNotchState.shared.dismiss()
                        }
                        return
                    }
                    if self.window != nil || SpeechQueueManager.shared.isSpeaking {
                        DispatchQueue.main.async {
                            SpeechQueueManager.shared.stopCurrent()
                        }
                    }
                }
            }
        }
        
        // 3. Local Key Monitor (Active when notch window or application has focus)
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // Escape
                    guard let self = self else { return event }
                    if self.dictationWindow != nil {
                        DispatchQueue.main.async {
                            DictationNotchState.shared.dismiss()
                        }
                        return nil
                    }
                    if self.window != nil || SpeechQueueManager.shared.isSpeaking {
                        DispatchQueue.main.async {
                            SpeechQueueManager.shared.stopCurrent()
                        }
                        return nil
                    }
                }
                return event
            }
        }
    }
    
    // MARK: - 4. Carbon Global HotKey (0 Permissions Required — macOS System-Wide Native Dispatch)
    public func registerGlobalEscapeHotKey() {
        guard hotKeyRef == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let target = GetEventDispatcherTarget()
        
        _ = InstallEventHandler(target, { (handler, event, userData) -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if hotKeyID.signature == 0x4153504B && hotKeyID.id == 53 {
                if NotchWindowController.shared.dictationWindow != nil {
                    DispatchQueue.main.async {
                        DictationNotchState.shared.dismiss()
                    }
                    return noErr
                }
                DispatchQueue.main.async {
                    SpeechQueueManager.shared.stopCurrent()
                }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }, 1, &eventType, nil, &eventHandlerRef)
        
        let hotKeyID = EventHotKeyID(signature: 0x4153504B, id: 53) // "ASPK", 53
        let regStatus = RegisterEventHotKey(UInt32(kVK_Escape), 0, hotKeyID, target, 0, &hotKeyRef)
        if regStatus == noErr {
            NSLog("[AgentSpeak] Carbon Global Escape HotKey registered (Zero permissions required).")
        } else {
            NSLog("[AgentSpeak] Carbon RegisterEventHotKey returned code \(regStatus).")
        }
    }
    
    public func unregisterGlobalEscapeHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
