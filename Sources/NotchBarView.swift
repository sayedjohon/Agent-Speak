import SwiftUI
import Cocoa

// MARK: - Pointy-Top Notch Bar View
struct PointyTopNotchBarView: View {
    @ObservedObject var state: StreamingAudioManager
    let hasNotch: Bool
    
    let notchWidth: CGFloat = 212.0
    let barHeight: CGFloat = 30.0
    
    var topRadius: CGFloat { hasNotch ? 0 : 10 }
    var bottomRadius: CGFloat { 10 }
    
    var body: some View {
        HStack(spacing: 5) {
            // Mini Jarvis Hologram Arc Reactor Orb
            JarvisOrbVisualizerView(
                isSpeaking: state.isPlaying,
                isPlayingMusic: BackgroundMusicManager.shared.isPlaying,
                size: 20
            )
            .frame(width: 20, height: 20)
            
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
