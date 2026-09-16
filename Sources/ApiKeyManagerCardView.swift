import SwiftUI

// MARK: - Key Test Status Enum
public enum KeyTestStatus: Equatable {
    case idle
    case testing
    case success(String)
    case failure(String)
}

// MARK: - API Key Manager Card View
public struct ApiKeyManagerCardView: View {
    @ObservedObject var whisperManager: GroqWhisperManager
    
    @State private var newKeyInput: String = ""
    @State private var testStatuses: [String: KeyTestStatus] = [:]
    @State private var revealedKeys: Set<String> = []
    @State private var isBulkImportOpen: Bool = false
    @State private var bulkImportText: String = ""
    @State private var copiedKeyMessage: String? = nil
    @State private var isTestingAll: Bool = false
    
    public init(whisperManager: GroqWhisperManager) {
        self.whisperManager = whisperManager
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Key Count & Action Buttons
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "key.horizontal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 13))
                    
                    Text("Groq API Key Pool & Fallbacks")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // Bulk Import / Edit Toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if !isBulkImportOpen {
                            bulkImportText = whisperManager.groqApiKeys.joined(separator: "\n")
                        }
                        isBulkImportOpen.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isBulkImportOpen ? "chevron.up" : "square.and.pencil")
                            .font(.system(size: 10))
                        Text(isBulkImportOpen ? "Close Bulk" : "Bulk Edit")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.gray)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Test All Keys Button
                Button(action: testAllKeys) {
                    HStack(spacing: 4) {
                        if isTestingAll {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                        }
                        Text(isTestingAll ? "Testing..." : "Test All")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isTestingAll || whisperManager.groqApiKeys.isEmpty)
            }
            
            // Subtitle description
            Text("Automatic failover chain: If rate-limited (HTTP 429), Agent Speak instantly shifts to the next key.")
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            // Bulk Edit Text Area Drawer
            if isBulkImportOpen {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Paste multiple Groq API keys (one per line):")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.gray)
                    
                    TextEditor(text: $bulkImportText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 80)
                        .padding(6)
                        .background(Color(white: 0.12))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            withAnimation { isBulkImportOpen = false }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .padding(.trailing, 8)
                        
                        Button(action: saveBulkKeys) {
                            Text("Apply & Save Keys")
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(10)
                .background(Color(white: 0.08))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
            }
            
            // Key List
            if whisperManager.groqApiKeys.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                        Text("No Groq API keys added yet.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Paste a Groq key below to enable cloud transcription.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
                .background(Color.white.opacity(0.03))
                .cornerRadius(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(whisperManager.groqApiKeys.enumerated()), id: \.offset) { index, key in
                        keyRow(index: index, key: key)
                    }
                }
            }
            
            // Add New Key Box
            HStack(spacing: 8) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.gray)
                    .font(.system(size: 13))
                
                TextField("Add new Groq API key (gsk_...)", text: $newKeyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { addNewKey() }
                
                // Paste from Clipboard Button
                Button(action: pasteFromClipboard) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Paste from clipboard")
                
                // Add Key Button
                Button(action: addNewKey) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                        Text("Add")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(newKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.2) : Color.green.opacity(0.25))
                    .foregroundColor(newKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .green)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(newKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            
            // Brief Copied Banner
            if let copied = copiedKeyMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Copied \(copied) to clipboard")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .padding(14)
        .background(Color(white: 0.12, opacity: 0.7))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
    
    // MARK: - Individual Key Row
    private func keyRow(index: Int, key: String) -> some View {
        let isActive = (index == whisperManager.activeKeyIndex)
        let isRevealed = revealedKeys.contains(key)
        let testStatus = testStatuses[key] ?? .idle
        
        return VStack(alignment: .leading, spacing: 6) {
            // Top Row: Role Badge, Primary Button & Test Status
            HStack(spacing: 8) {
                if isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Active Primary (#\(index + 1))")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(4)
                } else {
                    HStack(spacing: 4) {
                        Text("Fallback #\(index + 1)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                    
                    Button(action: {
                        withAnimation { whisperManager.setActiveKey(at: index) }
                    }) {
                        Text("Set Primary")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Spacer()
                
                // Test Status Display
                switch testStatus {
                case .idle:
                    Text("Not tested")
                        .font(.system(size: 10))
                        .foregroundColor(.gray.opacity(0.7))
                case .testing:
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.4)
                            .frame(width: 10, height: 10)
                        Text("Verifying...")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                case .success(let latency):
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        Text(latency)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                case .failure(let err):
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text(err)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Bottom Row: Masked String, Eye, Copy, Test, Delete
            HStack(spacing: 8) {
                // Key Display
                Text(isRevealed ? key : maskedKey(key))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Toggle Reveal Eye Button
                Button(action: {
                    if isRevealed {
                        revealedKeys.remove(key)
                    } else {
                        revealedKeys.insert(key)
                    }
                }) {
                    Image(systemName: isRevealed ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .help(isRevealed ? "Hide key" : "Show full key")
                
                // Copy Key Button
                Button(action: { copyKey(key) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Copy key to clipboard")
                
                Divider()
                    .frame(height: 14)
                    .background(Color.white.opacity(0.15))
                
                // 1-Click Test Button
                Button(action: { testKey(key) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 10))
                        Text("Test")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(testStatus == .testing)
                
                // 1-Click Delete Button
                Button(action: {
                    withAnimation { whisperManager.removeApiKey(at: index) }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Delete key from pool")
            }
        }
        .padding(10)
        .background(isActive ? Color.green.opacity(0.05) : Color.white.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isActive ? Color.green.opacity(0.3) : Color.white.opacity(0.07), lineWidth: 1)
        )
    }
    
    // MARK: - Helpers
    private func maskedKey(_ key: String) -> String {
        guard key.count > 12 else { return "••••••••" }
        let prefix = key.prefix(8)
        let suffix = key.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }
    
    private func copyKey(_ key: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(key, forType: .string)
        
        let masked = maskedKey(key)
        withAnimation {
            copiedKeyMessage = masked
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                if self.copiedKeyMessage == masked {
                    self.copiedKeyMessage = nil
                }
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let clip = NSPasteboard.general.string(forType: .string) {
            newKeyInput = clip.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    private func addNewKey() {
        let trimmed = newKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let res = whisperManager.addApiKey(trimmed)
        if res.success {
            newKeyInput = ""
            testKey(trimmed)
        }
    }
    
    private func saveBulkKeys() {
        let lines = bulkImportText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Deduplicate while preserving order
        var seen = Set<String>()
        var uniqueKeys: [String] = []
        for line in lines {
            if !seen.contains(line) {
                seen.insert(line)
                uniqueKeys.append(line)
            }
        }
        
        if !uniqueKeys.isEmpty {
            whisperManager.groqApiKeys = uniqueKeys
            if whisperManager.activeKeyIndex >= uniqueKeys.count {
                whisperManager.activeKeyIndex = 0
            }
            whisperManager.saveConfig()
        }
        withAnimation {
            isBulkImportOpen = false
        }
    }
    
    private func testKey(_ key: String) {
        testStatuses[key] = .testing
        whisperManager.testApiKey(key) { success, result in
            if success {
                testStatuses[key] = .success(result)
            } else {
                testStatuses[key] = .failure(result)
            }
        }
    }
    
    private func testAllKeys() {
        guard !whisperManager.groqApiKeys.isEmpty else { return }
        isTestingAll = true
        let group = DispatchGroup()
        
        for key in whisperManager.groqApiKeys {
            testStatuses[key] = .testing
            group.enter()
            whisperManager.testApiKey(key) { success, result in
                if success {
                    testStatuses[key] = .success(result)
                } else {
                    testStatuses[key] = .failure(result)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            isTestingAll = false
        }
    }
}
