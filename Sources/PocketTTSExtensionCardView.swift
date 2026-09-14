import SwiftUI
import AppKit

public struct PocketTTSExtensionCardView: View {
    @ObservedObject var manager = PocketTTSManager.shared
    @Binding var pocketVoice: String
    var onSave: () -> Void
    
    @State private var showingCloneSheet = false
    @State private var showingGuideSheet = false
    @State private var isAuditioning = false
    @State private var activeAuditionProcess: Process? = nil
    
    public init(pocketVoice: Binding<String>, onSave: @escaping () -> Void) {
        self._pocketVoice = pocketVoice
        self.onSave = onSave
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !manager.isInstalled {
                // MARK: - Not Installed View (On-Demand Downloader)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 22))
                            .foregroundColor(.purple)
                            .frame(width: 32, height: 32)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Pocket-TTS Neural Extension")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Text("NOT INSTALLED")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.yellow)
                                    .cornerRadius(4)
                            }
                            
                            Text("Kyutai Mimi & FlowLM neural voices running 100% offline on Apple Silicon CPU. Requires a one-time ~650MB component setup on your computer.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        badgeView(icon: "lock.shield", text: "100% Offline")
                        badgeView(icon: "bolt.fill", text: "Zero Cloud Latency")
                        badgeView(icon: "internaldrive", text: "~650 MB")
                    }
                    .padding(.top, 2)
                    
                    // CPU & Battery Warning Callout
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CPU Usage & Performance Notice")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                            Text("Pocket-TTS runs local neural AI on your Apple Silicon CPU, which uses slightly more CPU power during speech generation. If you prefer near-zero CPU usage and maximum battery life, use the MacBook Built-in Voice.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.25), lineWidth: 1))
                    
                    // Multilingual Auto-Fallback Notice
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Automatic Multilingual Fallback")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.cyan)
                            Text("Pocket-TTS synthesizes English neural clones. If Bengali, Hindi, Arabic, or other non-English languages are detected, speech automatically transfers to high-clarity native macOS voices.")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.cyan.opacity(0.08))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.cyan.opacity(0.25), lineWidth: 1))
                    
                    Divider().background(Color.white.opacity(0.1))
                    
                    if manager.isInstalling {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                Text("Setting up neural engine on your computer...")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            if !manager.installProgress.isEmpty {
                                Text(manager.installProgress)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.purple.opacity(0.9))
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Button(action: {
                                manager.installExtension { success, msg in
                                    if success {
                                        onSave()
                                    }
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download & Set Up Neural Engine (~650MB)")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(7)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                        }
                    }
                }
                .padding(14)
                .background(Color.purple.opacity(0.06))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.3), lineWidth: 1))
                
            } else {
                // MARK: - Installed View (Active Persona & Controls)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Pocket-TTS Neural Extension")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                
                                Text("● READY")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundColor(.green)
                            }
                            Text("Active Persona: \(selectedVoiceLabel)")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(manager.availableVoices) { item in
                                Button(action: {
                                    pocketVoice = item.tag
                                    onSave()
                                }) {
                                    HStack {
                                        Text("\(item.displayName) — \(item.subtitle)")
                                        if pocketVoice == item.tag {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedVoiceLabel)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.24, green: 0.26, blue: 0.33), lineWidth: 1)
                            )
                        }
                        .menuStyle(BorderlessButtonMenuStyle())
                        .frame(maxWidth: 240)
                    }
                    
                    Divider().background(Color.white.opacity(0.06))
                    
                    // Active Neural Engine CPU Notice
                    HStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                        Text("Neural AI speech uses moderate CPU while generating audio. Switch to MacBook Built-in Voice anytime for near-zero CPU.")
                            .font(.system(size: 9.5))
                            .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.06))
                    .cornerRadius(5)
                    
                    HStack(spacing: 10) {
                        // Audition / Test Button
                        Button(action: testCurrentVoice) {
                            HStack(spacing: 6) {
                                Image(systemName: isAuditioning ? "waveform" : "play.fill")
                                    .font(.system(size: 10))
                                Text(isAuditioning ? "Synthesizing..." : "Audition Voice")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.25, green: 0.27, blue: 0.34), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isAuditioning)
                        
                        if isAuditioning || SpeechQueueManager.shared.isSpeaking {
                            Button(action: stopAudition) {
                                HStack(spacing: 5) {
                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 9))
                                    Text("Stop")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Clone Custom Voice Button
                        Button(action: {
                            let hasSeen = UserDefaults.standard.bool(forKey: "hasSeenCloningGuide")
                            if !showingCloneSheet && !hasSeen {
                                showingGuideSheet = true
                            }
                            showingCloneSheet.toggle()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: showingCloneSheet ? "xmark" : "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text(showingCloneSheet ? "Close Cloner" : "Clone New Voice...")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(showingCloneSheet ? Color(red: 0.22, green: 0.24, blue: 0.30) : Color(red: 0.05, green: 0.48, blue: 0.95))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(red: 0.25, green: 0.55, blue: 1.0).opacity(showingCloneSheet ? 0.3 : 0.8), lineWidth: 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                        
                        Button(action: { manager.refreshState() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                                .padding(6)
                                .background(Color(red: 0.14, green: 0.15, blue: 0.19))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(red: 0.22, green: 0.24, blue: 0.30), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Refresh Voice Library")
                    }
                    
                    // MARK: - Reimagined High-Craft Voice Cloner Studio
                    if showingCloneSheet {
                        VoiceCloningStudioView(
                            isPresented: $showingCloneSheet,
                            onVoiceSaved: { newVoiceTag in
                                pocketVoice = newVoiceTag
                                onSave()
                            }
                        )
                    }
                }
                .padding(14)
                .background(Color(red: 0.11, green: 0.12, blue: 0.15))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
            }
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

    
    private var selectedVoiceLabel: String {
        manager.availableVoices.first(where: { $0.tag == pocketVoice })?.displayName ?? pocketVoice
    }
    
    private func badgeView(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.06))
        .cornerRadius(4)
    }

    
    private func testCurrentVoice() {
        guard let py = manager.activePythonPath, let script = manager.activeScriptPath else { return }
        isAuditioning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: py)
            let testPhrase = "This is a viral and proven voice  currently used by hundreds successful of youtube channels. so Do you like this voice? "
            proc.arguments = [script, testPhrase, "--voice", self.pocketVoice, "--play"]
            
            DispatchQueue.main.async {
                self.activeAuditionProcess = proc
            }
            
            try? proc.run()
            proc.waitUntilExit()
            
            DispatchQueue.main.async {
                self.activeAuditionProcess = nil
                self.isAuditioning = false
            }
        }
    }
    
    private func stopAudition() {
        activeAuditionProcess?.terminate()
        activeAuditionProcess = nil
        isAuditioning = false
        SpeechQueueManager.shared.stopCurrent()
        let killProc = Process()
        killProc.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killProc.arguments = ["afplay"]
        try? killProc.run()
    }
}

