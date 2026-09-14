import SwiftUI
import AppKit

// MARK: - Raycast-grade Voice Cloning Studio
public struct VoiceCloningStudioView: View {
    @ObservedObject var manager = PocketTTSManager.shared
    @Binding var isPresented: Bool
    var onVoiceSaved: (String) -> Void
    
    @State private var showingGuideSheet = false
    @State private var newVoiceName = ""
    @State private var selectedAudioPath = ""
    @State private var testSentence = "This is a viral and proven voice  currently used by hundreds successful of youtube channels. so Do you like this voice? "
    @State private var hasAuditioned = false
    @State private var auditionDuration: Double = 0.0
    
    // Audio Trimming & Auto-Detection State
    @State private var audioDuration: Double = 0.0
    @State private var autoDetectSpeech: Bool = true
    @State private var trimStartTime: Double = 0.0
    @State private var trimDuration: Double = 15.0
    @State private var isPlayingSource: Bool = false
    @State private var detectedSpeechInfo: String = ""
    @State private var isHoveringDropzone: Bool = false
    
    public init(isPresented: Binding<Bool>, onVoiceSaved: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.onVoiceSaved = onVoiceSaved
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Bar
            headerBar
            
            // Helpful Guide Banner
            guideBanner
            
            // 1. Voice Persona Name Input
            voiceNameInputSection
            
            // 2. Reference Audio File Card / Dropzone
            audioFileSection
            
            // 3. Speech Trimming & Segment Selector (Active when file loaded)
            if !selectedAudioPath.isEmpty {
                segmentTrimmingSection
            }
            
            // 4. Test Verification Script
            testScriptSection
            
            // 5. Action Buttons Bar
            actionButtonsBar
            
            // Status Feedback
            statusFeedbackView
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1)
        )
        .sheet(isPresented: $showingGuideSheet) {
            CloningGuideModalView(
                isPresented: $showingGuideSheet,
                onUnlockHuggingFace: {
                    manager.unlockZeroShotCloning()
                }
            )
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text("VOICE CLONING & AUDITION STUDIO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
            }
            
            Button(action: { showingGuideSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 9.5))
                    Text("Guide")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                .cornerRadius(5)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1))
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            Button(action: { manager.unlockZeroShotCloning() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 9.5))
                    Text("HuggingFace License")
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Guide Banner
    private var guideBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)
            Text("Select 10–30s of clean speech, audition your test sentence, and save only when satisfied.")
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(red: 0.14, green: 0.15, blue: 0.19))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.20, green: 0.22, blue: 0.28), lineWidth: 1))
    }
    
    // MARK: - 1. Voice Persona Name Input
    private var voiceNameInputSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Voice Persona Name")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                
                TextField("e.g. Jarvis, Samantha, Morgan", text: $newVoiceName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 11.5))
                    .foregroundColor(.white)
                
                if !newVoiceName.isEmpty {
                    Button(action: { newVoiceName = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(red: 0.09, green: 0.10, blue: 0.13))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
        }
    }
    
    // MARK: - 2. Reference Audio File Card
    private var audioFileSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Reference Speech Audio")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            
            if selectedAudioPath.isEmpty {
                // Empty State Dropzone
                Button(action: pickAudioFile) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.16, green: 0.18, blue: 0.24))
                                .frame(width: 34, height: 34)
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.65, green: 0.67, blue: 0.74))
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Select Reference Audio (.wav or .mp3)")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.white)
                            Text("Click to choose a clean audio recording • 10–30 seconds optimal")
                                .font(.system(size: 9.5))
                                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                        }
                        
                        Spacer()
                        
                        Text("Browse...")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1))
                    }
                    .padding(10)
                    .background(isHoveringDropzone ? Color(red: 0.14, green: 0.16, blue: 0.22) : Color(red: 0.09, green: 0.10, blue: 0.13))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isHoveringDropzone ? Color(red: 0.05, green: 0.48, blue: 0.95) : Color(red: 0.18, green: 0.19, blue: 0.24), style: StrokeStyle(lineWidth: 1, dash: isHoveringDropzone ? [] : [5]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onDrop(of: ["public.file-url"], isTargeted: $isHoveringDropzone) { providers in
                    handleDrop(providers: providers)
                }
            } else {
                // Loaded State Card
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(red: 0.16, green: 0.18, blue: 0.24))
                            .frame(width: 34, height: 34)
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.05, green: 0.48, blue: 0.95))
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text((selectedAudioPath as NSString).lastPathComponent)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        HStack(spacing: 6) {
                            if audioDuration > 0 {
                                Text(formatDuration(audioDuration))
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                                    .cornerRadius(3)
                            }
                            
                            let ext = (selectedAudioPath as NSString).pathExtension.uppercased()
                            Text(ext.isEmpty ? "AUDIO" : ext)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(3)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: pickAudioFile) {
                        Text("Change")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        selectedAudioPath = ""
                        audioDuration = 0.0
                        detectedSpeechInfo = ""
                        hasAuditioned = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Remove audio file")
                }
                .padding(9)
                .background(Color(red: 0.09, green: 0.10, blue: 0.13))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
            }
        }
    }
    
    // MARK: - 3. Trimming & Segment Selector
    private var segmentTrimmingSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Header
            HStack {
                Text("SPEECH REFERENCE EXTRACTION")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                
                Spacer()
                
                if !detectedSpeechInfo.isEmpty {
                    Text(detectedSpeechInfo)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                }
            }
            
            // Dual Selection Buttons: Auto-Detect vs Custom Range
            HStack(spacing: 8) {
                // Button 1: Auto-Detect
                Button(action: { autoDetectSpeech = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(autoDetectSpeech ? .yellow : Color(red: 0.55, green: 0.56, blue: 0.62))
                        Text("Auto-Detect Best Speech")
                            .font(.system(size: 10.5, weight: .semibold))
                        if autoDetectSpeech {
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(red: 0.05, green: 0.50, blue: 1.0))
                        }
                    }
                    .foregroundColor(autoDetectSpeech ? .white : Color(red: 0.55, green: 0.56, blue: 0.62))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(autoDetectSpeech ? Color(red: 0.14, green: 0.16, blue: 0.22) : Color(red: 0.09, green: 0.10, blue: 0.13))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(autoDetectSpeech ? Color(red: 0.05, green: 0.48, blue: 0.95) : Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // Button 2: Custom Range
                Button(action: { autoDetectSpeech = false }) {
                    HStack(spacing: 6) {
                        Image(systemName: "scissors")
                            .font(.system(size: 10))
                            .foregroundColor(!autoDetectSpeech ? Color(red: 0.05, green: 0.50, blue: 1.0) : Color(red: 0.55, green: 0.56, blue: 0.62))
                        Text("Custom Range")
                            .font(.system(size: 10.5, weight: .semibold))
                        if !autoDetectSpeech {
                            Spacer()
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(red: 0.05, green: 0.50, blue: 1.0))
                        }
                    }
                    .foregroundColor(!autoDetectSpeech ? .white : Color(red: 0.55, green: 0.56, blue: 0.62))
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                    .background(!autoDetectSpeech ? Color(red: 0.14, green: 0.16, blue: 0.22) : Color(red: 0.09, green: 0.10, blue: 0.13))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(!autoDetectSpeech ? Color(red: 0.05, green: 0.48, blue: 0.95) : Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Caption hint
            Text(autoDetectSpeech
                 ? "⚡ AI automatically finds the clearest speech segment without silent pauses."
                 : "✂️ Drag the slider below to select your reference speech window."
            )
            .font(.system(size: 9.5))
            .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
            
            Divider().background(Color.white.opacity(0.04))
            
            // Duration Selector Chips
            HStack(spacing: 6) {
                Text("Segment Length:")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                
                durationPill(label: "10s", value: 10.0)
                durationPill(label: "15s • Optimal", value: 15.0)
                durationPill(label: "20s", value: 20.0)
                durationPill(label: "25s", value: 25.0)
                
                Spacer()
            }
            
            // Precision Scrubber Slider (in Custom Range mode)
            if !autoDetectSpeech && audioDuration > 5.0 {
                HStack(spacing: 8) {
                    Text("Start: \(formatSeconds(trimStartTime))")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1))
                    
                    Slider(
                        value: $trimStartTime,
                        in: 0...max(0.1, audioDuration - trimDuration),
                        step: 1.0
                    )
                    .accentColor(Color(red: 0.05, green: 0.48, blue: 0.95))
                    
                    let endTime = min(audioDuration, trimStartTime + trimDuration)
                    Text("End: \(formatSeconds(endTime))")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.14, green: 0.15, blue: 0.19))
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.20, green: 0.22, blue: 0.28), lineWidth: 1))
                }
                .padding(.top, 2)
            }
            
            // Audio Reference Preview Button (Fixed Height, Sleek Bar)
            HStack {
                Button(action: playSourceSegmentPreview) {
                    HStack(spacing: 6) {
                        Image(systemName: isPlayingSource ? "waveform" : "speaker.wave.2.fill")
                            .font(.system(size: 11))
                        Text(isPlayingSource ? "Playing Reference Clip..." : "▶ Listen to Reference Clip (\(Int(trimDuration))s)")
                            .font(.system(size: 9.5, weight: .semibold))
                    }
                    .foregroundColor(isPlayingSource ? .white : Color(red: 0.05, green: 0.48, blue: 0.95))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isPlayingSource)
                
                Spacer()
            }
        }
        .padding(10)
        .background(Color(red: 0.09, green: 0.10, blue: 0.13))
        .cornerRadius(7)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
    }
    
    // MARK: - Duration Pill Component
    private func durationPill(label: String, value: Double) -> some View {
        let isSelected = (trimDuration == value)
        return Button(action: {
            trimDuration = value
            if trimStartTime > max(0.0, audioDuration - trimDuration) {
                trimStartTime = max(0.0, audioDuration - trimDuration)
            }
        }) {
            Text(label)
                .font(.system(size: 9, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color(red: 0.55, green: 0.56, blue: 0.62))
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(isSelected ? Color(red: 0.16, green: 0.18, blue: 0.24) : Color(red: 0.12, green: 0.13, blue: 0.17))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color(red: 0.05, green: 0.48, blue: 0.95) : Color(red: 0.20, green: 0.22, blue: 0.28), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 4. Test Verification Script
    private var testScriptSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Test Script to Verify Voice Quality")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
            
            TextField("Enter test sentence to audition...", text: $testSentence)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 11.5))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(red: 0.09, green: 0.10, blue: 0.13))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
        }
    }
    
    // MARK: - 5. Action Buttons Bar
    private var actionButtonsBar: some View {
        HStack(spacing: 10) {
            // Audition Preview Button
            Button(action: auditionVoiceSample) {
                HStack(spacing: 6) {
                    if manager.isCloning {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 11))
                    }
                    Text(manager.isCloning ? "Synthesizing Preview..." : "Audition Preview")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(red: 0.25, green: 0.27, blue: 0.35), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(selectedAudioPath.isEmpty || manager.isCloning)
            
            if manager.isCloning || SpeechQueueManager.shared.isSpeaking {
                Button(action: {
                    SpeechQueueManager.shared.stopCurrent()
                    let killProc = Process()
                    killProc.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
                    killProc.arguments = ["afplay"]
                    try? killProc.run()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                        Text("Stop")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Color.red)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Save & Activate Button (Only after auditioning)
            if hasAuditioned {
                Button(action: saveAuditionedVoice) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                        Text("Save & Activate Voice")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 30)
                    .background(Color(red: 0.05, green: 0.48, blue: 0.95))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.25, green: 0.55, blue: 1.0).opacity(0.8), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newVoiceName.isEmpty || manager.isCloning)
            }
            
            // Cancel Button
            Button(action: {
                isPresented = false
                hasAuditioned = false
            }) {
                Text("Cancel")
                    .font(.system(size: 11))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                    .padding(.horizontal, 10)
                    .frame(height: 30)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
    }
    
    // MARK: - Status Feedback
    @ViewBuilder
    private var statusFeedbackView: some View {
        if manager.isCloning {
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.6)
                Text(manager.cloneMessage)
                    .font(.system(size: 10))
                    .foregroundColor(.yellow)
            }
        } else if !manager.cloneMessage.isEmpty {
            Text(manager.cloneMessage)
                .font(.system(size: 10))
                .foregroundColor(hasAuditioned ? Color(red: 0.05, green: 0.50, blue: 1.0) : .green)
        }
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        if m > 0 {
            return "\(m)m \(s)s"
        }
        return String(format: "%.1fs", seconds)
    }
    
    private func formatSeconds(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func loadFile(url: URL) {
        self.selectedAudioPath = url.path
        self.hasAuditioned = false
        if newVoiceName.isEmpty {
            self.newVoiceName = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: " ", with: "_")
        }
        
        manager.getAudioFileInfo(audioPath: url.path, targetDuration: trimDuration) { dur, autoStart, _ in
            self.audioDuration = dur
            self.trimStartTime = autoStart
            if dur > 0 {
                let mins = Int(dur) / 60
                let secs = Int(dur) % 60
                self.detectedSpeechInfo = "\(mins)m \(secs)s total • Peak speech at \(Int(autoStart))s"
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
            if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                DispatchQueue.main.async { self.loadFile(url: url) }
            } else if let url = item as? URL {
                DispatchQueue.main.async { self.loadFile(url: url) }
            }
        }
        return true
    }
    
    private func pickAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .wav, .mp3]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            loadFile(url: url)
        }
    }
    
    private func playSourceSegmentPreview() {
        guard !selectedAudioPath.isEmpty else { return }
        isPlayingSource = true
        manager.playSourceSegment(
            audioPath: selectedAudioPath,
            startTime: trimStartTime,
            duration: trimDuration,
            autoTrim: autoDetectSpeech
        ) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + trimDuration) {
                self.isPlayingSource = false
            }
        }
    }
    
    private func auditionVoiceSample() {
        guard !selectedAudioPath.isEmpty else { return }
        let textToTest = testSentence.isEmpty ? "This is a viral and proven voice  currently used by hundreds successful of youtube channels. so Do you like this voice? " : testSentence
        manager.auditionVoice(
            audioPath: selectedAudioPath,
            text: textToTest,
            startTime: trimStartTime,
            duration: trimDuration,
            autoTrim: autoDetectSpeech
        ) { success, _, dur in
            if success {
                self.hasAuditioned = true
                self.auditionDuration = dur
            }
        }
    }
    
    private func saveAuditionedVoice() {
        guard !newVoiceName.isEmpty, !selectedAudioPath.isEmpty else { return }
        let targetName = newVoiceName
        manager.cloneVoice(
            name: targetName,
            audioPath: selectedAudioPath,
            startTime: trimStartTime,
            duration: trimDuration,
            autoTrim: autoDetectSpeech
        ) { success, _ in
            if success {
                self.onVoiceSaved(targetName)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.isPresented = false
                    self.hasAuditioned = false
                    self.newVoiceName = ""
                    self.selectedAudioPath = ""
                }
            }
        }
    }
}
