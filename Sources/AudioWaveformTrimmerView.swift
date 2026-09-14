import SwiftUI
import AppKit
import AVFoundation

// MARK: - Audio Trimmer Player Engine
public class AudioTrimmerPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var duration: Double = 0.0
    @Published public var waveformSamples: [CGFloat] = []
    
    private var player: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var activeStartTime: Double = 0.0
    private var activeEndTime: Double = 0.0
    
    public override init() {
        super.init()
    }
    
    public func loadAudio(url: URL) {
        stop()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            self.player = p
            self.duration = p.duration
            self.currentTime = 0.0
            self.extractWaveform(url: url)
        } catch {
            print("AudioTrimmerPlayer error: \(error.localizedDescription)")
            self.duration = 0.0
            self.waveformSamples = generateFallbackWaveform(sampleCount: 64)
        }
    }
    
    public func playSegment(start: Double, end: Double) {
        guard let p = player, duration > 0 else { return }
        stop()
        
        activeStartTime = max(0.0, min(start, duration))
        activeEndTime = min(duration, max(activeStartTime + 0.5, end))
        
        p.currentTime = activeStartTime
        currentTime = activeStartTime
        p.play()
        isPlaying = true
        
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] t in
            guard let self = self, let p = self.player else {
                t.invalidate()
                return
            }
            if p.isPlaying {
                self.currentTime = p.currentTime
                if self.currentTime >= self.activeEndTime {
                    self.stop()
                    self.currentTime = self.activeStartTime
                }
            } else {
                self.stop()
                self.currentTime = self.activeStartTime
            }
        }
        RunLoop.main.add(playbackTimer!, forMode: .common)
    }
    
    public func stop() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        player?.stop()
        isPlaying = false
    }
    
    public func togglePlay(start: Double, end: Double) {
        if isPlaying {
            stop()
            currentTime = start
        } else {
            playSegment(start: start, end: end)
        }
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
        currentTime = activeStartTime
    }
    
    // MARK: - Waveform Extraction
    private func extractWaveform(url: URL, sampleCount: Int = 64) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            guard let file = try? AVAudioFile(forReading: url) else {
                let fallback = self.generateFallbackWaveform(sampleCount: sampleCount)
                DispatchQueue.main.async { self.waveformSamples = fallback }
                return
            }
            
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(min(file.length, 44100 * 300))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                let fallback = self.generateFallbackWaveform(sampleCount: sampleCount)
                DispatchQueue.main.async { self.waveformSamples = fallback }
                return
            }
            
            do {
                try file.read(into: buffer)
                guard let floatData = buffer.floatChannelData?[0] else {
                    let fallback = self.generateFallbackWaveform(sampleCount: sampleCount)
                    DispatchQueue.main.async { self.waveformSamples = fallback }
                    return
                }
                
                let totalFrames = Int(buffer.frameLength)
                guard totalFrames > sampleCount else {
                    let fallback = self.generateFallbackWaveform(sampleCount: sampleCount)
                    DispatchQueue.main.async { self.waveformSamples = fallback }
                    return
                }
                
                let step = max(1, totalFrames / sampleCount)
                var bars: [CGFloat] = []
                
                for i in 0..<sampleCount {
                    let startFrame = i * step
                    let endFrame = min(startFrame + step, totalFrames)
                    var peak: Float = 0.0
                    let strideStep = max(1, step / 15)
                    for f in stride(from: startFrame, to: endFrame, by: strideStep) {
                        let val = abs(floatData[f])
                        if val > peak { peak = val }
                    }
                    let normalized = CGFloat(max(0.18, min(1.0, Double(peak) * 2.2)))
                    bars.append(normalized)
                }
                
                DispatchQueue.main.async {
                    self.waveformSamples = bars
                }
            } catch {
                let fallback = self.generateFallbackWaveform(sampleCount: sampleCount)
                DispatchQueue.main.async { self.waveformSamples = fallback }
            }
        }
    }
    
    private func generateFallbackWaveform(sampleCount: Int) -> [CGFloat] {
        return (0..<sampleCount).map { i in
            let phase = Double(i) / Double(sampleCount)
            let wave = sin(phase * .pi * 6) * 0.35 + sin(phase * .pi * 15) * 0.25 + 0.48
            return CGFloat(max(0.2, min(0.95, wave)))
        }
    }
}

