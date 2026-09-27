import SwiftUI
import AppKit

public struct LastVoiceCardView: View {
    @ObservedObject private var manager = LastVoiceManager.shared
    @State private var isDragging: Bool = false
    @State private var dragTime: Double = 0.0
    @State private var isHovered: Bool = false
    
    public init() {}
    
    public var body: some View {
        if manager.hasVoice || manager.isSynthesizing {
            VStack(alignment: .leading, spacing: 10) {
                // Header Row
                HStack(spacing: 6) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                    
                    Text("RECENT AUDIO PREVIEW")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if manager.hasVoice && !manager.isSynthesizing {
                        Text(formatTime(manager.totalDuration))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .quaternaryLabelColor))
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
                            .font(.system(size: 11.5, weight: .regular))
                            .italic()
                            .foregroundColor(.primary.opacity(0.85))
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.5))
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
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            
                            // Current Time
                            Text(formatTime(isDragging ? dragTime : manager.currentTime))
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            // Native-like Slider
                            Slider(
                                value: Binding(
                                    get: { isDragging ? dragTime : manager.currentTime },
                                    set: { newTime in
                                        dragTime = newTime
                                        if !isDragging {
                                            manager.seek(to: newTime)
                                        }
                                    }
                                ),
                                in: 0...max(0.1, manager.totalDuration),
                                onEditingChanged: { editing in
                                    isDragging = editing
                                    if !editing {
                                        manager.seek(to: dragTime)
                                    }
                                }
                            )
                            
                            // Total Duration
                            Text(formatTime(manager.totalDuration))
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        // Action Bar: Copy Audio & Save to Downloads
                        HStack(spacing: 10) {
                            Spacer()
                            
                            Button(action: {
                                manager.copyAudioFileToClipboard()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                    Text("Copy Audio")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4.5)
                                .background(Color(nsColor: .quaternaryLabelColor))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                manager.exportWithSavePanel()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 10))
                                    Text("Export M4A")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4.5)
                                .background(Color(nsColor: .quaternaryLabelColor))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
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
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "00:00" }
        let s = Int(seconds)
        let mins = s / 60
        let secs = s % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
