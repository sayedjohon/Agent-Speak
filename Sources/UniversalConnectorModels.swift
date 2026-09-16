import Foundation

// MARK: - Connector Format
public enum ConnectorFormat: String, Codable, CaseIterable, Identifiable {
    case jsonl = "jsonl"
    case json = "json"
    case sqlite = "sqlite"
    case markdown = "markdown"
    case plainText = "text"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .jsonl: return "JSON Lines (.jsonl)"
        case .json: return "JSON (.json)"
        case .sqlite: return "SQLite Database (.vscdb / .db)"
        case .markdown: return "Markdown (.md)"
        case .plainText: return "Plain Text (.txt / .log)"
        }
    }
}

// MARK: - Assistant Connector Model
public struct AssistantConnector: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var path: String
    public var format: ConnectorFormat
    public var roleKey: String
    public var textKey: String
    public var isPreset: Bool
    public var isEnabled: Bool
    public var dateAdded: TimeInterval
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        path: String,
        format: ConnectorFormat,
        roleKey: String = "assistant",
        textKey: String = "content",
        isPreset: Bool = false,
        isEnabled: Bool = true,
        dateAdded: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.format = format
        self.roleKey = roleKey
        self.textKey = textKey
        self.isPreset = isPreset
        self.isEnabled = isEnabled
        self.dateAdded = dateAdded
    }
}

// MARK: - Security Path Validator
public enum SecurityPathValidator {
    private static let forbiddenPrefixes: [String] = [
        "/System",
        "/usr",
        "/bin",
        "/sbin",
        "/etc",
        "/var/root",
        "/private/etc",
        "/private/var/root",
        "/Library/Keychains"
    ]
    
    private static let forbiddenSubstrings: [String] = [
        "/.ssh",
        "/.gnupg",
        "/.aws",
        "/.bash_history",
        "/.zsh_history",
        "/id_rsa",
        "/id_ed25519",
        "/credentials",
        "/Keychain",
        ";",
        "&&",
        "||",
        "|",
        "`",
        "$(",
        "sudo"
    ]
    
    public static func validate(path rawPath: String) -> (isValid: Bool, sanitizedPath: String, errorMessage: String?) {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return (false, "", "Path cannot be empty.")
        }
        
        // Block dangerous shell characters
        for forbidden in forbiddenSubstrings {
            if trimmed.contains(forbidden) {
                return (false, "", "Path contains forbidden or insecure tokens: '\(forbidden)'.")
            }
        }
        
        // Expand home directory ~
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expanded: String
        if trimmed.hasPrefix("~/") {
            expanded = home + String(trimmed.dropFirst(1))
        } else if trimmed == "~" {
            expanded = home
        } else {
            expanded = trimmed
        }
        
        let standardized = (expanded as NSString).standardizingPath
        
        // Verify path stays within home folder or /tmp
        let isInsideHome = standardized.hasPrefix(home)
        let isInsideTmp = standardized.hasPrefix("/tmp") || standardized.hasPrefix("/private/tmp")
        
        guard isInsideHome || isInsideTmp else {
            return (false, "", "Security Sandboxing Violation: Paths must be located inside your user home directory or /tmp.")
        }
        
        // Double check against forbidden system prefixes
        for prefix in forbiddenPrefixes {
            if standardized.hasPrefix(prefix) {
                return (false, "", "Security Violation: Access to system directory '\(prefix)' is strictly blocked.")
            }
        }
        
        return (true, standardized, nil)
    }
}

// MARK: - Universal Connector Manager
public class UniversalConnectorManager: ObservableObject {
    public static let shared = UniversalConnectorManager()
    
    @Published public var customConnectors: [AssistantConnector] = []
    @Published public var presetConnectors: [AssistantConnector] = []
    
    private let configURL: URL
    private let stateQueue = DispatchQueue(label: "com.agentspeak.connectors.queue", qos: .utility)
    
