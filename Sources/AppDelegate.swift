import Cocoa
import SwiftUI
import Carbon

public class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public static var shared: AppDelegate!
    
    var statusItem: NSStatusItem?
    var dashboardWindow: NSWindow?
    var trayHostingView: PassthroughHostingView<TrayGradientOrbView>?
    
    var idleIcon: NSImage?
    var speakingIcon: NSImage?
    
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    
    public var isTrayIconVisible: Bool {
        return statusItem?.isVisible ?? false
    }
    
    public override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        loadTrayIcons()
        
        // Ensure preferred menu bar position is registered away from the notch
        if UserDefaults.standard.object(forKey: "NSStatusItem Preferred Position AgentSpeakTray") == nil {
            UserDefaults.standard.set(360.0, forKey: "NSStatusItem Preferred Position AgentSpeakTray")
        }
        
        let showTray = loadTrayPreference()
        if showTray {
            setupMenuBar()
        }
        
        setupDashboardWindow()
        NotchWindowController.shared.setupEscapeKeyTap()
        registerGlobalHotKeys()
        
        // Listen for live speech state to toggle tray visual indicator
        SpeechQueueManager.shared.onSpeakingChanged = { [weak self] isSpeaking in
            self?.updateTrayIcon(isSpeaking: isSpeaking)
        }
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        NSLog("[AgentSpeak] Accessibility permission on launch: \(trusted ? "TRUSTED" : "NOT TRUSTED")")
        
        TranscriptWatcher.shared.onSpeechRequest = { source, text in
            SpeechQueueManager.shared.enqueue(source: source, text: text)
        }
        TranscriptWatcher.shared.start()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }
    
    // MARK: - Tray Icon Loading & Rendering
    
    private func loadTrayIcons() {
        let bundle = Bundle.main
        let resPath = bundle.resourcePath ?? ""
        let ptSize = NSSize(width: 20, height: 20)
        
        // 1. Prioritize native outline SVG (agent-speak-macos-outline-fixed.svg)
        let svgPaths = [
            bundle.path(forResource: "agent-speak-macos-outline-fixed", ofType: "svg"),
            "\(resPath)/agent-speak-macos-outline-fixed.svg",
            "/Users/sayedjohon/Downloads/agent-speak-macos-outline-fixed.svg",
            bundle.path(forResource: "agent-speak-icon-tray", ofType: "svg"),
            "\(resPath)/agent-speak-icon-tray.svg"
        ]
        
        var baseSvg: NSImage?
        for p in svgPaths {
            if let p = p, FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
                img.size = ptSize
                baseSvg = img
                break
            }
        }
        
        if let base = baseSvg {
            // Idle Icon: Template image natively switches stroke between pure white (Dark Mode) and pure black (Light Mode)
            base.isTemplate = true
            idleIcon = base
            
            // Speaking Icon: Dynamic appearance-aware drawing block preserving the vibrant green status dot
            speakingIcon = NSImage(size: ptSize, flipped: false) { rect in
                let appearance = NSAppearance.currentDrawing()
                let isDark: Bool
                if let match = appearance.bestMatch(from: [.darkAqua, .aqua]) {
                    isDark = (match == .darkAqua)
                } else {
                    isDark = (NSApp?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
                }
                
                // Draw base SVG outline
                base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
                
                // Tint outline color (white on dark menu bar, black on light menu bar)
                let outlineColor: NSColor = isDark ? .white : .black
                outlineColor.set()
                rect.fill(using: .sourceIn)
                
                // Draw active speech indicator dot badge (vibrant green with contrasting ring)
                let dotBorder = NSRect(x: 13.0, y: 1.0, width: 6.0, height: 6.0)
                (isDark ? NSColor(white: 0.1, alpha: 0.95) : NSColor.white).setFill()
                NSBezierPath(ovalIn: dotBorder).fill()
                
                let dotRect = NSRect(x: 13.5, y: 1.5, width: 5.0, height: 5.0)
                NSColor(red: 0.0, green: 0.9, blue: 0.45, alpha: 1.0).setFill()
                NSBezierPath(ovalIn: dotRect).fill()
                
                return true
            }
        }
        
        // 2. High-DPI Pre-rendered raster fallback
        if idleIcon == nil {
            let idlePaths = [
                "\(resPath)/TrayIcon_Idle@2x.png",
                "\(resPath)/TrayIcon@2x.png",
                "\(resPath)/TrayIcon.png"
            ]
            for p in idlePaths {
                if FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
                    img.size = ptSize
                    img.isTemplate = true
                    idleIcon = img
                    break
                }
            }
        }
        if speakingIcon == nil {
            let speakPaths = [
                "\(resPath)/TrayIcon_Speaking@2x.png",
                "\(resPath)/TrayIcon_Speaking.png"
            ]
            for p in speakPaths {
                if FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
                    img.size = ptSize
                    speakingIcon = img
                    break
                }
            }
        }
        
        // 3. System SF Symbol ultimate fallback
        if idleIcon == nil {
            idleIcon = NSImage(systemSymbolName: "ellipsis.message.fill", accessibilityDescription: "Agent Speak")
            idleIcon?.isTemplate = true
        }
        if speakingIcon == nil {
            speakingIcon = NSImage(systemSymbolName: "waveform.badge.magnifyingglass", accessibilityDescription: "Agent Speak Active")
        }
    }
    
    // MARK: - Menu Bar Setup & State
    
    public func setupMenuBar() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: 28)
            statusItem?.autosaveName = "AgentSpeakTray"
        }
        
        guard let item = statusItem, let button = item.button else { return }
        
        // Use live 3D gradient orb view in the menu bar
        button.image = nil
        let isSpeaking = SpeechQueueManager.shared.isSpeaking
        button.toolTip = isSpeaking ? "Agent Speak: Speaking... (Click for options)" : "Agent Speak: Ready & Monitoring (Click for options)"
        
        if trayHostingView == nil {
            let hosting = PassthroughHostingView(rootView: TrayGradientOrbView())
            hosting.frame = NSRect(x: 3, y: 1, width: 22, height: 20)
            hosting.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin, .maxYMargin]
            button.addSubview(hosting)
            trayHostingView = hosting
        }
        
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.isVisible = true
    }
    
    public func updateTrayIcon(isSpeaking: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem?.button else { return }
            button.toolTip = isSpeaking ? "Agent Speak: Speaking... (Click for options)" : "Agent Speak: Ready & Monitoring (Click for options)"
        }
    }
    
    public func setTrayIconVisible(_ visible: Bool) {
        saveTrayPreference(visible: visible)
        if visible {
            if statusItem == nil || statusItem?.isVisible == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    exit(0)
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.statusItem?.isVisible = false
            }
        }
    }
    
    private func loadTrayPreference() -> Bool {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let general = json["general"] as? [String: Any],
              let showTray = general["show_tray_icon"] as? Bool else {
            return true
        }
        return showTray
    }
    
    private func saveTrayPreference(visible: Bool) {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var general = json["general"] as? [String: Any] ?? [:]
        general["show_tray_icon"] = visible
        json["general"] = general
        
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? updated.write(to: configPath)
        }
    }
    
    // MARK: - NSMenuDelegate (Dynamic Context Menu)
    
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        let isSpeaking = SpeechQueueManager.shared.isSpeaking
        
        // 1. Settings (1 word, gear icon, ⌃,)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showDashboard), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings") {
            icon.isTemplate = true
            settingsItem.image = icon
        }
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Selected Play (2 words, text cursor icon, ⌃S)
        let selectedItem = NSMenuItem(title: "Selected Play", action: #selector(speakSelected), keyEquivalent: "s")
        selectedItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "text.cursor", accessibilityDescription: "Selected Play") {
            icon.isTemplate = true
            selectedItem.image = icon
        }
        selectedItem.target = self
        menu.addItem(selectedItem)
        
        // 3. Clipboard Play (2 words, clipboard icon, ⌃P)
        let clipboardItem = NSMenuItem(title: "Clipboard Play", action: #selector(speakClipboard), keyEquivalent: "p")
        clipboardItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Play") {
            icon.isTemplate = true
            clipboardItem.image = icon
        }
        clipboardItem.target = self
        menu.addItem(clipboardItem)
        
        // 4. Stop (1 word, stop icon, ⌃X)
        let stopItem = NSMenuItem(title: "Stop", action: #selector(stopSpeech), keyEquivalent: "x")
        stopItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: "Stop") {
            icon.isTemplate = true
            stopItem.image = icon
        }
        stopItem.target = self
        stopItem.isEnabled = isSpeaking
        menu.addItem(stopItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Quit (1 word, power icon, ⌘Q)
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        if let icon = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit") {
            icon.isTemplate = true
            quitItem.image = icon
        }
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // MARK: - Dashboard Window Management
    
    func setupDashboardWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 570),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 740, height: 490)
        window.maxSize = NSSize(width: 900, height: 900)
        window.center()
        window.isReleasedWhenClosed = false
        window.title = "Agent Speak"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.isOpaque = true
        window.backgroundColor = NSColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1.0)
        
        let hostingView = NSHostingView(rootView: DashboardView())
        window.contentView = hostingView
        
        self.dashboardWindow = window
    }
    
    private func loadCurrentMacosVoice() -> String {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audio = json["audio"] as? [String: Any],
              let mv = audio["macos_voice"] as? String else {
            return "default"
        }
        return mv
    }
    
    private func saveMacosVoicePreference(voice: String) {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var audio = json["audio"] as? [String: Any] ?? [:]
        audio["macos_voice"] = voice
        json["audio"] = audio
        
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? updated.write(to: configPath)
        }
    }
    
    @objc func selectVoiceFromMenu(_ sender: NSMenuItem) {
        guard let vTag = sender.representedObject as? String else { return }
        saveMacosVoicePreference(voice: vTag)
        let voiceName = vTag == "default" ? "System Default" : vTag
        SpeechQueueManager.shared.enqueue(
            source: "Agent Speak",
            text: "Voice switched to \(voiceName)."
        )
    }
    
    @objc public func showDashboard() {
        guard let window = dashboardWindow else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func toggleDashboard() {
        guard let window = dashboardWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showDashboard()
        }
    }
    
    // MARK: - Actions
    
    @objc func speakSelected() {
        // Wait 0.15s to ensure previous application window has key focus if triggered from menu click
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.captureAndSpeakSelectedText()
        }
    }
    
    public func captureAndSpeakSelectedText() {
        // 1. First attempt: AXUIElement (Fastest, zero clipboard modification)
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppValue: AnyObject?
        if AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success,
           let focusedApp = focusedAppValue {
            var focusedElementValue: AnyObject?
            if AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue) == .success,
               let focusedElem = focusedElementValue {
                var selectedTextValue: AnyObject?
                if AXUIElementCopyAttributeValue(focusedElem as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success,
                   let str = selectedTextValue as? String {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        let clean = TextSanitizer.sanitizeForSpeech(trimmed)
                        if !clean.isEmpty {
                            SpeechQueueManager.shared.enqueue(source: "Selected Text", text: clean)
                            return
                        }
                    }
                }
            }
        }
        
        // 2. Second attempt: Synthetic Command + C simulation (Universal across Chrome, Safari, Electron, Code Editors)
        let pb = NSPasteboard.general
        let prevCount = pb.changeCount
        let previousString = pb.string(forType: .string)
        
        let src = CGEventSource(stateID: .hidSystemState)
        let cDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true) // 'c'
        cDown?.flags = .maskCommand
        let cUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            if pb.changeCount != prevCount,
               let copied = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !copied.isEmpty {
                let clean = TextSanitizer.sanitizeForSpeech(copied)
                if !clean.isEmpty {
                    SpeechQueueManager.shared.enqueue(source: "Selected Text", text: clean)
                    return
                }
            }
            
            // 3. AppleScript keystroke fallback if CGEvent tap was filtered
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", "tell application \"System Events\" to keystroke \"c\" using {command down}"]
            try? p.run()
            p.waitUntilExit()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                if let copied = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !copied.isEmpty, copied != previousString {
                    let clean = TextSanitizer.sanitizeForSpeech(copied)
                    if !clean.isEmpty {
                        SpeechQueueManager.shared.enqueue(source: "Selected Text", text: clean)
                        return
                    }
                }
                
                // If nothing was selected, beep to give user feedback
                NSSound.beep()
            }
        }
    }
    
    @objc func speakClipboard() {
        if let pbText = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !pbText.isEmpty {
            let clean = TextSanitizer.sanitizeForSpeech(pbText)
            if !clean.isEmpty {
                SpeechQueueManager.shared.enqueue(source: "Clipboard", text: clean)
            }
        }
    }
    
    @objc func testVoice() {
        SpeechQueueManager.shared.enqueue(
            source: "Agent Speak",
            text: "Testing the default system voice. Agent Speak is running smoothly."
        )
    }
    
    @objc func stopSpeech() {
        SpeechQueueManager.shared.stopCurrent()
    }
    
    // MARK: - Global HotKeys (Carbon)
    
    private func registerGlobalHotKeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let target = GetEventDispatcherTarget()
        
        InstallEventHandler(target, { (handler, event, userData) -> OSStatus in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            DispatchQueue.main.async {
                guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
                switch hotKeyID.id {
                case 1: // Ctrl + S: Selected Play
                    appDelegate.captureAndSpeakSelectedText()
                case 2: // Ctrl + P: Clipboard Play
                    appDelegate.speakClipboard()
                case 3: // Ctrl + ,: Settings
                    appDelegate.showDashboard()
                case 4: // Ctrl + X: Stop
                    appDelegate.stopSpeech()
                default:
                    break
                }
            }
            return noErr
        }, 1, &eventType, nil, &eventHandlerRef)
        
        let sig: OSType = 0x4153504B // "ASPK"
        
        // 1. Ctrl + S (Selected Play)
        var ref1: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(kVK_ANSI_S), UInt32(controlKey), EventHotKeyID(signature: sig, id: 1), target, 0, &ref1) == noErr, let r = ref1 {
            hotKeyRefs.append(r)
        }
        
        // 2. Ctrl + P (Clipboard Play)
        var ref2: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(kVK_ANSI_P), UInt32(controlKey), EventHotKeyID(signature: sig, id: 2), target, 0, &ref2) == noErr, let r = ref2 {
            hotKeyRefs.append(r)
        }
        
        // 3. Ctrl + , (Settings)
        var ref3: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(kVK_ANSI_Comma), UInt32(controlKey), EventHotKeyID(signature: sig, id: 3), target, 0, &ref3) == noErr, let r = ref3 {
            hotKeyRefs.append(r)
        }
        
        // 4. Ctrl + X (Stop)
        var ref4: EventHotKeyRef?
        if RegisterEventHotKey(UInt32(kVK_ANSI_X), UInt32(controlKey), EventHotKeyID(signature: sig, id: 4), target, 0, &ref4) == noErr, let r = ref4 {
            hotKeyRefs.append(r)
        }
    }
    
    @objc func confirmHideTrayIcon() {
        let alert = NSAlert()
        alert.messageText = "Hide Agent Speak from Menu Bar?"
        alert.informativeText = "Agent Speak will continue running in the background. You can restore the menu bar icon anytime from the Agent Speak Dashboard or by running 'agentspeak tray on' in Terminal."
        alert.addButton(withTitle: "Hide Icon")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        if alert.runModal() == .alertFirstButtonReturn {
            setTrayIconVisible(false)
        }
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
