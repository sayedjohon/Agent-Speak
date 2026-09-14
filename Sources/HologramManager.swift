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

// MARK: - Hologram Manager (Singleton)
public class HologramManager: ObservableObject {
    public static let shared = HologramManager()
    
    @Published public var isEnabled: Bool = true
    @Published public var currentTheme: HologramTheme = .amber
    @Published public var isPreviewActive: Bool = false
    
    private var hologramPanel: NSPanel?
    private var dismissTimer: Timer?
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
        }
    }
    
    public func saveConfig() {
        guard let data = try? Data(contentsOf: configURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var holo = json["hologram"] as? [String: Any] ?? [:]
        holo["enabled"] = self.isEnabled
        holo["theme"] = self.currentTheme.id
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
    
    // MARK: - Panel Lifecycle Management
    
    func showHologram(targetScreen: NSScreen, audioManager: StreamingAudioManager) {
        guard isEnabled else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
            
            if self.hologramPanel == nil {
                let screenFrame = targetScreen.frame
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
                
                let hosting = NSHostingView(
                    rootView: FloatingJarvisHologramOverlayView(state: audioManager)
                )
                hosting.frame = NSRect(x: 0, y: 0, width: screenFrame.width, height: screenFrame.height)
                hosting.wantsLayer = true
                panel.contentView = hosting
                panel.orderFront(nil)
                self.hologramPanel = panel
            }
        }
    }
    
    public func dismissHologramImmediately() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismissTimer?.invalidate()
            self.dismissTimer = nil
            self.previewDummyManager = nil
            self.isPreviewActive = false
            self.hologramPanel?.orderOut(nil)
            self.hologramPanel = nil
        }
    }
    
    public func onSpeechFinished() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // If background music is still playing or fading out, let the hologram stay alive with the music!
            if BackgroundMusicManager.shared.isPlaying || BackgroundMusicManager.shared.isFadingOut {
                // Keep the panel open; the SwiftUI overlay observes bgm.fadeProgress and dissolves smoothly!
                return
            }
            
            // If no music is playing, smoothly dissolve after brief 0.35s tail
            self.dismissTimer?.invalidate()
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                self?.dismissHologramImmediately()
            }
        }
    }
    
    public func triggerPreview() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isEnabled else { return }
            
            self.dismissHologramImmediately()
            self.isPreviewActive = true
            
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
            
            let dummy = StreamingAudioManager(text: "") { }
            dummy.isPlaying = true
            self.previewDummyManager = dummy
            
            self.showHologram(targetScreen: targetScreen, audioManager: dummy)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                guard let self = self, self.isPreviewActive else { return }
                self.dismissHologramImmediately()
            }
        }
    }
}
