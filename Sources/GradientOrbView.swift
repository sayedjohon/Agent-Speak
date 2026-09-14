import SwiftUI
import Cocoa

// MARK: - Passthrough Hosting View for AppKit Status Item
public class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    public override func hitTest(_ point: NSPoint) -> NSView? {
        return nil // Clicks pass directly to the underlying NSStatusBarButton
    }
}

// MARK: - Native 3D Gradient Orb Visualizer (Subtle & Elegant)
/// Replaces the React/Three.js shader with a 100% native Apple Silicon GPU visualizer.
/// Subtle audio reactivity: calm majestic drift with gentle organic swell (no harsh jumping).
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
            let level = CGFloat(queueManager.audioLevel) // 0.0 ... 1.0 (smoothly filtered)
            
            // Ultra-calm, majestic rotation speed (steady & serene drift)
            let speed = isSpeaking ? 0.28 : 0.18
            let rot1 = Angle.radians(now * speed)
            let rot2 = Angle.radians(-now * (speed * 0.72))
            
            // Subtle, organic breathing swell (max ~2% variation, butter smooth)
            let breath = sin(now * (isSpeaking ? 1.6 : 1.0)) * 0.012
            let audioPulse = isSpeaking ? (level * 0.022) : 0.0
            let scale = 1.0 + CGFloat(breath) + audioPulse
            
            ZStack {
                // 1. Soft Ambient Halo Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color1.opacity(isSpeaking ? (0.28 + Double(level) * 0.12) : 0.15),
                                color2.opacity(isSpeaking ? (0.18 + Double(level) * 0.08) : 0.07),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.20,
                            endRadius: size * 0.62
                        )
                    )
                    .frame(width: size * 1.25, height: size * 1.25)
                    .blur(radius: isSpeaking ? 8 : 5)
                
                // 2. 3D Glass Sphere Body
                ZStack {
                    // Deep Obsidian Space Base
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 0.06, green: 0.08, blue: 0.18),
                                    Color(red: 0.02, green: 0.02, blue: 0.05)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.5
                            )
                        )
                    
                    // Liquid Swirl Layer 1: Electric Blue & Cyber Purple
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    color1,
                                    color2,
                                    color3,
                                    Color(red: 0.10, green: 0.80, blue: 0.95),
                                    color1
                                ]),
                                center: .center
                            )
                        )
                        .rotationEffect(rot1)
                        .blur(radius: size * 0.14)
                        .opacity(0.86)
                    
                    // Liquid Swirl Layer 2: Sunset Amber & Magenta Highlights
                    Ellipse()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    color3.opacity(0.85),
                                    Color(red: 0.70, green: 0.10, blue: 0.95).opacity(0.75),
                                    color1.opacity(0.65),
                                    color3.opacity(0.85)
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: size * 0.86, height: size * 0.66)
                        .rotationEffect(rot2)
                        .blur(radius: size * 0.12)
                        .blendMode(.plusLighter)
                    
                    // Subtle Harmonic Waves inside the Orb
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        let baseR = min(canvasSize.width, canvasSize.height) * 0.38
                        let waveCount = 2
                        
                        for w in 0..<waveCount {
                            let phaseOffset = now * 0.8 + Double(w) * 1.55
                            var path = Path()
                            let steps = 44
                            let amp = (size * 0.035) + (level * size * 0.03)
                            
                            for s in 0...steps {
                                let angle = (CGFloat(s) / CGFloat(steps)) * 2 * .pi
                                let harmonic = sin(angle * 3 + CGFloat(phaseOffset)) * amp
                                let r = baseR + harmonic - CGFloat(w * 5)
                                let pt = CGPoint(
                                    x: center.x + cos(angle) * r,
                                    y: center.y + sin(angle) * r
                                )
                                if s == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                            }
                            path.closeSubpath()
                            
                            let strokeColor = (w == 0)
                                ? Color(red: 0.4, green: 0.82, blue: 1.0).opacity(0.50 + Double(level) * 0.15)
                                : Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.35 + Double(level) * 0.15)
                            context.stroke(path, with: .color(strokeColor), lineWidth: 1.2)
                        }
                    }
                    
                    // Soft Luminescent Core (Gently warms with volume)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(isSpeaking ? (0.75 + Double(level) * 0.12) : 0.68),
                                    Color(red: 0.35, green: 0.78, blue: 1.0).opacity(0.40),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: size * 0.24
                            )
                        )
                        .frame(width: size * 0.48, height: size * 0.48)
                        .blendMode(.plusLighter)
                    
                    // 3D Glass Specular Reflection Highlight (top-left glint)
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.55),
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.45, height: size * 0.20)
                        .offset(x: -size * 0.14, y: -size * 0.20)
                        .rotationEffect(.degrees(-25))
                    
                    // Fine Glass Rim Border
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.65),
                                    Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.30),
                                    Color.white.opacity(0.08),
                                    Color(red: 1.0, green: 0.5, blue: 0.2).opacity(0.35)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.0
                        )
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .scaleEffect(scale)
                .shadow(
                    color: color1.opacity(isSpeaking ? 0.38 : 0.18),
                    radius: isSpeaking ? 10 : 5,
                    x: 0,
                    y: 2
                )
            }
            .frame(width: size * 1.25, height: size * 1.25)
        }
    }
}

// MARK: - Native macOS Menu Bar Tray (Subtle & Elegant Indicator)
public struct TrayGradientOrbView: View {
    @ObservedObject var queueManager = SpeechQueueManager.shared
    
    public init() {}
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let isSpeaking = queueManager.isSpeaking
            let level = CGFloat(queueManager.audioLevel)
            let now = timeline.date.timeIntervalSinceReferenceDate
            
            HStack(alignment: .center, spacing: 0) {
                if isSpeaking {
                    // 3 Subtle, calm equalizer pill bars (Apple Music / Siri elegance)
                    HStack(alignment: .center, spacing: 2.2) {
                        ForEach(0..<3) { i in
                            let baseH: CGFloat = (i == 1) ? 9.0 : 6.0
                            let phase = now * 2.2 + Double(i) * 1.2
                            let wave = CGFloat(sin(phase)) * 1.2
                            let audioMod = level * 2.2
                            let h = max(4.0, min(12.0, baseH + wave + audioMod))
                            
                            RoundedRectangle(cornerRadius: 1.4)
                                .fill(Color.primary)
                                .frame(width: 2.4, height: h)
                        }
                    }
                    .frame(width: 18, height: 16)
                } else {
                    // Clean, crisp native outline icon
                    if let img = AppDelegate.shared?.idleIcon {
                        Image(nsImage: img)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 17, height: 17)
                            .foregroundColor(.primary)
                    } else {
                        // Minimal ready soundwave glyph
                        HStack(spacing: 2.0) {
                            RoundedRectangle(cornerRadius: 1.0).fill(Color.primary.opacity(0.65)).frame(width: 2.2, height: 5)
                            RoundedRectangle(cornerRadius: 1.0).fill(Color.primary.opacity(0.95)).frame(width: 2.2, height: 11)
                            RoundedRectangle(cornerRadius: 1.0).fill(Color.primary.opacity(0.65)).frame(width: 2.2, height: 7)
                        }
                        .frame(width: 18, height: 16)
                    }
                }
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
