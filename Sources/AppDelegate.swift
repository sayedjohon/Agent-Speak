import Cocoa
import SwiftUI
import Carbon
import QuartzCore

public class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    public static var shared: AppDelegate!
    
    var statusItem: NSStatusItem?
    var dashboardWindow: NSWindow?
    var trayHostingView: PassthroughHostingView<TrayGradientOrbView>?
    private var dashboardDisplayLink: CADisplayLink?
    
    var idleIcon: NSImage?
    var speakingIcon: NSImage?
    
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    
    public var isTrayIconVisible: Bool {
        return statusItem?.isVisible ?? false
    }
    
    public override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 0. Single-Instance Guard: If already running, activate the existing instance and exit immediately
        let myPid = ProcessInfo.processInfo.processIdentifier
        let bundleId = Bundle.main.bundleIdentifier ?? "com.agentspeak.app"
        let otherApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).filter { $0.processIdentifier != myPid }
        
        if let existingApp = otherApps.first {
            NSLog("[AgentSpeak] Instance already running (PID %d). Activating existing instance and exiting.", existingApp.processIdentifier)
            if #available(macOS 14.0, *) {
                existingApp.activate()
            } else {
                existingApp.activate(options: [.activateIgnoringOtherApps])
            }
            exit(0)
        }
        
        let pidFile = "/tmp/agentspeak.pid"
        try? "\(myPid)".write(toFile: pidFile, atomically: true, encoding: .utf8)

        // 1. Immediately start transcript monitoring and IPC socket
        TranscriptWatcher.shared.onSpeechRequest = { source, text in
            SpeechQueueManager.shared.enqueue(source: source, text: text)
        }
        TranscriptWatcher.shared.start()
        
        loadTrayIcons()
        
        // Ensure preferred menu bar position is registered away from the notch
        if UserDefaults.standard.object(forKey: "NSStatusItem Preferred Position AgentSpeakTray") == nil {
            UserDefaults.standard.set(360.0, forKey: "NSStatusItem Preferred Position AgentSpeakTray")
        }
        
        let showTray = loadTrayPreference()
        if showTray {
            setupMenuBar()
        }
        
        NotchWindowController.shared.setupEscapeKeyTap()
        FnDictationController.shared.start()
        registerGlobalHotKeys()
        
        // Listen for live speech state to toggle tray visual indicator
        SpeechQueueManager.shared.onSpeakingChanged = { [weak self] isSpeaking in
            self?.updateTrayIcon(isSpeaking: isSpeaking)
        }
        
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        NSLog("[AgentSpeak] Accessibility permission on launch: \(trusted ? "TRUSTED" : "NOT TRUSTED")")
        
        // Load speak code blocks preference
        CodeSpeechManager.shared.loadConfiguration()
        
        // Initialize Camera Gesture engine if enabled in config
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        if let data = try? Data(contentsOf: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let gestures = json["gestures"] as? [String: Any],
           let enabled = gestures["enabled"] as? Bool, enabled {
            CameraGestureManager.shared.start()
        }
        
        // Announce persona signature greeting once at application startup
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            let mgr = PersonaGreetingManager.shared
            mgr.loadConfiguration()
            if mgr.speakOnStartup {
                let greeting = mgr.resolveGreeting()
                SpeechQueueManager.shared.enqueue(source: greeting.character, text: greeting.text)
            }
        }
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
        button.toolTip = isSpeaking ? "Agent Speak: Speaking... (Click for options)" : "Agent Speak: Ready (Click for options)"
        
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
            button.toolTip = isSpeaking ? "Agent Speak: Speaking... (Click for options)" : "Agent Speak: Ready (Click for options)"
        }
    }
    
    public func getTrayButtonScreenFrame() -> NSRect? {
        guard let button = statusItem?.button, let win = button.window else { return nil }
        return win.convertToScreen(button.bounds)
    }
    
    public func setTrayIconVisible(_ visible: Bool) {
        saveTrayPreference(visible: visible)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if visible {
                if self.statusItem == nil {
                    self.setupMenuBar()
                } else {
                    self.statusItem?.isVisible = true
                }
            } else {
                self.statusItem?.isVisible = false
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
        let bgmEnabled = BackgroundMusicManager.shared.isEnabled
        
        // 1. Speak Selection (text viewfinder icon, ⌃S)
        let selectedItem = NSMenuItem(title: "Speak Selection", action: #selector(speakSelected), keyEquivalent: "s")
        selectedItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Speak Selection") {
            icon.isTemplate = true
            selectedItem.image = icon
        }
        selectedItem.target = self
        menu.addItem(selectedItem)
        
        // 2. Speak Clipboard (clipboard icon, ⌃P)
        let clipboardItem = NSMenuItem(title: "Speak Clipboard", action: #selector(speakClipboard), keyEquivalent: "p")
        clipboardItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Speak Clipboard") {
            icon.isTemplate = true
            clipboardItem.image = icon
        }
        clipboardItem.target = self
        menu.addItem(clipboardItem)
        
        // 3. Stop Speech (stop icon, ⌃X)
        let stopItem = NSMenuItem(title: "Stop Speech", action: #selector(stopSpeech), keyEquivalent: "x")
        stopItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: "Stop Speech") {
            icon.isTemplate = true
            stopItem.image = icon
        }
        stopItem.target = self
        stopItem.isEnabled = isSpeaking
        menu.addItem(stopItem)
        
        // 4. Re-listen to Last Speech (arrow.counterclockwise.circle, ⌃R)
        let rawPrompt = LastVoiceManager.shared.textPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let previewTitle: String
        if rawPrompt.isEmpty {
            previewTitle = "Re-listen to Last Speech"
        } else {
            let truncated = rawPrompt.count > 34 ? String(rawPrompt.prefix(32)) + "…" : rawPrompt
            previewTitle = "Replay: \"\(truncated)\""
        }
        let replayItem = NSMenuItem(title: previewTitle, action: #selector(replayLastSpeech), keyEquivalent: "r")
        replayItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "arrow.counterclockwise.circle", accessibilityDescription: "Re-listen to Last Speech") {
            icon.isTemplate = true
            replayItem.image = icon
        }
        replayItem.target = self
        replayItem.isEnabled = LastVoiceManager.shared.hasVoice || !rawPrompt.isEmpty
        menu.addItem(replayItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Speak Code Blocks Toggle (curly braces icon, checkmark state)
        let speakCode = CodeSpeechManager.shared.speakCodeBlocks
        let speakCodeTitle = speakCode ? "Speak Code Blocks: Active" : "Speak Everything Including Code Blocks"
        let speakCodeItem = NSMenuItem(
            title: speakCodeTitle,
            action: #selector(toggleSpeakCodeBlocks),
            keyEquivalent: ""
        )
        speakCodeItem.state = speakCode ? .on : .off
        if let icon = NSImage(systemSymbolName: speakCode ? "curlybraces.square.fill" : "curlybraces", accessibilityDescription: "Speak Code Blocks") {
            icon.isTemplate = true
            speakCodeItem.image = icon
        }
        speakCodeItem.target = self
        menu.addItem(speakCodeItem)
        
        // 5. Hands-Free Gestures Direct 1-Click Toggle (hand icon, checkmark state, ⌃G)
        let gesturesRunning = CameraGestureManager.shared.isRunning
        let gestureTitle = gesturesRunning ? "Hands-Free Gestures: Active" : "Hands-Free Gestures: Off"
        let gestureItem = NSMenuItem(
            title: gestureTitle,
            action: #selector(toggleHandsFreeGestures),
            keyEquivalent: "g"
        )
        gestureItem.keyEquivalentModifierMask = [.control]
        gestureItem.state = gesturesRunning ? .on : .off
        if let icon = NSImage(systemSymbolName: gesturesRunning ? "hand.raised.fill" : "hand.raised", accessibilityDescription: "Hands-Free Gestures") {
            icon.isTemplate = true
            gestureItem.image = icon
        }
        gestureItem.target = self
        menu.addItem(gestureItem)
        
        // 5. Background Music Direct 1-Click Toggle (music icon, checkmark state)
        let bgmItem = NSMenuItem(
            title: bgmEnabled ? "Background Music: On" : "Background Music: Off",
            action: #selector(toggleBackgroundMusic),
            keyEquivalent: ""
        )
        bgmItem.state = bgmEnabled ? .on : .off
        if let icon = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Background Music") {
            icon.isTemplate = true
            bgmItem.image = icon
        }
        bgmItem.target = self
        menu.addItem(bgmItem)
        
        // 6. Hologram Overlay Direct 1-Click Toggle (atom icon, checkmark state, ⌃H)
        let holoEnabled = HologramManager.shared.isEnabled
        let holoTitle = holoEnabled ? "Hologram Overlay: Active" : "Hologram Overlay: Disabled"
        let holoItem = NSMenuItem(
            title: holoTitle,
            action: #selector(toggleHologramOverlay),
            keyEquivalent: "h"
        )
        holoItem.keyEquivalentModifierMask = [.control]
        holoItem.state = holoEnabled ? .on : .off
        if let icon = NSImage(systemSymbolName: holoEnabled ? "atom" : "circle.slash", accessibilityDescription: "Hologram Overlay") {
            icon.isTemplate = true
            holoItem.image = icon
        }
        holoItem.target = self
        menu.addItem(holoItem)
        
        // 7. Hologram Blend Mode Submenu (Photoshop Modes)
        let blendSubmenu = NSMenu()
        for mode in HologramBlendMode.allCases {
            let isCurrent = (HologramManager.shared.currentBlendMode == mode)
            let item = NSMenuItem(title: mode.displayName, action: #selector(selectBlendModeFromMenu(_:)), keyEquivalent: "")
            item.representedObject = mode.id
            item.state = isCurrent ? .on : .off
            item.target = self
            if let modeIcon = NSImage(systemSymbolName: mode.systemIcon, accessibilityDescription: mode.displayName) {
                modeIcon.isTemplate = true
                item.image = modeIcon
            }
            blendSubmenu.addItem(item)
        }
        let blendParentItem = NSMenuItem(title: "Hologram Blend Mode (\(HologramManager.shared.currentBlendMode.displayName))", action: nil, keyEquivalent: "")
        if let bIcon = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "Blend Mode") {
            bIcon.isTemplate = true
            blendParentItem.image = bIcon
        }
        blendParentItem.submenu = blendSubmenu
        menu.addItem(blendParentItem)

        menu.addItem(NSMenuItem.separator())
        
        // 5. Settings (gear icon, ⌃,)
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showDashboard), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.control]
        if let icon = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings") {
            icon.isTemplate = true
            settingsItem.image = icon
        }
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Quit Agent Speak (power icon, ⌘Q)
        let quitItem = NSMenuItem(title: "Quit Agent Speak", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        if let icon = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit Agent Speak") {
            icon.isTemplate = true
            quitItem.image = icon
        }
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // MARK: - Dashboard Window Management
    
    func setupDashboardWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 840, height: 580)
        window.maxSize = NSSize(width: 1100, height: 850)
        window.setFrameAutosaveName("AgentSpeakDashboardWindow")
        if !window.setFrameUsingName("AgentSpeakDashboardWindow") {
            window.center()
        }
        window.isReleasedWhenClosed = false
        window.title = "Agent Speak"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.level = .normal
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        
        window.delegate = self
        
        let hostingView = NSHostingView(rootView: DashboardView())
        hostingView.wantsLayer = true
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        window.contentView = hostingView
        
        self.dashboardWindow = window
    }
    
    // MARK: - Hardware ProMotion 120Hz Window Engine
    
    public func startDashboardDisplayLink() {
        guard dashboardDisplayLink == nil else { return }
        if #available(macOS 14.0, *), let view = dashboardWindow?.contentView {
            let link = view.displayLink(target: self, selector: #selector(onDashboardDisplayTick(link:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            self.dashboardDisplayLink = link
        }
    }
    
    public func stopDashboardDisplayLink() {
        dashboardDisplayLink?.invalidate()
        dashboardDisplayLink = nil
    }
    
    @objc private func onDashboardDisplayTick(link: CADisplayLink) {
        // Locks macOS WindowServer compositor to true 120Hz ProMotion mode
    }
    
    public func windowDidBecomeKey(_ notification: Notification) {
        if notification.object as? NSWindow == dashboardWindow {
            startDashboardDisplayLink()
        }
    }
    
    public func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == dashboardWindow {
            stopDashboardDisplayLink()
            NSApp.setActivationPolicy(.accessory)
        }
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
        let greeting = PersonaGreetingManager.shared.resolveVoiceSwitchGreeting(voiceName: voiceName)
        SpeechQueueManager.shared.enqueue(
            source: greeting.character,
            text: greeting.text
        )
    }
    
    @objc public func showDashboard() {
        if dashboardWindow == nil {
            setupDashboardWindow()
        }
        guard let window = dashboardWindow else { return }
        NSApp.setActivationPolicy(.regular)
        if let iconUrl = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconUrl) {
            NSApp.applicationIconImage = icon
        }
        if !window.setFrameUsingName("AgentSpeakDashboardWindow") && !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        startDashboardDisplayLink()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func toggleDashboard() {
        if dashboardWindow == nil {
            setupDashboardWindow()
        }
        guard let window = dashboardWindow else { return }
        if window.isVisible {
            stopDashboardDisplayLink()
            window.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
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
    
    public func extractAXSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppValue: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue) == .success,
              let focusedApp = focusedAppValue else { return nil }
        
        var focusedElementValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElementValue) == .success,
              let focusedElem = focusedElementValue else { return nil }
        
        var selectedTextValue: AnyObject?
        if AXUIElementCopyAttributeValue(focusedElem as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue) == .success,
           let str = selectedTextValue as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
    
    public func captureAndSpeakSelectedText() {
        // Stop previous speech immediately so selection takes priority
        SpeechQueueManager.shared.stopCurrent()
        
        let pb = NSPasteboard.general
        let prevCount = pb.changeCount
        
        // Post synthetic Command + C using combinedSessionState (independent of held modifier keys)
        let src = CGEventSource(stateID: .combinedSessionState)
        let cDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true) // 'c'
        cDown?.flags = .maskCommand
        let cUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        cUp?.flags = .maskCommand
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        
        // AppleScript fallback trigger in background for apps with strict event tap filtering
        DispatchQueue.global(qos: .userInitiated).async {
            usleep(35_000) // 35ms
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", "tell application \"System Events\" to keystroke \"c\" using {command down}"]
            try? p.run()
            p.waitUntilExit()
        }
        
        let startTime = Date()
        func checkPasteboardResult() {
            if pb.changeCount != prevCount,
               let copied = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !copied.isEmpty {
                let clean = TextSanitizer.sanitizeForSpeech(copied)
                if !clean.isEmpty {
                    SpeechQueueManager.shared.enqueue(source: "Selected Text", text: clean, immediate: true)
                    return
                }
            }
            
            if Date().timeIntervalSince(startTime) < 0.35 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                    checkPasteboardResult()
                }
            } else {
                // Fallback 1: Accessibility API text
                if let axText = self.extractAXSelectedText() {
                    let clean = TextSanitizer.sanitizeForSpeech(axText)
                    if !clean.isEmpty {
                        SpeechQueueManager.shared.enqueue(source: "Selected Text", text: clean, immediate: true)
                        return
                    }
                }
                
                // Fallback 2: Any existing clipboard text
                if let existing = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !existing.isEmpty {
                    let clean = TextSanitizer.sanitizeForSpeech(existing)
                    if !clean.isEmpty {
                        SpeechQueueManager.shared.enqueue(source: "Selected Text", text: clean, immediate: true)
                        return
                    }
                }
                
                NSSound.beep()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            checkPasteboardResult()
        }
    }
    
    @objc func speakClipboard() {
        if let pbText = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !pbText.isEmpty {
            let clean = TextSanitizer.sanitizeForSpeech(pbText)
            if !clean.isEmpty {
                SpeechQueueManager.shared.enqueue(source: "Clipboard", text: clean, immediate: true)
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
    
    @objc func replayLastSpeech() {
        LastVoiceManager.shared.replayVoice()
    }
    
    @objc func toggleSpeakCodeBlocks() {
        CodeSpeechManager.shared.toggle()
        let state = CodeSpeechManager.shared.speakCodeBlocks ? "ENABLED" : "DISABLED"
        NSLog("[AgentSpeak] Toggled speak code blocks -> \(state)")
    }
    
    @objc func toggleBackgroundMusic() {
        let current = BackgroundMusicManager.shared.isEnabled
        BackgroundMusicManager.shared.isEnabled = !current
        BackgroundMusicManager.shared.saveConfig()
        if current {
            BackgroundMusicManager.shared.stopWithFadeAndReverb()
        } else {
            if SpeechQueueManager.shared.isSpeaking {
                BackgroundMusicManager.shared.start()
            }
        }
    }
    
    @objc func toggleHologramOverlay() {
        let current = HologramManager.shared.isEnabled
        HologramManager.shared.setEnabled(!current)
    }
    
    @objc func selectBlendModeFromMenu(_ sender: NSMenuItem) {
        if let modeId = sender.representedObject as? String {
            HologramManager.shared.setBlendMode(id: modeId)
        }
    }
    
    private var lastGestureToggleTime: TimeInterval = 0
    @objc func toggleHandsFreeGestures() {
        let now = Date().timeIntervalSince1970
        guard now - lastGestureToggleTime > 0.35 else { return }
        lastGestureToggleTime = now
        
        let willBeRunning = !CameraGestureManager.shared.isRunning
        CameraGestureManager.shared.toggle()
        NSLog("[AgentSpeak] Toggled hands-free gestures -> \(willBeRunning ? "STARTING" : "STOPPING")")
        
        if willBeRunning {
            NSSound(named: "Pop")?.play()
        } else {
            NSSound(named: "Blow")?.play()
        }
    }
    
    // MARK: - Global HotKeys (Carbon)
    
    private func registerGlobalHotKeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let target = GetEventDispatcherTarget()
        let sig: OSType = 0x4153504B // "ASPK"
        
        InstallEventHandler(target, { (handler, event, userData) -> OSStatus in
            guard let event = event else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            guard hotKeyID.signature == 0x4153504B else {
                return OSStatus(eventNotHandledErr)
            }
            
            DispatchQueue.main.async {
                guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
                switch hotKeyID.id {
                case 1: // Ctrl + S: Speak Selection
                    appDelegate.captureAndSpeakSelectedText()
                case 2: // Ctrl + P: Speak Clipboard
                    appDelegate.speakClipboard()
                case 3: // Ctrl + ,: Settings
                    appDelegate.showDashboard()
                case 4: // Ctrl + X: Stop Speech
                    appDelegate.stopSpeech()
                case 5: // Ctrl + G: Toggle Camera Gestures
                    NSLog("[AgentSpeak] Carbon HotKey Ctrl+G fired.")
                    appDelegate.toggleHandsFreeGestures()
                case 6: // Ctrl + R: Replay Last Speech
                    NSLog("[AgentSpeak] Carbon HotKey Ctrl+R fired.")
                    appDelegate.replayLastSpeech()
                default:
                    break
                }
            }
            return noErr
        }, 1, &eventType, nil, &eventHandlerRef)
        
        let hotkeys: [(Int, Int)] = [
            (kVK_ANSI_S, 1),      // Ctrl + S (Speak Selection)
            (kVK_ANSI_P, 2),      // Ctrl + P (Speak Clipboard)
            (kVK_ANSI_Comma, 3),  // Ctrl + , (Settings)
            (kVK_ANSI_X, 4),      // Ctrl + X (Stop Speech)
            (kVK_ANSI_G, 5),      // Ctrl + G (Toggle Camera Gestures)
            (kVK_ANSI_R, 6)       // Ctrl + R (Replay Last Speech)
        ]
        for (vk, hid) in hotkeys {
            var ref: EventHotKeyRef?
            if RegisterEventHotKey(UInt32(vk), UInt32(controlKey), EventHotKeyID(signature: sig, id: UInt32(hid)), target, 0, &ref) == noErr, let r = ref {
                hotKeyRefs.append(r)
            }
        }
        
        // Redundant NSEvent Global Monitor for Control + G and Control + R
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.control), let key = event.charactersIgnoringModifiers?.lowercased() else { return }
            if key == "g" || event.keyCode == 5 {
                DispatchQueue.main.async { self?.toggleHandsFreeGestures() }
            } else if key == "r" || event.keyCode == 15 {
                DispatchQueue.main.async { self?.replayLastSpeech() }
            }
        }
        
        // Redundant NSEvent Local Monitor (when Agent Speak itself is focused)
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.control), let key = event.charactersIgnoringModifiers?.lowercased() else { return event }
            if key == "g" || event.keyCode == 5 {
                DispatchQueue.main.async { self?.toggleHandsFreeGestures() }
                return nil
            } else if key == "r" || event.keyCode == 15 {
                DispatchQueue.main.async { self?.replayLastSpeech() }
                return nil
            }
            return event
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
        // Unload launch agent so launchd will not automatically restart the app on user quit
        let uid = getuid()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["bootout", "gui/\(uid)/com.agentspeak.app"]
        try? proc.run()
        proc.waitUntilExit()
        
        let pidFile = "/tmp/agentspeak.pid"
        try? FileManager.default.removeItem(atPath: pidFile)
        
        NSApp.terminate(nil)
    }
}
