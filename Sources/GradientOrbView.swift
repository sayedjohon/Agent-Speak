import SwiftUI
import Cocoa

// MARK: - Passthrough Hosting View for AppKit Status Item
public class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    public override func hitTest(_ point: NSPoint) -> NSView? {
        return nil // Clicks pass directly to the underlying NSStatusBarButton
    }
}

// MARK: - Native 3D Gradient Orb Visualizer (Audio & Equalizer Reactive)
/// Replaces the React/Three.js shader with a 100% native Apple Silicon GPU visualizer.
/// Audio-reactive: modulates scale, fluid turbulence, rotation speed, and glow from live decibel meters.
public struct GradientOrbVisualizerView: View {
    @ObservedObject var queueManager = SpeechQueueManager.shared
    
    public var isSpeaking: Bool
    public var size: CGFloat
    public var color1: Color
    public var color2: Color
    public var color3: Color
    
    public init(
        isSpeaking: Bool = false,
        size: CGFloat = 68,
        color1: Color = Color(red: 0.24, green: 0.35, blue: 1.0),   // Electric Blue #3D5AFF
        color2: Color = Color(red: 0.61, green: 0.0, blue: 1.0),    // Cyber Purple #9D00FF
        color3: Color = Color(red: 1.0, green: 0.37, blue: 0.12)    // Neon Amber #FF5F1F
    ) {
        self.isSpeaking = isSpeaking
        self.size = size
        self.color1 = color1
        self.color2 = color2
        self.color3 = color3
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let level = CGFloat(queueManager.audioLevel) // 0.0 ... 1.0
            
            // Speed accelerates with volume
            let baseSpeed = isSpeaking ? 1.7 : 0.65
            let speed = baseSpeed + Double(level) * 2.5
            let rot1 = Angle.radians(now * speed)
            let rot2 = Angle.radians(-now * (speed * 0.72))
            
            // Equalizer pulse: gentle breathing + reactive sound boost
            let breath = sin(now * (isSpeaking ? 3.6 : 1.6)) * (isSpeaking ? 0.04 : 0.02)
            let audioPulse = level * 0.16
            let scale = 1.0 + CGFloat(breath) + audioPulse
            
            ZStack {
                // 1. Ambient Outer Bloom Aura
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color1.opacity(isSpeaking ? (0.45 + Double(level) * 0.35) : 0.22),
                                color2.opacity(isSpeaking ? (0.35 + Double(level) * 0.25) : 0.15),
                                color3.opacity(isSpeaking ? (0.20 + Double(level) * 0.20) : 0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.15,
                            endRadius: size * (0.65 + level * 0.2)
                        )
                    )
                    .frame(width: size * (1.35 + level * 0.25), height: size * (1.35 + level * 0.25))
                    .blur(radius: isSpeaking ? (12 + level * 8) : 8)
                
                // 2. Main 3D Spherical Plasma Orb
                ZStack {
                    // Deep space black base
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.10, blue: 0.20),
                                    Color(red: 0.02, green: 0.02, blue: 0.05)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.5
                            )
                        )
                    
                    // Rotating Gradient Layer 1 (Electric Blue -> Purple -> Amber)
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    color1,
                                    color2,
                                    color3,
                                    Color(red: 0.08, green: 0.85, blue: 0.95),
                                    color1
                                ]),
                                center: .center
                            )
                        )
                        .rotationEffect(rot1)
                        .blur(radius: size * 0.08)
                        .opacity(0.88)
                    
                    // Rotating Gradient Layer 2 (Cross-directional plasma swirl)
                    Ellipse()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    color3.opacity(0.9),
                                    color2.opacity(0.85),
                                    color1.opacity(0.75),
                                    color3.opacity(0.9)
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: size * (0.88 + level * 0.15), height: size * (0.68 + level * 0.12))
                        .rotationEffect(rot2)
                        .blur(radius: size * 0.06)
                        .blendMode(.plusLighter)
                    
                    // Fluid Equalizer Wave Contours (Height modulated by live audio)
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        let baseR = min(canvasSize.width, canvasSize.height) * 0.38
                        let waveCount = isSpeaking ? 3 : 2
                        
                        for w in 0..<waveCount {
                            let phaseOffset = now * (speed * 1.25) + Double(w) * 1.55
                            var path = Path()
                            let steps = 48
                            
                            // Audio-reactive wave amplitude
                            let baseAmp = isSpeaking ? (size * 0.07) : (size * 0.035)
                            let amp = baseAmp + (level * size * 0.12)
                            
                            for s in 0...steps {
                                let angle = (CGFloat(s) / CGFloat(steps)) * 2 * .pi
                                let harmonic = sin(angle * 3 + CGFloat(phaseOffset)) * amp
                                let r = baseR + harmonic - CGFloat(w * 6)
                                let pt = CGPoint(
                                    x: center.x + cos(angle) * r,
                                    y: center.y + sin(angle) * r
                                )
                                if s == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                            }
                            path.closeSubpath()
                            
                            let strokeColor = (w == 0)
                                ? Color(red: 0.4, green: 0.82, blue: 1.0).opacity(0.65 + Double(level) * 0.35)
                                : Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.45 + Double(level) * 0.35)
                            context.stroke(path, with: .color(strokeColor), lineWidth: 1.5 + level * 1.2)
                        }
                    }
                    
                    // High-Intensity Audio-Reactive Core Glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(isSpeaking ? (0.85 + Double(level) * 0.15) : 0.75),
                                    Color(red: 0.3, green: 0.85, blue: 1.0).opacity(0.6 + Double(level) * 0.3),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * (0.22 + level * 0.12)
                            )
                        )
                        .frame(width: size * (0.44 + level * 0.25), height: size * (0.44 + level * 0.25))
                        .blendMode(.plusLighter)
                    
                    // 3D Glass Specular Reflection Highlight (top-left glint)
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.65),
                                    Color.white.opacity(0.12),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.46, height: size * 0.22)
                        .offset(x: -size * 0.15, y: -size * 0.22)
                        .rotationEffect(.degrees(-25))
                    
                    // Glass Rim Border
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.75),
                                    Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.4),
                                    Color.white.opacity(0.1),
                                    Color(red: 1.0, green: 0.5, blue: 0.2).opacity(0.45)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .scaleEffect(scale)
                .shadow(
                    color: color1.opacity(isSpeaking ? (0.55 + Double(level) * 0.35) : 0.26),
                    radius: isSpeaking ? (12 + level * 10) : 7,
                    x: 0,
                    y: 3
                )
            }
            .frame(width: size * 1.35, height: size * 1.35)
        }
    }
}

