import SwiftUI
import Cocoa

// =============================================================================
// MARK: - AGENT SPEAK HOLOGRAPHIC SKIN SPECIFICATION
// =============================================================================
// 🤖 INSTRUCTIONS FOR FUTURE AI AGENTS / DEVELOPERS:
// To add a new Hologram skin to Agent Speak:
// 1. Add your new skin identifier to `HologramSkinType` below.
// 2. Add your skin metadata (name, subtitle, creator, systemIcon) in the switch.
// 3. Create your SwiftUI View in a dedicated file (e.g. `Sources/Skin<Name>.swift`).
//    - Keep your file strictly under 900 lines.
//    - Accept `isSpeaking: Bool`, `isPlayingMusic: Bool`, `size: CGFloat`,
//      `themeColor: Color`, `audioLevel: CGFloat`, `audioBass: CGFloat`.
// 4. Add your view into the `switch skin` in `HologramSkinContainerView` below.
// That is all! It will immediately appear in the Dashboard, CLI, and Full-Screen HUD.
// =============================================================================

public enum HologramSkinType: String, CaseIterable, Identifiable {
    // 1. MASTER DEFAULT
    case classicArc = "classicArc"
    
    // 2. GOOGLE AI STUDIO
    case googleJarvis = "googleJarvis"
    case googleUltron = "googleUltron"
    
    // 3. GEMINI APP
    case geminiJarvis = "geminiJarvis"
    case geminiUltron = "geminiUltron"
    
    // 4. GLM
    case glmJarvis = "glmJarvis"
    case glmUltron = "glmUltron"
    
    // 5. CHATGPT
    case chatgptJarvis = "chatgptJarvis"
    case chatgptUltron = "chatgptUltron"
    
    public var id: String { rawValue }
    
    public var name: String {
        switch self {
        case .classicArc: return "Tony Stark Arc Reactor"
        case .googleJarvis: return "Stark Cybernetic Vortex"
        case .googleUltron: return "Ultron Crimson Geodesic"
        case .geminiJarvis: return "Spherical Circuit Matrix"
        case .geminiUltron: return "Mind Stone Synaptic Brain"
        case .glmJarvis: return "3D Gyroscopic Telemetry HUD"
        case .glmUltron: return "Ultron Tactical Hexagon Core"
        case .chatgptJarvis: return "Orbital Particle HUD"
        case .chatgptUltron: return "Crimson Ocular Iris"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .classicArc: return "Classic Mark 42 core with 12 concentric magnetic rings & particle vortex"
        case .googleJarvis: return "Cinematic radiant filaments, optical burst beams & PCB circuit tracks"
        case .googleUltron: return "Aggressive sawtooth shockwaves, crystalline geodesic lattice & sparks"
        case .geminiJarvis: return "3D dashed orbital rings with undulating acoustic voice wave"
        case .geminiUltron: return "Electric neural synaptic cluster with twitching axons & dendrites"
        case .glmJarvis: return "3D wireframe spherical gyroscope with HUD telemetry coordinates & dials"
        case .glmUltron: return "Glowing hex aperture core with radar targeting ticks & fracture trails"
        case .chatgptJarvis: return "Dense orbital particle cloud with golden iris & bracket targeting reticles"
        case .chatgptUltron: return "Focused red ocular iris with cyan needle rays & spiderweb filament mesh"
        }
    }
    
    public var creator: String {
        switch self {
        case .classicArc: return "Sayed Johon / Stark Industries"
        case .googleJarvis: return "Google AI Studio"
        case .googleUltron: return "Google AI Studio"
        case .geminiJarvis: return "Gemini App"
        case .geminiUltron: return "Gemini App"
        case .glmJarvis: return "GLM"
        case .glmUltron: return "GLM"
        case .chatgptJarvis: return "ChatGPT"
        case .chatgptUltron: return "ChatGPT"
        }
    }
    
    public var isDefault: Bool {
        return self == .classicArc
    }
    
    public var systemIcon: String {
        switch self {
        case .classicArc: return "star.circle.fill"
        case .googleJarvis: return "atom"
        case .googleUltron: return "bolt.shield.fill"
        case .geminiJarvis: return "waveform.path.ecg"
        case .geminiUltron: return "brain.head.profile"
        case .glmJarvis: return "globe.desk.fill"
        case .glmUltron: return "hexagon.fill"
        case .chatgptJarvis: return "scope"
        case .chatgptUltron: return "eye.circle.fill"
        }
    }
    
    public static func find(id: String) -> HologramSkinType {
        let cleaned = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return allCases.first(where: { $0.rawValue.lowercased() == cleaned || $0.name.lowercased() == cleaned }) ?? .classicArc
    }
}

