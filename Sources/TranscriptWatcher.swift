import Foundation

public class TranscriptWatcher {
    public static let shared = TranscriptWatcher()
    
    private var state: [String: String] = [:]
    private let stateLock = NSLock()
    private let stateURL: URL
    private var scanTimer: DispatchSourceTimer?
    private let scanQueue = DispatchQueue(label: "com.agentspeak.scanner", qos: .utility)
    private let socketPath = "/tmp/agentspeak.sock"
    private var socketSource: DispatchSourceRead?
    private var fileMetadataCache: [String: (mtime: TimeInterval, size: UInt64)] = [:]
    
    private var activeAntigravityTranscripts: [(url: URL, convId: String)] = []
    private var lastAntigravityRefresh: TimeInterval = 0
    
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
        scanQueue.async { [weak self] in
            guard let self = self else { return }
            self.scan()
            
            let timer = DispatchSource.makeTimerSource(queue: self.scanQueue)
            timer.schedule(deadline: .now() + 0.4, repeating: 0.4)
            timer.setEventHandler { [weak self] in
                self?.scan()
            }
            timer.resume()
            self.scanTimer = timer
        }
    }
    
    public func stop() {
        scanTimer?.cancel()
        scanTimer = nil
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
    
    private func readTailOfFile(at url: URL, maxBytes: Int = 524288) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        
        let fileSize = handle.seekToEndOfFile()
        if fileSize == 0 { return nil }
        let readSize = min(fileSize, UInt64(maxBytes))
        let offset = fileSize - readSize
        handle.seek(toFileOffset: offset)
        let data = handle.readData(ofLength: Int(readSize))
        return String(decoding: data, as: UTF8.self)
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
        let now = Date().timeIntervalSince1970
        
        // Refresh active candidate transcripts periodically (every 6 seconds or on startup)
        if activeAntigravityTranscripts.isEmpty || (now - lastAntigravityRefresh > 6.0) {
            lastAntigravityRefresh = now
            if let convDirs = try? FileManager.default.contentsOfDirectory(at: brainDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                var candidates: [(url: URL, convId: String)] = []
                for convDir in convDirs {
                    let transcriptURL = convDir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: transcriptURL.path),
                       let modDate = attrs[.modificationDate] as? Date {
                        let age = now - modDate.timeIntervalSince1970
                        if age < 7200 {
                            candidates.append((url: transcriptURL, convId: convDir.lastPathComponent))
                        }
                    }
                }
                activeAntigravityTranscripts = candidates
            }
        }
        
        for item in activeAntigravityTranscripts {
            let transcriptURL = item.url
            let convId = item.convId
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: transcriptURL.path),
                  let modDate = attrs[.modificationDate] as? Date,
                  let fileSize = attrs[.size] as? UInt64 else { continue }
            
            let modTime = modDate.timeIntervalSince1970
            let timeSinceMod = now - modTime
            if timeSinceMod > 7200 { continue }
            
            let tPath = transcriptURL.path
            if let cached = fileMetadataCache[tPath], cached.mtime == modTime, cached.size == fileSize {
                continue
            }
            fileMetadataCache[tPath] = (modTime, fileSize)
            
            let convKey = "antigravity_\(convId)"
            
            guard let content = readTailOfFile(at: transcriptURL) else { continue }
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !lines.isEmpty else { continue }
            
            let subset = lines.suffix(150)
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
                let rawId = "\(latestCreatedAt)_\(latestStep)_\(text.prefix(60))"
                
                stateLock.lock()
                let lastId = state[convKey]
                
                if lastId == nil && timeSinceMod > 90 {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    continue
                }
                
                if rawId != lastId {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    
                    let clean = TextSanitizer.sanitizeForSpeech(text)
                    if !clean.isEmpty {
                        DispatchQueue.main.async { [weak self] in
                            self?.onSpeechRequest?("Antigravity", clean)
                        }
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
            guard let files = try? FileManager.default.contentsOfDirectory(at: pFolder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
            
            for file in files where file.pathExtension == "jsonl" {
                guard let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                      let modDate = attrs[.modificationDate] as? Date,
                      let fileSize = attrs[.size] as? UInt64 else { continue }
                
                let modTime = modDate.timeIntervalSince1970
                let timeSinceMod = now - modTime
                if timeSinceMod > 7200 { continue }
                
                let fPath = file.path
                if let cached = fileMetadataCache[fPath], cached.mtime == modTime, cached.size == fileSize {
                    continue
                }
                fileMetadataCache[fPath] = (modTime, fileSize)
                
                let sessionId = file.deletingPathExtension().lastPathComponent
                let convKey = "claude_\(sessionId)"
                
                guard let content = readTailOfFile(at: file) else { continue }
                let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                guard !lines.isEmpty else { continue }
                
                let subset = lines.suffix(150)
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
                    let rawId = "\(latestMsgId)_\(text.prefix(60))"
                    
                    stateLock.lock()
                    let lastId = state[convKey]
                    
                    if lastId == nil && timeSinceMod > 90 {
                        state[convKey] = rawId
                        saveState()
                        stateLock.unlock()
                        continue
                    }
                    
                    if rawId != lastId {
                        state[convKey] = rawId
                        saveState()
                        stateLock.unlock()
                        
                        let clean = TextSanitizer.sanitizeForSpeech(text)
                        if !clean.isEmpty {
                            DispatchQueue.main.async { [weak self] in
                                self?.onSpeechRequest?("Claude", clean)
                            }
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
        scanOpenCodeSQLite()
        scanOpenCodeLegacyFiles()
    }
    
    private func scanOpenCodeSQLite() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dbPath = "\(home)/.local/share/opencode/opencode.db"
        let walPath = "\(home)/.local/share/opencode/opencode.db-wal"
        guard FileManager.default.fileExists(atPath: dbPath) else { return }
        
        let now = Date().timeIntervalSince1970
        var targetPath = dbPath
        if FileManager.default.fileExists(atPath: walPath) {
            targetPath = walPath
        }
        
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: targetPath),
              let modDate = attrs[.modificationDate] as? Date,
              let fileSize = attrs[.size] as? UInt64 else { return }
        
        let modTime = modDate.timeIntervalSince1970
        let timeSinceMod = now - modTime
        if timeSinceMod > 7200 { return }
        
        if let cached = fileMetadataCache[targetPath], cached.mtime == modTime, cached.size == fileSize {
            return
        }
        fileMetadataCache[targetPath] = (modTime, fileSize)
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        proc.arguments = [
            dbPath,
            "SELECT part.id, json_extract(part.data, '$.text') FROM part JOIN message ON part.message_id = message.id WHERE json_extract(message.data, '$.role') = 'assistant' AND json_extract(part.data, '$.type') = 'text' ORDER BY part.time_created DESC LIMIT 1;"
        ]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return }
        
        let parts = str.components(separatedBy: "|")
        guard parts.count >= 2 else { return }
        let partId = parts[0]
        let text = parts.dropFirst().joined(separator: "|")
        
        let convKey = "opencode_sqlite_latest"
        stateLock.lock()
        let lastId = state[convKey]
        
        if lastId == nil && timeSinceMod > 90 {
            state[convKey] = partId
            saveState()
            stateLock.unlock()
            return
        }
        
        if partId != lastId {
            state[convKey] = partId
            saveState()
            stateLock.unlock()
            
            let clean = TextSanitizer.sanitizeForSpeech(text)
            if !clean.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.onSpeechRequest?("OpenCode", clean)
                }
            }
        } else {
            stateLock.unlock()
        }
    }
    
    private func scanOpenCodeLegacyFiles() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let opencodeDir = home.appendingPathComponent(".opencode/sessions")
        guard FileManager.default.fileExists(atPath: opencodeDir.path) else { return }
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: opencodeDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        let now = Date().timeIntervalSince1970
        
        for file in files where file.pathExtension == "json" || file.pathExtension == "jsonl" {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                  let modDate = attrs[.modificationDate] as? Date,
                  let fileSize = attrs[.size] as? UInt64 else { continue }
            
            let modTime = modDate.timeIntervalSince1970
            let timeSinceMod = now - modTime
            if timeSinceMod > 7200 { continue }
            
            let fPath = file.path
            if let cached = fileMetadataCache[fPath], cached.mtime == modTime, cached.size == fileSize {
                continue
            }
            fileMetadataCache[fPath] = (modTime, fileSize)
            
            let sessionId = file.deletingPathExtension().lastPathComponent
            let convKey = "opencode_\(sessionId)"
            
            guard let content = readTailOfFile(at: file) else { continue }
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let lastLine = lines.last,
                  let data = lastLine.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            
            if let role = json["role"] as? String, role == "assistant",
               let text = json["content"] as? String, !text.isEmpty {
                let rawId = "\(file.path)_\(text.prefix(60))"
                
                stateLock.lock()
                let lastId = state[convKey]
                if lastId == nil && timeSinceMod > 90 {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    continue
                }
                
                if rawId != lastId {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    let clean = TextSanitizer.sanitizeForSpeech(text)
                    if !clean.isEmpty {
                        DispatchQueue.main.async { [weak self] in
                            self?.onSpeechRequest?("OpenCode", clean)
                        }
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
        addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        addr.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = socketPath.utf8CString
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            _ = pathBytes.withUnsafeBufferPointer { buf in
                memcpy(ptr, buf.baseAddress!, buf.count)
            }
        }
        
        let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bindRes = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                bind(fd, saPtr, addrLen)
            }
        }
        NSLog("[AgentSpeak] Socket fd: %d, bindRes: %d, errno: %d", fd, bindRes, errno)
        guard bindRes == 0 else {
            close(fd)
            return
        }
        let listenRes = listen(fd, 5)
        NSLog("[AgentSpeak] Socket listenRes: %d", listenRes)
        
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
                    } else if raw == "__CMD_SPEAK_SELECTED__" {
                        DispatchQueue.main.async {
                            AppDelegate.shared?.speakSelected()
                        }
                    } else if raw == "__CMD_SPEAK_CLIPBOARD__" {
                        DispatchQueue.main.async {
                            AppDelegate.shared?.speakClipboard()
                        }
                    } else if raw == "__PING__" {
                        // Health check ping, no action required
                    } else if raw == "__CMD_TRAY_ON__" {
                        DispatchQueue.main.async {
                            AppDelegate.shared?.setTrayIconVisible(true)
                        }
                    } else if raw == "__CMD_TRAY_OFF__" {
                        DispatchQueue.main.async {
                            AppDelegate.shared?.setTrayIconVisible(false)
                        }
                    } else if raw == "__CMD_TOGGLE_TRAY__" {
                        DispatchQueue.main.async {
                            let cur = AppDelegate.shared?.isTrayIconVisible ?? true
                            AppDelegate.shared?.setTrayIconVisible(!cur)
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
                    } else if raw == "__CMD_BGM_ON__" {
                        DispatchQueue.main.async {
                            BackgroundMusicManager.shared.isEnabled = true
                            BackgroundMusicManager.shared.saveConfig()
                        }
                    } else if raw == "__CMD_BGM_OFF__" {
                        DispatchQueue.main.async {
                            BackgroundMusicManager.shared.isEnabled = false
                            BackgroundMusicManager.shared.saveConfig()
                            BackgroundMusicManager.shared.stopImmediately()
                        }
                    } else if raw == "__CMD_BGM_TOGGLE__" {
                        DispatchQueue.main.async {
                            let cur = BackgroundMusicManager.shared.isEnabled
                            BackgroundMusicManager.shared.isEnabled = !cur
                            BackgroundMusicManager.shared.saveConfig()
                            if cur {
                                BackgroundMusicManager.shared.stopImmediately()
                            }
                        }
                    } else if raw == "__CMD_BGM_OPEN__" {
                        DispatchQueue.main.async {
                            BackgroundMusicManager.shared.openBgmFolderInFinder()
                        }
                    } else if raw == "__CMD_BGM_TEST__" {
                        DispatchQueue.main.async {
                            BackgroundMusicManager.shared.start()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                BackgroundMusicManager.shared.stopWithFadeAndReverb()
                            }
                        }
                    } else if raw.hasPrefix("__CMD_BGM_VOL_") && raw.hasSuffix("__") {
                        let inner = raw.replacingOccurrences(of: "__CMD_BGM_VOL_", with: "").replacingOccurrences(of: "__", with: "")
                        if let intVal = Float(inner) {
                            let vol = intVal / 100.0
                            DispatchQueue.main.async {
                                BackgroundMusicManager.shared.setVolume(vol)
                            }
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
