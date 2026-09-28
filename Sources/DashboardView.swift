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
    case hardware = "Hologram & HUD"
    case gestures = "Vision & Gestures"
    case shortcuts = "Shortcuts & CLI"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .voice: return "waveform"
        case .bgm: return "music.note"
        case .workspaces: return "circle.hexagongrid.fill"
        case .hardware: return "atom"
        case .gestures: return "hand.raised.fingers.spread.fill"
        case .shortcuts: return "command"
        }
    }
    
    var iconGradient: [Color] {
        switch self {
        case .voice: return [Color.blue, Color.cyan]
        case .bgm: return [Color.pink, Color.purple]
        case .workspaces: return [Color.indigo, Color.purple]
        case .hardware: return [Color.teal, Color.blue]
        case .gestures: return [Color.cyan, Color.teal]
        case .shortcuts: return [Color.orange, Color.red]
        }
    }
}

// MARK: - Dashboard Main View
public struct DashboardView: View {
    @ObservedObject var queueManager = SpeechQueueManager.shared
    @ObservedObject var pocketTTS = PocketTTSManager.shared
    @ObservedObject var codeSpeech = CodeSpeechManager.shared
    @State private var selectedTab: DashboardTab = .voice
    @State private var hoveredTab: DashboardTab? = nil
    @State private var showingCloneSheet: Bool = false
    
    // Config States
    @State private var isEnabled: Bool = true
    @State private var voiceEngine: String = "macos_default"
    @State private var macosVoice: String = "default"
    @State private var pocketVoice: String = "Jarvis_Best"
    @State private var skipSeconds: Int = 5
    @State private var showTrayIcon: Bool = true
    @State private var availableSystemVoices: [SystemVoiceItem] = []
    @State private var customTestText: String = "Hello! This is a real-time preview of your active voice persona. Pacing, tone, and inflection are synthesized on-device with zero cloud latency."
    
    // Workspace States
    @State private var watchAntigravity: Bool = true
    @State private var watchClaude: Bool = true
    @State private var watchOpenCode: Bool = true
    @State private var watchTerminal: Bool = true
    @State private var isAccessibilityTrusted: Bool = AXIsProcessTrusted()
    
    public init() {}
    
    private var brandLogoImage: NSImage? {
        let paths = [
            Bundle.main.bundlePath + "/Contents/Resources/Agent-Speak-logo.png",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/logo.png").path,
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
            codeSpeech.loadConfiguration()
        }
        
        if let general = json["general"] as? [String: Any] {
            if let show = general["show_tray_icon"] as? Bool { showTrayIcon = show }
            if let en = general["enabled"] as? Bool { isEnabled = en }
        }
        
        if let workspaces = json["workspaces"] as? [String: Any] {
            if let ag = workspaces["antigravity"] as? Bool {
                watchAntigravity = ag
                TranscriptWatcher.shared.isAntigravityEnabled = ag
            }
            if let cl = workspaces["claude"] as? Bool {
                watchClaude = cl
                TranscriptWatcher.shared.isClaudeEnabled = cl
            }
            if let oc = workspaces["opencode"] as? Bool {
                watchOpenCode = oc
                TranscriptWatcher.shared.isOpenCodeEnabled = oc
            }
            if let tm = workspaces["terminal"] as? Bool {
                watchTerminal = tm
                TranscriptWatcher.shared.isTerminalEnabled = tm
            }
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
        audio["speak_code_blocks"] = codeSpeech.speakCodeBlocks
        var ptts = audio["pocket_tts"] as? [String: Any] ?? [:]
        ptts["voice"] = pocketVoice
        ptts["enabled"] = (voiceEngine == "pocket_tts")
        audio["pocket_tts"] = ptts
        json["audio"] = audio
        
        var general = json["general"] as? [String: Any] ?? [:]
        general["show_tray_icon"] = showTrayIcon
        general["enabled"] = isEnabled
        json["general"] = general
        
        var workspaces: [String: Any] = [:]
        workspaces["antigravity"] = watchAntigravity
        workspaces["claude"] = watchClaude
        workspaces["opencode"] = watchOpenCode
        workspaces["terminal"] = watchTerminal
        json["workspaces"] = workspaces
        
        TranscriptWatcher.shared.isAntigravityEnabled = watchAntigravity
        TranscriptWatcher.shared.isClaudeEnabled = watchClaude
        TranscriptWatcher.shared.isOpenCodeEnabled = watchOpenCode
        TranscriptWatcher.shared.isTerminalEnabled = watchTerminal
        
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
            // Left Sidebar with macOS controlBackgroundColor
            sidebarView
                .frame(width: 220)
                .background(Color(nsColor: .controlBackgroundColor))
            
            // Native macOS vertical divider
            Divider()
            
            // Right Detail Area
            detailContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 840, idealWidth: 880, maxWidth: 1100, minHeight: 580, idealHeight: 640, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            loadConfig()
            availableSystemVoices = loadAvailableVoices()
            isAccessibilityTrusted = AXIsProcessTrusted()
            pocketTTS.refreshState()
        }
        .sheet(isPresented: $showingCloneSheet) {
            VoiceCloningStudioSheet(isPresented: $showingCloneSheet) { newVoiceTag in
                pocketVoice = newVoiceTag
                saveConfig()
            }
        }
    }
    
