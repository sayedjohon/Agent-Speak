import Foundation
import Cocoa
import SwiftUI

// MARK: - Hologram Theme Model
public struct HologramTheme: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let previewColor: Color
    public let glint: Color
    public let hotWhite: Color
    public let amber: Color
    public let deepAmber: Color
    public let lensAmber: Color
    
    public static let amber = HologramTheme(
        id: "amber",
        name: "Golden Amber",
        subtitle: "Stark Mark 42 warm holographic glow",
        previewColor: Color(red: 1.00, green: 0.65, blue: 0.15),
        glint: Color(red: 1.00, green: 0.85, blue: 0.35),
        hotWhite: Color(red: 1.00, green: 0.72, blue: 0.16),
        amber: Color(red: 1.00, green: 0.52, blue: 0.04),
        deepAmber: Color(red: 0.90, green: 0.28, blue: 0.02),
        lensAmber: Color(red: 1.00, green: 0.65, blue: 0.15)
    )
    
    public static let cyan = HologramTheme(
        id: "cyan",
        name: "Arc Reactor Cyan",
        subtitle: "Classic Mark 3 electric chest reactor blue",
        previewColor: Color(red: 0.00, green: 0.82, blue: 1.00),
        glint: Color(red: 0.75, green: 0.95, blue: 1.00),
        hotWhite: Color(red: 0.35, green: 0.88, blue: 1.00),
        amber: Color(red: 0.00, green: 0.65, blue: 0.95),
        deepAmber: Color(red: 0.02, green: 0.35, blue: 0.75),
        lensAmber: Color(red: 0.20, green: 0.85, blue: 1.00)
    )
    
    public static let green = HologramTheme(
        id: "green",
        name: "Matrix Emerald",
        subtitle: "Neon emerald quantum matrix circuits",
        previewColor: Color(red: 0.10, green: 0.95, blue: 0.45),
        glint: Color(red: 0.70, green: 1.00, blue: 0.80),
        hotWhite: Color(red: 0.25, green: 0.95, blue: 0.45),
        amber: Color(red: 0.05, green: 0.75, blue: 0.30),
        deepAmber: Color(red: 0.02, green: 0.42, blue: 0.16),
        lensAmber: Color(red: 0.25, green: 0.90, blue: 0.45)
    )
    
    public static let red = HologramTheme(
        id: "red",
        name: "Crimson Ruby",
        subtitle: "War Machine & tactical combat ruby core",
        previewColor: Color(red: 1.00, green: 0.25, blue: 0.25),
        glint: Color(red: 1.00, green: 0.68, blue: 0.68),
        hotWhite: Color(red: 1.00, green: 0.35, blue: 0.35),
        amber: Color(red: 0.92, green: 0.12, blue: 0.12),
        deepAmber: Color(red: 0.65, green: 0.02, blue: 0.06),
        lensAmber: Color(red: 1.00, green: 0.35, blue: 0.35)
    )
    
    public static let purple = HologramTheme(
        id: "purple",
        name: "Neon Violet",
        subtitle: "Futuristic synthwave ultraviolet plasma",
        previewColor: Color(red: 0.75, green: 0.35, blue: 1.00),
        glint: Color(red: 0.92, green: 0.78, blue: 1.00),
        hotWhite: Color(red: 0.78, green: 0.38, blue: 1.00),
        amber: Color(red: 0.58, green: 0.15, blue: 0.92),
        deepAmber: Color(red: 0.36, green: 0.04, blue: 0.65),
        lensAmber: Color(red: 0.80, green: 0.42, blue: 1.00)
    )
    
    public static let white = HologramTheme(
        id: "white",
        name: "Diamond Ice",
        subtitle: "Crisp crystalline celestial silver glow",
        previewColor: Color(red: 0.85, green: 0.92, blue: 1.00),
        glint: Color(red: 1.00, green: 1.00, blue: 1.00),
        hotWhite: Color(red: 0.90, green: 0.95, blue: 1.00),
        amber: Color(red: 0.65, green: 0.78, blue: 0.92),
        deepAmber: Color(red: 0.32, green: 0.45, blue: 0.62),
        lensAmber: Color(red: 0.80, green: 0.90, blue: 1.00)
    )
    
    public static let allThemes: [HologramTheme] = [
        .amber, .cyan, .green, .red, .purple, .white
    ]
    
    public static func find(id: String) -> HologramTheme {
        allThemes.first(where: { $0.id.lowercased() == id.lowercased() }) ?? .amber
    }
}

