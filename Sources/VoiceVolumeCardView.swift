import SwiftUI

public struct VoiceVolumeCardView: View {
    @ObservedObject var volumeManager = VoiceVolumeManager.shared
    
    public init() {}
    
    private let presets: [(label: String, val: Int, subtitle: String)] = [
        ("50%", 50, "Soft"),
        ("80%", 80, "Quiet"),
        ("100%", 100, "Full (Default)"),
        ("140%", 140, "+2.9 dB"),
        ("175%", 175, "+4.9 dB"),
        ("200%", 200, "Max Force (+6 dB)")
    ]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                volumeManager.isBoosted
                                    ? LinearGradient(colors: [Color.orange.opacity(0.35), Color.red.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color.blue.opacity(0.3), Color.cyan.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: volumeManager.isBoosted ? "bolt.shield.fill" : (volumeManager.volume < 100 ? "speaker.wave.1.fill" : "speaker.wave.3.fill"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(volumeManager.isBoosted ? .orange : (volumeManager.volume < 100 ? .cyan : .blue))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("VOICE PLAYBACK VOLUME & FORCE GAIN")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            
                            if volumeManager.isBoosted {
                                Text("BOOST ACTIVE")
                                    .font(.system(size: 8.5, weight: .heavy))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.25))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(volumeManager.isBoosted
                             ? "Force Decibel Boost actively amplifying quiet voice models with analog soft-saturation"
                             : "100% represents standard full loudness. Scale down or boost up to 200% (+6.0 dB)")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.60, green: 0.62, blue: 0.70))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Live Status Badge
                HStack(spacing: 5) {
                    Circle()
                        .fill(volumeManager.isBoosted ? Color.orange : (volumeManager.volume == 100 ? Color.green : Color.blue))
                        .frame(width: 6, height: 6)
                    Text(statusBadgeText)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(volumeManager.isBoosted ? .orange : (volumeManager.volume == 100 ? .green : .white))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(volumeManager.isBoosted ? Color.orange.opacity(0.12) : Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(volumeManager.isBoosted ? Color.orange.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            
            // Slider Row with Visual Scale
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(width: 14)
                    
                    Slider(
                        value: Binding(
                            get: { Double(volumeManager.volume) },
                            set: { volumeManager.setVolume(Int(round($0))) }
                        ),
                        in: 1...200,
                        step: 1
                    )
                    .accentColor(volumeManager.isBoosted ? .orange : .blue)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundColor(volumeManager.isBoosted ? .orange : .secondary)
                        .frame(width: 14)
                    
                    // Stepper / Value Display
                    Text("\(volumeManager.volume)%")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(volumeManager.isBoosted ? .orange : .white)
                        .frame(width: 44, alignment: .trailing)
                }
                
                // Decibel Visual Scale Ruler
                HStack {
                    Text("1% (Silent)")
                    Spacer()
                    Text("50% (-6 dB)")
                    Spacer()
                    Text("100% (0 dB Normal)")
                        .fontWeight(.semibold)
                        .foregroundColor(volumeManager.volume == 100 ? .green : .secondary)
                    Spacer()
                    Text("150% (+3.5 dB)")
                    Spacer()
                    Text("200% (+6.0 dB Max)")
                        .fontWeight(.semibold)
                        .foregroundColor(volumeManager.volume >= 195 ? .orange : .secondary)
                }
                .font(.system(size: 9.5))
                .foregroundColor(.secondary.opacity(0.8))
                .padding(.horizontal, 26)
            }
            
            // Quick Presets Row
            HStack(spacing: 8) {
                ForEach(presets, id: \.val) { p in
                    Button(action: {
                        volumeManager.setVolume(p.val)
                    }) {
                        VStack(spacing: 1) {
                            Text(p.label)
                                .font(.system(size: 11, weight: volumeManager.volume == p.val ? .bold : .medium))
                            Text(p.subtitle)
                                .font(.system(size: 8.5))
                                .foregroundColor(volumeManager.volume == p.val ? .white.opacity(0.9) : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            volumeManager.volume == p.val
                                ? (p.val > 100 ? Color.orange : (p.val == 100 ? Color.blue : Color.white.opacity(0.18)))
                                : Color.white.opacity(0.06)
                        )
                        .foregroundColor(volumeManager.volume == p.val ? .white : Color(red: 0.82, green: 0.84, blue: 0.90))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    volumeManager.volume == p.val
                                        ? (p.val > 100 ? Color.orange : Color.blue)
                                        : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Studio Soft-Limiter Footer Notice
            if volumeManager.isBoosted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    Text("Studio analog soft-saturation limiter active (tanh curve): Smooths waveform peaks approaching 0 dBFS to prevent harsh clipping.")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.70, green: 0.72, blue: 0.78))
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
    }
    
    private var statusBadgeText: String {
        if volumeManager.volume == 100 {
            return "100% Normal"
        } else if volumeManager.volume < 100 {
            return "\(volumeManager.volume)% Soft"
        } else {
            return "\(volumeManager.volume)% (+\(String(format: "%.1f", volumeManager.decibelBoost)) dB Boost)"
        }
    }
}
