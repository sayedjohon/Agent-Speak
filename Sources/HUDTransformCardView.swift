import SwiftUI
import Cocoa

// MARK: - DaVinci Resolve-Grade HUD Transform Card View (Z-Zoom, X-Position, Y-Position)
public struct HUDTransformCardView: View {
    @ObservedObject private var hologram = HologramManager.shared
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Header with DaVinci-Style Master Reset Button
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(hologram.currentTheme.previewColor)
                    Text("HUD GEOMETRY & TRANSFORM")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                        .tracking(0.5)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    if hologram.isPreviewActive {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                hologram.stopPreview()
                            }
                        }) {
                            HStack(spacing: 3.5) {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 7.5, weight: .bold))
                                Text("Stop")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                hologram.triggerPreview()
                            }
                        }) {
                            HStack(spacing: 3.5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 7.5, weight: .bold))
                                Text("Test")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(hologram.currentTheme.previewColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(hologram.currentTheme.previewColor.opacity(0.12))
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            hologram.resetTransform()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("Reset")
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        }
                        .foregroundColor(isAtDefault ? .secondary : hologram.currentTheme.previewColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(isAtDefault ? Color(nsColor: .quaternaryLabelColor).opacity(0.2) : hologram.currentTheme.previewColor.opacity(0.12))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isAtDefault ? Color(nsColor: .separatorColor) : hologram.currentTheme.previewColor.opacity(0.35), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Reset Zoom to 50% (1.0x), Position X to 0, and Position Y to 0")
                }
            }
            
            // Subtitle Description
            Text("Fine-tune size and coordinate alignment across ultra-wide, vertical, or asymmetric multi-display setups.")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            VStack(spacing: 12) {
                
                // MARK: - 1. Zoom / Scale Slider (Z-Axis)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("ZOOM / SCALE (Z)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.primary)
                            if abs(hologram.zoomScale - 0.50) < 0.01 {
                                Text("DEFAULT")
                                    .font(.system(size: 7.5, weight: .black, design: .monospaced))
                                    .foregroundColor(hologram.currentTheme.previewColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(hologram.currentTheme.previewColor.opacity(0.15))
                                    .cornerRadius(3)
                            }
                        }
                        Spacer()
                        Text("\(Int(round(hologram.zoomScale * 100)))% • \(String(format: "%.2f", hologram.effectiveScaleMultiplier))x")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(hologram.currentTheme.previewColor)
                    }
                    
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { hologram.zoomScale },
                                set: { hologram.setZoomScale($0) }
                            ),
                            in: 0.0...1.0
                        )
                        .accentColor(hologram.currentTheme.previewColor)
                        
                        // Scale Presets
                        HStack(spacing: 3) {
                            ForEach([("25%", 0.25), ("50%", 0.50), ("75%", 0.75), ("100%", 1.00)], id: \.0) { label, val in
                                Button(action: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        hologram.setZoomScale(val)
                                    }
                                }) {
                                    Text(label)
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(abs(hologram.zoomScale - val) < 0.03 ? hologram.currentTheme.previewColor.opacity(0.25) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                        .foregroundColor(abs(hologram.zoomScale - val) < 0.03 ? hologram.currentTheme.previewColor : .secondary)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Text("50% = 1.0x native standard. Push to 100% (2.80x) to expand beyond monitor boundaries.")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                
                // MARK: - 2. Horizontal Position Slider (X-Axis)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("HORIZONTAL POSITION (X)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.primary)
                            if abs(hologram.positionX) < 1 {
                                Text("CENTERED")
                                    .font(.system(size: 7.5, weight: .black, design: .monospaced))
                                    .foregroundColor(hologram.currentTheme.previewColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(hologram.currentTheme.previewColor.opacity(0.15))
                                    .cornerRadius(3)
                            }
                        }
                        Spacer()
                        Text(formatOffset(hologram.positionX, axis: "X"))
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(hologram.currentTheme.previewColor)
                    }
                    
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { hologram.positionX },
                                set: { hologram.setPositionX($0) }
                            ),
                            in: -1000.0...1000.0
                        )
                        .accentColor(hologram.currentTheme.previewColor)
                        
                        // X Presets
                        HStack(spacing: 3) {
                            ForEach([("-300", -300.0), ("Center", 0.0), ("+300", 300.0)], id: \.0) { label, val in
                                Button(action: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        hologram.setPositionX(val)
                                    }
                                }) {
                                    Text(label)
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(abs(hologram.positionX - val) < 5 ? hologram.currentTheme.previewColor.opacity(0.25) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                        .foregroundColor(abs(hologram.positionX - val) < 5 ? hologram.currentTheme.previewColor : .secondary)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // MARK: - 3. Vertical Position Slider (Y-Axis)
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("VERTICAL POSITION (Y)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.primary)
                            if abs(hologram.positionY) < 1 {
                                Text("CENTERED")
                                    .font(.system(size: 7.5, weight: .black, design: .monospaced))
                                    .foregroundColor(hologram.currentTheme.previewColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(hologram.currentTheme.previewColor.opacity(0.15))
                                    .cornerRadius(3)
                            }
                        }
                        Spacer()
                        Text(formatOffset(hologram.positionY, axis: "Y"))
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(hologram.currentTheme.previewColor)
                    }
                    
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { hologram.positionY },
                                set: { hologram.setPositionY($0) }
                            ),
                            in: -800.0...800.0
                        )
                        .accentColor(hologram.currentTheme.previewColor)
                        
                        // Y Presets
                        HStack(spacing: 3) {
                            ForEach([("-200", -200.0), ("Center", 0.0), ("+200", 200.0)], id: \.0) { label, val in
                                Button(action: {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        hologram.setPositionY(val)
                                    }
                                }) {
                                    Text(label)
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 3)
                                        .background(abs(hologram.positionY - val) < 5 ? hologram.currentTheme.previewColor.opacity(0.25) : Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                                        .foregroundColor(abs(hologram.positionY - val) < 5 ? hologram.currentTheme.previewColor : .secondary)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.15))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    private var isAtDefault: Bool {
        abs(hologram.zoomScale - 0.50) < 0.01 &&
        abs(hologram.positionX) < 1.0 &&
        abs(hologram.positionY) < 1.0
    }
    
    private func formatOffset(_ val: Double, axis: String) -> String {
        let rounded = Int(round(val))
        if rounded == 0 {
            return "0 px (Center)"
        } else if axis == "X" {
            return "\(rounded > 0 ? "+" : "")\(rounded) px \(rounded > 0 ? "(Right)" : "(Left)")"
        } else {
            return "\(rounded > 0 ? "+" : "")\(rounded) px \(rounded > 0 ? "(Down)" : "(Up)")"
        }
    }
}
