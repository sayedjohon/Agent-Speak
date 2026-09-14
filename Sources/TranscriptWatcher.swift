import Foundation

public class TranscriptWatcher {
    public static let shared = TranscriptWatcher()
    
    private var state: [String: String] = [:]
    private let stateLock = NSLock()
    private let stateURL: URL
    private var timer: Timer?
    private let socketPath = "/tmp/agentspeak.sock"
    private var socketSource: DispatchSourceRead?
    private var isBootstrapping: Bool = false
    
    public var onSpeechRequest: ((_ source: String, _ text: String) -> Void)?
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".agentspeak")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        stateURL = dir.appendingPathComponent("state.json")
        loadState()
        startSocketListener()
    }
    
    public func start() {
        // Initial silent baseline scan so existing conversation history is NEVER spoken on launch
        self.isBootstrapping = true
        self.scan()
        self.isBootstrapping = false
        
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
                self?.scan()
            }
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func loadState() {
        if let data = try? Data(contentsOf: stateURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            state = json
        }
    }
    
    private func saveState() {
        if let data = try? JSONSerialization.data(withJSONObject: state, options: .prettyPrinted) {
            try? data.write(to: stateURL)
        }
    }
    
    public func scan() {
        scanAntigravity()
        scanClaude()
        scanOpenCode()
    }
    
    // MARK: - Antigravity Scanner
    private func scanAntigravity() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let brainDir = home.appendingPathComponent(".gemini/antigravity/brain")
        guard FileManager.default.fileExists(atPath: brainDir.path) else { return }
        
        guard let convDirs = try? FileManager.default.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { return }
        
        let now = Date().timeIntervalSince1970
        
        for convDir in convDirs {
            let transcriptURL = convDir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
            guard FileManager.default.fileExists(atPath: transcriptURL.path) else { continue }
            
            if let attrs = try? FileManager.default.attributesOfItem(atPath: transcriptURL.path),
               let modDate = attrs[.modificationDate] as? Date {
                if !isBootstrapping && (now - modDate.timeIntervalSince1970 > 600) {
                    continue
                }
            }
            
            let convId = convDir.lastPathComponent
            let convKey = "antigravity_\(convId)"
            
            guard let content = try? String(contentsOf: transcriptURL, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !lines.isEmpty else { continue }
            
            let subset = lines.suffix(200)
            var latestModelText: String? = nil
            var latestStep: Int = -1
            var latestCreatedAt: String = ""
            
            for line in subset.reversed() {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                
                let src = json["source"] as? String
                let typ = json["type"] as? String
                let cnt = (json["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                let tools = json["tool_calls"] as? [Any]
                let hasNoTools = (tools == nil || tools!.isEmpty)
                
                if src == "MODEL" && typ == "PLANNER_RESPONSE" && !cnt.isEmpty && hasNoTools {
                    latestModelText = cnt
                    latestStep = json["step_index"] as? Int ?? -1
                    latestCreatedAt = json["created_at"] as? String ?? ""
                    break
                }
            }
            
            if let text = latestModelText {
                let rawId = "\(latestCreatedAt)_\(latestStep)"
                
                stateLock.lock()
                let lastId = state[convKey]
                
                if isBootstrapping {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    continue
                }
                
                if lastId == nil {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    
                    let clean = TextSanitizer.sanitizeForSpeech(text)
                    if !clean.isEmpty {
                        onSpeechRequest?("Antigravity", clean)
                    }
                    continue
                }
                
                if rawId != lastId {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    
                    let clean = TextSanitizer.sanitizeForSpeech(text)
                    if !clean.isEmpty {
                        onSpeechRequest?("Antigravity", clean)
                    }
                } else {
                    stateLock.unlock()
                }
            }
        }
    }
    
    // MARK: - Claude Scanner
    private func scanClaude() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let projectsDir = home.appendingPathComponent(".claude/projects")
        guard FileManager.default.fileExists(atPath: projectsDir.path) else { return }
        
        guard let projectFolders = try? FileManager.default.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        let now = Date().timeIntervalSince1970
        
        for pFolder in projectFolders {
            guard let files = try? FileManager.default.contentsOfDirectory(at: pFolder, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { continue }
            
            for file in files where file.pathExtension == "jsonl" {
                if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                   let modDate = attrs[.modificationDate] as? Date {
                    if !isBootstrapping && (now - modDate.timeIntervalSince1970 > 600) {
                        continue
                    }
                }
                
                let sessionId = file.deletingPathExtension().lastPathComponent
                let convKey = "claude_\(sessionId)"
                
                guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
                let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                guard !lines.isEmpty else { continue }
                
                let subset = lines.suffix(200)
                var latestAssistantText: String? = nil
                var latestMsgId: String = ""
                
                for line in subset.reversed() {
                    guard let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    
                    let type = json["type"] as? String
                    let role = json["role"] as? String
                    
                    if type == "assistant" || role == "assistant" {
                        guard let msg = json["message"] as? [String: Any] else { continue }
                        if let stopReason = msg["stop_reason"] as? String, stopReason == "tool_use" { continue }
                        
                        var pieces: [String] = []
                        if let arr = msg["content"] as? [[String: Any]] {
                            for item in arr {
                                if (item["type"] as? String) == "text", let t = item["text"] as? String {
                                    pieces.append(t)
                                }
                            }
                        } else if let s = msg["content"] as? String {
                            pieces.append(s)
                        }
                        
                        let combined = pieces.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !combined.isEmpty {
                            latestAssistantText = combined
                            latestMsgId = (json["uuid"] as? String) ?? (msg["id"] as? String) ?? ""
                            break
                        }
                    }
                }
                
                if let text = latestAssistantText, !latestMsgId.isEmpty {
                    let rawId = latestMsgId
                    
                    stateLock.lock()
                    let lastId = state[convKey]
                    
                    if isBootstrapping {
                        state[convKey] = rawId
                        saveState()
                        stateLock.unlock()
                        continue
                    }
                    
                    if lastId == nil {
                        state[convKey] = rawId
                        saveState()
                        stateLock.unlock()
                        
                        let clean = TextSanitizer.sanitizeForSpeech(text)
                        if !clean.isEmpty {
                            onSpeechRequest?("Claude", clean)
                        }
                        continue
                    }
                    
                    if rawId != lastId {
                        state[convKey] = rawId
                        saveState()
                        stateLock.unlock()
                        
                        let clean = TextSanitizer.sanitizeForSpeech(text)
                        if !clean.isEmpty {
                            onSpeechRequest?("Claude", clean)
                        }
                    } else {
                        stateLock.unlock()
                    }
                }
            }
        }
    }
    
    // MARK: - OpenCode & Generic Agent Scanner
    private func scanOpenCode() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let opencodeDir = home.appendingPathComponent(".opencode/sessions")
        guard FileManager.default.fileExists(atPath: opencodeDir.path) else { return }
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: opencodeDir, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles) else { return }
        let now = Date().timeIntervalSince1970
        
        for file in files where file.pathExtension == "json" || file.pathExtension == "jsonl" {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let modDate = attrs[.modificationDate] as? Date {
                if !isBootstrapping && (now - modDate.timeIntervalSince1970 > 600) {
                    continue
                }
            }
            
            let sessionId = file.deletingPathExtension().lastPathComponent
            let convKey = "opencode_\(sessionId)"
            
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let lastLine = lines.last,
                  let data = lastLine.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            
            if let role = json["role"] as? String, role == "assistant",
               let text = json["content"] as? String, !text.isEmpty {
                let rawId = "\(file.path)_\(text.prefix(60))"
                
                stateLock.lock()
                let lastId = state[convKey]
                if isBootstrapping {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    continue
                }
                
                if lastId == nil {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    let clean = TextSanitizer.sanitizeForSpeech(text)
                    if !clean.isEmpty {
                        onSpeechRequest?("OpenCode", clean)
                    }
                    continue
                }
                
                if rawId != lastId {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    let clean = TextSanitizer.sanitizeForSpeech(text)
                    if !clean.isEmpty {
                        onSpeechRequest?("OpenCode", clean)
                    }
                } else {
                    stateLock.unlock()
                }
            }
        }
    }
    
    // MARK: - UNIX Domain Socket Listener
    private func startSocketListener() {
        unlink(socketPath)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            _ = pathBytes.withUnsafeBufferPointer { buf in
                memcpy(ptr, buf.baseAddress!, buf.count)
            }
        }
        
        let addrLen = socklen_t(MemoryLayout<sa_family_t>.size + socketPath.utf8.count + 1)
        let bindRes = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                bind(fd, saPtr, addrLen)
            }
        }
        guard bindRes == 0 else { return }
        listen(fd, 5)
        
        let queue = DispatchQueue(label: "com.agentspeak.socket")
        let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        src.setEventHandler { [weak self] in
            var clientAddr = sockaddr_un()
            var clientLen = socklen_t(MemoryLayout<sockaddr_un>.size)
            let clientFd = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                    accept(fd, saPtr, &clientLen)
                }
            }
            guard clientFd >= 0 else { return }
            
            var buffer = [UInt8](repeating: 0, count: 65536)
            let n = read(clientFd, &buffer, buffer.count)
            if n > 0 {
                let data = Data(buffer.prefix(n))
                if let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    if raw == "__CMD_SHOW_DASHBOARD__" {
                        DispatchQueue.main.async {
                            AppDelegate.shared?.showDashboard()
                        }
                    } else if raw == "__CMD_STOP_SPEECH__" {
                        DispatchQueue.main.async {
                            SpeechQueueManager.shared.stopCurrent()
                        }
                    } else if raw == "__CMD_TEST_JARVIS__" {
                        let jarvisPaths = [
                            FileManager.default.homeDirectoryForCurrentUser.path + "/Downloads/Jarvis-trimmed.wav",
                            Bundle.main.bundlePath + "/Contents/Resources/voices/Jarvis.wav",
                            FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/DEV_AREA/ssh linux/agent-speak/Resources/voices/Jarvis.wav"
                        ]
                        if let p = jarvisPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                            SpeechQueueManager.shared.playAudioFile(filePath: p, source: "Jarvis AI")
                        }
                    } else {
                        let clean = TextSanitizer.sanitizeForSpeech(raw)
                        if !clean.isEmpty {
                            self?.onSpeechRequest?("Terminal", clean)
                        }
                    }
                }
            }
            close(clientFd)
        }
        src.resume()
        self.socketSource = src
    }
}