    public static let universalPromptText = """
You are an AI coding assistant. I want to connect you (or the tool you specify) to "Agent Speak", a local macOS voice companion that reads your conversational answers aloud.

Please inspect where your session transcripts or logs are saved on this Mac and provide an Agent Speak Connector JSON block.

Format your response strictly as a JSON block inside triple backticks:
```json
{
  "name": "<Tool Name>",
  "path": "<Absolute path or ~/ path to your session logs or chat file>",
  "format": "jsonl",
  "role_key": "assistant",
  "text_key": "content"
}
```
Rules:
- Format options: jsonl, json, sqlite, markdown, text
- Strictly read-only file or folder paths inside my home folder (~/) or /tmp
- Do NOT include any shell commands, scripts, or network URLs
"""
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".agentspeak")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        configURL = dir.appendingPathComponent("custom_connectors.json")
        initPresets()
        loadConnectors()
    }
    
    private func initPresets() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        presetConnectors = [
            AssistantConnector(
                id: "preset_cursor",
                name: "Cursor IDE",
                path: "\(home)/Library/Application Support/Cursor/User/workspaceStorage",
                format: .sqlite,
                roleKey: "assistant",
                textKey: "text",
                isPreset: true,
                isEnabled: true
            ),
            AssistantConnector(
                id: "preset_cline",
                name: "Cline (Claude Dev)",
                path: "\(home)/Library/Application Support/Code/User/globalStorage/saoudrizwan.claude-dev/tasks",
                format: .json,
                roleKey: "assistant",
                textKey: "text",
                isPreset: true,
                isEnabled: true
            ),
            AssistantConnector(
                id: "preset_roocode",
                name: "Roo Code",
                path: "\(home)/Library/Application Support/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks",
                format: .json,
                roleKey: "assistant",
                textKey: "text",
                isPreset: true,
                isEnabled: true
            ),
            AssistantConnector(
                id: "preset_windsurf",
                name: "Windsurf IDE",
                path: "\(home)/Library/Application Support/Windsurf/User/workspaceStorage",
                format: .sqlite,
                roleKey: "assistant",
                textKey: "text",
                isPreset: true,
                isEnabled: true
            ),
            AssistantConnector(
                id: "preset_hermes",
                name: "Hermes AI & OpenClaw",
                path: "\(home)/.hermes/logs",
                format: .jsonl,
                roleKey: "assistant",
                textKey: "content",
                isPreset: true,
                isEnabled: true
            ),
            AssistantConnector(
                id: "preset_aider",
                name: "Aider CLI",
                path: "\(home)/.aider.chat.history.md",
                format: .markdown,
                roleKey: "assistant",
                textKey: "content",
                isPreset: true,
                isEnabled: true
            )
        ]
    }
    
    // MARK: - Connector Persistence
    public func loadConnectors() {
        guard let data = try? Data(contentsOf: configURL),
              let list = try? JSONDecoder().decode([AssistantConnector].self, from: data) else {
            return
        }
        self.customConnectors = list
    }
    
    public func saveConnectors() {
        guard let data = try? JSONEncoder().encode(customConnectors) else { return }
        try? data.write(to: configURL, options: .atomic)
    }
    
public struct ConnectorParseError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
    public init(_ message: String) { self.message = message }
}

    // MARK: - JSON Recipe Parser
    public func parseAndAddRecipe(from rawInput: String) -> Result<AssistantConnector, ConnectorParseError> {
        var cleanJson = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Extract content between ```json ... ``` if present
        if let start = cleanJson.range(of: "```json"),
           let end = cleanJson.range(of: "```", range: start.upperBound..<cleanJson.endIndex) {
            cleanJson = String(cleanJson[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let start = cleanJson.range(of: "```"),
                  let end = cleanJson.range(of: "```", range: start.upperBound..<cleanJson.endIndex) {
            cleanJson = String(cleanJson[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let data = cleanJson.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(ConnectorParseError("Invalid JSON format. Please paste a valid JSON code block."))
        }
        
        let name = (json["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Custom Assistant"
        guard let rawPath = (json["path"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !rawPath.isEmpty else {
            return .failure(ConnectorParseError("Missing 'path' field in JSON recipe."))
        }
        
        // Validate security of the path
        let validation = SecurityPathValidator.validate(path: rawPath)
        guard validation.isValid else {
            return .failure(ConnectorParseError(validation.errorMessage ?? "Path failed security verification."))
        }
        
        let formatStr = (json["format"] as? String)?.lowercased() ?? "jsonl"
        let format = ConnectorFormat(rawValue: formatStr) ?? .jsonl
        let roleKey = (json["role_key"] as? String) ?? "assistant"
        let textKey = (json["text_key"] as? String) ?? "content"
        
        let connector = AssistantConnector(
            id: UUID().uuidString,
            name: name,
            path: validation.sanitizedPath,
            format: format,
            roleKey: roleKey,
            textKey: textKey,
            isPreset: false,
            isEnabled: true
        )
        
        DispatchQueue.main.async {
            self.customConnectors.removeAll { $0.path == connector.path }
            self.customConnectors.append(connector)
            self.saveConnectors()
        }
        
        return .success(connector)
    }
    
    public func removeConnector(id: String) {
        customConnectors.removeAll { $0.id == id }
        saveConnectors()
    }
    
    public func toggleConnector(id: String, enabled: Bool) {
        if let idx = customConnectors.firstIndex(where: { $0.id == id }) {
            customConnectors[idx].isEnabled = enabled
            saveConnectors()
        }
        if let idx = presetConnectors.firstIndex(where: { $0.id == id }) {
            presetConnectors[idx].isEnabled = enabled
        }
    }
    
    public func isPathDetected(path: String) -> Bool {
        let validation = SecurityPathValidator.validate(path: path)
        guard validation.isValid else { return false }
        return FileManager.default.fileExists(atPath: validation.sanitizedPath)
    }
}