    // MARK: - Sidebar View
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand Header in Apple Settings style with safe top margin below window controls
            HStack(spacing: 10) {
                if let logo = brandLogoImage {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Agent Speak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(queueManager.isSpeaking ? Color.green : (isEnabled ? Color.blue : Color.orange))
                            .frame(width: 6, height: 6)
                        Text(queueManager.isSpeaking ? "Speaking" : (isEnabled ? "Ready" : "Paused"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 40)
            .padding(.bottom, 16)
            
            // Nav Tab List (macOS System Settings Style)
            VStack(spacing: 2) {
                ForEach(DashboardTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 10) {
                            // Apple Squircle Badge with Gradient
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(LinearGradient(colors: tab.iconGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 20, height: 20)
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(tab.rawValue)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .white : .primary)
                            
                            Spacer()
                            
                            if tab == .voice && queueManager.isSpeaking {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                            } else if tab == .bgm && BackgroundMusicManager.shared.isPlaying {
                                Circle().fill(Color.purple).frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == tab ? Color.accentColor : (hoveredTab == tab ? Color(nsColor: .quaternaryLabelColor).opacity(0.3) : Color.clear))
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredTab = isHovered ? tab : (hoveredTab == tab ? nil : hoveredTab)
                    }
                }
            }
            .padding(.horizontal, 10)
            
            Spacer()
            
            // Sidebar Footer Deck
            VStack(spacing: 8) {
                Divider()
                    .padding(.horizontal, 12)
                
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
                        Text(queueManager.isSpeaking ? "Stop Speech (Esc)" : (isEnabled ? "Mute All Speech" : "Unmute Speech"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(queueManager.isSpeaking ? Color.red.opacity(0.15) : Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                    .foregroundColor(queueManager.isSpeaking ? .red : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Text("100% On-Device & Private")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(14)
        }
    }
    
    // MARK: - Detail Content View
    
    @ViewBuilder
    private var detailContentView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Bar aligned with sidebar header baseline
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text(tabSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 38)
            .padding(.bottom, 16)
            
            Divider()
            
            // Tab Specific Content (Smooth Scrolling)
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .voice:
                        voiceSettingsTab
                    case .bgm:
                        BackgroundMusicView()
                    case .workspaces:
                        workspacesTab
                    case .hardware:
                        hardwareTab
                    case .gestures:
                        DashboardGestureView()
                    case .shortcuts:
                        shortcutsTab
                    }
                }
                .padding(24)
            }
        }
    }
    
    private var tabSubtitle: String {
        switch selectedTab {
        case .voice: return "Select native Apple Silicon voice or neural Pocket-TTS extension."
        case .bgm: return "Play soundtrack audio behind speech with shuffle, random offset, and reverb decay."
        case .workspaces: return "Monitors text output from local AI assistants. Never accesses microphone."
        case .hardware: return "Customize dynamic camera notch HUD and menu bar status icon."
        case .gestures: return "Dual-hand camera gesture tracking, cursor navigation, and hands-free shortcuts."
        case .shortcuts: return "Global keyboard shortcuts and terminal command cheat sheet."
        }
    }
    
    // MARK: - Tab 1: Voice & Playback
    
