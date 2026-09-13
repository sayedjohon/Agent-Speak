import SwiftUI
import Cocoa

// MARK: - 3D Visualizer Orb
struct VisualizerOrbView: View {
    @Binding var isSpeaking: Bool
    @State private var phase: CGFloat = 0.0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let baseRadius = min(size.width, size.height) * 0.32
                
                // Multi-layered resonance rings
                let ringColors: [Color] = [
                    Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.85),
                    Color(red: 0.1, green: 0.9, blue: 0.8).opacity(0.65),
                    Color(red: 0.5, green: 0.3, blue: 1.0).opacity(0.55)
                ]
                
                for (idx, color) in ringColors.enumerated() {
                    let offsetPhase = phase + CGFloat(idx) * 0.85
                    var path = Path()
                    let points = 64
                    for p in 0...points {
                        let angle = (CGFloat(p) / CGFloat(points)) * 2 * .pi
                        let wave = sin(angle * 4 + offsetPhase) * (isSpeaking ? 15 : 5)
                        let r = baseRadius + wave + CGFloat(idx * 6)
                        let x = center.x + cos(angle) * r
                        let y = center.y + sin(angle) * r
                        if p == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.closeSubpath()
                    context.stroke(path, with: .color(color), lineWidth: 2.2)
                }
                
                // Central Glowing Core
                let coreGradient = Gradient(colors: [
                    Color.white.opacity(0.95),
                    Color(red: 0.1, green: 0.7, blue: 1.0).opacity(0.8),
                    Color(red: 0.05, green: 0.2, blue: 0.5).opacity(0.2)
                ])
                let coreRect = CGRect(
                    x: center.x - baseRadius * 0.55,
                    y: center.y - baseRadius * 0.55,
                    width: baseRadius * 1.1,
                    height: baseRadius * 1.1
                )
                context.fill(Path(ellipseIn: coreRect), with: .radialGradient(coreGradient, center: center, startRadius: 0.0, endRadius: baseRadius * 0.55))
            }
        }
        .frame(height: 140)
        .onAppear {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Dashboard Main View
public struct DashboardView: View {
    @ObservedObject var queueManager = SpeechQueueManager.shared
    @State private var isEnabled: Bool = true
    @State private var watchAntigravity: Bool = true
    @State private var watchClaude: Bool = true
    @State private var watchOpenCode: Bool = true
    @State private var watchTerminal: Bool = true
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Liquid Glass Dark Obsidian Background
            Color(red: 0.07, green: 0.08, blue: 0.10)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                        Text("AGENT SPEAK")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(1.4)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    // Status Badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isEnabled ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(isEnabled ? "LISTENING" : "MUTED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isEnabled ? .green : .orange)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 6)
                
                // 3D Audio Visualizer Orb
                VisualizerOrbView(isSpeaking: $queueManager.isSpeaking)
                    .padding(.vertical, 4)
                
                // Active Voice Info Card (Default System Voice)
                HStack(spacing: 12) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Active Voice Engine")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("Default Apple Silicon Voice (Native)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("0ms Delay")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(6)
                }
                .padding(12)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Scrollable Controls
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        // Watched Environments
                        VStack(alignment: .leading, spacing: 10) {
                            Text("CONNECTED AGENT WORKSPACES")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Toggle(isOn: $watchAntigravity) {
                                HStack {
                                    Image(systemName: "circle.hexagongrid.circle.fill")
                                        .foregroundColor(.purple)
                                    Text("Antigravity AI Workspaces")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .toggleStyle(.switch)
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            Toggle(isOn: $watchClaude) {
                                HStack {
                                    Image(systemName: "terminal.fill")
                                        .foregroundColor(.orange)
                                    Text("Claude Code & Desktop")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .toggleStyle(.switch)
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            Toggle(isOn: $watchOpenCode) {
                                HStack {
                                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                                        .foregroundColor(.cyan)
                                    Text("OpenCode, Aider & Cloud Agents")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .toggleStyle(.switch)
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            Toggle(isOn: $watchTerminal) {
                                HStack {
                                    Image(systemName: "apple.terminal.on.rectangle.fill")
                                        .foregroundColor(.green)
                                    Text("Universal UNIX Socket & CLI")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // Hardware Notch Controls
                        VStack(alignment: .leading, spacing: 10) {
                            Text("HARDWARE NOTCH INTEGRATION")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "macbook.gen2")
                                    .foregroundColor(.blue)
                                Text("MacBook Camera Notch Bezel")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("Adaptive 0pt")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider().background(Color.white.opacity(0.08))
                            
                            HStack {
                                Image(systemName: "escape")
                                    .foregroundColor(.yellow)
                                Text("Global Escape Key Dismiss")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Text("0ms Tap")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    }
                    .padding(.horizontal, 20)
                }
                
                // Bottom Action Deck
                HStack(spacing: 12) {
                    Button(action: {
                        SpeechQueueManager.shared.enqueue(
                            source: "Agent Speak",
                            text: "Hello! Agent Speak is online with your MacBook's natural default system voice."
                        )
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11))
                            Text("Test Voice Now")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if queueManager.isSpeaking {
                            queueManager.stopCurrent()
                        } else {
                            isEnabled.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: queueManager.isSpeaking ? "stop.fill" : (isEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill"))
                                .font(.system(size: 11))
                            Text(queueManager.isSpeaking ? "Stop Speech" : (isEnabled ? "Mute" : "Unmute"))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.45))
            }
        }
        .frame(width: 420, height: 560)
    }
}
