import Foundation
import SwiftUI
import Combine

public struct PocketVoiceItem: Identifiable, Hashable {
    public var id: String { tag }
    public let tag: String
    public let displayName: String
    public let subtitle: String
}

public class PocketTTSManager: ObservableObject {
    public static let shared = PocketTTSManager()
    
    @Published public var isInstalled: Bool = false
    @Published public var isInstalling: Bool = false
    @Published public var installProgress: String = ""
    @Published public var availableVoices: [PocketVoiceItem] = []
    
    @Published public var isCloning: Bool = false
    @Published public var cloneMessage: String = ""
    @Published public var lastError: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let installed = (activePythonPath != nil && activeScriptPath != nil)
        self.isInstalled = installed
        loadVoices()
    }
    
    public var extensionDir: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.agentspeak/extensions/pocket-tts"
    }
    
    public var activePythonPath: String? {
        let extPython = extensionDir + "/venv/bin/python"
        if FileManager.default.fileExists(atPath: extPython) { return extPython }
        return nil
    }
    
    public var activeScriptPath: String? {
        let extScript = extensionDir + "/speak.py"
        if FileManager.default.fileExists(atPath: extScript) { return extScript }
        if let bundleScript = Bundle.main.resourcePath.map({ $0 + "/speak.py" }), FileManager.default.fileExists(atPath: bundleScript) {
            return bundleScript
        }
        return nil
    }
    
    public var activeCloneScriptPath: String? {
        let extClone = extensionDir + "/clone_voice.py"
        if FileManager.default.fileExists(atPath: extClone) { return extClone }
        if let bundleClone = Bundle.main.resourcePath.map({ $0 + "/clone_voice.py" }), FileManager.default.fileExists(atPath: bundleClone) {
            return bundleClone
        }
        return nil
    }
    
    public func refreshState() {
        let installed = (activePythonPath != nil && activeScriptPath != nil)
        if Thread.isMainThread {
            self.isInstalled = installed
            self.loadVoices()
        } else {
            DispatchQueue.main.async {
                self.isInstalled = installed
                self.loadVoices()
            }
        }
    }
    
    public func loadVoices() {
        var items: [PocketVoiceItem] = []
        var seenTags = Set<String>()
        
        // Standard curated personas from PersonaGreetingManager
        let profiles = PersonaGreetingManager.shared.profiles
        let order = [
            "Jarvis_Best", "Sayed_Johon_Primary", "Jarvis", "Male_Peace", "Male_News_Caster",
            "Female_Soft_Intimate", "Female_Podcast_Host", "Male_American_Narrator", "Male_Shorts_Creator",
            "Male_Viral_Actor", "Female_Confident_Sultry", "Male_Energetic_Creator", "Male_Social_Media",
            "Male_New", "Female_New", "Male_Old_Storyteller", "Female_Aah", "Female_Pro_2",
            "Male_Adam_v2", "alba", "george", "cosette", "marius"
        ]
        
        var curatedMap: [String: (name: String, desc: String)] = [:]
        for tag in order {
            if let p = profiles[tag] {
                let displayName: String
                if p.tag == "Jarvis_Best" {
                    displayName = "Jarvis (Best)"
                } else if p.tag == "Sayed_Johon_Primary" {
                    displayName = "Johon (Sayed Johon)"
                } else if p.tag == "Jarvis" {
                    displayName = "Jarvis (Classic)"
                } else {
                    displayName = "\(p.characterName) (\(p.gender))"
                }
                items.append(PocketVoiceItem(tag: p.tag, displayName: displayName, subtitle: p.subtitle))
                seenTags.insert(p.tag)
                curatedMap[p.tag] = (displayName, p.subtitle)
                curatedMap[p.tag.replacingOccurrences(of: "_", with: "-")] = (displayName, p.subtitle)
            }
        }
        
        // Search custom voice files strictly in private app storage & application bundle
        var searchDirs = [
            extensionDir + "/voices",
            FileManager.default.homeDirectoryForCurrentUser.path + "/.agentspeak/voices"
        ]
        if let bundleVoices = Bundle.main.resourcePath.map({ $0 + "/voices" }) {
            searchDirs.append(bundleVoices)
        }
        
        for dir in searchDirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for file in files {
                    if file.hasSuffix(".safetensors") {
                        let stem = (file as NSString).deletingPathExtension
                        if !seenTags.contains(stem) && !stem.hasPrefix("test_") {
                            seenTags.insert(stem)
                            if let match = curatedMap[stem] {
                                items.append(PocketVoiceItem(tag: stem, displayName: match.name, subtitle: match.desc))
                            } else {
                                let cleanLabel = stem.replacingOccurrences(of: "_", with: " ")
                                items.append(PocketVoiceItem(tag: stem, displayName: cleanLabel, subtitle: "Custom Cloned Voice"))
                            }
                        }
                    }
                }
            }
        }
        
        self.availableVoices = items
    }
    
    public func installExtension(completion: @escaping (Bool, String) -> Void) {
        guard !isInstalling else { return }
        
        DispatchQueue.main.async {
            self.isInstalling = true
            self.installProgress = "Initializing Custom Voice installer..."
            self.lastError = nil
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            var trustedScript: String? = nil
            let scriptCandidates = [
                Bundle.main.path(forResource: "install_pocket_tts", ofType: "sh"),
                Bundle.main.resourcePath.map { $0 + "/install_pocket_tts.sh" },
                FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/Agent Speak.app/Contents/Resources/install_pocket_tts.sh",
                "/Applications/Agent Speak.app/Contents/Resources/install_pocket_tts.sh",
                self.extensionDir + "/install.sh"
            ]
            
            for candidate in scriptCandidates {
                if let path = candidate, FileManager.default.fileExists(atPath: path) {
                    trustedScript = path
                    break
                }
            }
            
            guard let script = trustedScript else {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.lastError = "Installer script not found in application bundle."
                    self.installProgress = "Installer script not found."
                    completion(false, "Installer script not found in application bundle.")
                }
                return
            }
            
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [script]
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let rawStr = String(data: data, encoding: .utf8), !rawStr.isEmpty {
                    // Strip ANSI escape sequences and carriage returns for clean HUD display
                    let cleaned = rawStr.replacingOccurrences(of: #"\x1B\[[0-?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
                    let lines = cleaned.components(separatedBy: CharacterSet.newlines)
                    if let last = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                        DispatchQueue.main.async {
                            self.installProgress = last.trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
            }
            
            do {
                try proc.run()
                proc.waitUntilExit()
                pipe.fileHandleForReading.readabilityHandler = nil
                
                let success = (proc.terminationStatus == 0)
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.refreshState()
                    let msg = success ? "Custom Voice installed successfully!" : "Installation failed (Code \(proc.terminationStatus))"
                    self.installProgress = msg
                    if !success {
                        self.lastError = msg
                    } else {
                        self.lastError = nil
                    }
                    completion(success, msg)
                }
            } catch {
                pipe.fileHandleForReading.readabilityHandler = nil
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.lastError = error.localizedDescription
                    self.installProgress = "Error: \(error.localizedDescription)"
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    public func getAudioFileInfo(audioPath: String, targetDuration: Double = 15.0, completion: @escaping (Double, Double, Double) -> Void) {
        guard let py = activePythonPath, let cloneScript = activeCloneScriptPath else {
            completion(0, 0, 15.0)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: py)
            proc.arguments = [cloneScript, audioPath, "--info", "--duration", String(format: "%.1f", targetDuration)]
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            do {
                try proc.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   let jsonData = output.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let s = json["status"] as? String, s == "success" {
                    let dur = json["duration"] as? Double ?? 0.0
                    let start = json["auto_start"] as? Double ?? 0.0
                    let rec = json["recommended_duration"] as? Double ?? 15.0
                    DispatchQueue.main.async {
                        completion(dur, start, rec)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(0, 0, 15.0)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(0, 0, 15.0)
                }
            }
        }
    }
    
    public func playSourceSegment(audioPath: String, startTime: Double, duration: Double, autoTrim: Bool, completion: @escaping (Bool, String) -> Void) {
        guard let py = activePythonPath, let cloneScript = activeCloneScriptPath else {
            completion(false, "Neural engine is not installed yet.")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: py)
            var args = [cloneScript, audioPath, "--play-source", "--start-time", String(format: "%.2f", startTime), "--duration", String(format: "%.2f", duration)]
            if autoTrim {
                args.append("--auto-trim")
            }
            proc.arguments = args
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            do {
                try proc.run()
                _ = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                let success = (proc.terminationStatus == 0)
                DispatchQueue.main.async {
                    completion(success, success ? "Playing reference audio segment." : "Failed to play audio segment.")
                }
            } catch {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    public func cloneVoice(name: String, audioPath: String, startTime: Double = 0.0, duration: Double = 20.0, autoTrim: Bool = false, completion: @escaping (Bool, String) -> Void) {
        guard let py = activePythonPath, let cloneScript = activeCloneScriptPath else {
            completion(false, "Neural engine is not installed yet.")
            return
        }
        
        guard !isCloning else {
            completion(false, "Another voice operation is already in progress.")
            return
        }
        
        DispatchQueue.main.async {
            self.isCloning = true
            self.cloneMessage = "Preprocessing audio & extracting speaker embeddings..."
        }
        
        // Sanitize name: alphanumeric and underscores only, strip leading hyphens
        let safeName = name.trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_")).inverted)
            .joined(separator: "_")
        let finalName = safeName.isEmpty ? "Custom_Voice" : safeName
        
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: py)
            var args = [cloneScript, audioPath, "--name", finalName, "--save", "--start-time", String(format: "%.2f", startTime), "--duration", String(format: "%.2f", duration)]
            if autoTrim {
                args.append("--auto-trim")
            }
            proc.arguments = args
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            
            do {
                try proc.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let success = (proc.terminationStatus == 0)
                DispatchQueue.main.async {
                    self.isCloning = false
                    self.refreshState()
                    let message = success ? "Voice persona '\(finalName)' saved to library successfully!" : "Failed to save persona: \(output)"
                    self.cloneMessage = message
                    completion(success, message)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCloning = false
                    self.cloneMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                }
            }
        }
    }
    
    public func auditionVoice(audioPath: String, text: String, startTime: Double = 0.0, duration: Double = 20.0, autoTrim: Bool = false, completion: @escaping (Bool, String, Double) -> Void) {
        guard let py = activePythonPath, let cloneScript = activeCloneScriptPath else {
            completion(false, "Neural engine is not installed yet.", 0)
            return
        }
        
        guard !isCloning else {
            completion(false, "Another voice operation is already in progress.", 0)
            return
        }
        
        DispatchQueue.main.async {
            self.isCloning = true
            self.cloneMessage = "Generating audition preview..."
        }
        
        // Clamp audition test text to prevent excessive CPU saturation
        let boundedText = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(280))
        let cleanText = boundedText.isEmpty ? "Hello, this is a test of your cloned voice." : boundedText
        
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: py)
            var args = [cloneScript, audioPath, "--preview", "--text", cleanText, "--play", "--start-time", String(format: "%.2f", startTime), "--duration", String(format: "%.2f", duration)]
            if autoTrim {
                args.append("--auto-trim")
            }
            proc.arguments = args
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            
            do {
                try proc.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                var success = (proc.terminationStatus == 0)
                var previewDuration = 0.0
                var msg = "Audition audio synthesized."
                
                if let jsonData = output.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    if let s = json["status"] as? String, s == "success" {
                        success = true
                        previewDuration = json["duration"] as? Double ?? 0.0
                        msg = json["message"] as? String ?? msg
                    } else if let m = json["message"] as? String {
                        msg = m
                        success = false
                    }
                }
                
                DispatchQueue.main.async {
                    self.isCloning = false
                    self.cloneMessage = msg
                    completion(success, msg, previewDuration)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isCloning = false
                    self.cloneMessage = error.localizedDescription
                    completion(false, error.localizedDescription, 0)
                }
            }
        }
    }
    
    public func unlockZeroShotCloning() {
        if let url = URL(string: "https://huggingface.co/kyutai/pocket-tts") {
            NSWorkspace.shared.open(url)
        }
    }
}
