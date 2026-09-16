import Foundation

public class UniversalConnectorWatcher {
    public static let shared = UniversalConnectorWatcher()
    
    private var fileMetadataCache: [String: (mtime: TimeInterval, size: UInt64)] = [:]
    private var state: [String: String] = [:]
    private let stateLock = NSLock()
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
    
    private init() {}
    
    // MARK: - Master Scan Method
    public func scan(onSpeech: @escaping (_ source: String, _ text: String) -> Void) {
        let manager = UniversalConnectorManager.shared
        
        // 1. Scan enabled presets
        for preset in manager.presetConnectors where preset.isEnabled {
            scanConnector(preset, onSpeech: onSpeech)
        }
        
        // 2. Scan enabled custom connectors
        for custom in manager.customConnectors where custom.isEnabled {
            scanConnector(custom, onSpeech: onSpeech)
        }
    }
    
    // MARK: - Connector Dispatcher
    private func scanConnector(_ connector: AssistantConnector, onSpeech: @escaping (String, String) -> Void) {
        switch connector.id {
        case "preset_cursor":
            scanCursor(connector: connector, onSpeech: onSpeech)
        case "preset_cline", "preset_roocode":
            scanVSCodeExtensionTasks(connector: connector, onSpeech: onSpeech)
        case "preset_windsurf":
            scanWindsurf(connector: connector, onSpeech: onSpeech)
        case "preset_aider":
            scanAider(connector: connector, onSpeech: onSpeech)
        case "preset_hermes":
            scanHermesLogs(connector: connector, onSpeech: onSpeech)
        default:
            scanGenericConnector(connector: connector, onSpeech: onSpeech)
        }
    }
    
    // MARK: - Helper: Read Tail of File
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
    
