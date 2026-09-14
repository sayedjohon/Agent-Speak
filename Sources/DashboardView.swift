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
    case voice = "Voice & Audio"
    case bgm = "Background Music"
    case workspaces = "Connected AI"
    case hardware = "Notch & Menu Bar"
    case shortcuts = "Shortcuts & CLI"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .voice: return "waveform"
        case .bgm: return "music.quarternote.3"
        case .workspaces: return "circle.hexagongrid.fill"
        case .hardware: return "macbook.and.ipad"
        case .shortcuts: return "command.square.fill"
        }
    }
}

// MARK: - Dashboard Main View
public struct DashboardView: View {
    @ObservedObject var queueManager = SpeechQueueManager.shared
    @State private var selectedTab: DashboardTab = .voice
    @State private var hoveredTab: DashboardTab? = nil
    
    // Config States
    @State private var isEnabled: Bool = true
    @State private var voiceEngine: String = "macos_default"
    @State private var macosVoice: String = "default"
    @State private var pocketVoice: String = "Jarvis_Best"
    @State private var skipSeconds: Int = 5
    @State private var showTrayIcon: Bool = true
    @State private var availableSystemVoices: [SystemVoiceItem] = []
    @State private var customTestText: String = "This is a viral and proven voice  currently used by hundreds successful of youtube channels. so Do you like this voice? "
    
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
        .frame(minWidth: 740, idealWidth: 750, maxWidth: 950, minHeight: 580, idealHeight: 720, maxHeight: .infinity)
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
                            .fill(queueManager.isSpeaking ? Color.green : (isEnabled ? Color(red: 0.2, green: 0.85, blue: 0.5) : Color.orange))
                            .frame(width: 6, height: 6)
                        Text(queueManager.isSpeaking ? "SPEAKING" : (isEnabled ? "READY" : "PAUSED"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(queueManager.isSpeaking ? .green : (isEnabled ? Color(red: 0.2, green: 0.85, blue: 0.5) : .orange))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 22)
            .padding(.bottom, 20)
            
            // Nav Tab List
            VStack(spacing: 4) {
                ForEach(DashboardTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            selectedTab = tab
                        }
                    }) {
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
                            } else if tab == .bgm && BackgroundMusicManager.shared.isPlaying {
                                Circle().fill(Color.purple).frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == tab ? Color.white.opacity(0.12) : (hoveredTab == tab ? Color.white.opacity(0.06) : Color.clear))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedTab == tab ? Color.white.opacity(0.14) : Color.clear, lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredTab = isHovered ? tab : (hoveredTab == tab ? nil : hoveredTab)
                    }
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
                        Text(queueManager.isSpeaking ? "Stop Speech (Esc)" : (isEnabled ? "Pause Speech" : "Resume Speech"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(queueManager.isSpeaking ? Color.red.opacity(0.25) : Color.white.opacity(0.08))
                    .foregroundColor(queueManager.isSpeaking ? .red : .white)
                    .cornerRadius(7)
                    .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                
                Text("100% On-Device & Private")
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
                    case .bgm:
                        BackgroundMusicView()
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
        case .bgm: return "Play soundtrack audio behind speech with shuffle, random offset, and reverb decay."
        case .workspaces: return "Monitors text output from local AI assistants. Never accesses microphone."
        case .hardware: return "Customize dynamic camera notch HUD and menu bar status icon."
        case .shortcuts: return "Global keyboard shortcuts and terminal command cheat sheet."
        }
    }
    
    // MARK: - Tab 1: Voice & Playback
    
    private var voiceSettingsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Compact Orb Visualizer
            CompactVisualizerOrbView(isSpeaking: $queueManager.isSpeaking)
                .padding(.vertical, 2)
            
            // Engine Switcher: Dual Prominent Raycast Cards
            VStack(alignment: .leading, spacing: 8) {
                Text("SPEECH ENGINE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                
                HStack(spacing: 12) {
                    // Option 1: MacBook Built-in Voice
                    Button(action: {
                        voiceEngine = "macos_default"
                        saveConfig()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(voiceEngine == "macos_default" ? Color.green.opacity(0.2) : Color.white.opacity(0.06))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(voiceEngine == "macos_default" ? .green : Color(red: 0.6, green: 0.62, blue: 0.68))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("MacBook Built-in")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if voiceEngine == "macos_default" {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 0.05, green: 0.50, blue: 1.0))
                                            .font(.system(size: 15))
                                    } else {
                                        Circle()
                                            .stroke(Color(red: 0.3, green: 0.32, blue: 0.38), lineWidth: 1)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                                Text("Zero CPU • 100% Native & Fast")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(voiceEngine == "macos_default" ? Color(red: 0.16, green: 0.18, blue: 0.23) : Color(red: 0.11, green: 0.12, blue: 0.15))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(voiceEngine == "macos_default" ? Color(red: 0.15, green: 0.55, blue: 1.0) : Color(red: 0.20, green: 0.22, blue: 0.27), lineWidth: voiceEngine == "macos_default" ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Option 2: Pocket-TTS Neural AI
                    Button(action: {
                        voiceEngine = "pocket_tts"
                        saveConfig()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(voiceEngine == "pocket_tts" ? Color.purple.opacity(0.25) : Color.white.opacity(0.06))
                                    .frame(width: 38, height: 38)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(voiceEngine == "pocket_tts" ? .purple : Color(red: 0.6, green: 0.62, blue: 0.68))
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Pocket-TTS Neural")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    if voiceEngine == "pocket_tts" {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(red: 0.05, green: 0.50, blue: 1.0))
                                            .font(.system(size: 15))
                                    } else {
                                        Circle()
                                            .stroke(Color(red: 0.3, green: 0.32, blue: 0.38), lineWidth: 1)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                                Text("Custom Clones • Offline AI")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(voiceEngine == "pocket_tts" ? Color(red: 0.16, green: 0.18, blue: 0.23) : Color(red: 0.11, green: 0.12, blue: 0.15))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(voiceEngine == "pocket_tts" ? Color(red: 0.15, green: 0.55, blue: 1.0) : Color(red: 0.20, green: 0.22, blue: 0.27), lineWidth: voiceEngine == "pocket_tts" ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Active Voice Details Card
            if voiceEngine == "macos_default" {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("System Voice Persona")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Native Apple Silicon speech synthesizer (100% Zero CPU)")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(availableSystemVoices) { v in
                                Button(action: {
                                    macosVoice = v.tag
                                    saveConfig()
                                }) {
                                    HStack {
                                        Text(v.label)
                                        if macosVoice == v.tag {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedVoiceDisplayName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1)
                            )
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                    }
                }
                .padding(14)
                .background(Color(red: 0.11, green: 0.12, blue: 0.15))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
            } else {
                PocketTTSExtensionCardView(pocketVoice: $pocketVoice, onSave: { saveConfig() })
            }
            
            // Playback & Skip Controls Card (Raycast Style Row)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Skip Forward / Backward Step")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Interval leaped by the Notch Player scrub buttons")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("5 seconds (Default)") { skipSeconds = 5; saveConfig() }
                        Button("10 seconds") { skipSeconds = 10; saveConfig() }
                        Button("15 seconds") { skipSeconds = 15; saveConfig() }
                        Button("30 seconds") { skipSeconds = 30; saveConfig() }
                    } label: {
                        HStack(spacing: 8) {
                            Text("\(skipSeconds) seconds")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1)
                        )
                    }
                    .menuStyle(BorderlessButtonMenuStyle())
                }
            }
            .padding(14)
            .background(Color(red: 0.11, green: 0.12, blue: 0.15))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
            
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
                    
                    if queueManager.isSpeaking {
                        Button(action: {
                            SpeechQueueManager.shared.stopCurrent()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 9))
                                Text("Stop")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        let textToSpeak = customTestText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let prompt = textToSpeak.isEmpty ? "This is a viral and proven voice  currently used by hundreds successful of youtube channels. so Do you like this voice? " : textToSpeak
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
    
    // MARK: - Tab 2: Connected AI
    
    private var workspacesTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Privacy Reassurance Card
            HStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.5))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("100% Private • Zero Microphone Access")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("Agent Speak only vocalizes text generated by your AI tools. It never uses, records, or monitors your microphone.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .background(Color(red: 0.2, green: 0.85, blue: 0.5).opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.2, green: 0.85, blue: 0.5).opacity(0.2), lineWidth: 1)
            )
            
            Text("CONNECTED AI CODING ASSISTANTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.top, 2)
            
            VStack(spacing: 0) {
                workspaceRow(
                    icon: "circle.hexagongrid.circle.fill",
                    color: .purple,
                    title: "Antigravity Assistant",
                    subtitle: "Speaks conversational responses from Antigravity IDE and CLI",
                    isOn: $watchAntigravity
                )
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
                
                workspaceRow(
                    icon: "terminal.fill",
                    color: .orange,
                    title: "Claude Code",
                    subtitle: "Speaks session answers and output from Claude Code CLI",
                    isOn: $watchClaude
                )
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
                
                workspaceRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    color: .cyan,
                    title: "OpenCode & Other Agents",
                    subtitle: "Speaks activity logs and answers from supported developer agents",
                    isOn: $watchOpenCode
                )
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 12)
                
                workspaceRow(
                    icon: "apple.terminal.on.rectangle.fill",
                    color: .green,
                    title: "Terminal & UNIX Socket",
                    subtitle: "Accepts speech commands from custom scripts, shortcuts, and CLI",
                    isOn: $watchTerminal
                )
            }
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                Text("Instant Streaming: Automatically begins speaking sentences in real-time as your AI responds.")
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
    
    // MARK: - Tab 3: Notch & Menu Bar
    
    private var hardwareTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Notch Section
            VStack(alignment: .leading, spacing: 10) {
                Text("DYNAMIC NOTCH HUD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "macbook.gen2")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Camera Notch Overlay")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Floats smoothly under the camera notch on MacBook Pro and Air")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Active")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                HStack {
                    Image(systemName: "escape")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Silence Key (Esc)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Press Escape anywhere on macOS to immediately stop speech and close notch")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if isAccessibilityTrusted {
                        Text("Active 🟢")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Button(action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Enable Accessibility")
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
                Text("MENU BAR STATUS ICON")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Menu Bar Icon")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Quickly access controls and settings from the top macOS status bar")
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
                            .fill(queueManager.isSpeaking ? Color.green : Color(red: 0.2, green: 0.85, blue: 0.5))
                            .frame(width: 7, height: 7)
                        Text(queueManager.isSpeaking ? "Menu Bar Status: Speaking (Active)" : "Menu Bar Status: Ready (Standby)")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(showTrayIcon ? "Visible in Menu Bar" : "Hidden")
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
        DashboardShortcutsView()
    }
}
