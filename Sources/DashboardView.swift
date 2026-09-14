import SwiftUI
import Cocoa
import AVFoundation

// MARK: - System Voice Model
public struct SystemVoiceItem: Identifiable, Hashable {
    public var id: String { tag }
    public let tag: String
    public let label: String
    
    public init(tag: String, label: String) {
        self.tag = tag
        self.label = label
    }
}

// MARK: - Dashboard Navigation Tabs
enum DashboardTab: String, CaseIterable, Identifiable {
    case voice = "Voice & Playback"
    case workspaces = "AI Workspaces"
    case hardware = "Notch & Menu Bar"
    case shortcuts = "Shortcuts & CLI"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .voice: return "waveform"
        case .workspaces: return "circle.hexagongrid.fill"
        case .hardware: return "macbook.and.ipad"
        case .shortcuts: return "terminal.fill"
        }
    }
}

// MARK: - Dashboard Main View
public struct DashboardView: View {
    @ObservedObject var queueManager = SpeechQueueManager.shared
    @State private var selectedTab: DashboardTab = .voice
    
    // Config States
    @State private var isEnabled: Bool = true
    @State private var voiceEngine: String = "macos_default"
    @State private var macosVoice: String = "default"
    @State private var pocketVoice: String = "Jarvis"
    @State private var skipSeconds: Int = 5
    @State private var showTrayIcon: Bool = true
    @State private var availableSystemVoices: [SystemVoiceItem] = []
    @State private var customTestText: String = "Hello Johon! Agent Speak is live with multilingual speech."
    
    // Workspace States
    @State private var watchAntigravity: Bool = true
    @State private var watchClaude: Bool = true
    @State private var watchOpenCode: Bool = true
    @State private var watchTerminal: Bool = true
    @State private var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
    
    public init() {}
    
    private var brandLogoImage: NSImage? {
        let paths = [
            "/Users/sayedjohon/Downloads/Agent-Speak-logo.png",
            Bundle.main.bundlePath + "/Contents/Resources/Agent-Speak-logo.png",
            Bundle.main.bundlePath + "/Contents/Resources/AppIcon.icns"
        ]
        for p in paths {
            if FileManager.default.fileExists(atPath: p), let img = NSImage(contentsOfFile: p) {
                return img
            }
        }
        return NSImage(named: "AppIcon")
    }
    
    private var selectedVoiceDisplayName: String {
        if macosVoice == "default" || macosVoice.isEmpty {
            return "System Default"
        }
        return availableSystemVoices.first(where: { $0.tag == macosVoice })?.label ?? macosVoice
    }
    
    // MARK: - Configuration I/O
    
    private func loadConfig() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        if let audio = json["audio"] as? [String: Any] {
            if let engine = audio["engine"] as? String { voiceEngine = engine }
            if let mv = audio["macos_voice"] as? String { macosVoice = mv }
            if let s = audio["skip_seconds"] as? Int { skipSeconds = s }
            if let ptts = audio["pocket_tts"] as? [String: Any], let v = ptts["voice"] as? String { pocketVoice = v }
        }
        
