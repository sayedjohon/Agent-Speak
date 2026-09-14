import SwiftUI
import AppKit
import AVFoundation
import CoreMedia

// MARK: - Dedicated Apple Pro Voice Cloning Studio Sheet
public struct VoiceCloningStudioSheet: View {
    @ObservedObject var manager = PocketTTSManager.shared
    @Binding var isPresented: Bool
    var onVoiceSaved: (String) -> Void
    
    @State private var showingGuideSheet = false
    @State private var newVoiceName = ""
    @State private var selectedAudioPath = ""
    @State private var testSentence = "Here is a quick demo of your new cloned voice. Pacing, tone, and inflection are synthesized on-device with zero cloud latency."
    @State private var hasAuditioned = false
    @State private var auditionDuration: Double = 0.0
    
    // Audio Trimming State
    @StateObject private var trimmerPlayer = AudioTrimmerPlayer()
    @State private var audioDuration: Double = 0.0
    @State private var trimStartTime: Double = 0.0
    @State private var trimEndTime: Double = 15.0
    @State private var isCutActive: Bool = true
    @State private var isHoveringDropzone: Bool = false
    
    private let promptPresets: [(title: String, prompt: String)] = [
        ("Tech Explainer", "Here is what happened: instead of querying the disk every cycle, we cached the response in memory. Speed improved instantly."),
        ("Friendly Assistant", "I've finished analyzing your project. Everything looks clean, all tests are passing, and we're ready to ship."),
        ("Casual Banter", "Quick heads up—the build finished in under five seconds. Want to run the integration suite, or call it a day?"),
        ("Code Review", "The race condition occurred because the worker thread mutated state before acquiring the database lock.")
    ]
    
