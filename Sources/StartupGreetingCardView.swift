import SwiftUI
import Cocoa

// MARK: - Startup Greeting & User Identity Card View
public struct StartupGreetingCardView: View {
    @ObservedObject var greetingManager = PersonaGreetingManager.shared
    @ObservedObject var queueManager = SpeechQueueManager.shared
    
    @State private var userName: String = "Johon"
    @State private var agentName: String = "Jarvis"
    @State private var greetingMode: String = "dynamic"
    @State private var greetingCategory: String = "all"
    @State private var customStartupText: String = "Good day Johon, Jarvis is ready at your service."
    @State private var speakOnStartup: Bool = true
    @State private var samplePreviewText: String = ""
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // MARK: - Card Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(LinearGradient(colors: [Color.teal, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 24, height: 24)
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        
                        Text("User Identity & Startup Greeting")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Text("Personalize your name and assistant persona. Replaces technical system jargon with warm, friendly greetings.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                // Greet on Startup Toggle
                HStack(spacing: 8) {
                    Text("Greet on Startup")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(speakOnStartup ? .teal : .secondary)
                    
                    Toggle("", isOn: Binding(
                        get: { speakOnStartup },
                        set: { newVal in
                            speakOnStartup = newVal
                            syncProfile()
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }
            
            Divider()
            
            // MARK: - Identity Fields (User Name & Agent Name)
            HStack(spacing: 12) {
                // User Name Field
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.teal)
                        Text("YOUR NAME")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                    }
                    
                    HStack(spacing: 6) {
                        TextField("Your name (e.g. Johon)", text: Binding(
                            get: { userName },
                            set: { newVal in
                                userName = newVal
                                syncProfile()
                                refreshSample()
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                }
                .frame(maxWidth: .infinity)
                
                // Assistant Name Field
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.cyan)
                        Text("ASSISTANT NAME")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                    }
                    
                    HStack(spacing: 6) {
                        TextField("Agent name (e.g. Jarvis)", text: Binding(
                            get: { agentName },
                            set: { newVal in
                                agentName = newVal
                                syncProfile()
                                refreshSample()
                            }
                        ))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                    )
                }
                .frame(maxWidth: .infinity)
            }
            
            // MARK: - Greeting Mode Selector
            VStack(alignment: .leading, spacing: 6) {
                Text("GREETING STYLE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                Picker("", selection: Binding(
                    get: { greetingMode },
                    set: { newVal in
                        greetingMode = newVal
                        syncProfile()
                        refreshSample()
                    }
                )) {
                    Text("🎲 Dynamic Greetings (32 Friendly Variations)").tag("dynamic")
                    Text("✍️ Custom Startup Text").tag("custom")
                }
                .pickerStyle(.segmented)
            }
            
            // MARK: - Dynamic Mode View
            if greetingMode == "dynamic" {
                VStack(alignment: .leading, spacing: 10) {
                    // Persona & Tone Category Picker
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 5) {
                            Image(systemName: "theatermasks.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.teal)
                            Text("PERSONA & GREETING STYLE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(0.5)
                        }
                        
                        Menu {
                            ForEach(greetingManager.availableCategories) { cat in
                                Button(action: {
                                    greetingCategory = cat.tag
                                    syncProfile()
                                    refreshSample()
                                }) {
                                    HStack {
                                        Text(cat.displayName)
                                        if greetingCategory == cat.tag {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if let selected = greetingManager.availableCategories.first(where: { $0.tag == greetingCategory }) {
                                    Image(systemName: selected.icon)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(greetingCategory == "jarvis" ? .orange : .teal)
                                    Text(selected.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(selected.subtitle)
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                            )
                        }
                    }
                    
                    // Preview Bubble
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.teal.opacity(0.8))
                        
                        Text(samplePreviewText.isEmpty ? "Hey \(userName), \(agentName) is here and ready to help!" : samplePreviewText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                            .italic()
                            .lineSpacing(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(Color.teal.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.teal.opacity(0.25), lineWidth: 0.8)
                    )
                    
                    // Buttons: Roll new greeting & Audition
                    HStack(spacing: 8) {
                        Button(action: {
                            rollRandomGreeting()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "die.face.5.fill")
                                    .font(.system(size: 11))
                                Text("Shuffle Variation")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Preview another random greeting from the 32 friendly styles")
                        
                        Spacer()
                        
                        Button(action: {
                            auditionCurrentGreeting()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: queueManager.isSpeaking ? "stop.fill" : "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(queueManager.isSpeaking ? "Stop" : "Audition Greeting")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(queueManager.isSpeaking ? Color.red.opacity(0.85) : Color.teal)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Hear how this greeting sounds with your active voice persona")
                    }
                }
            } else {
                // MARK: - Custom Mode View
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextEditor(text: Binding(
                            get: { customStartupText },
                            set: { newVal in
                                customStartupText = newVal
                                syncProfile()
                            }
                        ))
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .frame(minHeight: 52)
                        .padding(6)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                    }
                    
                    HStack(spacing: 6) {
                        Text("Tokens:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Button(action: { insertToken("{user}") }) {
                            Text("{user}")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.teal)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.teal.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Click to append {user} to your custom startup text")
                        
                        Button(action: { insertToken("{agent}") }) {
                            Text("{agent}")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Click to append {agent} to your custom startup text")
                        
                        Spacer()
                        
                        Button(action: {
                            auditionCurrentGreeting()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: queueManager.isSpeaking ? "stop.fill" : "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(queueManager.isSpeaking ? "Stop" : "Test Custom Text")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(queueManager.isSpeaking ? Color.red.opacity(0.85) : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .onAppear {
            greetingManager.loadConfiguration()
            userName = greetingManager.userName
            agentName = greetingManager.agentName
            greetingMode = greetingManager.greetingMode
            greetingCategory = greetingManager.greetingCategory
            customStartupText = greetingManager.customStartupText
            speakOnStartup = greetingManager.speakOnStartup
            refreshSample()
        }
    }
    
    // MARK: - Actions & Helpers
    
    private func syncProfile() {
        greetingManager.updateProfile(
            userName: userName,
            agentName: agentName,
            greetingMode: greetingMode,
            greetingCategory: greetingCategory,
            customStartupText: customStartupText,
            speakOnStartup: speakOnStartup
        )
    }
    
    private func refreshSample() {
        samplePreviewText = greetingManager.previewSample(for: greetingCategory)
    }
    
    private func rollRandomGreeting() {
        let template = greetingManager.getRandomGreetingTemplate(for: greetingCategory)
        samplePreviewText = greetingManager.formatGreeting(template, user: userName, agent: agentName)
    }
    
    private func auditionCurrentGreeting() {
        if queueManager.isSpeaking {
            queueManager.stopCurrent()
            return
        }
        
        let greeting = greetingManager.resolveGreeting()
        let textToSpeak: String
        if greetingMode == "dynamic" && !samplePreviewText.isEmpty {
            textToSpeak = samplePreviewText
        } else {
            textToSpeak = greeting.text
        }
        
        let characterSource = greetingCategory == "jarvis" ? "Jarvis" : greeting.character
        LastVoiceManager.shared.prepareForNewVoice(text: textToSpeak)
        SpeechQueueManager.shared.enqueue(
            source: characterSource,
            text: textToSpeak,
            immediate: true
        )
    }
    
    private func insertToken(_ token: String) {
        if customStartupText.isEmpty {
            customStartupText = token
        } else if customStartupText.hasSuffix(" ") {
            customStartupText += token
        } else {
            customStartupText += " " + token
        }
        syncProfile()
    }
}