        if let general = json["general"] as? [String: Any] {
            if let show = general["show_tray_icon"] as? Bool { showTrayIcon = show }
            if let en = general["enabled"] as? Bool { isEnabled = en }
        }
    }
    
    private func saveConfig() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var audio = json["audio"] as? [String: Any] ?? [:]
        audio["engine"] = voiceEngine
        audio["macos_voice"] = macosVoice
        audio["skip_seconds"] = skipSeconds
        var ptts = audio["pocket_tts"] as? [String: Any] ?? [:]
        ptts["voice"] = pocketVoice
        ptts["enabled"] = (voiceEngine == "pocket_tts")
        audio["pocket_tts"] = ptts
        json["audio"] = audio
        
        var general = json["general"] as? [String: Any] ?? [:]
        general["show_tray_icon"] = showTrayIcon
        general["enabled"] = isEnabled
        json["general"] = general
        
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? updated.write(to: configPath)
        }
    }
    
    private func loadAvailableVoices() -> [SystemVoiceItem] {
        var items: [SystemVoiceItem] = [
            SystemVoiceItem(tag: "default", label: "Default (System Default)")
        ]
        let curated: [(tag: String, label: String)] = [
            ("Samantha", "Samantha (US English)"),
            ("Daniel", "Daniel (British English)"),
            ("Karen", "Karen (Australian English)"),
            ("Moira", "Moira (Irish English)"),
            ("Rishi", "Rishi (Indian English)"),
            ("Tessa", "Tessa (South African English)"),
            ("Fred", "Fred (Classic macOS)"),
            ("Piya", "Piya (Bengali)"),
            ("Alex", "Alex (Natural US)")
        ]
        var seen = Set<String>(["default"])
        for c in curated {
            items.append(SystemVoiceItem(tag: c.tag, label: c.label))
            seen.insert(c.tag.lowercased())
        }
        
        let avVoices = AVSpeechSynthesisVoice.speechVoices()
        for v in avVoices {
            let name = v.name
            if !seen.contains(name.lowercased()) {
                seen.insert(name.lowercased())
                let loc = Locale.current.localizedString(forIdentifier: v.language) ?? v.language
                items.append(SystemVoiceItem(tag: name, label: "\(name) (\(loc))"))
            }
        }
        return items
    }
    
    // MARK: - View Layout
    
    public var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar with solid dark background
            sidebarView
                .frame(width: 215)
                .background(Color(red: 0.09, green: 0.10, blue: 0.13))
            
            // Thin Solid Divider (eliminates see-through gap)
            Rectangle()
                .fill(Color(red: 0.18, green: 0.20, blue: 0.25))
                .frame(width: 1)
            
            // Right Detail Area (Zero Scrolling)
            detailContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.06, green: 0.07, blue: 0.09))
        }
        .frame(width: 740, height: 490)
        .background(Color(red: 0.07, green: 0.08, blue: 0.10))
        .onAppear {
            loadConfig()
            availableSystemVoices = loadAvailableVoices()
            isAccessibilityTrusted = AXIsProcessTrusted()
        }
    }
    
    // MARK: - Sidebar View
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand Header
            HStack(spacing: 9) {
                if let logo = brandLogoImage {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .cornerRadius(6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("AGENT SPEAK")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(queueManager.isSpeaking ? Color.green : (isEnabled ? Color.blue : Color.orange))
                            .frame(width: 6, height: 6)
                        Text(queueManager.isSpeaking ? "SPEAKING" : (isEnabled ? "LISTENING" : "MUTED"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(queueManager.isSpeaking ? .green : (isEnabled ? .blue : .orange))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 20)
            
            // Nav Tab List
            VStack(spacing: 5) {
                ForEach(DashboardTab.allCases) { tab in
                    Button(action: { selectedTab = tab }) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .cyan : .secondary)
                                .frame(width: 20)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .medium))
                                .foregroundColor(selectedTab == tab ? .white : .secondary)
                            
                            Spacer()
                            
                            if tab == .voice && queueManager.isSpeaking {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.white.opacity(0.10) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            
            Spacer()
            
            // Sidebar Footer Deck
            VStack(spacing: 10) {
                Button(action: {
                    if queueManager.isSpeaking {
                        queueManager.stopCurrent()
                    } else {
                        isEnabled.toggle()
                        saveConfig()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: queueManager.isSpeaking ? "stop.fill" : (isEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill"))
                            .font(.system(size: 11))
                        Text(queueManager.isSpeaking ? "Stop Speech (Esc)" : (isEnabled ? "Mute All" : "Unmute"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(queueManager.isSpeaking ? Color.red.opacity(0.25) : Color.white.opacity(0.08))
                    .foregroundColor(queueManager.isSpeaking ? .red : .white)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
                
                Text("v1.0.0 • 100% Native Swift")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(14)
            .background(Color.black.opacity(0.25))
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.12))
    }
    
    // MARK: - Detail Content View
    
    @ViewBuilder
    private var detailContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(tabSubtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 12)
            
            Divider().background(Color.white.opacity(0.08))
            
            // Tab Specific Content (Smooth Scrolling)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .voice:
                        voiceSettingsTab
                    case .workspaces:
                        workspacesTab
                    case .hardware:
                        hardwareTab
                    case .shortcuts:
                        shortcutsTab
                    }
                }
                .padding(22)
            }
        }
    }
    
    private var tabSubtitle: String {
        switch selectedTab {
        case .voice: return "Select native Apple Silicon voice or neural Pocket-TTS extension."
        case .workspaces: return "Configure background transcript monitors for local AI tools."
        case .hardware: return "Adjust MacBook camera notch player and macOS menu bar options."
        case .shortcuts: return "Instant keyboard controls and terminal command cheat sheet."
        }
    }
    
    // MARK: - Tab 1: Voice & Playback
    
    private var voiceSettingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Compact Orb Visualizer
            CompactVisualizerOrbView(isSpeaking: $queueManager.isSpeaking)
                .padding(.vertical, 2)
            
            // Engine Switcher
            VStack(alignment: .leading, spacing: 8) {
                Text("VOICE ENGINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $voiceEngine) {
                    Text("MacBook Voice (Built-in)").tag("macos_default")
                    Text("Pocket-TTS Extension").tag("pocket_tts")
                }
                .pickerStyle(.segmented)
                .onChange(of: voiceEngine) { _ in saveConfig() }
            }
            
            // Active Voice Details Card
            if voiceEngine == "macos_default" {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MacBook System Voice")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Active Voice: \(selectedVoiceDisplayName)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $macosVoice) {
                        ForEach(availableSystemVoices) { v in
                            Text(v.label).tag(v.tag)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 195)
                    .onChange(of: macosVoice) { _ in saveConfig() }
                }
                .padding(11)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pocket-TTS Neural Extension")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text("Active Persona: \(pocketVoice)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $pocketVoice) {
                        Text("Jarvis (Butler)").tag("Jarvis")
                        Text("Sayed Johon (Clone)").tag("Sayed_Johon_Primary")
                        Text("Alba (Storyteller)").tag("alba")
                        Text("George (Narrator)").tag("george")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                    .onChange(of: pocketVoice) { _ in saveConfig() }
                }
                .padding(11)
                .background(Color.white.opacity(0.04))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.3), lineWidth: 1))
            }
            
            // Playback & Skip Controls Card
            VStack(alignment: .leading, spacing: 10) {
                Text("PLAYBACK & SCRUBBING CONTROLS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "goforward")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skip Forward / Backward Step")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Interval leaped by the Notch Player scrub buttons")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Picker("", selection: $skipSeconds) {
                        Text("5 seconds (Default)").tag(5)
                        Text("10 seconds").tag(10)
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 170)
                    .onChange(of: skipSeconds) { _ in saveConfig() }
                }
            }
            .padding(11)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            // Interactive Voice & Multilingual Test Card
            VStack(alignment: .leading, spacing: 8) {
                Text("TEST VOICE & MULTILINGUAL SPEECH")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    TextField("Enter text to speak (e.g. English, বাংলা, हिंदी, Español)...", text: $customTestText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    
                    Button(action: {
                        let textToSpeak = customTestText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let prompt = textToSpeak.isEmpty ? "Testing Agent Speak voice playback." : textToSpeak
                        LastVoiceManager.shared.prepareForNewVoice(text: prompt)
                        SpeechQueueManager.shared.enqueue(
                            source: "Voice Test",
                            text: prompt
                        )
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Test Voice")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Downward: Last Voice Player, Scrubber & Download
                LastVoiceCardView()
                    .padding(.top, 4)
            }
            .padding(11)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
    
    // MARK: - Tab 2: AI Workspaces
    
    private var workspacesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("UNIVERSAL ZERO-LATENCY MONITORS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                workspaceRow(
                    icon: "circle.hexagongrid.circle.fill",
                    color: .purple,
                    title: "Antigravity AI Workspaces",
                    subtitle: "IDE transcripts and agy CLI commands in background",
                    isOn: $watchAntigravity
                )
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
                
                workspaceRow(
                    icon: "terminal.fill",
                    color: .orange,
                    title: "Claude Code CLI & Desktop",
                    subtitle: "Watches project session logs and instant prompts",
                    isOn: $watchClaude
                )
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
                
                workspaceRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: .cyan,
                    title: "OpenCode & Cloud Agents",
                    subtitle: "Monitors opencode SQLite database and trace streams",
                    isOn: $watchOpenCode
                )
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
                
                workspaceRow(
                    icon: "apple.terminal.on.rectangle.fill",
                    color: .green,
                    title: "Universal UNIX Socket & CLI",
                    subtitle: "Local socket listener for terminal commands and clipboard",
                    isOn: $watchTerminal
                )
            }
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                Text("All detected agents stream with instant 50ms runway chunks. No delays.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }
    
    private func workspaceRow(icon: String, color: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    // MARK: - Tab 3: Hardware & Menu Bar
    
    private var hardwareTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Notch Section
            VStack(alignment: .leading, spacing: 10) {
                Text("MACBOOK CAMERA NOTCH BEZEL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "macbook.gen2")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hardware Notch Fluid Island")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Adapts seamlessly to 14\" and 16\" MacBook Pro displays")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("0pt Bezel Active")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                HStack {
                    Image(systemName: "escape")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global Escape Key Dismiss")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Pressing Esc instantly silences and closes the notch bar")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if isAccessibilityTrusted {
                        Text("0ms Active 🟢")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Button(action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Fix Permission")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.yellow)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            // Menu Bar Tray Section
            VStack(alignment: .leading, spacing: 10) {
                Text("MACBOOK SYSTEM TRAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Menu Bar Tray Icon")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Anchored safely beside Wi-Fi & Battery (clear of notch)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $showTrayIcon)
                        .toggleStyle(.switch)
                        .onChange(of: showTrayIcon) { newValue in
                            saveConfig()
                            AppDelegate.shared?.setTrayIconVisible(newValue)
                        }
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(queueManager.isSpeaking ? Color.green : Color.blue)
                            .frame(width: 7, height: 7)
                        Text(queueManager.isSpeaking ? "Live Tray State: Speaking (🟢 Active Dot)" : "Live Tray State: Ready (⚪ Clean Logo)")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(showTrayIcon ? "Visible in Tray" : "Hidden")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(showTrayIcon ? .green : .secondary)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
    
    // MARK: - Tab 4: Shortcuts & CLI
    
    private var shortcutsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Keyboard Deck
            VStack(alignment: .leading, spacing: 8) {
                Text("GLOBAL SHORTCUTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                shortcutRow(keys: "Esc", title: "Instant Silence", desc: "Dismisses notch player and halts active speech immediately")
                shortcutRow(keys: "⌘ P", title: "Read Clipboard", desc: "Available in menu bar tray menu to read copied browser/ChatGPT text")
                shortcutRow(keys: "⌘ ,", title: "Settings", desc: "Open this Settings window from the menu bar icon")
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            // CLI Commands Deck
            VStack(alignment: .leading, spacing: 8) {
                Text("TERMINAL CLI COMMANDS (aspk / agentspeak)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                cliRow(cmd: "aspk pb", desc: "Speak text currently copied on clipboard")
                cliRow(cmd: "aspk say <text>", desc: "Speak any arbitrary text via notch player")
                cliRow(cmd: "aspk tray on | off", desc: "Enable or hide menu bar tray icon")
                cliRow(cmd: "aspk dashboard", desc: "Open this wide desktop settings window")
                cliRow(cmd: "aspk stop", desc: "Silence and dismiss active playback")
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
    
    private func shortcutRow(keys: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.cyan.opacity(0.12))
                .cornerRadius(5)
                .frame(width: 55, alignment: .leading)
            
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            Text(desc)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
    
    private func cliRow(cmd: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Text(cmd)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12))
                .cornerRadius(5)
            
            Spacer()
            
            Text(desc)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}
