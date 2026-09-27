import Cocoa
import AVFoundation
import Speech
import CoreAudio

// MARK: - Dictation Engine Mode
public enum DictationEngineMode: String, CaseIterable, Identifiable {
    case groqCloud = "Groq Whisper v3 (Cloud)"
    case appleOnDevice = "Apple Silicon On-Device (Offline)"
    case localEndpoint = "Custom / Local Endpoint"
    case modifierHold = "Hold Modifier Key (Whisper Flow)"
    
    public var id: String { rawValue }
}

// MARK: - Dictation Trigger Key Model & Presets
public struct DictationKeyPreset: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let symbol: String
    public let keyCode: Int64
    public let isModifier: Bool
    public let note: String
    
    public init(id: String, name: String, symbol: String, keyCode: Int64, isModifier: Bool, note: String = "") {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.keyCode = keyCode
        self.isModifier = isModifier
        self.note = note
    }
    
    public static let standardPresets: [DictationKeyPreset] = [
        DictationKeyPreset(id: "rightOption", name: "Right Option / Alt", symbol: "⌥", keyCode: 61, isModifier: true, note: "Mac Mini & External Keyboards (Recommended)"),
        DictationKeyPreset(id: "rightCommand", name: "Right Command", symbol: "⌘", keyCode: 54, isModifier: true, note: "Right Thumb on Mac Keyboards"),
        DictationKeyPreset(id: "rightControl", name: "Right Control", symbol: "⌃", keyCode: 62, isModifier: true, note: "PC / External Keyboards"),
        DictationKeyPreset(id: "leftControl", name: "Left Control", symbol: "⌃", keyCode: 59, isModifier: true, note: "Classic Gaming / Streamer PTT"),
        DictationKeyPreset(id: "leftOption", name: "Left Option / Alt", symbol: "⌥", keyCode: 58, isModifier: true, note: "Left Hand Push-to-Talk"),
        DictationKeyPreset(id: "capsLock", name: "Caps Lock", symbol: "⇪", keyCode: 57, isModifier: true, note: "Toggleable Modifier Key"),
        DictationKeyPreset(id: "fn", name: "Fn / Globe", symbol: "🌐", keyCode: 63, isModifier: true, note: "MacBook Built-in Keyboard"),
        DictationKeyPreset(id: "f12", name: "F12 Key", symbol: "F12", keyCode: 111, isModifier: false, note: "Dedicated Function Key"),
        DictationKeyPreset(id: "f6", name: "F6 Key", symbol: "F6", keyCode: 97, isModifier: false, note: "Dedicated Function Key"),
        DictationKeyPreset(id: "grave", name: "Grave / Tilde", symbol: "` ~", keyCode: 50, isModifier: false, note: "Top-Left below Escape")
    ]
    
    public static func isModifierKeyCode(_ code: Int64) -> Bool {
        return [63, 61, 58, 54, 55, 62, 59, 60, 56, 57].contains(code)
    }
    
    public static func nameForKeyCode(_ keyCode: Int64) -> (name: String, symbol: String) {
        switch keyCode {
        case 63: return ("Fn / Globe", "🌐")
        case 61: return ("Right Option", "⌥")
        case 58: return ("Left Option", "⌥")
        case 54: return ("Right Command", "⌘")
        case 55: return ("Left Command", "⌘")
        case 62: return ("Right Control", "⌃")
        case 59: return ("Left Control", "⌃")
        case 60: return ("Right Shift", "⇧")
        case 56: return ("Left Shift", "⇧")
        case 57: return ("Caps Lock", "⇪")
        case 122: return ("F1", "F1")
        case 120: return ("F2", "F2")
        case 99: return ("F3", "F3")
        case 118: return ("F4", "F4")
        case 96: return ("F5", "F5")
        case 97: return ("F6", "F6")
        case 98: return ("F7", "F7")
        case 100: return ("F8", "F8")
        case 101: return ("F9", "F9")
        case 109: return ("F10", "F10")
        case 103: return ("F11", "F11")
        case 111: return ("F12", "F12")
        case 105: return ("F13", "F13")
        case 107: return ("F14", "F14")
        case 113: return ("F15", "F15")
        case 106: return ("F16", "F16")
        case 64: return ("F17", "F17")
        case 79: return ("F18", "F18")
        case 80: return ("F19", "F19")
        case 90: return ("F20", "F20")
        case 50: return ("Grave / Tilde", "` ~")
        case 49: return ("Space", "␣")
        case 36: return ("Return", "⏎")
        case 48: return ("Tab", "⇥")
        case 51: return ("Delete", "⌫")
        default: return ("Key #\(keyCode)", "#\(keyCode)")
        }
    }
}

