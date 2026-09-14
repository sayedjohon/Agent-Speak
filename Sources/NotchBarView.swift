import SwiftUI
import Cocoa

// MARK: - Pointy-Top Notch Bar View
struct PointyTopNotchBarView: View {
    @ObservedObject var state: StreamingAudioManager
    let hasNotch: Bool
    
    let notchWidth: CGFloat = 185.0
    let barHeight: CGFloat = 30.0
    
    var topRadius: CGFloat { hasNotch ? 0 : 10 }
    var bottomRadius: CGFloat { 10 }
    
    var body: some View {
        HStack(spacing: 5) {
            // Play / Pause
            Button(action: { state.togglePlayPause() }) {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            
            // Skip Back (Configurable Step)
            Button(action: { state.skip(seconds: -Double(state.skipSeconds)) }) {
                Image(systemName: "gobackward.\(state.skipSeconds)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            
            // Liquid Scrubber
            GeometryReader { geo in
                let w = geo.size.width
                let progress = state.globalTotalDuration > 0 ? CGFloat(state.globalCurrentTime / state.globalTotalDuration) : 0
                let clamped = max(0, min(1, progress))
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(3, w * clamped), height: 3)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7.5, height: 7.5)
                        .shadow(color: Color.black.opacity(0.4), radius: 1.5, x: 0, y: 1)
                        .offset(x: max(0, min(w - 7.5, w * clamped - 3.75)))
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            state.isDragging = true
                            let ratio = max(0, min(1, value.location.x / w))
                            state.globalCurrentTime = Double(ratio) * state.globalTotalDuration
                        }
                        .onEnded { value in
                            let ratio = max(0, min(1, value.location.x / w))
                            let target = Double(ratio) * state.globalTotalDuration
                            state.seek(to: target)
                            state.isDragging = false
                        }
                )
            }
            .frame(height: 12)
            
            // Skip Forward (Configurable Step)
            Button(action: { state.skip(seconds: Double(state.skipSeconds)) }) {
                Image(systemName: "goforward.\(state.skipSeconds)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            
            // Close Button
            Button(action: { state.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 4)
        .frame(width: notchWidth, height: barHeight)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: topRadius, bottomLeadingRadius: bottomRadius, bottomTrailingRadius: bottomRadius, topTrailingRadius: topRadius)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: topRadius, bottomLeadingRadius: bottomRadius, bottomTrailingRadius: bottomRadius, topTrailingRadius: topRadius)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.65)
        )
        .shadow(color: Color.black.opacity(0.40), radius: 10, x: 0, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Floating Full-Screen Holographic Jarvis Arc Reactor
struct FloatingJarvisHologramOverlayView: View {
    @ObservedObject var state: StreamingAudioManager
    @ObservedObject var meter = JarvisAudioLevelMeter.shared
    
    let reactorSize: CGFloat = 480.0
    
    init(state: StreamingAudioManager) {
        self.state = state
    }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let energy = state.isPlaying ? meter.level : 0.0
            
            ZStack(alignment: .center) {
                // Invisible click-through container
                Color.clear
                
                // 1. Ambient Scene Wave Glow (Radiates across the room/screen when speaking)
                if state.isPlaying {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                        let now = timeline.date.timeIntervalSinceReferenceDate
                        let pulse = sin(now * 2.6) * 0.5 + 0.5
                        let waveRadius: CGFloat = 460.0 + CGFloat(pulse) * 45.0 + CGFloat(energy) * 80.0
                        let rippleProgress = CGFloat((now.truncatingRemainder(dividingBy: 2.2)) / 2.2)
                        
                        ZStack {
                            // Soft atmospheric warm amber room illumination
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.60, blue: 0.12).opacity(0.18 + Double(energy) * 0.20),
                                            Color(red: 0.95, green: 0.30, blue: 0.02).opacity(0.08 + Double(energy) * 0.10),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 30,
                                        endRadius: waveRadius
                                    )
                                )
                                .frame(width: waveRadius * 2, height: waveRadius * 2)
                                .blur(radius: 60)
                                .blendMode(.plusLighter)
                            
                            // Outward propagating harmonic ripple wave ring
                            Circle()
                                .stroke(
                                    Color(red: 1.0, green: 0.72, blue: 0.25).opacity((1.0 - Double(rippleProgress)) * (0.28 + Double(energy) * 0.30)),
                                    lineWidth: 1.8
                                )
                                .frame(width: 240 + rippleProgress * 440, height: 240 + rippleProgress * 440)
                                .blur(radius: 2.5)
                                .blendMode(.plusLighter)
                        }
                        // Center ambient glow precisely behind the reactor
                        .position(x: w / 2.0, y: h * 0.36)
                    }
                }
                
                // 2. Large Tony Stark Holographic Arc Reactor (100% Opacity + Dual Bloom Glow)
                ZStack {
                    // Layer A: Intense Bloom Glow Pass
                    JarvisOrbVisualizerView(
                        isSpeaking: state.isPlaying,
                        isPlayingMusic: BackgroundMusicManager.shared.isPlaying,
                        size: reactorSize
                    )
                    .blur(radius: 16)
                    .opacity(state.isPlaying ? 0.95 : 0.40)
                    .blendMode(.plusLighter)
                    
                    // Layer B: Crisp 100% Opacity Hologram Pass
                    JarvisOrbVisualizerView(
                        isSpeaking: state.isPlaying,
                        isPlayingMusic: BackgroundMusicManager.shared.isPlaying,
                        size: reactorSize
                    )
                    .blendMode(.plusLighter)
                }
                .frame(width: reactorSize, height: reactorSize)
                // Position in the upper-middle of the screen, floating right below notch
                .position(x: w / 2.0, y: h * 0.36)
            }
            .frame(width: w, height: h)
            .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}


