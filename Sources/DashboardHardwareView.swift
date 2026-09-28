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
                            .foregroundColor(.primary)
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
                    Divider()
                    
                    // MARK: - Live Interactive Holographic Stage Viewport
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(red: 0.03, green: 0.03, blue: 0.04))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(hologram.currentTheme.previewColor.opacity(0.35), lineWidth: 1)
                            )
                        
                        // Subtle radial ambient glow inside stage
                        RadialGradient(
                            colors: [
                                hologram.currentTheme.previewColor.opacity(0.20),
                                hologram.currentTheme.previewColor.opacity(0.05),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 30,
                            endRadius: 220
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        // Live rendering of the currently selected skin spanning full stage width
                        GeometryReader { stageGeo in
                            let previewScale = CGFloat(hologram.effectiveScaleMultiplier)
                            let previewX = (stageGeo.size.width / 2.0) + CGFloat(hologram.positionX * 0.15)
                            let previewY = 108.0 + CGFloat(hologram.positionY * 0.15)
                            
                            HologramSkinContainerView(
                                skin: hologram.currentSkin,
                                theme: hologram.currentTheme,
                                blendMode: hologram.currentBlendMode,
                                isSpeaking: true,
                                isPlayingMusic: false,
                                size: 216,
                                customWidth: stageGeo.size.width,
                                simulateAudio: true
                            )
                            .frame(width: stageGeo.size.width, height: 216)
                            .scaleEffect(previewScale, anchor: .center)
                            .position(x: previewX, y: previewY)
                        }
                        .clipped()
                        
                        // Overlay HUD Badges
                        VStack {
                            HStack {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(hologram.currentTheme.previewColor)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: hologram.currentTheme.previewColor, radius: 4)
                                    Text("LIVE VIEWPORT")
                                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.65))
                                .cornerRadius(5)
                                
                                Spacer()
                                
                                if hologram.isPreviewActive {
                                    Button(action: {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            hologram.stopPreview()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "stop.fill")
                                                .font(.system(size: 8, weight: .bold))
                                            Text("STOP PREVIEW")
                                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        }
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.red.opacity(0.90))
                                        .foregroundColor(.white)
                                        .cornerRadius(5)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            hologram.triggerPreview()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "macwindow.on.rectangle")
                                                .font(.system(size: 8.5, weight: .bold))
                                            Text("TEST FULL SCREEN")
                                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        }
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(hologram.currentTheme.previewColor.opacity(0.20))
                                        .foregroundColor(hologram.currentTheme.previewColor)
                                        .cornerRadius(5)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .stroke(hologram.currentTheme.previewColor.opacity(0.6), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                HStack(spacing: 4) {
                                    Text(hologram.currentSkin.name.uppercased())
                                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(hologram.currentTheme.previewColor)
                                    Text("•")
                                        .font(.system(size: 8.5))
                                        .foregroundColor(.secondary)
                                    Text(hologram.currentBlendMode.displayName.uppercased())
                                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.65))
                                .cornerRadius(5)
                            }
                            Spacer()
                            HStack {
                                Text("120Hz Metal Native • Live Color Sync")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(Color(white: 0.5))
                                Spacer()
                                Text(hologram.currentSkin.creator)
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color(white: 0.5))
                            }
                        }
                        .padding(10)
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    
                    Divider()
                    
                    // MARK: - Holographic Core Skin Selector
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("HOLOGRAPHIC REACTOR CORE SKIN")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                            Spacer()
                            Text(hologram.currentSkin.creator)
                                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                .foregroundColor(hologram.currentTheme.previewColor.opacity(0.85))
                        }
                        
                        // 1. Pinned Default Master Skin (Tony Stark Mark 42)
                        let isDefaultSelected = (hologram.currentSkin == .classicArc)
                        Button(action: {
                            hologram.setSkin(.classicArc)
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(hologram.currentTheme.previewColor)
                                    .frame(width: 24, height: 24)
                                    .background(hologram.currentTheme.previewColor.opacity(0.15))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 6) {
                                        Text(HologramSkinType.classicArc.name)
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Text("MASTER DEFAULT")
                                            .font(.system(size: 8, weight: .black, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1)
                                            .background(hologram.currentTheme.previewColor.opacity(0.25))
                                            .foregroundColor(hologram.currentTheme.previewColor)
                                            .cornerRadius(3)
                                    }
                                    Text(HologramSkinType.classicArc.subtitle)
                                        .font(.system(size: 8.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if isDefaultSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(hologram.currentTheme.previewColor)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(isDefaultSelected ? hologram.currentTheme.previewColor.opacity(0.14) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isDefaultSelected ? hologram.currentTheme.previewColor.opacity(0.8) : Color(nsColor: .separatorColor), lineWidth: isDefaultSelected ? 1.5 : 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // 2. Additional Repaired Skins Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(HologramSkinType.allCases.filter { !$0.isDefault }) { skin in
                                let isSelected = (hologram.currentSkin == skin)
                                Button(action: {
                                    hologram.setSkin(skin)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: skin.systemIcon)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(isSelected ? hologram.currentTheme.previewColor : .secondary)
                                            .frame(width: 20, height: 20)
                                            .background(isSelected ? hologram.currentTheme.previewColor.opacity(0.2) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(skin.name)
                                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            Text(skin.creator)
                                                .font(.system(size: 8, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8.5, weight: .bold))
                                                .foregroundColor(hologram.currentTheme.previewColor)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(isSelected ? hologram.currentTheme.previewColor.opacity(0.12) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                    .cornerRadius(7)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7)
                                            .stroke(isSelected ? hologram.currentTheme.previewColor.opacity(0.7) : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.2 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                    
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
                                                .foregroundColor(.primary)
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
                                    .background(isSelected ? theme.previewColor.opacity(0.12) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? theme.previewColor.opacity(0.7) : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.5 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // MARK: - Holographic Blending Mode Selector (Photoshop-Grade)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("HOLOGRAPHIC BLENDING MODE")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                                Text("Composites visualizer over desktop windows, code & browser text")
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            // Photoshop Blending Mode Dropdown Menu
                            Menu {
                                ForEach(HologramBlendMode.allCases) { mode in
                                    Button(action: {
                                        hologram.setBlendMode(mode)
                                    }) {
                                        HStack {
                                            Image(systemName: mode.systemIcon)
                                            Text(mode.displayName)
                                            if hologram.currentBlendMode == mode {
                                                Spacer()
                                                Text("✓")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: hologram.currentBlendMode.systemIcon)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(hologram.currentTheme.previewColor)
                                    Text(hologram.currentBlendMode.displayName)
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .foregroundColor(.primary)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(hologram.currentTheme.previewColor.opacity(0.18))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(hologram.currentTheme.previewColor.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        }
                        
                        // Quick Mode Pill Selector (Fast 1-click presets)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(HologramBlendMode.allCases) { mode in
                                    let isSelected = (hologram.currentBlendMode == mode)
                                    Button(action: {
                                        hologram.setBlendMode(mode)
                                    }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: mode.systemIcon)
                                                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                                                .foregroundColor(isSelected ? hologram.currentTheme.previewColor : .secondary)
                                            Text(mode.displayName)
                                                .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(isSelected ? .primary : .secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(isSelected ? hologram.currentTheme.previewColor.opacity(0.18) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(isSelected ? hologram.currentTheme.previewColor.opacity(0.75) : Color(nsColor: .separatorColor), lineWidth: isSelected ? 1.2 : 0.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Active Blend Mode Visual Explainer Card
                        HStack(spacing: 8) {
                            Image(systemName: hologram.currentBlendMode.systemIcon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(hologram.currentTheme.previewColor)
                                .frame(width: 22, height: 22)
                                .background(hologram.currentTheme.previewColor.opacity(0.12))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(hologram.currentBlendMode.displayName.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(hologram.currentTheme.previewColor)
                                Text(hologram.currentBlendMode.subtitle)
                                    .font(.system(size: 8.5))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                        .cornerRadius(6)
                        
                        // Overlay Opacity / Translucency Slider
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text("OVERLAY TRANSLUCENCY / INTENSITY")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                                Spacer()
                                Text("\(Int(round(hologram.opacity * 100)))%")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(hologram.currentTheme.previewColor)
                            }
                            
                            HStack(spacing: 10) {
                                Slider(
                                    value: Binding(
                                        get: { hologram.opacity },
                                        set: { hologram.setOpacity($0) }
                                    ),
                                    in: 0.15...1.0
                                )
                                .accentColor(hologram.currentTheme.previewColor)
                                
                                // Preset Buttons
                                HStack(spacing: 4) {
                                    ForEach([("100%", 1.0), ("75%", 0.75), ("50%", 0.50), ("30%", 0.30)], id: \.0) { label, val in
                                        Button(action: {
                                            hologram.setOpacity(val)
                                        }) {
                                            Text(label)
                                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 3)
                                                .background(abs(hologram.opacity - val) < 0.05 ? hologram.currentTheme.previewColor.opacity(0.25) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                                .foregroundColor(abs(hologram.opacity - val) < 0.05 ? hologram.currentTheme.previewColor : .secondary)
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // DaVinci Resolve-Grade HUD Transform Controls (Z-Zoom, X-Pos, Y-Pos)
                    HUDTransformCardView()
                    
                    Divider()
                    
                    // Live Preview & Stop Controls
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Test Holographic Glow")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                            Text(hologram.isPreviewActive ? "Preview is currently active on screen (auto-exits in 5s)..." : "Simulates the full-screen visualizer overlay live on your display for 5 seconds")
                                .font(.system(size: 9.5))
                                .foregroundColor(hologram.isPreviewActive ? hologram.currentTheme.previewColor : .secondary)
                        }
                        Spacer()
                        
                        HStack(spacing: 8) {
                            if hologram.isPreviewActive {
                                Button(action: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        hologram.stopPreview()
                                    }
                                }) {
                                    HStack(spacing: 5) {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("Stop Preview")
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.90))
                                    .cornerRadius(6)
                                    .shadow(color: Color.red.opacity(0.5), radius: 6)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        hologram.triggerPreview()
                                    }
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
                } else {
                    // Deactivated Hologram Notice with 1-Click Activate Button
                    HStack(spacing: 10) {
                        Image(systemName: "circle.slash")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Hologram Overlay is Deactivated")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Audio output and Notch HUD play normally without full-screen graphics.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            hologram.setEnabled(true)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                Text("Activate Hologram")
                            }
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(hologram.currentTheme.previewColor)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
                    .cornerRadius(8)
                }
            }
            .padding(14)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(hologram.isEnabled ? hologram.currentTheme.previewColor.opacity(0.3) : Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            
            // MARK: - Notch Section
            VStack(alignment: .leading, spacing: 8) {
                Text("DYNAMIC NOTCH HUD")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "macbook.gen2")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camera Notch Overlay")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Floats smoothly under the camera notch on MacBook Pro and Air")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Active")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    
                    Divider().padding(.horizontal, 14)
                    
                    HStack {
                        Image(systemName: "escape")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Silence Key (Esc)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Press Escape anywhere on macOS to immediately stop speech, hologram and music")
                                .font(.system(size: 11))
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
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            }
            
            // MARK: - Menu Bar Tray Section
            VStack(alignment: .leading, spacing: 8) {
                Text("MENU BAR STATUS ICON")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "menubar.rectangle")
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Menu Bar Icon")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Quickly access controls and settings from the top macOS status bar")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $showTrayIcon)
                            .toggleStyle(.switch)
                            .onChange(of: showTrayIcon) { _, newValue in
                                onSaveConfig()
                                AppDelegate.shared?.setTrayIconVisible(newValue)
                            }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    
                    Divider().padding(.horizontal, 14)
                    
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(queueManager.isSpeaking ? Color.green : Color.blue)
                                .frame(width: 7, height: 7)
                            Text(queueManager.isSpeaking ? "Menu Bar Status: Speaking" : "Menu Bar Status: Ready")
                                .font(.system(size: 11))
                                .foregroundColor(.primary)
                        }
                        Spacer()
                        Text(showTrayIcon ? "Visible in Menu Bar" : "Hidden")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(showTrayIcon ? .green : .secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            }
        }
    }
}