// MARK: - Hologram Blending Modes (Photoshop-Grade)
public enum HologramBlendMode: String, CaseIterable, Identifiable {
    case normal = "normal"              // Default: Normal standard compositing
    case screen = "screen"              // Screen: Lighter, drops blacks, translucent
    case plusLighter = "plusLighter"    // Linear Dodge (Add): Pure additive Stark neon beam
    case overlay = "overlay"            // Overlay: Crisp contrast & dynamic range
    case softLight = "softLight"        // Soft Light: Gentle translucent wash (High Screen Readability!)
    case hardLight = "hardLight"        // Hard Light: Punchy cinematic contrast
    case colorDodge = "colorDodge"      // Color Dodge: Intense electrified highlights
    case multiply = "multiply"          // Multiply: Darkened background tint
    case difference = "difference"      // Difference: Inverted chromatic HUD (stands out on text)
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .normal: return "Normal (Default)"
        case .screen: return "Screen"
        case .plusLighter: return "Linear Dodge (Add)"
        case .overlay: return "Overlay"
        case .softLight: return "Soft Light"
        case .hardLight: return "Hard Light"
        case .colorDodge: return "Color Dodge"
        case .multiply: return "Multiply"
        case .difference: return "Difference"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .normal: return "Standard full-strength holographic projection (default)"
        case .screen: return "Drops dark pixels, luminous highlights, transparent text areas"
        case .plusLighter: return "Linear Dodge pure additive neon rays (Stark HUD beam)"
        case .overlay: return "High contrast highlights and shadows with transparent midtones"
        case .softLight: return "Subtle translucent diffuse wash — easiest to read text behind"
        case .hardLight: return "Punchy, dramatic cinematic contrast"
        case .colorDodge: return "Electrified high-saturation bloom and reactive flares"
        case .multiply: return "Absorptive darkening tint — filters bright desktop glare"
        case .difference: return "Inverted spectral contrast — sharp edge distinction on text"
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .normal: return "circle.fill"
        case .screen: return "sun.max.fill"
        case .plusLighter: return "plus.circle.fill"
        case .overlay: return "circle.lefthalf.filled"
        case .softLight: return "circle.dotted"
        case .hardLight: return "bolt.circle.fill"
        case .colorDodge: return "sparkles"
        case .multiply: return "multiply.circle.fill"
        case .difference: return "plusminus.circle.fill"
        }
    }
    
    public var swiftUIBlendMode: BlendMode {
        switch self {
        case .normal: return .normal
        case .screen: return .screen
        case .plusLighter: return .plusLighter
        case .overlay: return .overlay
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .colorDodge: return .colorDodge
        case .multiply: return .multiply
        case .difference: return .difference
        }
    }
    
    public var graphicsBlendMode: GraphicsContext.BlendMode {
        switch self {
        case .normal: return .plusLighter
        case .screen: return .screen
        case .plusLighter: return .plusLighter
        case .overlay: return .overlay
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .colorDodge: return .colorDodge
        case .multiply: return .multiply
        case .difference: return .difference
        }
    }
    
    public var baseOpacity: Double {
        switch self {
        case .normal: return 1.00
        case .screen: return 0.88
        case .plusLighter: return 0.85
        case .overlay: return 0.85
        case .softLight: return 0.68
        case .hardLight: return 0.85
        case .colorDodge: return 0.80
        case .multiply: return 0.78
        case .difference: return 0.82
        }
    }
    
    public static func find(id: String) -> HologramBlendMode {
        let cleaned = id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch cleaned {
        case "normal", "default": return .normal
        case "screen": return .screen
        case "pluslighter", "lineardodge", "add", "plus": return .plusLighter
        case "overlay": return .overlay
        case "softlight", "soft-light", "soft_light": return .softLight
        case "hardlight", "hard-light", "hard_light": return .hardLight
        case "colordodge", "color-dodge", "color_dodge", "dodge": return .colorDodge
        case "multiply", "darken": return .multiply
        case "difference", "exclusion": return .difference
        default:
            return allCases.first(where: {
                $0.rawValue.lowercased() == cleaned ||
                $0.displayName.lowercased() == cleaned ||
                $0.id.lowercased() == cleaned
            }) ?? .normal
        }
    }
}