// =============================================================================
// MARK: - UNIFIED HOLOGRAPHIC SKIN CONTAINER VIEW
// =============================================================================

public struct HologramSkinContainerView: View {
    public var skin: HologramSkinType
    public var theme: HologramTheme
    public var blendMode: HologramBlendMode
    public var isSpeaking: Bool
    public var isPlayingMusic: Bool
    public var size: CGFloat
    public var customWidth: CGFloat?
    public var simulateAudio: Bool
    
    @ObservedObject private var meter = JarvisAudioLevelMeter.shared
    
    public init(
        skin: HologramSkinType = .classicArc,
        theme: HologramTheme = .amber,
        blendMode: HologramBlendMode = .normal,
        isSpeaking: Bool = false,
        isPlayingMusic: Bool = false,
        size: CGFloat = 820,
        customWidth: CGFloat? = nil,
        simulateAudio: Bool = false
    ) {
        self.skin = skin
        self.theme = theme
        self.blendMode = blendMode
        self.isSpeaking = isSpeaking
        self.isPlayingMusic = isPlayingMusic
        self.size = size
        self.customWidth = customWidth
        self.simulateAudio = simulateAudio
    }
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let simulatedLevel = CGFloat(sin(now * 3.8) * 0.25 + 0.58)
            let simulatedBass = CGFloat(sin(now * 2.1) * 0.25 + 0.48)
            
            let audioLevel = simulateAudio ? max(meter.level, simulatedLevel) : meter.level
            let audioBass = simulateAudio ? max(meter.bass, simulatedBass) : meter.bass
            let effectiveSpeaking = isSpeaking || simulateAudio
            let color = theme.previewColor
            
            CinematicHologramLifecycleWrapper(
                color: color,
                size: size,
                customWidth: customWidth,
                isSpeaking: effectiveSpeaking
            ) {
                Group {
                    switch skin {
                    case .classicArc:
                        // Original Tony Stark Arc Reactor
                        JarvisOrbVisualizerView(
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            theme: theme
                        )
                        
                    case .googleJarvis:
                        GoogleAI_JarvisView(
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            themeColor: color,
                            audioLevel: audioLevel,
                            audioBass: audioBass
                        )
                        
                    case .googleUltron:
                        GoogleAI_UltronView(
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            themeColor: color,
                            audioLevel: audioLevel,
                            audioBass: audioBass
                        )
                        
                    case .geminiJarvis:
                        GeminiApp_HologramView(
                            skin: .jarvis,
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            themeColor: color,
                            audioLevel: audioLevel,
                            audioBass: audioBass
                        )
                        
                    case .geminiUltron:
                        GeminiApp_HologramView(
                            skin: .ultron,
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            themeColor: color,
                            audioLevel: audioLevel,
                            audioBass: audioBass
                        )
                        
                    case .glmJarvis:
                        GLM_JarvisView(
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            themeColor: color,
                            audioLevel: audioLevel,
                            audioBass: audioBass
                        )
                        
                    case .glmUltron:
                        GLM_UltronView(
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            themeColor: color,
                            audioLevel: audioLevel,
                            audioBass: audioBass
                        )
                        
                    case .chatgptJarvis:
                        ChatGPT_JarvisView(
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            themeColor: color,
                            audioLevel: audioLevel,
                            audioBass: audioBass
                        )
                        
                    case .chatgptUltron:
                        ChatGPT_UltronView(
                            isSpeaking: effectiveSpeaking,
                            isPlayingMusic: isPlayingMusic,
                            size: size,
                            customWidth: customWidth,
                            themeColor: color,
                            audioLevel: audioLevel,
                            audioBass: audioBass
                        )
                    }
                }
                .blendMode(blendMode.swiftUIBlendMode)
                .opacity(blendMode.baseOpacity)
                .frame(width: customWidth ?? size, height: size)
            }
            .frame(width: customWidth ?? size, height: size)
        }
    }
}

// =============================================================================
// MARK: - CINEMATIC HOLOGRAM LIFECYCLE CONTROLLER (IGNITION & COLLAPSE)
// =============================================================================

public struct CinematicHologramLifecycleWrapper<Content: View>: View {
    let content: Content
    let size: CGFloat
    let customWidth: CGFloat?
    
    public init(
        color: Color,
        size: CGFloat,
        customWidth: CGFloat? = nil,
        isSpeaking: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.size = size
        self.customWidth = customWidth
        self.content = content()
    }
    
    public var body: some View {
        content
            .frame(width: customWidth ?? size, height: size)
    }
}