// MARK: - First-Time Voice Cloning Guide Modal
public struct CloningGuideModalView: View {
    @Binding var isPresented: Bool
    @State private var dontShowAgain: Bool = UserDefaults.standard.bool(forKey: "hasSeenCloningGuide")
    var onUnlockHuggingFace: () -> Void
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.purple.opacity(0.35), Color.cyan.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                    Image(systemName: "waveform.badge.mic")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.cyan)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Persona Cloning Guide")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Follow these 3 simple steps to create crystal-clear custom AI voices.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { close() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Steps List
            VStack(spacing: 11) {
                stepCard(
                    number: "1",
                    icon: "mic.fill",
                    color: .blue,
                    title: "Select Clean Reference Audio (10–30 Seconds)",
                    desc: "Use a clean WAV or MP3 recording of a single speaker talking naturally. Avoid background music, heavy room echo, or noisy environments."
                )
                
                stepCard(
                    number: "2",
                    icon: "play.circle.fill",
                    color: .cyan,
                    title: "Audition First Before Saving",
                    desc: "Type any test sentence into the preview box and click '▶ Audition Preview'. Pocket-TTS generates a quick sample and plays it out loud so you can verify how it sounds before saving."
                )
                
                stepCard(
                    number: "3",
                    icon: "lock.open.fill",
                    color: .purple,
                    title: "One-Click Free Hugging Face Access",
                    desc: "Zero-shot cloning uses Kyutai's official neural weights. Click 'Unlock Free Zero-Shot' to accept the research terms on Hugging Face once with your free account."
                )
            }
            
            // CPU & Battery Note
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                Text("Performance Note: Pocket-TTS uses CPU compute for neural generation. For completely zero CPU impact and maximum battery life, use the MacBook Built-in Voice.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.orange.opacity(0.07))
            .cornerRadius(6)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Bottom Bar
            HStack {
                Toggle("Don't show this guide automatically again", isOn: $dontShowAgain)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .onChange(of: dontShowAgain) { val in
                        UserDefaults.standard.set(val, forKey: "hasSeenCloningGuide")
                    }
                
                Spacer()
                
                Button(action: {
                    onUnlockHuggingFace()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.square")
                        Text("Unlock on Hugging Face")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(7)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { close() }) {
                    Text("Got it, Let's Clone!")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(7)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .frame(width: 530)
        .background(Color(red: 0.10, green: 0.11, blue: 0.14))
    }
    
    private func close() {
        if dontShowAgain {
            UserDefaults.standard.set(true, forKey: "hasSeenCloningGuide")
        }
        isPresented = false
    }
    
    private func stepCard(number: String, icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