// MARK: - Live Menu Bar Tray Gradient Orb (18x18 pt)
public struct TrayGradientOrbView: View {
    @ObservedObject var queueManager = SpeechQueueManager.shared
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let isSpeaking = queueManager.isSpeaking
            let level = CGFloat(queueManager.audioLevel)
            let now = timeline.date.timeIntervalSinceReferenceDate
            
            let speed = isSpeaking ? (2.2 + Double(level) * 3.0) : 0.8
            let rot1 = Angle.radians(now * speed)
            let rot2 = Angle.radians(-now * (speed * 0.75))
            let pulse = isSpeaking ? (1.0 + level * 0.22 + CGFloat(sin(now * 4.0) * 0.05)) : 1.0
            
            ZStack {
                // Outer Ambient Halo
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.24, green: 0.35, blue: 1.0).opacity(isSpeaking ? (0.6 + Double(level) * 0.4) : 0.3),
                                Color(red: 0.61, green: 0.0, blue: 1.0).opacity(isSpeaking ? 0.4 : 0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 9
                        )
                    )
                    .frame(width: 20, height: 20)
                    .blur(radius: isSpeaking ? 2.5 : 1.5)
                
                // Orb Body
                ZStack {
                    // Base Dark
                    Circle()
                        .fill(Color(red: 0.05, green: 0.06, blue: 0.15))
                    
                    // Rotating Color Swirl 1
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.24, green: 0.35, blue: 1.0),   // Blue
                                    Color(red: 0.61, green: 0.0, blue: 1.0),    // Purple
                                    Color(red: 1.0, green: 0.37, blue: 0.12),   // Amber
                                    Color(red: 0.1, green: 0.9, blue: 1.0),     // Cyan
                                    Color(red: 0.24, green: 0.35, blue: 1.0)
                                ]),
                                center: .center
                            )
                        )
                        .rotationEffect(rot1)
                        .blur(radius: 1.5)
                    
                    // Rotating Color Swirl 2
                    Ellipse()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 1.0, green: 0.37, blue: 0.12).opacity(0.85),
                                    Color(red: 0.61, green: 0.0, blue: 1.0).opacity(0.8),
                                    Color(red: 0.2, green: 0.6, blue: 1.0).opacity(0.7)
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: 14, height: 10)
                        .rotationEffect(rot2)
                        .blendMode(.plusLighter)
                    
                    // Core Glint
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(isSpeaking ? 0.95 : 0.8),
                                    Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.5),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 4
                            )
                        )
                        .frame(width: 6, height: 6)
                        .blendMode(.plusLighter)
                    
                    // Specular Highlight
                    Ellipse()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 5, height: 2.5)
                        .offset(x: -2.5, y: -3)
                    
                    // Glass Rim
                    Circle()
                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.75)
                }
                .frame(width: 15, height: 15)
                .clipShape(Circle())
                .scaleEffect(pulse)
            }
            .frame(width: 22, height: 20)
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Compact Dashboard Container
public struct CompactVisualizerOrbView: View {
    @Binding public var isSpeaking: Bool
    
    public init(isSpeaking: Binding<Bool>) {
        self._isSpeaking = isSpeaking
    }
    
    public var body: some View {
        HStack(spacing: 20) {
            GradientOrbVisualizerView(isSpeaking: isSpeaking, size: 58)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isSpeaking ? Color.green : Color.blue)
                        .frame(width: 8, height: 8)
                    
                    Text(isSpeaking ? "ACTIVE PLAYBACK" : "INTELLIGENT AGENT READY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(isSpeaking ? .green : .blue)
                }
                
                Text(isSpeaking ? "Synthesizing voice response at the camera notch..." : "Monitoring active terminal and AI coding assistant transcripts...")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