// MARK: - Hologram Manager (Singleton)
public class HologramManager: ObservableObject {
    public static let shared = HologramManager()
    
    @Published public var isEnabled: Bool = true
    @Published public var currentTheme: HologramTheme = .amber
    @Published public var currentSkin: HologramSkinType = .classicArc
    @Published public var currentBlendMode: HologramBlendMode = .normal
    @Published public var opacity: Double = 1.0
    @Published public var zoomScale: Double = 0.50          // Range 0.0...1.0, default 0.50 = 50% (1.00x)
    @Published public var positionX: Double = 0.0           // Range -1000.0...+1000.0 px (default 0.0)
    @Published public var positionY: Double = 0.0           // Range -800.0...+800.0 px (default 0.0)
    @Published public var isPreviewActive: Bool = false
    @Published public var isCollapsing: Bool = false
    @Published public var isFadingOut: Bool = false
    @Published public var fadeProgress: Double = 0.0
    @Published public var bootupDate: Date = Date()
    @Published public var collapseStartDate: Date? = nil
    
    public var effectiveOpacity: Double {
        return currentBlendMode.baseOpacity * opacity
    }
    
    /// DaVinci Resolve-grade dynamic scale multiplier.
    /// At 50% (0.50): exactly 1.00x standard scale.
    /// Below 50%: smoothly scales down to 0.25x mini HUD.
    /// Above 50%: smoothly scales up to 2.80x, exceeding standard monitor bounds for ultra-immersive setups.
    public var effectiveScaleMultiplier: Double {
        if zoomScale <= 0.50 {
            return 0.25 + (zoomScale / 0.50) * 0.75
        } else {
            return 1.00 + ((zoomScale - 0.50) / 0.50) * 1.80
        }
    }
    
    private var hologramPanel: NSPanel?
    private var dismissTimer: Timer?
    private var fadeTimer: Timer?
    private var previewTimer: Timer?
    private var previewDummyManager: StreamingAudioManager?
    
