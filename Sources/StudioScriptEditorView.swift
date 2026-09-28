import SwiftUI
import AppKit

// MARK: - Apple HIG Studio Script Editor View
public struct StudioScriptEditorView: View {
    @Binding var text: String
    var isSpeaking: Bool
    var onTest: () -> Void
    var onStop: () -> Void
    
    private let presetChips: [(title: String, icon: String, text: String)] = [
        ("Tech Explainer", "sparkles", "Here is what happened: instead of querying the disk every cycle, we cached the response in memory. Speed improved instantly."),
        ("Friendly Assistant", "person.bubble.fill", "I've finished analyzing your project. Everything looks clean, all tests are passing, and we're ready to ship."),
        ("Casual Banter", "cup.and.saucer.fill", "Quick heads up—the build finished in under five seconds. Want to run the integration suite, or call it a day?"),
        ("Code Review", "checkmark.shield.fill", "The race condition occurred because the worker thread mutated state before acquiring the database lock.")
    ]
    
    public init(
        text: Binding<String>,
        isSpeaking: Bool,
        onTest: @escaping () -> Void,
        onStop: @escaping () -> Void
    ) {
        self._text = text
        self.isSpeaking = isSpeaking
        self.onTest = onTest
        self.onStop = onStop
    }
    
    private var wordCount: Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Section Title & Character/Word Count
            HStack {
                Text("VOICE TEST SCRIPT")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Text("\(text.count) characters")
                    Text("•")
                    Text("\(wordCount) words")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
            }
            
            // Preset Scenario Chips (Apple HIG Pill Bar)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(presetChips, id: \.title) { chip in
                        Button(action: {
                            text = chip.text
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: chip.icon)
                                    .font(.system(size: 9.5))
                                Text(chip.title)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(nsColor: .quaternaryLabelColor))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Insert '\(chip.title)' sample script")
                    }
                }
            }
            
            // Multi-Line Text Editor Container
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Type or paste any test sentence in any language (English, বাংলা, Español, etc.)...")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .allowsHitTesting(false)
                }
                
                TextEditor(text: $text)
                    .font(.system(size: 12.5, weight: .regular))
                    .lineSpacing(3)
                    .padding(6)
                    .frame(height: 72)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 0.5)
            )
            
            // Bottom Action Bar
            HStack(alignment: .center) {
                HStack(spacing: 4) {
                    Image(systemName: "command")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text("Return to test")
                        .font(.system(size: 10.5))
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                if isSpeaking {
                    Button(action: onStop) {
                        HStack(spacing: 5) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 9))
                            Text("Stop")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Button(action: onTest) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 9.5))
                        Text("Test Voice")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 6)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Test voice with current script (⌘ Return)")
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}
