import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    public static var shared: AppDelegate!
    
    var statusItem: NSStatusItem?
    var dashboardWindow: NSWindow?
    
    private var idleIcon: NSImage?
    private var speakingIcon: NSImage?
    
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
            idleIcon = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Agent Speak")
            idleIcon?.isTemplate = true
        }
        if speakingIcon == nil {
            speakingIcon = NSImage(systemSymbolName: "waveform.badge.magnifyingglass", accessibilityDescription: "Agent Speak Active")
        }
    }
    
    // MARK: - Menu Bar Setup & State
    
    public func setupMenuBar() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem?.autosaveName = "AgentSpeakTray"
        }
        
        guard let item = statusItem, let button = item.button else { return }
        
        let isSpeaking = SpeechQueueManager.shared.isSpeaking
        button.image = isSpeaking ? (speakingIcon ?? idleIcon) : idleIcon
        button.toolTip = isSpeaking ? "Agent Speak: Speaking... (Click for options)" : "Agent Speak: Ready & Monitoring (Click for options)"
        
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.isVisible = true
    }
    
    public func updateTrayIcon(isSpeaking: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let button = self.statusItem?.button else { return }
            button.image = isSpeaking ? (self.speakingIcon ?? self.idleIcon) : self.idleIcon
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
        
        // 1. Live Status Header
        let statusTitle = isSpeaking ? "🟢 Agent Speak: Speaking..." : "⚪ Agent Speak: Ready & Monitoring"
        let statusItem = NSMenuItem(title: statusTitle, action: #selector(showDashboard), keyEquivalent: "")
        statusItem.target = self
        let font = NSFont.boldSystemFont(ofSize: 13)
        statusItem.attributedTitle = NSAttributedString(string: statusTitle, attributes: [.font: font])
        menu.addItem(statusItem)
        
        if isSpeaking && !SpeechQueueManager.shared.currentSpeakerSource.isEmpty {
            let sourceItem = NSMenuItem(title: "    Active Source: \(SpeechQueueManager.shared.currentSpeakerSource)", action: nil, keyEquivalent: "")
            sourceItem.isEnabled = false
            menu.addItem(sourceItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Open Dashboard
        let dashItem = NSMenuItem(title: "Open Agent Speak Dashboard...", action: #selector(showDashboard), keyEquivalent: "d")
        dashItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: nil)
        dashItem.target = self
        menu.addItem(dashItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Quick Actions
        let pbItem = NSMenuItem(title: "Speak Clipboard Text (ChatGPT / Web)", action: #selector(speakClipboard), keyEquivalent: "p")
        pbItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        pbItem.target = self
        menu.addItem(pbItem)
        
        let testItem = NSMenuItem(title: "Test System Voice", action: #selector(testVoice), keyEquivalent: "t")
        testItem.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
        testItem.target = self
        menu.addItem(testItem)
        
        let stopItem = NSMenuItem(title: "Stop Speech (or press Esc)", action: #selector(stopSpeech), keyEquivalent: "s")
        stopItem.image = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: nil)
        stopItem.target = self
        stopItem.isEnabled = isSpeaking
        menu.addItem(stopItem)
        
        // Voice Quick Selection Submenu
        let voiceMenu = NSMenu()
        let currentVoice = loadCurrentMacosVoice()
        let topVoices = [
            ("default", "Default (System Default)"),
            ("Samantha", "Samantha (US English)"),
            ("Daniel", "Daniel (British English)"),
            ("Karen", "Karen (Australian English)"),
            ("Moira", "Moira (Irish English)"),
            ("Rishi", "Rishi (Indian English)"),
            ("Tessa", "Tessa (South African English)"),
            ("Fred", "Fred (Classic macOS)"),
            ("Piya", "Piya (Bengali)")
        ]
        for (vTag, vName) in topVoices {
            let vItem = NSMenuItem(title: vName, action: #selector(selectVoiceFromMenu(_:)), keyEquivalent: "")
            vItem.target = self
            vItem.representedObject = vTag
            vItem.state = ((vTag == currentVoice) || (currentVoice.isEmpty && vTag == "default")) ? .on : .off
            voiceMenu.addItem(vItem)
        }
        let voiceSelectorItem = NSMenuItem(title: "Select MacBook Voice", action: nil, keyEquivalent: "")
        voiceSelectorItem.image = NSImage(systemSymbolName: "person.wave.2", accessibilityDescription: nil)
        voiceSelectorItem.submenu = voiceMenu
        menu.addItem(voiceSelectorItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Monitored Workspaces Status
        let agentsHeader = NSMenuItem(title: "Monitored Workspaces:", action: nil, keyEquivalent: "")
        agentsHeader.isEnabled = false
        menu.addItem(agentsHeader)
        
        let antigravityItem = NSMenuItem(title: "  ✓ Antigravity AI Workspaces", action: nil, keyEquivalent: "")
        antigravityItem.isEnabled = false
        menu.addItem(antigravityItem)
        
        let claudeItem = NSMenuItem(title: "  ✓ Claude Code & Desktop", action: nil, keyEquivalent: "")
        claudeItem.isEnabled = false
        menu.addItem(claudeItem)
        
        let openCodeItem = NSMenuItem(title: "  ✓ OpenCode & Terminal Socket", action: nil, keyEquivalent: "")
        openCodeItem.isEnabled = false
        menu.addItem(openCodeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Hide from Menu Bar
        let hideItem = NSMenuItem(title: "Hide Menu Bar Icon...", action: #selector(confirmHideTrayIcon), keyEquivalent: "")
        hideItem.image = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: nil)
        hideItem.target = self
        menu.addItem(hideItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 6. Quit
        let quitItem = NSMenuItem(title: "Quit Agent Speak", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // MARK: - Dashboard Window Management
    
    func setupDashboardWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 740, height: 490),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 740, height: 490)
        window.maxSize = NSSize(width: 740, height: 490)
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
