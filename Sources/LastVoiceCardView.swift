import SwiftUI
import AppKit

public struct LastVoiceCardView: View {
    @ObservedObject private var manager = LastVoiceManager.shared
    @State private var isDragging: Bool = false
    @State private var dragTime: Double = 0.0
    @State private var isHovered: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row
            HStack(spacing: 6) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cyan)
                
                Text("RECENT AUDIO EXPORT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if manager.hasVoice && !manager.isSynthesizing {
                    Text(formatTime(manager.totalDuration))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                }
            }
            
            if manager.isSynthesizing {
                // Synthesizing Loading State
                HStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                    Text("Preparing voice audio...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            } else if manager.hasVoice {
                // Voice Text Snippet
                if !manager.textPrompt.isEmpty {
                    Text("“\(manager.textPrompt)”")
                        .font(.system(size: 11, weight: .regular))
                        .italic()
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.2))
                        .cornerRadius(6)
                }
                
                // Audio Scrubber / Scrollbar & Playback Controls
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        // Play / Pause Button
                        Button(action: {
                            manager.togglePlayPause()
                        }) {
                            Image(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                        
                        // Current Time
                        Text(formatTime(isDragging ? dragTime : manager.currentTime))
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .leading)
                        
                        // Interactive Timeline Scrubber (Scrollbar)
                        GeometryReader { geometry in
                            let totalWidth = max(10, geometry.size.width)
                            let currentProgress = manager.totalDuration > 0
                                ? (isDragging ? dragTime : manager.currentTime) / manager.totalDuration
                                : 0.0
                            let progressWidth = max(0.0, min(totalWidth, CGFloat(currentProgress) * totalWidth))
                            
                            ZStack(alignment: .leading) {
                                // Background Track
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: isHovered || isDragging ? 8 : 6)
                                
                                // Progress Active Track
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: progressWidth, height: isHovered || isDragging ? 8 : 6)
                                
                                // Scrubber Thumb Handle
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: isHovered || isDragging ? 13 : 10, height: isHovered || isDragging ? 13 : 10)
                                    .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
                                    .offset(x: max(0, min(totalWidth - (isHovered || isDragging ? 13 : 10), progressWidth - ((isHovered || isDragging ? 13 : 10) / 2))))
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        isDragging = true
                                        let fraction = max(0.0, min(1.0, Double(value.location.x / totalWidth)))
                                        dragTime = fraction * manager.totalDuration
                                    }
                                    .onEnded { value in
                                        let fraction = max(0.0, min(1.0, Double(value.location.x / totalWidth)))
                                        let finalTime = fraction * manager.totalDuration
                                        manager.seek(to: finalTime)
                                        isDragging = false
                                    }
                            )
                        }
                        .frame(height: 18)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isHovered = hovering
                            }
                        }
                        
                        // Total Duration
                        Text(formatTime(manager.totalDuration))
                            .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                    
                    // Action Buttons Row (Download & Save As)
                    HStack(spacing: 8) {
                        // 1-Click Download Button
                        Button(action: {
                            manager.downloadAudio()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 11))
                                Text("Download Audio (.m4a)")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // Custom Destination (Save As...)
                        Button(action: {
                            manager.exportWithSavePanel()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 10))
                                Text("Save As...")
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.04))
                            .foregroundColor(.secondary)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        // Status Notification Toast
                        if let status = manager.downloadStatusMessage {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 11))
                                Text(status)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.top, 4)
                }
            } else {
                // Empty State Placeholder
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Generated speech audio will appear here with an interactive player and download option.")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.vertical, 4)
            }
        }
        .padding(11)
        .background(Color.white.opacity(0.03))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let s = Int(seconds)
        let mins = s / 60
        let secs = s % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