// MARK: - Groq & Whisper Dictation Manager
public class GroqWhisperManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    public static let shared = GroqWhisperManager()
    
    // Published states for SwiftUI
    @Published public var engineMode: DictationEngineMode = .groqCloud
    @Published public var groqApiKeys: [String] = []
    @Published public var activeKeyIndex: Int = 0
    
    public var groqApiKey: String {
        get {
            if groqApiKeys.indices.contains(activeKeyIndex) {
                return groqApiKeys[activeKeyIndex]
            }
            return groqApiKeys.first ?? ""
        }
        set {
            let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return }
            if groqApiKeys.isEmpty {
                groqApiKeys = [clean]
            } else if groqApiKeys.indices.contains(activeKeyIndex) {
                groqApiKeys[activeKeyIndex] = clean
            } else {
                groqApiKeys[0] = clean
            }
        }
    }
    
    public var multiKeysText: String {
        get { groqApiKeys.joined(separator: "\n") }
        set {
            let lines = newValue.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !lines.isEmpty {
                groqApiKeys = lines
            }
        }
    }
    
    @Published public var selectedModel: String = "whisper-large-v3"
    @Published public var customModelId: String = ""
    @Published public var customBaseUrl: String = ""
    @Published public var customApiKey: String = ""
    @Published public var languageCode: String = "" // Empty = Auto-detect
    @Published public var autoSubmitReturn: Bool = false
    @Published public var fnHoldDictationEnabled: Bool = true
    
    // MARK: - Push-to-Talk Trigger Key Configuration
    @Published public var dictationTriggerKey: String = "rightOption"
    @Published public var dictationTriggerKeyCode: Int64 = 61
    @Published public var dictationTriggerName: String = "Right Option (⌥)"
    @Published public var dictationTriggerIsModifier: Bool = true
    
    public func setPresetTriggerKey(_ preset: DictationKeyPreset) {
        dictationTriggerKey = preset.id
        dictationTriggerKeyCode = preset.keyCode
        dictationTriggerName = "\(preset.name) (\(preset.symbol))"
        dictationTriggerIsModifier = preset.isModifier
        saveConfig()
    }
    
    public func setCustomTriggerKey(code: Int64, name: String, isModifier: Bool) {
        dictationTriggerKey = "custom"
        dictationTriggerKeyCode = code
        dictationTriggerName = name
        dictationTriggerIsModifier = isModifier
        saveConfig()
    }
    
    // MARK: - Key Management Helpers
    @discardableResult
    public func addApiKey(_ key: String) -> (success: Bool, message: String) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return (false, "Key cannot be empty")
        }
        if groqApiKeys.contains(clean) {
            return (false, "Key is already in the pool")
        }
        groqApiKeys.append(clean)
        saveConfig()
        return (true, "Key added successfully")
    }
    
    public func removeApiKey(at index: Int) {
        guard groqApiKeys.indices.contains(index) else { return }
        groqApiKeys.remove(at: index)
        if activeKeyIndex >= groqApiKeys.count {
            activeKeyIndex = max(0, groqApiKeys.count - 1)
        }
        saveConfig()
    }
    
    public func setActiveKey(at index: Int) {
        guard groqApiKeys.indices.contains(index) else { return }
        activeKeyIndex = index
        saveConfig()
    }
    
    // MARK: - Live Key & Endpoint Testing
    public func testApiKey(_ key: String, completion: @escaping (Bool, String) -> Void) {
        let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let url = URL(string: "https://api.groq.com/openai/v1/models") else {
            completion(false, "Invalid key format")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(clean)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 6.0
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
                return
            }
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                if statusCode == 200 {
                    completion(true, "Valid (\(latencyMs)ms)")
                } else if statusCode == 401 {
                    completion(false, "Invalid Key (401)")
                } else if statusCode == 429 {
                    completion(false, "Rate Limited (429)")
                } else {
                    completion(false, "HTTP \(statusCode)")
                }
            }
        }
        task.resume()
    }

    public func testCustomEndpoint(url urlString: String, apiKey: String, completion: @escaping (Bool, String) -> Void) {
        let cleanUrl = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUrl.isEmpty, let url = URL(string: cleanUrl) else {
            completion(false, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty {
            request.setValue("Bearer \(cleanKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 6.0
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            
            if let error = error {
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
                return
            }
            
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            DispatchQueue.main.async {
                if statusCode == 200 || statusCode == 405 || statusCode == 400 {
                    completion(true, "Reachable (\(latencyMs)ms)")
                } else if statusCode == 401 {
                    completion(false, "Unauthorized (401)")
                } else {
                    completion(true, "HTTP \(statusCode) (\(latencyMs)ms)")
                }
            }
        }
        task.resume()
    }
    
    @Published public var isRecording: Bool = false
    @Published public var isTranscribing: Bool = false
    @Published public var lastTranscription: String = ""
    @Published public var statusMessage: String = "Ready"
    
    private var audioRecorder: AVAudioRecorder?
    private let recordingURL = URL(fileURLWithPath: "/tmp/agentspeak_dictation.wav")
    private let workQueue = DispatchQueue(label: "com.agentspeak.dictation", qos: .userInitiated)
    
    // Apple On-Device Speech Recognizer
    private var speechRecognizer: SFSpeechRecognizer?
    
    public override init() {
        super.init()
        loadConfig()
    }
    
    // MARK: - Apple Speech Setup (100% Offline)
    public func setupAppleSpeechRecognizer() {
        guard engineMode == .appleOnDevice else { return }
        let locale = languageCode.isEmpty ? Locale.current : Locale(identifier: languageCode)
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            SFSpeechRecognizer.requestAuthorization { status in
                NSLog("[GroqWhisper] Apple Speech authorization: %ld", status.rawValue)
            }
        }
    }
    
    // MARK: - Audio Input Hardware Check
    public static func hasActiveInputDevice() -> Bool {
        var defaultInputDeviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &defaultInputDeviceID
        )
        return status == noErr && defaultInputDeviceID != 0 && defaultInputDeviceID != kAudioDeviceUnknown
    }
    
    // MARK: - Start Recording
    public func startRecording() {
        guard !isRecording else { return }
        
        guard Self.hasActiveInputDevice() else {
            NSLog("[GroqWhisper] No audio input device detected on Mac.")
            DispatchQueue.main.async {
                self.statusMessage = "No Mic Detected"
                GestureHUDState.shared.showGesture(.clutch, label: "No Mic Connected (Connect AirPods / Mic)")
            }
            return
        }
        
        // Ensure microphone permission cleanly
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.statusMessage = "Listening..."
                GestureHUDState.shared.showGesture(.whisperFlowHold, label: "Listening (Dictation)...")
            }
            NSLog("[GroqWhisper] Started audio recording.")
        } catch {
            NSLog("[GroqWhisper] Failed to start recorder: %@", error.localizedDescription)
            DispatchQueue.main.async {
                self.statusMessage = "Mic Error"
            }
        }
    }
    
    // MARK: - Cancel Recording (Abort)
    public func cancelRecording() {
        guard isRecording else { return }
        audioRecorder?.stop()
        audioRecorder = nil
        try? FileManager.default.removeItem(at: recordingURL)
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.isTranscribing = false
            self.statusMessage = "Cancelled"
            GestureHUDState.shared.hide()
        }
        NSLog("[GroqWhisper] Audio recording cancelled.")
    }
    
    // MARK: - Stop Recording & Transcribe
    public func stopRecordingAndTranscribe() {
        guard isRecording else { return }
        
        audioRecorder?.stop()
        audioRecorder = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.isTranscribing = true
            self.statusMessage = "Transcribing..."
            GestureHUDState.shared.showGesture(.whisperFlowHold, label: "Transcribing audio...")
        }
        
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch self.engineMode {
            case .groqCloud, .localEndpoint:
                self.transcribeWithCloudWhisper()
            case .appleOnDevice:
                self.transcribeWithAppleOnDevice()
            case .modifierHold:
                DispatchQueue.main.async {
                    self.isTranscribing = false
                }
            }
        }
    }
    
    // MARK: - Cloud Groq Whisper Transcription with Multi-Key Fallback
    private func transcribeWithCloudWhisper() {
        let candidateKeys: [String]
        if engineMode == .localEndpoint && !customApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidateKeys = [customApiKey.trimmingCharacters(in: .whitespacesAndNewlines)]
        } else {
            let filtered = groqApiKeys
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            candidateKeys = (filtered.isEmpty && engineMode == .localEndpoint) ? [""] : filtered
        }
        
        if engineMode == .groqCloud && candidateKeys.isEmpty {
            notifyFailure("No Groq API Keys configured")
            return
        }
        
        let endpointString: String
        if !customBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            endpointString = customBaseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            endpointString = "https://api.groq.com/openai/v1/audio/transcriptions"
        }
        
        guard let url = URL(string: endpointString) else {
            notifyFailure("Invalid Whisper URL")
            return
        }
        
        guard FileManager.default.fileExists(atPath: recordingURL.path),
              let audioData = try? Data(contentsOf: recordingURL),
              audioData.count > 4100 else {
            notifyFailure("No audio recorded (Check mic)")
            return
        }
        
        let targetModel: String
        if selectedModel == "custom" && !customModelId.isEmpty {
            targetModel = customModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            targetModel = selectedModel
        }
        
        let startIndex = activeKeyIndex % candidateKeys.count
        executeWhisperRequest(
            candidateKeys: candidateKeys,
            keyIndex: startIndex,
            attempts: 0,
            url: url,
            audioData: audioData,
            model: targetModel
        )
    }
    
    private func executeWhisperRequest(
        candidateKeys: [String],
        keyIndex: Int,
        attempts: Int,
        url: URL,
        audioData: Data,
        model: String
    ) {
        let totalKeys = candidateKeys.count
        guard attempts < totalKeys else {
            notifyFailure("All \(totalKeys) Groq API keys failed")
            return
        }
        
        let currentKey = candidateKeys[keyIndex]
        let keyNum = keyIndex + 1
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if !currentKey.isEmpty {
            request.setValue("Bearer \(currentKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 12.0
        
        var body = Data()
        // Model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)
        
        // Language (if set)
        if !languageCode.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(languageCode)\r\n".data(using: .utf8)!)
        }
        
        // Response format: json
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        // Audio File
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            
            // Retry on network error, 401 Unauthorized, 429 Rate Limit, or 5xx Server Error
            let isRetryable = (error != nil) || statusCode == 401 || statusCode == 429 || statusCode >= 500
            
            if isRetryable && (attempts + 1 < totalKeys) {
                let nextIndex = (keyIndex + 1) % totalKeys
                NSLog("[GroqWhisper] Key %ld/%ld failed (HTTP %ld / %@). Failing over to Key %ld...", keyNum, totalKeys, statusCode, error?.localizedDescription ?? "Status", nextIndex + 1)
                
                DispatchQueue.main.async {
                    GestureHUDState.shared.showGesture(.whisperFlowHold, label: "Failover: trying Key \(nextIndex + 1)...")
                }
                
                self.workQueue.async {
                    self.executeWhisperRequest(
                        candidateKeys: candidateKeys,
                        keyIndex: nextIndex,
                        attempts: attempts + 1,
                        url: url,
                        audioData: audioData,
                        model: model
                    )
                }
                return
            }
            
            if let error = error {
                self.notifyFailure("Network Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.notifyFailure("Server Error (HTTP \(statusCode))")
                return
            }
            
            if let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                if msg.lowercased().contains("audio file is too short") {
                    self.notifyFailure("No speech captured (Check mic)")
                    return
                }
                if attempts + 1 < totalKeys {
                    let nextIndex = (keyIndex + 1) % totalKeys
                    NSLog("[GroqWhisper] Key %ld returned '%@'. Failing over to Key %ld...", keyNum, msg, nextIndex + 1)
                    DispatchQueue.main.async {
                        GestureHUDState.shared.showGesture(.whisperFlowHold, label: "Groq error: trying Key \(nextIndex + 1)...")
                    }
                    self.workQueue.async {
                        self.executeWhisperRequest(
                            candidateKeys: candidateKeys,
                            keyIndex: nextIndex,
                            attempts: attempts + 1,
                            url: url,
                            audioData: audioData,
                            model: model
                        )
                    }
                    return
                } else {
                    self.notifyFailure("Groq Error: \(msg)")
                    return
                }
            }
            
            if let text = json["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DispatchQueue.main.async {
                    self.activeKeyIndex = keyIndex
                }
                self.deliverTranscription(text.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                self.notifyFailure("No speech detected")
            }
        }
        task.resume()
    }
    
    // MARK: - Apple Silicon On-Device Transcription (100% Offline)
    private func transcribeWithAppleOnDevice() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            notifyFailure("Apple Speech unavailable")
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: recordingURL)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.notifyFailure("Speech Error: \(error.localizedDescription)")
                return
            }
            
            if let result = result, result.isFinal {
                let text = result.bestTranscription.formattedString
                self.deliverTranscription(text)
            }
        }
    }
    
    // MARK: - Deliver & Auto-Paste
    private func deliverTranscription(_ text: String) {
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.lastTranscription = text
            self.statusMessage = "Pasted: \(text.prefix(30))..."
            
            // Put on clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            
            // Show on HUD
            GestureHUDState.shared.showGesture(.whisperFlowHold, label: "Transcribed: \"\(text.prefix(25))...\"")
            
            // Ensure any virtual modifier keys are fully released
            KeyboardShortcutController.shared.releaseAllHeldModifiers()
            
            // Auto paste into active application via Cmd + V
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                KeyboardShortcutController.shared.sendPaste()
                
                // If auto-submit is enabled, press Return
                if self.autoSubmitReturn {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        KeyboardShortcutController.shared.sendReturn()
                    }
                }
            }
        }
        NSLog("[GroqWhisper] Transcribed: '%@'", text)
    }
    
    private func notifyFailure(_ message: String) {
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.statusMessage = message
            GestureHUDState.shared.showGesture(.clutch, label: message)
        }
        NSLog("[GroqWhisper] Failed: %@", message)
    }
    
    // MARK: - Configuration I/O
    public func loadConfig() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = json["dictation"] as? [String: Any] else { return }
        
        if let modeStr = d["mode"] as? String, let m = DictationEngineMode(rawValue: modeStr) {
            engineMode = m
        }
        if let keys = d["groq_api_keys"] as? [String] {
            let clean = keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !clean.isEmpty {
                groqApiKeys = clean
            }
        } else if let key = d["groq_api_key"] as? String {
            let clean = key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                groqApiKeys = [clean]
            }
        }
        if let model = d["model"] as? String { selectedModel = model }
        if let customM = d["custom_model"] as? String { customModelId = customM }
        if let base = d["custom_base_url"] as? String { customBaseUrl = base }
        if let customK = d["custom_api_key"] as? String { customApiKey = customK }
        if let lang = d["language"] as? String { languageCode = lang }
        if let autoSub = d["auto_submit_return"] as? Bool { autoSubmitReturn = autoSub }
        if let fnHold = d["fn_hold_dictation"] as? Bool { fnHoldDictationEnabled = fnHold }
        if let trigKey = d["dictation_trigger_key"] as? String { dictationTriggerKey = trigKey }
        if let trigCode = d["dictation_trigger_keycode"] as? Int64 {
            dictationTriggerKeyCode = trigCode
        } else if let trigCodeInt = d["dictation_trigger_keycode"] as? Int {
            dictationTriggerKeyCode = Int64(trigCodeInt)
        }
        if let trigName = d["dictation_trigger_name"] as? String { dictationTriggerName = trigName }
        if let trigMod = d["dictation_trigger_is_modifier"] as? Bool { dictationTriggerIsModifier = trigMod }
        
        setupAppleSpeechRecognizer()
    }
    
    public func saveConfig() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }
        
        var d: [String: Any] = [:]
        d["mode"] = engineMode.rawValue
        let cleanKeys = groqApiKeys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        d["groq_api_keys"] = cleanKeys
        d["groq_api_key"] = cleanKeys.first ?? ""
        d["model"] = selectedModel
        d["custom_model"] = customModelId
        d["custom_base_url"] = customBaseUrl
        d["custom_api_key"] = customApiKey
        d["language"] = languageCode
        d["auto_submit_return"] = autoSubmitReturn
        d["fn_hold_dictation"] = fnHoldDictationEnabled
        d["dictation_trigger_key"] = dictationTriggerKey
        d["dictation_trigger_keycode"] = dictationTriggerKeyCode
        d["dictation_trigger_name"] = dictationTriggerName
        d["dictation_trigger_is_modifier"] = dictationTriggerIsModifier
        json["dictation"] = d
        
        if let outData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) {
            try? outData.write(to: configPath)
        }
        setupAppleSpeechRecognizer()
    }
}