    // MARK: - Cline & Roo Code Scanner
    private func scanVSCodeExtensionTasks(connector: AssistantConnector, onSpeech: @escaping (String, String) -> Void) {
        let tasksDir = URL(fileURLWithPath: connector.path)
        guard FileManager.default.fileExists(atPath: tasksDir.path) else { return }
        
        guard let taskFolders = try? FileManager.default.contentsOfDirectory(at: tasksDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        let now = Date().timeIntervalSince1970
        
        for taskFolder in taskFolders {
            let uiMessagesURL = taskFolder.appendingPathComponent("ui_messages.json")
            guard FileManager.default.fileExists(atPath: uiMessagesURL.path),
                  let attrs = try? FileManager.default.attributesOfItem(atPath: uiMessagesURL.path),
                  let modDate = attrs[.modificationDate] as? Date,
                  let fileSize = attrs[.size] as? UInt64 else { continue }
            
            let modTime = modDate.timeIntervalSince1970
            if now - modTime > 3600 { continue }
            
            let fPath = uiMessagesURL.path
            if let cached = fileMetadataCache[fPath], cached.mtime == modTime, cached.size == fileSize {
                continue
            }
            fileMetadataCache[fPath] = (modTime, fileSize)
            
            guard let content = readTailOfFile(at: uiMessagesURL, maxBytes: 262144),
                  let data = content.data(using: .utf8),
                  let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  !jsonArray.isEmpty else { continue }
            
            // Find latest assistant text message
            for msg in jsonArray.reversed() {
                let sayType = msg["say"] as? String
                let msgType = msg["type"] as? String
                guard sayType == "text" || msgType == "say" else { continue }
                
                guard let text = (msg["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !text.isEmpty else { continue }
                
                let tsVal = (msg["ts"] as? Double) ?? 0.0
                let tsSec = tsVal > 100000000000 ? (tsVal / 1000.0) : tsVal
                let isFresh = (now - tsSec <= 30.0) && (tsSec >= (appStartTime - 5.0))
                
                let rawId = "\(fPath)_\(tsVal)_\(text.prefix(60))"
                let convKey = "\(connector.id)_\(taskFolder.lastPathComponent)"
                
                stateLock.lock()
                let lastId = state[convKey]
                if lastId != rawId {
                    state[convKey] = rawId
                    stateLock.unlock()
                    
                    if isFresh {
                        let clean = TextSanitizer.sanitizeForSpeech(text)
                        if !clean.isEmpty {
                            DispatchQueue.main.async {
                                onSpeech(connector.name, clean)
                            }
                        }
                    }
                } else {
                    stateLock.unlock()
                }
                break
            }
        }
    }
    
    // MARK: - Hermes AI & OpenClaw Scanner
    private func scanHermesLogs(connector: AssistantConnector, onSpeech: @escaping (String, String) -> Void) {
        let logsDir = URL(fileURLWithPath: connector.path)
        guard FileManager.default.fileExists(atPath: logsDir.path) else { return }
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        let now = Date().timeIntervalSince1970
        
        for file in files where file.pathExtension == "jsonl" || file.pathExtension == "log" {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
                  let modDate = attrs[.modificationDate] as? Date,
                  let fileSize = attrs[.size] as? UInt64 else { continue }
            
            let modTime = modDate.timeIntervalSince1970
            if now - modTime > 3600 { continue }
            
            let fPath = file.path
            if let cached = fileMetadataCache[fPath], cached.mtime == modTime, cached.size == fileSize {
                continue
            }
            fileMetadataCache[fPath] = (modTime, fileSize)
            
            guard let content = readTailOfFile(at: file, maxBytes: 262144) else { continue }
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let lastLine = lines.last,
                  let data = lastLine.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            
            let role = json[connector.roleKey] as? String
            let text = (json[connector.textKey] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if (role == "assistant" || role == "model" || role == "agent") && text != nil && !text!.isEmpty {
                let cleanText = text!
                let rawId = "\(fPath)_\(cleanText.prefix(60))"
                let convKey = "\(connector.id)_\(file.lastPathComponent)"
                let isFresh = (now - modTime <= 30.0) && (modTime >= (appStartTime - 5.0))
                
                stateLock.lock()
                let lastId = state[convKey]
                if lastId != rawId {
                    state[convKey] = rawId
                    stateLock.unlock()
                    
                    if isFresh {
                        let clean = TextSanitizer.sanitizeForSpeech(cleanText)
                        if !clean.isEmpty {
                            DispatchQueue.main.async {
                                onSpeech(connector.name, clean)
                            }
                        }
                    }
                } else {
                    stateLock.unlock()
                }
            }
        }
    }
    
    // MARK: - Aider Scanner
    private func scanAider(connector: AssistantConnector, onSpeech: @escaping (String, String) -> Void) {
        let fileURL = URL(fileURLWithPath: connector.path)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date,
              let fileSize = attrs[.size] as? UInt64 else { return }
        
        let now = Date().timeIntervalSince1970
        let modTime = modDate.timeIntervalSince1970
        if now - modTime > 1800 { return }
        
        let fPath = fileURL.path
        if let cached = fileMetadataCache[fPath], cached.mtime == modTime, cached.size == fileSize {
            return
        }
        fileMetadataCache[fPath] = (modTime, fileSize)
        
        guard let content = readTailOfFile(at: fileURL, maxBytes: 131072) else { return }
        let sections = content.components(separatedBy: "\n#### ")
        guard let lastSection = sections.last, !lastSection.isEmpty else { return }
        
        let lines = lastSection.components(separatedBy: .newlines)
        let bodyLines = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bodyLines.isEmpty else { return }
        
        let rawId = "\(fPath)_\(bodyLines.prefix(60))"
        let convKey = connector.id
        let isFresh = (now - modTime <= 25.0) && (modTime >= (appStartTime - 5.0))
        
        stateLock.lock()
        let lastId = state[convKey]
        if lastId != rawId {
            state[convKey] = rawId
            stateLock.unlock()
            
            if isFresh {
                let clean = TextSanitizer.sanitizeForSpeech(bodyLines)
                if !clean.isEmpty {
                    DispatchQueue.main.async {
                        onSpeech(connector.name, clean)
                    }
                }
            }
        } else {
            stateLock.unlock()
        }
    }
    
    // MARK: - Cursor & Windsurf SQLite Scanner
    private func scanCursor(connector: AssistantConnector, onSpeech: @escaping (String, String) -> Void) {
        scanVSCDBStorage(connector: connector, appName: "Cursor", onSpeech: onSpeech)
    }
    
    private func scanWindsurf(connector: AssistantConnector, onSpeech: @escaping (String, String) -> Void) {
        scanVSCDBStorage(connector: connector, appName: "Windsurf", onSpeech: onSpeech)
    }
    
    private func scanVSCDBStorage(connector: AssistantConnector, appName: String, onSpeech: @escaping (String, String) -> Void) {
        let storageDir = URL(fileURLWithPath: connector.path)
        guard FileManager.default.fileExists(atPath: storageDir.path) else { return }
        
        guard let workspaces = try? FileManager.default.contentsOfDirectory(at: storageDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
        let now = Date().timeIntervalSince1970
        
        for ws in workspaces {
            let dbFile = ws.appendingPathComponent("state.vscdb")
            guard FileManager.default.fileExists(atPath: dbFile.path),
                  let attrs = try? FileManager.default.attributesOfItem(atPath: dbFile.path),
                  let modDate = attrs[.modificationDate] as? Date,
                  let fileSize = attrs[.size] as? UInt64 else { continue }
            
            let modTime = modDate.timeIntervalSince1970
            if now - modTime > 1800 { continue }
            
            let fPath = dbFile.path
            if let cached = fileMetadataCache[fPath], cached.mtime == modTime, cached.size == fileSize {
                continue
            }
            fileMetadataCache[fPath] = (modTime, fileSize)
            
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
            proc.arguments = [
                fPath,
                "SELECT value FROM ItemTable WHERE key = 'workbench.panel.aichat.view.state' OR key = 'composer.composerData' LIMIT 1;"
            ]
            let pipe = Pipe()
            proc.standardOutput = pipe
            try? proc.run()
            proc.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let rawStr = String(data: data, encoding: .utf8), !rawStr.isEmpty else { continue }
            
            // Extract the last assistant response
            if let jsonData = rawStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                var foundText: String? = nil
                if let tabs = json["tabs"] as? [[String: Any]], let lastTab = tabs.last,
                   let bubbles = lastTab["bubbles"] as? [[String: Any]] {
                    for b in bubbles.reversed() {
                        if (b["type"] as? String) == "ai", let txt = b["rawText"] as? String, !txt.isEmpty {
                            foundText = txt
                            break
                        }
                    }
                }
                
                if let txt = foundText {
                    let rawId = "\(fPath)_\(txt.prefix(60))"
                    let convKey = "\(connector.id)_\(ws.lastPathComponent)"
                    let isFresh = (now - modTime <= 25.0) && (modTime >= (appStartTime - 5.0))
                    
                    stateLock.lock()
                    let lastId = state[convKey]
                    if lastId != rawId {
                        state[convKey] = rawId
                        stateLock.unlock()
                        
                        if isFresh {
                            let clean = TextSanitizer.sanitizeForSpeech(txt)
                            if !clean.isEmpty {
                                DispatchQueue.main.async {
                                    onSpeech(connector.name, clean)
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
    
    // MARK: - Generic Custom Connector Scanner
    private func scanGenericConnector(connector: AssistantConnector, onSpeech: @escaping (String, String) -> Void) {
        let path = connector.path
        let fileURL = URL(fileURLWithPath: path)
        let fm = FileManager.default
        
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return }
        
        if isDir.boolValue {
            guard let files = try? fm.contentsOfDirectory(at: fileURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { return }
            for f in files {
                scanSingleGenericFile(fileURL: f, connector: connector, onSpeech: onSpeech)
            }
        } else {
            scanSingleGenericFile(fileURL: fileURL, connector: connector, onSpeech: onSpeech)
        }
    }
    
    private func scanSingleGenericFile(fileURL: URL, connector: AssistantConnector, onSpeech: @escaping (String, String) -> Void) {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date,
              let fileSize = attrs[.size] as? UInt64 else { return }
        
        let now = Date().timeIntervalSince1970
        let modTime = modDate.timeIntervalSince1970
        if now - modTime > 3600 { return }
        
        let fPath = fileURL.path
        if let cached = fileMetadataCache[fPath], cached.mtime == modTime, cached.size == fileSize {
            return
        }
        fileMetadataCache[fPath] = (modTime, fileSize)
        
        guard let content = readTailOfFile(at: fileURL) else { return }
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let lastLine = lines.last else { return }
        
        var assistantText: String? = nil
        
        switch connector.format {
        case .jsonl:
            if let data = lastLine.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let roleVal = (json["role"] as? String)?.lowercased()
                    ?? (json["type"] as? String)?.lowercased()
                    ?? (json[connector.roleKey] as? String)?.lowercased()
                
                let isRoleMatch = roleVal == nil || roleVal == "assistant" || roleVal == "model" || roleVal == "agent" || roleVal == connector.roleKey.lowercased()
                
                let extracted = (json[connector.textKey] as? String)
                    ?? (json["content"] as? String)
                    ?? (json["text"] as? String)
                    ?? (json["message"] as? String)
                    ?? (json["response"] as? String)
                
                if isRoleMatch, let text = extracted {
                    assistantText = text
                }
            }
        case .json:
            if let fullData = content.data(using: .utf8) {
                if let array = try? JSONSerialization.jsonObject(with: fullData) as? [[String: Any]], let lastItem = array.last {
                    let roleVal = (lastItem["role"] as? String)?.lowercased()
                        ?? (lastItem["type"] as? String)?.lowercased()
                        ?? (lastItem[connector.roleKey] as? String)?.lowercased()
                    let isRoleMatch = roleVal == nil || roleVal == "assistant" || roleVal == "model" || roleVal == "agent" || roleVal == connector.roleKey.lowercased()
                    let extracted = (lastItem[connector.textKey] as? String)
                        ?? (lastItem["content"] as? String)
                        ?? (lastItem["text"] as? String)
                        ?? (lastItem["message"] as? String)
                    if isRoleMatch, let text = extracted {
                        assistantText = text
                    }
                } else if let json = try? JSONSerialization.jsonObject(with: fullData) as? [String: Any] {
                    let roleVal = (json["role"] as? String)?.lowercased()
                        ?? (json["type"] as? String)?.lowercased()
                        ?? (json[connector.roleKey] as? String)?.lowercased()
                    let isRoleMatch = roleVal == nil || roleVal == "assistant" || roleVal == "model" || roleVal == "agent" || roleVal == connector.roleKey.lowercased()
                    let extracted = (json[connector.textKey] as? String)
                        ?? (json["content"] as? String)
                        ?? (json["text"] as? String)
                        ?? (json["message"] as? String)
                    if isRoleMatch, let text = extracted {
                        assistantText = text
                    }
                }
            }
        case .markdown, .plainText:
            assistantText = lastLine
        case .sqlite:
            break
        }
        
        if let txt = assistantText?.trimmingCharacters(in: .whitespacesAndNewlines), !txt.isEmpty {
            let rawId = "\(fPath)_\(txt.prefix(60))"
            let convKey = "\(connector.id)_\(fileURL.lastPathComponent)"
            let isFresh = (now - modTime <= 30.0) && (modTime >= (appStartTime - 5.0))
            
            stateLock.lock()
            let lastId = state[convKey]
            if lastId != rawId {
                state[convKey] = rawId
                stateLock.unlock()
                
                if isFresh {
                    let clean = TextSanitizer.sanitizeForSpeech(txt)
                    if !clean.isEmpty {
                        DispatchQueue.main.async {
                            onSpeech(connector.name, clean)
                        }
                    }
                }
            } else {
                stateLock.unlock()
            }
        }
    }
}
