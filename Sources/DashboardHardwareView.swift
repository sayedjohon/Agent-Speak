import SwiftUI
import Cocoa

// MARK: - Dashboard Hardware, Hologram & Menu Bar View
public struct DashboardHardwareView: View {
    @Binding var showTrayIcon: Bool
    let isAccessibilityTrusted: Bool
    let onSaveConfig: () -> Void
    @ObservedObject private var queueManager = SpeechQueueManager.shared
    @ObservedObject private var hologram = HologramManager.shared
    
    public init(showTrayIcon: Binding<Bool>, isAccessibilityTrusted: Bool, onSaveConfig: @escaping () -> Void) {
        self._showTrayIcon = showTrayIcon
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.onSaveConfig = onSaveConfig
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // MARK: - Holographic Jarvis Reactor Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("JARVIS HOLOGRAPHIC REACTOR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if hologram.isEnabled {
                        Text("Online")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(hologram.currentTheme.previewColor)
                    }
                }
                
                // Toggle Row
                HStack(spacing: 12) {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [hologram.currentTheme.previewColor, hologram.currentTheme.amber.opacity(0.3)],
                                center: .center,
                                startRadius: 2,
                                endRadius: 14
                            )
                        )
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(hologram.currentTheme.previewColor, lineWidth: 1.5))
                        .shadow(color: hologram.currentTheme.previewColor.opacity(0.6), radius: 6)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Full-Screen Hologram Overlay")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Renders an arc reactor dead-center on screen with ambient audio-reactive wave glow")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { hologram.isEnabled },
                        set: { hologram.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                }
                
                if hologram.isEnabled {
                    Divider().background(Color.white.opacity(0.06))
                    
                    // Theme Color Selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REACTOR CORE COLOR PALETTE")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(HologramTheme.allThemes) { theme in
                                let isSelected = (hologram.currentTheme.id == theme.id)
                                Button(action: {
                                    hologram.setTheme(id: theme.id)
                                }) {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(theme.previewColor)
                                            .frame(width: 12, height: 12)
                                            .shadow(color: theme.previewColor.opacity(isSelected ? 0.9 : 0.4), radius: isSelected ? 5 : 2)
                                        
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(theme.name)
                                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(isSelected ? .white : Color(red: 0.82, green: 0.83, blue: 0.88))
                                            Text(theme.subtitle)
                                                .font(.system(size: 8.5))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(theme.previewColor)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? theme.previewColor.opacity(0.12) : Color.white.opacity(0.03))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? theme.previewColor.opacity(0.7) : Color.white.opacity(0.06), lineWidth: isSelected ? 1.5 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    // Live Preview Button
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Test Holographic Glow")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                            Text("Simulates the full-screen visualizer overlay live on your display for 4 seconds")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            hologram.triggerPreview()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Preview Live")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(hologram.currentTheme.previewColor.opacity(0.85))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(hologram.isEnabled ? hologram.currentTheme.previewColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            
            // MARK: - Notch Section
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
                        Text("Press Escape anywhere on macOS to immediately stop speech, hologram and music")
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
            
            // MARK: - Menu Bar Tray Section
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
                            onSaveConfig()
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
}
