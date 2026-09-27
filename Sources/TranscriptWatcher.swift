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
    private let appStartTime = Date().timeIntervalSince1970
    
    private static let isoFormatterWithMillis: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterStandard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseISO8601Date(_ str: String) -> Date? {
        if let d = Self.isoFormatterWithMillis.date(from: str) { return d }
        return Self.isoFormatterStandard.date(from: str)
    }
    
    private var activeAntigravityTranscripts: [(url: URL, convId: String)] = []
    private var lastAntigravityRefresh: TimeInterval = 0
    
    public var onSpeechRequest: ((_ source: String, _ text: String) -> Void)?
    public var isAntigravityEnabled: Bool = true
    public var isClaudeEnabled: Bool = true
    public var isOpenCodeEnabled: Bool = true
    public var isTerminalEnabled: Bool = true
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".agentspeak")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        stateURL = dir.appendingPathComponent("state.json")
        loadState()
        loadWorkspacesConfig()
        startSocketListener()
    }
    
    public func loadWorkspacesConfig() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let workspaces = json["workspaces"] as? [String: Any] else { return }
        if let ag = workspaces["antigravity"] as? Bool { isAntigravityEnabled = ag }
        if let cl = workspaces["claude"] as? Bool { isClaudeEnabled = cl }
        if let oc = workspaces["opencode"] as? Bool { isOpenCodeEnabled = oc }
        if let tm = workspaces["terminal"] as? Bool { isTerminalEnabled = tm }
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
        if isAntigravityEnabled { scanAntigravity() }
        if isClaudeEnabled { scanClaude() }
        if isOpenCodeEnabled { scanOpenCode() }
        UniversalConnectorWatcher.shared.scan { [weak self] source, text in
            self?.onSpeechRequest?(source, text)
        }
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
                    let fullURL = convDir.appendingPathComponent(".system_generated/logs/transcript_full.jsonl")
                    let compactURL = convDir.appendingPathComponent(".system_generated/logs/transcript.jsonl")
                    let transcriptURL = FileManager.default.fileExists(atPath: fullURL.path) ? fullURL : compactURL
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
            
            guard let content = readTailOfFile(at: transcriptURL, maxBytes: 1048576) else { continue }
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
            
            if let rawText = latestModelText {
                let text = resolveUntruncatedAntigravityText(convId: convId, stepIndex: latestStep, fallbackText: rawText)
                let rawId = "\(latestCreatedAt)_\(latestStep)_\(text.prefix(60))"
                
                var isFresh = false
                if let msgDate = parseISO8601Date(latestCreatedAt) {
                    let age = now - msgDate.timeIntervalSince1970
                    let isAfterAppLaunch = (msgDate.timeIntervalSince1970 >= (appStartTime - 5.0))
                    isFresh = (age >= -5.0 && age <= 30.0 && isAfterAppLaunch)
                } else {
                    isFresh = (timeSinceMod <= 30.0)
                }
                
                stateLock.lock()
                let lastId = state[convKey]
                
                if lastId == nil {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    
                    if isFresh {
                        let clean = TextSanitizer.sanitizeForSpeech(text)
                        if !clean.isEmpty {
                            DispatchQueue.main.async { [weak self] in
                                self?.onSpeechRequest?("Antigravity", clean)
                            }
                        }
                    }
                    continue
                }
                
                if rawId != lastId {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    
                    if isFresh {
                        let clean = TextSanitizer.sanitizeForSpeech(text)
                        if !clean.isEmpty {
                            DispatchQueue.main.async { [weak self] in
                                self?.onSpeechRequest?("Antigravity", clean)
                            }
                        }
                    }
                } else {
                    stateLock.unlock()
                }
            }
        }
    }
    
    private func resolveUntruncatedAntigravityText(convId: String, stepIndex: Int, fallbackText: String) -> String {
        guard fallbackText.contains("<truncated") else { return fallbackText }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let fullURL = home.appendingPathComponent(".gemini/antigravity/brain/\(convId)/.system_generated/logs/transcript_full.jsonl")
        guard FileManager.default.fileExists(atPath: fullURL.path),
              let content = readTailOfFile(at: fullURL, maxBytes: 2097152) else {
            return fallbackText
        }
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        for line in lines.suffix(150).reversed() {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let step = json["step_index"] as? Int, step == stepIndex,
                  let full = (json["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !full.isEmpty else { continue }
            return full
        }
        return fallbackText
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
                var latestMsgCreatedAt: String = ""
                
                for line in subset.reversed() {
                    guard let data = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                    
                    // Filter out synthetic error notifications and API errors
                    if json["isApiErrorMessage"] as? Bool == true { continue }
                    if json["error"] != nil { continue }
                    
                    let type = json["type"] as? String
                    let role = json["role"] as? String
                    
                    if type == "assistant" || role == "assistant" {
                        guard let msg = json["message"] as? [String: Any] else { continue }
                        
                        // Filter out synthetic models (e.g. "<synthetic>")
                        if let model = msg["model"] as? String {
                            if model == "<synthetic>" || model.lowercased().contains("synthetic") {
                                continue
                            }
                        }
                        
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
                        if combined.isEmpty || combined == "No response requested." || combined.hasPrefix("API Error:") {
                            continue
                        }
                        
                        latestAssistantText = combined
                        latestMsgId = (json["uuid"] as? String) ?? (msg["id"] as? String) ?? ""
                        latestMsgCreatedAt = json["timestamp"] as? String ?? ""
                        break
                    }
                }
                
                if let text = latestAssistantText, !latestMsgId.isEmpty {
                    let rawId = "\(latestMsgId)_\(text.prefix(60))"
                    
                    var isFresh = false
                    if let msgDate = parseISO8601Date(latestMsgCreatedAt) {
                        let age = now - msgDate.timeIntervalSince1970
                        let isAfterAppLaunch = (msgDate.timeIntervalSince1970 >= (appStartTime - 5.0))
                        isFresh = (age >= -5.0 && age <= 30.0 && isAfterAppLaunch)
                    } else {
                        isFresh = (timeSinceMod <= 30.0)
                    }
                    
                    stateLock.lock()
                    let lastId = state[convKey]
                    
                    if lastId == nil {
                        state[convKey] = rawId
                        saveState()
                        stateLock.unlock()
                        
                        if isFresh {
                            let clean = TextSanitizer.sanitizeForSpeech(text)
                            if !clean.isEmpty {
                                DispatchQueue.main.async { [weak self] in
                                    self?.onSpeechRequest?("Claude", clean)
                                }
                            }
                        }
                        continue
                    }
                    
                    if rawId != lastId {
                        state[convKey] = rawId
                        saveState()
                        stateLock.unlock()
                        
                        if isFresh {
                            let clean = TextSanitizer.sanitizeForSpeech(text)
                            if !clean.isEmpty {
                                DispatchQueue.main.async { [weak self] in
                                    self?.onSpeechRequest?("Claude", clean)
                                }
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
            "SELECT part.id, json_extract(part.data, '$.text'), part.time_created FROM part JOIN message ON part.message_id = message.id WHERE json_extract(message.data, '$.role') = 'assistant' AND json_extract(part.data, '$.type') = 'text' ORDER BY part.time_created DESC LIMIT 1;"
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
        let timeMillis = (parts.count >= 3 ? Double(parts[parts.count - 1]) : nil) ?? 0
        let textParts = parts.count >= 3 ? parts[1..<(parts.count - 1)] : parts[1...]
        let text = textParts.joined(separator: "|")
        
        let createdSec = timeMillis > 100000000000 ? (timeMillis / 1000.0) : timeMillis
        var isFresh = false
        if createdSec > 0 {
            let age = now - createdSec
            let isAfterLaunch = (createdSec >= (appStartTime - 5.0))
            isFresh = (age >= -5.0 && age <= 30.0 && isAfterLaunch)
        } else {
            isFresh = (timeSinceMod <= 30.0)
        }
        
        let convKey = "opencode_sqlite_latest"
        stateLock.lock()
        let lastId = state[convKey]
        
        if lastId == nil {
            state[convKey] = partId
            saveState()
            stateLock.unlock()
            
            if isFresh {
                let clean = TextSanitizer.sanitizeForSpeech(text)
                if !clean.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        self?.onSpeechRequest?("OpenCode", clean)
                    }
                }
            }
            return
        }
        
        if partId != lastId {
            state[convKey] = partId
            saveState()
            stateLock.unlock()
            
            if isFresh {
                let clean = TextSanitizer.sanitizeForSpeech(text)
                if !clean.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        self?.onSpeechRequest?("OpenCode", clean)
                    }
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
                
                var isFresh = false
                if let tsStr = json["timestamp"] as? String ?? json["created_at"] as? String,
                   let msgDate = parseISO8601Date(tsStr) {
                    let age = now - msgDate.timeIntervalSince1970
                    let isAfterAppLaunch = (msgDate.timeIntervalSince1970 >= (appStartTime - 5.0))
                    isFresh = (age >= -5.0 && age <= 30.0 && isAfterAppLaunch)
                } else {
                    isFresh = (timeSinceMod <= 30.0)
                }
                
                stateLock.lock()
                let lastId = state[convKey]
                if lastId == nil {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    
                    if isFresh {
                        let clean = TextSanitizer.sanitizeForSpeech(text)
                        if !clean.isEmpty {
                            DispatchQueue.main.async { [weak self] in
                                self?.onSpeechRequest?("OpenCode", clean)
                            }
                        }
                    }
                    continue
                }
                
                if rawId != lastId {
                    state[convKey] = rawId
                    saveState()
                    stateLock.unlock()
                    if isFresh {
                        let clean = TextSanitizer.sanitizeForSpeech(text)
                        if !clean.isEmpty {
                            DispatchQueue.main.async { [weak self] in
                                self?.onSpeechRequest?("OpenCode", clean)
                            }
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
            defer { close(clientFd) }
            
            var fullData = Data()
            var chunk = [UInt8](repeating: 0, count: 16384)
            while true {
                let n = read(clientFd, &chunk, chunk.count)
                if n > 0 {
                    fullData.append(chunk, count: n)
                } else {
                    break
                }
            }
            
            if !fullData.isEmpty {
                if let raw = String(data: fullData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
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
                    } else if raw == "__CMD_SPEAK_CODE_ON__" {
                        DispatchQueue.main.async {
                            CodeSpeechManager.shared.setSpeakCodeBlocks(true)
                        }
                    } else if raw == "__CMD_SPEAK_CODE_OFF__" {
                        DispatchQueue.main.async {
                            CodeSpeechManager.shared.setSpeakCodeBlocks(false)
                        }
                    } else if raw == "__CMD_TOGGLE_SPEAK_CODE__" {
                        DispatchQueue.main.async {
                            CodeSpeechManager.shared.toggle()
                        }
                    } else if raw == "__CMD_TEST_JARVIS__" {
                        let jarvisPaths = [
                            Bundle.main.bundlePath + "/Contents/Resources/voices/Jarvis.wav",
                            FileManager.default.homeDirectoryForCurrentUser.path + "/.agentspeak/extensions/pocket-tts/voices/Jarvis.wav",
                            FileManager.default.homeDirectoryForCurrentUser.path + "/.agentspeak/voices/Jarvis.wav"
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
                    } else if raw.hasPrefix("__CMD_VOICE_VOL_") && raw.hasSuffix("__") {
                        let inner = raw.replacingOccurrences(of: "__CMD_VOICE_VOL_", with: "").replacingOccurrences(of: "__", with: "")
                        if let intVal = Int(inner) {
                            DispatchQueue.main.async {
                                VoiceVolumeManager.shared.setVolume(intVal)
                            }
                        }
                    } else if raw == "__CMD_GREET__" {
                        let greeting = PersonaGreetingManager.shared.resolveGreeting()
                        DispatchQueue.main.async {
                            SpeechQueueManager.shared.enqueue(source: greeting.character, text: greeting.text)
                        }
                    } else if raw == "__CMD_HOLOGRAM_ON__" {
                        DispatchQueue.main.async {
                            HologramManager.shared.setEnabled(true)
                        }
                    } else if raw == "__CMD_HOLOGRAM_OFF__" {
                        DispatchQueue.main.async {
                            HologramManager.shared.setEnabled(false)
                        }
                    } else if raw == "__CMD_HOLOGRAM_TOGGLE__" {
                        DispatchQueue.main.async {
                            let cur = HologramManager.shared.isEnabled
                            HologramManager.shared.setEnabled(!cur)
                        }
                    } else if raw == "__CMD_HOLOGRAM_PREVIEW__" {
                        DispatchQueue.main.async {
                            HologramManager.shared.triggerPreview()
                        }
                    } else if raw.hasPrefix("__CMD_HOLOGRAM_COLOR_") && raw.hasSuffix("__") {
                        let colorId = raw.replacingOccurrences(of: "__CMD_HOLOGRAM_COLOR_", with: "").replacingOccurrences(of: "__", with: "").lowercased()
                        DispatchQueue.main.async {
                            HologramManager.shared.setTheme(id: colorId)
                        }
                    } else if raw.hasPrefix("__CMD_HOLOGRAM_SKIN_") && raw.hasSuffix("__") {
                        let skinId = raw.replacingOccurrences(of: "__CMD_HOLOGRAM_SKIN_", with: "").replacingOccurrences(of: "__", with: "")
                        DispatchQueue.main.async {
                            HologramManager.shared.setSkin(id: skinId)
                        }
                    } else if raw.hasPrefix("__CMD_HOLOGRAM_BLEND_") && raw.hasSuffix("__") {
                        let blendId = raw.replacingOccurrences(of: "__CMD_HOLOGRAM_BLEND_", with: "").replacingOccurrences(of: "__", with: "")
                        DispatchQueue.main.async {
                            HologramManager.shared.setBlendMode(id: blendId)
                        }
                    } else if raw.hasPrefix("__CMD_HOLOGRAM_OPACITY_") && raw.hasSuffix("__") {
                        let opStr = raw.replacingOccurrences(of: "__CMD_HOLOGRAM_OPACITY_", with: "").replacingOccurrences(of: "__", with: "")
                        if let val = Double(opStr) {
                            DispatchQueue.main.async {
                                HologramManager.shared.setOpacity(val > 1.0 ? val / 100.0 : val)
                            }
                        }
                    } else if raw == "__CMD_GESTURE_ON__" {
                        DispatchQueue.main.async {
                            CameraGestureManager.shared.start()
                        }
                    } else if raw == "__CMD_GESTURE_OFF__" {
                        DispatchQueue.main.async {
                            CameraGestureManager.shared.stop()
                        }
                    } else if raw == "__CMD_GESTURE_TOGGLE__" {
                        DispatchQueue.main.async {
                            CameraGestureManager.shared.toggle()
                        }
                    } else if raw == "__CMD_GESTURE_HUD_ON__" {
                        DispatchQueue.main.async {
                            CameraGestureManager.shared.isHUDEnabled = true
                            GestureHUDController.shared.show()
                        }
                    } else if raw == "__CMD_GESTURE_HUD_OFF__" {
                        DispatchQueue.main.async {
                            CameraGestureManager.shared.isHUDEnabled = false
                            GestureHUDController.shared.hide()
                        }
                    } else if raw == "__CMD_GESTURE_PREVIEW_ON__" {
                        DispatchQueue.main.async {
                            CameraGestureManager.shared.isSkeletonPreviewEnabled = true
                            TraySkeletonHUDController.shared.show()
                        }
                    } else if raw == "__CMD_GESTURE_PREVIEW_OFF__" {
                        DispatchQueue.main.async {
                            CameraGestureManager.shared.isSkeletonPreviewEnabled = false
                            TraySkeletonHUDController.shared.hide()
                        }
                    } else if raw == "__CMD_GESTURE_PREVIEW_TOGGLE__" {
                        DispatchQueue.main.async {
                            let cur = CameraGestureManager.shared.isSkeletonPreviewEnabled
                            CameraGestureManager.shared.isSkeletonPreviewEnabled = !cur
                            if !cur {
                                TraySkeletonHUDController.shared.show()
                            } else {
                                TraySkeletonHUDController.shared.hide()
                            }
                        }
                    } else if raw == "__CMD_FN_DICTATION_ON__" {
                        DispatchQueue.main.async {
                            GroqWhisperManager.shared.fnHoldDictationEnabled = true
                            GroqWhisperManager.shared.saveConfig()
                            FnDictationController.shared.start()
                        }
                    } else if raw == "__CMD_FN_DICTATION_OFF__" {
                        DispatchQueue.main.async {
                            GroqWhisperManager.shared.fnHoldDictationEnabled = false
                            GroqWhisperManager.shared.saveConfig()
                        }
                    } else if raw == "__CMD_FN_DICTATION_TOGGLE__" {
                        DispatchQueue.main.async {
                            let cur = GroqWhisperManager.shared.fnHoldDictationEnabled
                            GroqWhisperManager.shared.fnHoldDictationEnabled = !cur
                            GroqWhisperManager.shared.saveConfig()
                        }
                    } else if raw.hasPrefix("__CMD_DICTATION_KEY__:") {
                        let keyId = String(raw.dropFirst("__CMD_DICTATION_KEY__:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                        DispatchQueue.main.async {
                            if let preset = DictationKeyPreset.standardPresets.first(where: { $0.id.lowercased() == keyId.lowercased() }) {
                                GroqWhisperManager.shared.setPresetTriggerKey(preset)
                                FnDictationController.shared.stop()
                                FnDictationController.shared.start()
                            }
                        }
                    } else if raw == "__CMD_RELOAD_CONNECTORS__" {
                        DispatchQueue.main.async {
                            UniversalConnectorManager.shared.loadConnectors()
                        }
                    } else {
                        guard self?.isTerminalEnabled == true else { return }
                        let clean = TextSanitizer.sanitizeForSpeech(raw)
                        if !clean.isEmpty {
                            self?.onSpeechRequest?("Terminal", clean)
                        }
                    }
                }
            }
        }
        src.resume()
        self.socketSource = src
    }
}