    public var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
    }
    
    private init() {
        loadConfig()
    }
    
    public func loadConfig() {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        if let holo = json["hologram"] as? [String: Any] {
            if let en = holo["enabled"] as? Bool {
                self.isEnabled = en
            }
            if let themeId = holo["theme"] as? String {
                self.currentTheme = HologramTheme.find(id: themeId)
            }
            if let skinId = holo["skin"] as? String {
                self.currentSkin = HologramSkinType.find(id: skinId)
            }
            if let blendId = (holo["blend_mode"] as? String) ?? (holo["blendMode"] as? String) {
                self.currentBlendMode = HologramBlendMode.find(id: blendId)
            }
            if let op = holo["opacity"] as? Double {
                self.opacity = max(0.15, min(1.0, op))
            }
            if let sc = (holo["scale"] as? Double) ?? (holo["zoom"] as? Double) {
                self.zoomScale = max(0.0, min(1.0, sc))
            }
            if let ox = (holo["offsetX"] as? Double) ?? (holo["positionX"] as? Double) {
                self.positionX = max(-1000.0, min(1000.0, ox))
            }
            if let oy = (holo["offsetY"] as? Double) ?? (holo["positionY"] as? Double) {
                self.positionY = max(-800.0, min(800.0, oy))
            }
        }
    }
    
    public func saveConfig() {
        guard let data = try? Data(contentsOf: configURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var holo = json["hologram"] as? [String: Any] ?? [:]
        holo["enabled"] = self.isEnabled
        holo["theme"] = self.currentTheme.id
        holo["skin"] = self.currentSkin.id
        holo["blend_mode"] = self.currentBlendMode.id
        holo["opacity"] = self.opacity
        holo["scale"] = self.zoomScale
        holo["offsetX"] = self.positionX
        holo["offsetY"] = self.positionY
        json["hologram"] = holo
        
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? updated.write(to: configURL)
        }
    }
    
    public func setEnabled(_ enabled: Bool) {
        DispatchQueue.main.async {
            self.isEnabled = enabled
            self.saveConfig()
            if !enabled {
                self.dismissHologramImmediately()
            }
        }
    }
    
    public func setTheme(id: String) {
        DispatchQueue.main.async {
            self.currentTheme = HologramTheme.find(id: id)
            self.saveConfig()
        }
    }
    
    public func setSkin(id: String) {
        DispatchQueue.main.async {
            self.currentSkin = HologramSkinType.find(id: id)
            self.saveConfig()
        }
    }
    
    public func setSkin(_ skin: HologramSkinType) {
        DispatchQueue.main.async {
            self.currentSkin = skin
            self.saveConfig()
        }
    }
    
    public func setBlendMode(id: String) {
        DispatchQueue.main.async {
            self.currentBlendMode = HologramBlendMode.find(id: id)
            self.saveConfig()
        }
    }
    
    public func setBlendMode(_ mode: HologramBlendMode) {
        DispatchQueue.main.async {
            self.currentBlendMode = mode
            self.saveConfig()
        }
    }
    
    public func setOpacity(_ val: Double) {
        DispatchQueue.main.async {
            self.opacity = max(0.15, min(1.0, val))
            self.saveConfig()
        }
    }
    
    public func setZoomScale(_ val: Double) {
        DispatchQueue.main.async {
            self.zoomScale = max(0.0, min(1.0, val))
            self.saveConfig()
        }
    }
    
    public func setPositionX(_ val: Double) {
        DispatchQueue.main.async {
            self.positionX = max(-1000.0, min(1000.0, val))
            self.saveConfig()
        }
    }
    
    public func setPositionY(_ val: Double) {
        DispatchQueue.main.async {
            self.positionY = max(-800.0, min(800.0, val))
            self.saveConfig()
        }
    }
    
    public func setPosition(x: Double, y: Double) {
        DispatchQueue.main.async {
            self.positionX = max(-1000.0, min(1000.0, x))
            self.positionY = max(-800.0, min(800.0, y))
            self.saveConfig()
        }
    }
    
    public func resetTransform() {
        DispatchQueue.main.async {
            self.zoomScale = 0.50
            self.positionX = 0.0
            self.positionY = 0.0
            self.saveConfig()
        }
    }
    
    // MARK: - Panel Lifecycle Management
    
    func showHologram(targetScreen: NSScreen, audioManager: StreamingAudioManager) {
        guard isEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
            self.fadeTimer?.invalidate()
            self.fadeTimer = nil
            self.isFadingOut = false
            self.fadeProgress = 0.0
            self.isCollapsing = false
            self.collapseStartDate = nil
            self.bootupDate = Date()
            
            let screenFrame = targetScreen.frame
            let hosting = NSHostingView(
                rootView: FloatingJarvisHologramOverlayView(state: audioManager)
            )
            hosting.frame = NSRect(x: 0, y: 0, width: screenFrame.width, height: screenFrame.height)
            hosting.wantsLayer = true
            
            if let panel = self.hologramPanel {
                panel.setFrame(screenFrame, display: true)
                panel.contentView = hosting
                panel.alphaValue = 1.0
                panel.orderFrontRegardless()
            } else {
                let panel = NSPanel(
                    contentRect: screenFrame,
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered,
                    defer: false
                )
                panel.isFloatingPanel = true
                panel.level = .statusBar - 1
                panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false
                panel.ignoresMouseEvents = true // 100% click-through anywhere on screen
                panel.contentView = hosting
                panel.alphaValue = 0.0
                panel.orderFrontRegardless()
                self.hologramPanel = panel
                
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.20
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().alphaValue = 1.0
                }
            }
        }
    }
    
    public func dismissHologramImmediately() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewTimer?.invalidate()
            self.previewTimer = nil
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
            self.fadeTimer?.invalidate()
            self.fadeTimer = nil
            self.previewDummyManager?.isPlaying = false
            self.previewDummyManager = nil
            self.isPreviewActive = false
            self.isCollapsing = false
            self.collapseStartDate = nil
            self.isFadingOut = false
            self.fadeProgress = 0.0
            
            if let panel = self.hologramPanel {
                panel.orderOut(nil)
                panel.contentView = nil
                self.hologramPanel = nil
            }
        }
    }
    
    public func startWindowFadeOut(duration: Double = 2.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let panel = self.hologramPanel, !self.isFadingOut else { return }
            
            self.isFadingOut = true
            self.fadeProgress = 0.0
            
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0.0
            }
        }
    }
    
    public func dismissHologramWithFade(duration: Double = 1.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewTimer?.invalidate()
            self.previewTimer = nil
            self.previewDummyManager?.isPlaying = false
            self.previewDummyManager = nil
            self.isPreviewActive = false
            
            guard let panel = self.hologramPanel else {
                self.dismissHologramImmediately()
                return
            }
            
            self.dismissTimer?.invalidate()
            self.fadeTimer?.invalidate()
            self.isFadingOut = true
            self.fadeProgress = 0.0
            
            // CoreAnimation window alpha dissolve in parallel with guaranteed completion
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().alphaValue = 0.0
            }, completionHandler: { [weak self] in
                self?.dismissHologramImmediately()
            })
            
            // Hard safety fallback timeout (guarantees exit even if animation drops)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.15) { [weak self] in
                if self?.hologramPanel != nil {
                    self?.dismissHologramImmediately()
                }
            }
        }
    }
    
    public func onSpeechFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.hologramPanel != nil, !self.isFadingOut else { return }
            
            // If background music is still playing or fading out, start matching window fade!
            if BackgroundMusicManager.shared.isPlaying || BackgroundMusicManager.shared.isFadingOut {
                self.startWindowFadeOut(duration: BackgroundMusicManager.shared.fadeOutDuration)
                return
            }
            
            // If no music is playing, smoothly dissolve in 1.5s
            self.dismissHologramWithFade(duration: 1.5)
        }
    }
    
    public func triggerPreview(duration: Double = 5.0) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isEnabled else { return }
            
            // Immediately stop any existing preview
            self.stopPreview()
            
            self.isPreviewActive = true
            self.isCollapsing = false
            self.collapseStartDate = nil
            self.isFadingOut = false
            self.fadeProgress = 0.0
            self.bootupDate = Date()
            
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
            
            let dummy = StreamingAudioManager(text: "") { }
            dummy.isPlaying = true
            self.previewDummyManager = dummy
            
            self.showHologram(targetScreen: targetScreen, audioManager: dummy)
            
            // Automatic ironclad exit after specified seconds
            self.previewTimer?.invalidate()
            self.previewTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                self?.dismissHologramWithFade(duration: 1.0)
            }
        }
    }
    
    public func stopPreview() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewTimer?.invalidate()
            self.previewTimer = nil
            self.previewDummyManager?.isPlaying = false
            self.previewDummyManager = nil
            self.isPreviewActive = false
            self.dismissHologramImmediately()
        }
    }
}