// MARK: - Pocket TTS Style Audio Waveform & Cut Trimmer View
public struct AudioWaveformTrimmerView: View {
    @Binding public var startTime: Double
    @Binding public var endTime: Double
    @Binding public var isCutActive: Bool
    public let totalDuration: Double
    @ObservedObject public var player: AudioTrimmerPlayer
    
    @State private var dragInitialStart: Double = 0.0
    @State private var dragInitialEnd: Double = 0.0
    @State private var isDraggingBody: Bool = false
    @State private var isDraggingLeftHandle: Bool = false
    @State private var isDraggingRightHandle: Bool = false
    
    public init(
        startTime: Binding<Double>,
        endTime: Binding<Double>,
        isCutActive: Binding<Bool>,
        totalDuration: Double,
        player: AudioTrimmerPlayer
    ) {
        self._startTime = startTime
        self._endTime = endTime
        self._isCutActive = isCutActive
        self.totalDuration = totalDuration
        self.player = player
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Player Top Header Bar (Play/Pause, Time counter & Cut button)
            playerHeaderBar
            
            // Interactive Waveform Track with Cut Overlay
            waveformTrackView
            
            // Quick Duration Preset Chips & Guidance
            presetChipsAndGuidanceBar
        }
        .padding(10)
        .background(Color(red: 0.09, green: 0.10, blue: 0.13))
        .cornerRadius(7)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
    }
    
    // MARK: - Header Bar (Play/Pause & Cut Button)
    private var playerHeaderBar: some View {
        HStack(spacing: 10) {
            // Play/Pause Button
            Button(action: {
                let start = isCutActive ? startTime : 0.0
                let end = isCutActive ? endTime : max(1.0, totalDuration)
                player.togglePlay(start: start, end: end)
            }) {
                HStack(spacing: 5) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(player.isPlaying ? "Pause" : (isCutActive ? "Play Selected Area" : "Play Audio"))
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(player.isPlaying ? Color(red: 0.85, green: 0.35, blue: 0.25) : Color(red: 0.05, green: 0.48, blue: 0.95))
                .cornerRadius(5)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Time Readout
            HStack(spacing: 4) {
                if player.isPlaying {
                    Text(formatClock(player.currentTime))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("/")
                        .font(.system(size: 9.5))
                        .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                    Text(formatClock(isCutActive ? endTime : totalDuration))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                } else if isCutActive {
                    Text("Selected: \(formatClock(startTime)) – \(formatClock(endTime))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.20, green: 0.75, blue: 1.0))
                    Text("(\(String(format: "%.1fs", max(0.1, endTime - startTime))))")
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                } else {
                    Text("Full Track: \(formatClock(totalDuration))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                }
            }
            
            Spacer()
            
            // Pocket TTS Style ✂️ Cut Button
            Button(action: {
                isCutActive.toggle()
                if !isCutActive {
                    startTime = 0.0
                    endTime = max(1.0, totalDuration)
                } else {
                    let currentSpan = endTime - startTime
                    if currentSpan >= (totalDuration - 0.2) || endTime <= startTime {
                        if totalDuration > 15.0 {
                            startTime = 0.0
                            endTime = 15.0
                        } else if totalDuration > 4.0 {
                            startTime = 0.0
                            endTime = max(3.0, round(totalDuration * 0.70))
                        } else {
                            startTime = 0.0
                            endTime = totalDuration
                        }
                    }
                }
                if player.isPlaying { player.stop() }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "scissors")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(isCutActive ? "Cut Active" : "Cut")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(isCutActive ? .white : Color(red: 0.70, green: 0.72, blue: 0.80))
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background(isCutActive ? Color(red: 0.05, green: 0.48, blue: 0.95) : Color(red: 0.16, green: 0.17, blue: 0.22))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isCutActive ? Color(red: 0.35, green: 0.65, blue: 1.0) : Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .help("Toggle Pocket TTS Cut / Trim window on the audio track")
        }
    }
    
    // MARK: - Waveform Track with Cut Overlay
    private var waveformTrackView: some View {
        GeometryReader { geo in
            let total = max(0.5, totalDuration)
            let trackWidth = geo.size.width
            let trackHeight = geo.size.height
            
            let startFrac = max(0.0, min(1.0, startTime / total))
            let endFrac = max(startFrac, min(1.0, endTime / total))
            
            let leftX = startFrac * trackWidth
            let rightX = isCutActive ? max(leftX + 16, endFrac * trackWidth) : trackWidth
            let cutWidth = max(16, rightX - leftX)
            
            ZStack(alignment: .leading) {
                // Background Track Fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.06, green: 0.07, blue: 0.09))
                    .frame(height: trackHeight)
                
                // Waveform Bars Across Track
                HStack(alignment: .center, spacing: 2) {
                    let samples = player.waveformSamples.isEmpty ? defaultSampleBars : player.waveformSamples
                    ForEach(0..<samples.count, id: \.self) { idx in
                        let barFrac = CGFloat(idx) / CGFloat(samples.count)
                        let barX = barFrac * trackWidth
                        let inCut = !isCutActive || (barX >= leftX && barX <= rightX)
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(inCut ? Color(red: 0.15, green: 0.75, blue: 1.0) : Color.white.opacity(0.12))
                            .frame(
                                width: max(1.5, (trackWidth / CGFloat(samples.count)) - 2),
                                height: max(4.0, samples[idx] * (trackHeight - 14))
                            )
                    }
                }
                .frame(width: trackWidth, height: trackHeight)
                
                // Cut Highlight Overlay & Drag Handles
                if isCutActive {
                    // Left Dimming Curtain (dim outside of cut window)
                    if leftX > 0 {
                        Rectangle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: leftX, height: trackHeight)
                    }
                    
                    // Right Dimming Curtain (dim outside of cut window)
                    if rightX < trackWidth {
                        Rectangle()
                            .fill(Color.black.opacity(0.65))
                            .frame(width: max(0, trackWidth - rightX), height: trackHeight)
                            .offset(x: rightX)
                    }
                    
                    // 1. Shaded Selected Region (Draggable to pan cut window)
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.05, green: 0.50, blue: 1.0).opacity(0.22))
                        
                        // Top & Bottom guide borders
                        VStack {
                            Rectangle()
                                .fill(Color(red: 0.05, green: 0.55, blue: 1.0))
                                .frame(height: 2)
                            Spacer()
                            Rectangle()
                                .fill(Color(red: 0.05, green: 0.55, blue: 1.0))
                                .frame(height: 2)
                        }
                    }
                    .frame(width: cutWidth, height: trackHeight)
                    .offset(x: leftX)
                    .gesture(
                        DragGesture()
                            .onChanged { g in
                                if !isDraggingBody {
                                    isDraggingBody = true
                                    dragInitialStart = startTime
                                    dragInitialEnd = endTime
                                }
                                let windowLen = dragInitialEnd - dragInitialStart
                                let deltaSec = (Double(g.translation.width) / Double(trackWidth)) * total
                                let newStart = max(0.0, min(total - windowLen, dragInitialStart + deltaSec))
                                self.startTime = newStart
                                self.endTime = newStart + windowLen
                                if player.isPlaying { player.stop() }
                            }
                            .onEnded { _ in
                                isDraggingBody = false
                            }
                    )
                    
                    // 2. Left Drag Handle
                    handleView(isLeft: true)
                        .offset(x: max(0, leftX - 1))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    if !isDraggingLeftHandle {
                                        isDraggingLeftHandle = true
                                        dragInitialStart = startTime
                                    }
                                    let deltaSec = (Double(g.translation.width) / Double(trackWidth)) * total
                                    self.startTime = max(0.0, min(self.endTime - 1.0, dragInitialStart + deltaSec))
                                    if player.isPlaying { player.stop() }
                                }
                                .onEnded { _ in
                                    isDraggingLeftHandle = false
                                }
                        )
                    
                    // 3. Right Drag Handle
                    handleView(isLeft: false)
                        .offset(x: min(trackWidth - 14, rightX - 13))
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    if !isDraggingRightHandle {
                                        isDraggingRightHandle = true
                                        dragInitialEnd = endTime
                                    }
                                    let deltaSec = (Double(g.translation.width) / Double(trackWidth)) * total
                                    self.endTime = max(self.startTime + 1.0, min(total, dragInitialEnd + deltaSec))
                                    if player.isPlaying { player.stop() }
                                }
                                .onEnded { _ in
                                    isDraggingRightHandle = false
                                }
                        )
                }
                
                // Real-time Playhead Indicator
                if player.isPlaying {
                    let playFrac = max(0.0, min(1.0, player.currentTime / total))
                    let playX = playFrac * trackWidth
                    
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2, height: trackHeight)
                        .shadow(color: Color.white.opacity(0.8), radius: 2)
                        .offset(x: playX)
                }
            }
            .frame(width: trackWidth, height: trackHeight)
            .clipped()
        }
        .frame(height: 52)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.18, green: 0.20, blue: 0.26), lineWidth: 1)
        )
    }
    
    // MARK: - Handle Grip View
    private func handleView(isLeft: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: 0.05, green: 0.50, blue: 1.0))
                .frame(width: 14, height: 52)
            
            VStack(spacing: 2.5) {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.white)
                    .frame(width: 2, height: 12)
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(Color.white)
                    .frame(width: 2, height: 12)
            }
        }
        .frame(width: 14, height: 52)
        .shadow(color: Color.black.opacity(0.5), radius: 2)
    }
    
    // MARK: - Preset Chips & Guidance Bar
    private var presetChipsAndGuidanceBar: some View {
        HStack(spacing: 6) {
            Text("Cut Length:")
                .font(.system(size: 9.5, weight: .medium))
                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
            
            presetPill(label: "10s", seconds: 10.0)
            presetPill(label: "15s • Optimal", seconds: 15.0)
            presetPill(label: "20s", seconds: 20.0)
            presetPill(label: "30s", seconds: 30.0)
            presetPill(label: "Full Track", seconds: totalDuration)
            
            Spacer()
            
            Text("✂️ Only overlay plays & clones")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
        }
        .padding(.top, 2)
    }
    
    private func presetPill(label: String, seconds: Double) -> some View {
        let currentLen = endTime - startTime
        let isSelected = isCutActive && abs(currentLen - seconds) < 0.5
        
        return Button(action: {
            if seconds >= totalDuration {
                isCutActive = false
                startTime = 0.0
                endTime = totalDuration
            } else {
                isCutActive = true
                let target = min(totalDuration, seconds)
                if startTime + target <= totalDuration {
                    endTime = startTime + target
                } else {
                    startTime = max(0.0, totalDuration - target)
                    endTime = totalDuration
                }
            }
            if player.isPlaying { player.stop() }
        }) {
            Text(label)
                .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color(red: 0.55, green: 0.56, blue: 0.62))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(isSelected ? Color(red: 0.16, green: 0.18, blue: 0.24) : Color(red: 0.12, green: 0.13, blue: 0.17))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color(red: 0.05, green: 0.48, blue: 0.95) : Color(red: 0.20, green: 0.22, blue: 0.28), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var defaultSampleBars: [CGFloat] {
        return [
            0.3, 0.4, 0.6, 0.5, 0.8, 0.9, 0.7, 0.4, 0.5, 0.7, 0.85, 0.95, 0.6, 0.3,
            0.25, 0.45, 0.7, 0.8, 0.65, 0.5, 0.75, 0.9, 0.8, 0.55, 0.35, 0.2, 0.4,
            0.6, 0.75, 0.85, 0.7, 0.5, 0.65, 0.8, 0.9, 0.85, 0.6, 0.4, 0.3, 0.5,
            0.7, 0.85, 0.9, 0.75, 0.6, 0.45, 0.3, 0.25, 0.5, 0.7, 0.8, 0.65, 0.4
        ]
    }
    
    private func formatClock(_ sec: Double) -> String {
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
