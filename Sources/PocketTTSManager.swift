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
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        refreshState()
    }
    
    public var extensionDir: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/.agentspeak/extensions/pocket-tts"
    }
    
    public var devDir: String {
        FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/DEV_AREA/ssh linux/pocket-tts"
    }
    
    public var activePythonPath: String? {
        let extPython = extensionDir + "/venv/bin/python"
        if FileManager.default.fileExists(atPath: extPython) { return extPython }
        let devPython = devDir + "/venv/bin/python"
        if FileManager.default.fileExists(atPath: devPython) { return devPython }
        return nil
    }
    
    public var activeScriptPath: String? {
        let extScript = extensionDir + "/speak.py"
        if FileManager.default.fileExists(atPath: extScript) { return extScript }
        if let bundleScript = Bundle.main.resourcePath.map({ $0 + "/speak.py" }), FileManager.default.fileExists(atPath: bundleScript) {
            return bundleScript
        }
        let devScript = devDir + "/speak.py"
        if FileManager.default.fileExists(atPath: devScript) { return devScript }
        return nil
    }
    
    public var activeCloneScriptPath: String? {
        let extClone = extensionDir + "/clone_voice.py"
        if FileManager.default.fileExists(atPath: extClone) { return extClone }
        if let bundleClone = Bundle.main.resourcePath.map({ $0 + "/clone_voice.py" }), FileManager.default.fileExists(atPath: bundleClone) {
            return bundleClone
        }
        let devClone = devDir + "/clone_voice.py"
        if FileManager.default.fileExists(atPath: devClone) { return devClone }
        return nil
    }
    
    public func refreshState() {
        let installed = (activePythonPath != nil && activeScriptPath != nil)
        DispatchQueue.main.async {
            self.isInstalled = installed
            self.loadVoices()
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
        
        // Search custom voice files in voices directories
        var searchDirs = [
            extensionDir + "/voices",
            devDir + "/pocket_tts_lab/voices",
            devDir + "/saved_voices"
        ]
        if let bundleVoices = Bundle.main.resourcePath.map({ $0 + "/voices" }) {
            searchDirs.append(bundleVoices)
        }
        let cwdVoices = FileManager.default.currentDirectoryPath + "/Resources/voices"
        if FileManager.default.fileExists(atPath: cwdVoices) {
            searchDirs.append(cwdVoices)
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
            self.installProgress = "Initializing neural installer..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let possibleScripts = [
                self.extensionDir + "/install.sh",
                Bundle.main.resourcePath.map { $0 + "/install_pocket_tts.sh" } ?? "",
                FileManager.default.currentDirectoryPath + "/Resources/install_pocket_tts.sh",
                FileManager.default.currentDirectoryPath + "/config/install_pocket_tts.sh"
            ]
            
            var scriptToRun: String?
            for s in possibleScripts {
                if FileManager.default.fileExists(atPath: s) {
                    scriptToRun = s
                    break
                }
            }
            
            guard let script = scriptToRun else {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.installProgress = "Installer script not found."
                    completion(false, "Installer script not found.")
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
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    DispatchQueue.main.async {
                        // Extract high-level status line
                        let lines = str.components(separatedBy: "\n")
                        if let last = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                            self.installProgress = last
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
                    let msg = success ? "Pocket-TTS installed successfully!" : "Installation failed with code \(proc.terminationStatus)"
                    self.installProgress = msg
                    completion(success, msg)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
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
            try? proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
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
            try? proc.run()
            proc.waitUntilExit()
            let success = (proc.terminationStatus == 0)
            DispatchQueue.main.async {
                completion(success, success ? "Playing reference audio segment." : "Failed to play audio segment.")
            }
        }
    }
    
    public func cloneVoice(name: String, audioPath: String, startTime: Double = 0.0, duration: Double = 20.0, autoTrim: Bool = false, completion: @escaping (Bool, String) -> Void) {
        guard let py = activePythonPath, let cloneScript = activeCloneScriptPath else {
            completion(false, "Neural engine is not installed yet.")
            return
        }
        
        DispatchQueue.main.async {
            self.isCloning = true
            self.cloneMessage = "Preprocessing audio & extracting speaker embeddings..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: py)
            var args = [cloneScript, audioPath, "--name", name, "--save", "--start-time", String(format: "%.2f", startTime), "--duration", String(format: "%.2f", duration)]
            if autoTrim {
                args.append("--auto-trim")
            }
            proc.arguments = args
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            
            do {
                try proc.run()
                proc.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                let success = (proc.terminationStatus == 0)
                DispatchQueue.main.async {
                    self.isCloning = false
                    self.refreshState()
                    let message = success ? "Voice persona '\(name)' saved to library successfully!" : "Failed to save persona: \(output)"
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
        
        DispatchQueue.main.async {
            self.isCloning = true
            self.cloneMessage = "Generating audition preview..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: py)
            var args = [cloneScript, audioPath, "--preview", "--text", text, "--play", "--start-time", String(format: "%.2f", startTime), "--duration", String(format: "%.2f", duration)]
            if autoTrim {
                args.append("--auto-trim")
            }
            proc.arguments = args
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe
            
            do {
                try proc.run()
                proc.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                var success = (proc.terminationStatus == 0)
                var duration = 0.0
                var msg = "Audition audio synthesized."
                
                if let jsonData = output.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    if let s = json["status"] as? String, s == "success" {
                        success = true
                        duration = json["duration"] as? Double ?? 0.0
                        msg = json["message"] as? String ?? msg
                    } else if let m = json["message"] as? String {
                        msg = m
                        success = false
                    }
                }
                
                DispatchQueue.main.async {
                    self.isCloning = false
                    self.cloneMessage = msg
                    completion(success, msg, duration)
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
