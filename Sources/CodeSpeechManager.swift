import Foundation
import Cocoa

/// Manages the global preference for reading code blocks aloud vs stripping them for natural conversational speech.
public class CodeSpeechManager: ObservableObject {
    public static let shared = CodeSpeechManager()
    
    @Published public var speakCodeBlocks: Bool = false {
        didSet {
            TextSanitizer.speakCodeBlocks = speakCodeBlocks
        }
    }
    
    private let configPath: URL
    
    private init() {
        self.configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agentspeak/config.json")
        loadConfiguration()
    }
    
    public func loadConfiguration() {
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audio = json["audio"] as? [String: Any] else {
            self.speakCodeBlocks = false
            TextSanitizer.speakCodeBlocks = false
            return
        }
        
        let enabled = audio["speak_code_blocks"] as? Bool ?? false
        self.speakCodeBlocks = enabled
        TextSanitizer.speakCodeBlocks = enabled
    }
    
    public func setSpeakCodeBlocks(_ enabled: Bool) {
        guard self.speakCodeBlocks != enabled else { return }
        self.speakCodeBlocks = enabled
        TextSanitizer.speakCodeBlocks = enabled
        saveConfiguration()
    }
    
    public func toggle() {
        setSpeakCodeBlocks(!speakCodeBlocks)
    }
    
    private func saveConfiguration() {
        guard let data = try? Data(contentsOf: configPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var audio = json["audio"] as? [String: Any] ?? [:]
        audio["speak_code_blocks"] = speakCodeBlocks
        json["audio"] = audio
        
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? updated.write(to: configPath)
        }
    }
}