    public init(isPresented: Binding<Bool>, onVoiceSaved: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.onVoiceSaved = onVoiceSaved
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            modalHeaderBar
            
            Divider().background(Color(nsColor: .separatorColor))
            
            // Scrollable Studio Workspace
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // Step 1: Voice Persona Name
                    voiceNameSection
                    
                    // Step 2: Reference Audio File Card
                    audioFileSection
                    
                    // Step 3: Waveform Trimmer (only if file loaded)
                    if !selectedAudioPath.isEmpty {
                        segmentTrimmingSection
                    }
                    
                    // Step 4: Multi-Line Audition Prompter
                    auditionScriptSection
                    
                    // Status Feedback Bar
                    statusFeedbackView
                }
                .padding(20)
            }
            
            Divider().background(Color(nsColor: .separatorColor))
            
            // Modal Action Footer
            modalFooterBar
        }
        .frame(width: 640, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            trimmerPlayer.stop()
        }
        .sheet(isPresented: $showingGuideSheet) {
            CloningGuideModalView(
                isPresented: $showingGuideSheet,
                onUnlockHuggingFace: {
                    manager.unlockZeroShotCloning()
                }
            )
        }
    }
    
    // MARK: - Modal Header Bar
    private var modalHeaderBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice Studio & Zero-Shot Cloner")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(nsColor: .labelColor))
                Text("Clone any custom voice from a clean 10–30 second audio sample")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
            
            Spacer()
            
            Button(action: { showingGuideSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11))
                    Text("Guide")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                trimmerPlayer.stop()
                isPresented = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }
    
    // MARK: - Step 1: Voice Persona Name
    private var voiceNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("1. Persona Name")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                Spacer()
                Text("Alphanumeric & underscores")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 13))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                
                TextField("e.g. Jarvis_Pro, Samantha_Studio, Tech_Host", text: $newVoiceName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !newVoiceName.isEmpty {
                    Button(action: { newVoiceName = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Step 2: Reference Audio File
    private var audioFileSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("2. Reference Audio Sample")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            
            if selectedAudioPath.isEmpty {
                // Dropzone
                Button(action: pickAudioFile) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 36, height: 36)
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.accentColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Select Clean Voice Recording (.wav or .mp3)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(nsColor: .labelColor))
                            Text("Click to browse or drag & drop • 10–30 seconds recommended")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        }
                        
                        Spacer()
                        
                        Text("Browse...")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )
                    }
                    .padding(12)
                    .background(isHoveringDropzone ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.7))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isHoveringDropzone ? Color.accentColor : Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: isHoveringDropzone ? [] : [4]))
                    )
                }
                .buttonStyle(.plain)
                .onDrop(of: ["public.file-url"], isTargeted: $isHoveringDropzone) { providers in
                    handleDrop(providers: providers)
                }
            } else {
                // Loaded File Card
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: "waveform")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.accentColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text((selectedAudioPath as NSString).lastPathComponent)
                            .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(nsColor: .labelColor))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        HStack(spacing: 6) {
                            if audioDuration > 0 {
                                Text(formatDuration(audioDuration))
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.white.opacity(0.08))
                                    .cornerRadius(3)
                            }
                            let ext = (selectedAudioPath as NSString).pathExtension.uppercased()
                            Text(ext.isEmpty ? "AUDIO" : ext)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(3)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: pickAudioFile) {
                        Text("Change")
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        trimmerPlayer.stop()
                        selectedAudioPath = ""
                        audioDuration = 0.0
                        trimStartTime = 0.0
                        trimEndTime = 0.0
                        hasAuditioned = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
        }
    }
    
    // MARK: - Step 3: Waveform Trimmer
    private var segmentTrimmingSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("3. Speech Trimmer & Window Crop")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                Spacer()
                Text("Select cleanest 10–20s segment")
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
            }
            
            AudioWaveformTrimmerView(
                startTime: $trimStartTime,
                endTime: $trimEndTime,
                isCutActive: $isCutActive,
                totalDuration: audioDuration,
                player: trimmerPlayer
            )
        }
    }
    
    // MARK: - Step 4: Multi-Line Audition Prompter
    private var auditionScriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("4. Audition Test Script")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                Spacer()
                Text("\(testSentence.count) / 280 chars")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(testSentence.count > 260 ? .orange : Color(nsColor: .secondaryLabelColor))
            }
            
            // Preset Prompt Chips
            HStack(spacing: 6) {
                ForEach(promptPresets, id: \.title) { item in
                    Button(action: { testSentence = item.prompt }) {
                        Text(item.title)
                            .font(.system(size: 10.5, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(5)
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            
            // Multi-Line Editor Box
            ZStack(alignment: .topLeading) {
                if testSentence.isEmpty {
                    Text("Type a sentence to test voice quality, natural cadence, and pronunciation...")
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: .placeholderTextColor))
                        .padding(8)
                }
                
                TextEditor(text: $testSentence)
                    .font(.system(size: 12))
                    .lineSpacing(3)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .frame(minHeight: 55, maxHeight: 85)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Status Feedback
    @ViewBuilder
    private var statusFeedbackView: some View {
        if manager.isCloning {
            HStack(spacing: 8) {
                ProgressView().scaleEffect(0.7)
                Text(manager.cloneMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.yellow)
            }
            .padding(.vertical, 2)
        } else if !manager.cloneMessage.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: hasAuditioned ? "checkmark.circle.fill" : "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(hasAuditioned ? .green : .accentColor)
                Text(manager.cloneMessage)
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .labelColor))
            }
            .padding(.vertical, 2)
        }
    }
    
    // MARK: - Modal Footer Bar
    private var modalFooterBar: some View {
        HStack(spacing: 12) {
            // Audition Preview Button
            Button(action: auditionVoiceSample) {
                HStack(spacing: 6) {
                    if manager.isCloning {
                        ProgressView().scaleEffect(0.6)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 11))
                    }
                    Text(manager.isCloning ? "Synthesizing..." : "Audition Preview")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.accentColor)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(selectedAudioPath.isEmpty || manager.isCloning)
            
            if trimmerPlayer.isPlaying || SpeechQueueManager.shared.isSpeaking {
                Button(action: {
                    trimmerPlayer.stop()
                    SpeechQueueManager.shared.stopCurrent()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 10))
                        Text("Stop Audio")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            Button("Cancel") {
                trimmerPlayer.stop()
                isPresented = false
            }
            .font(.system(size: 11.5))
            .buttonStyle(.plain)
            
            // Save & Activate Button
            Button(action: saveAuditionedVoice) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("Save Persona to Library")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background((hasAuditioned && !cleanName.isEmpty) ? Color.green : Color.gray.opacity(0.4))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!hasAuditioned || cleanName.isEmpty || manager.isCloning)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }
    
    // MARK: - Helpers & Actions
    private var cleanName: String {
        newVoiceName.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
            .joined(separator: "_")
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        if m > 0 { return "\(m)m \(s)s" }
        return String(format: "%.1fs", seconds)
    }
    
    private func loadFile(url: URL) {
        trimmerPlayer.stop()
        self.selectedAudioPath = url.path
        self.hasAuditioned = false
        if newVoiceName.isEmpty {
            self.newVoiceName = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: " ", with: "_")
        }
        
        trimmerPlayer.loadAudio(url: url)
        let dur = trimmerPlayer.duration > 0 ? trimmerPlayer.duration : ((try? AVAudioPlayer(contentsOf: url))?.duration ?? 0.0)
        
        self.audioDuration = dur
        self.trimStartTime = 0.0
        if dur > 15.0 {
            self.trimEndTime = 15.0
            self.isCutActive = true
        } else if dur > 5.0 {
            self.trimEndTime = max(3.0, round(dur * 0.70))
            self.isCutActive = true
        } else {
            self.trimEndTime = dur
            self.isCutActive = false
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
    
    private func auditionVoiceSample() {
        guard !selectedAudioPath.isEmpty else { return }
        trimmerPlayer.stop()
        let textToTest = testSentence.isEmpty ? "Hello! This is a test of your cloned voice." : testSentence
        let actualStart = isCutActive ? trimStartTime : 0.0
        let actualDur = isCutActive ? max(1.0, trimEndTime - trimStartTime) : max(1.0, audioDuration)
        
        manager.auditionVoice(
            audioPath: selectedAudioPath,
            text: textToTest,
            startTime: actualStart,
            duration: actualDur,
            autoTrim: false
        ) { success, _, dur in
            if success {
                self.hasAuditioned = true
                self.auditionDuration = dur
            }
        }
    }
    
    private func saveAuditionedVoice() {
        let finalName = cleanName
        guard !finalName.isEmpty, !selectedAudioPath.isEmpty else { return }
        trimmerPlayer.stop()
        let actualStart = isCutActive ? trimStartTime : 0.0
        let actualDur = isCutActive ? max(1.0, trimEndTime - trimStartTime) : max(1.0, audioDuration)
        
        manager.cloneVoice(
            name: finalName,
            audioPath: selectedAudioPath,
            startTime: actualStart,
            duration: actualDur,
            autoTrim: false
        ) { success, _ in
            if success {
                self.onVoiceSaved(finalName)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isPresented = false
                    self.hasAuditioned = false
                    self.newVoiceName = ""
                    self.selectedAudioPath = ""
                }
            }
        }
    }
}

// Backward-compatibility bridge
public typealias VoiceCloningStudioView = VoiceCloningStudioSheet