    private var voiceSettingsTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            // MARK: - Section 1: Engine Selector (Native Segmented Control)
            VStack(alignment: .leading, spacing: 8) {
                Text("SPEECH SYNTHESIS ENGINE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                Picker("Speech Engine", selection: $voiceEngine) {
                    Text("MacBook Built-in (Zero CPU)").tag("macos_default")
                    Text("Pocket-TTS Neural AI").tag("pocket_tts")
                }
                .pickerStyle(.segmented)
                .onChange(of: voiceEngine) {
                    saveConfig()
                }
            }
            
            // MARK: - Section 2: Active Voice Persona Card
            VStack(alignment: .leading, spacing: 8) {
                Text("ACTIVE VOICE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                VStack(spacing: 0) {
                    if voiceEngine == "macos_default" {
                        // System Voice Row
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 28, height: 28)
                                Image(systemName: "person.wave.2.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("System Voice")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("Native Apple Silicon speech synthesizer")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Picker("", selection: $macosVoice) {
                                ForEach(availableSystemVoices) { v in
                                    Text(v.label).tag(v.tag)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 240)
                            .onChange(of: macosVoice) {
                                saveConfig()
                            }
                            
                            Button(action: {
                                if queueManager.isSpeaking {
                                    queueManager.stopCurrent()
                                } else {
                                    let sampleText = PersonaGreetingManager.shared.previewSample()
                                    queueManager.enqueue(source: selectedVoiceDisplayName, text: sampleText, immediate: true)
                                }
                            }) {
                                Image(systemName: queueManager.isSpeaking ? "stop.fill" : "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(queueManager.isSpeaking ? .red : .accentColor)
                                    .frame(width: 26, height: 26)
                                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Audition selected voice")
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    } else {
                        // Pocket-TTS Neural Engine
                        if !pocketTTS.isInstalled {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color.purple.opacity(0.15))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.purple)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pocket-TTS Neural Extension Required")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text("Kyutai FlowLM models run 100% offline on Apple Silicon (~650MB setup).")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                
                                if pocketTTS.isInstalling {
                                    HStack(spacing: 8) {
                                        ProgressView().scaleEffect(0.7)
                                        Text(pocketTTS.installProgress.isEmpty ? "Setting up neural models..." : pocketTTS.installProgress)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                } else {
                                    Button(action: {
                                        pocketTTS.installExtension { success, _ in
                                            if success { saveConfig() }
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.circle.fill")
                                            Text("Download & Set Up Engine (~650MB)")
                                        }
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.purple)
                                        .foregroundColor(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        } else {
                            // Installed Pocket-TTS Row
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Neural Persona")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("On-device Kyutai neural clone")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Picker("", selection: $pocketVoice) {
                                    ForEach(pocketTTS.availableVoices) { item in
                                        Text(item.displayName).tag(item.tag)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: 220)
                                .onChange(of: pocketVoice) {
                                    saveConfig()
                                }
                                
                                Button(action: {
                                    if queueManager.isSpeaking {
                                        queueManager.stopCurrent()
                                    } else {
                                        let sample = PersonaGreetingManager.shared.previewSample()
                                        queueManager.enqueue(source: pocketVoice, text: sample, immediate: true)
                                    }
                                }) {
                                    Image(systemName: queueManager.isSpeaking ? "stop.fill" : "play.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(queueManager.isSpeaking ? .red : .accentColor)
                                        .frame(width: 26, height: 26)
                                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                                .help("Audition persona")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            
                            Divider().padding(.horizontal, 14)
                            
                            // Voice Cloning Studio Row
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: "waveform.badge.plus")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Voice Cloning Studio")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    Text("Clone any voice from a 5–10s audio sample")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    showingCloneSheet = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("Clone Voice...")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
            
            // MARK: - Section 3: User Identity & Personalized Startup Greeting
            StartupGreetingCardView()
            
            // MARK: - Section 4: Playback & Volume Inset Grouped Card
            VStack(alignment: .leading, spacing: 8) {
                Text("PLAYBACK & VOLUME")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                VStack(spacing: 0) {
                    // Volume / Gain Row
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(LinearGradient(colors: [Color.green, Color.teal], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 28, height: 28)
                                Image(systemName: VoiceVolumeManager.shared.isBoosted ? "bolt.shield.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text("Speech Gain")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.primary)
                                    if VoiceVolumeManager.shared.isBoosted {
                                        Text("+\(String(format: "%.1f", VoiceVolumeManager.shared.decibelBoost)) dB")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Color.orange.opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    }
                                }
                                Text(VoiceVolumeManager.shared.isBoosted ? "Studio soft-saturation limiter prevents clipping" : "Standard audio playback loudness")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(VoiceVolumeManager.shared.volume)%")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(VoiceVolumeManager.shared.isBoosted ? .orange : .primary)
                        }
                        
                        // Slider
                        HStack(spacing: 10) {
                            Image(systemName: "speaker.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Slider(
                                value: Binding(
                                    get: { Double(VoiceVolumeManager.shared.volume) },
                                    set: { VoiceVolumeManager.shared.setVolume(Int(round($0))) }
                                ),
                                in: 1...200,
                                step: 1
                            )
                            .accentColor(VoiceVolumeManager.shared.isBoosted ? .orange : .accentColor)
                            
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 11))
                                .foregroundColor(VoiceVolumeManager.shared.isBoosted ? .orange : .secondary)
                        }
                        
                        // Quick Presets
                        HStack(spacing: 8) {
                            ForEach([80, 100, 140, 200], id: \.self) { preset in
                                Button(action: {
                                    VoiceVolumeManager.shared.setVolume(preset)
                                }) {
                                    Text(preset == 100 ? "100% (Default)" : (preset == 200 ? "200% (Max)" : "\(preset)%"))
                                        .font(.system(size: 11, weight: VoiceVolumeManager.shared.volume == preset ? .semibold : .regular))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(VoiceVolumeManager.shared.volume == preset ? Color.accentColor.opacity(0.2) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                        .foregroundColor(VoiceVolumeManager.shared.volume == preset ? .accentColor : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    
                    Divider().padding(.horizontal, 14)
                    
                    // Skip Interval Row
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 28, height: 28)
                            Image(systemName: "goforward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HUD Skip Step")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Interval leaped by notch player scrub buttons")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("", selection: $skipSeconds) {
                            Text("5 seconds").tag(5)
                            Text("10 seconds").tag(10)
                            Text("15 seconds").tag(15)
                            Text("30 seconds").tag(30)
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 160)
                        .onChange(of: skipSeconds) {
                            saveConfig()
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    
                    Divider().padding(.horizontal, 14)
                    
                    // Code & Technical Block Speech Row
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [Color.indigo, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 28, height: 28)
                            Image(systemName: "curlybraces")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Speak Everything Including Code Blocks")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Reads code blocks aloud. Markdown and comment hashtags are automatically cleaned. Off by default.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { codeSpeech.speakCodeBlocks },
                            set: { codeSpeech.setSpeakCodeBlocks($0) }
                        ))
                        .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
            
            // MARK: - Section 4: Studio Script Editor (Apple HIG Multi-Line Prompter & Presets)
            StudioScriptEditorView(
                text: $customTestText,
                isSpeaking: queueManager.isSpeaking,
                onTest: {
                    let textToSpeak = customTestText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let prompt = textToSpeak.isEmpty ? "Hello! This is a real-time preview of your active voice persona. Pacing, tone, and inflection are synthesized on-device with zero cloud latency." : textToSpeak
                    LastVoiceManager.shared.prepareForNewVoice(text: prompt)
                    SpeechQueueManager.shared.enqueue(
                        source: "Voice Test",
                        text: prompt
                    )
                },
                onStop: {
                    SpeechQueueManager.shared.stopCurrent()
                }
            )
            
            // MARK: - Section 5: Last Voice Player, Scrubber & Download (Shown only when available)
            LastVoiceCardView()
        }
    }
    
    // MARK: - Tab 2: Connected AI
    
    private var workspacesTab: some View {
        DashboardWorkspacesView(
            watchAntigravity: $watchAntigravity,
            watchClaude: $watchClaude,
            watchOpenCode: $watchOpenCode,
            watchTerminal: $watchTerminal
        )
    }
    
    // MARK: - Tab 3: Notch & Menu Bar
    
    private var hardwareTab: some View {
        DashboardHardwareView(
            showTrayIcon: $showTrayIcon,
            isAccessibilityTrusted: isAccessibilityTrusted,
            onSaveConfig: { saveConfig() }
        )
    }
    
    // MARK: - Tab 4: Shortcuts & CLI
    
    private var shortcutsTab: some View {
        DashboardShortcutsView()
    }
}
