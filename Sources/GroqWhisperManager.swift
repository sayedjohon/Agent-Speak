import Cocoa
import AVFoundation
import Speech

// MARK: - Dictation Engine Mode
public enum DictationEngineMode: String, CaseIterable, Identifiable {
    case groqCloud = "Groq Whisper v3 (Cloud)"
    case appleOnDevice = "Apple Silicon On-Device (Offline)"
    case localEndpoint = "Custom / Local Endpoint"
    case modifierHold = "Hold Modifier Key (Whisper Flow)"
    
    public var id: String { rawValue }
}

// MARK: - Groq & Whisper Dictation Manager
public class GroqWhisperManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    public static let shared = GroqWhisperManager()
    
    // Published states for SwiftUI
    @Published public var engineMode: DictationEngineMode = .groqCloud
    @Published public var groqApiKey: String = ""
    @Published public var selectedModel: String = "whisper-large-v3"
    @Published public var customModelId: String = ""
    @Published public var customBaseUrl: String = ""
    @Published public var languageCode: String = "" // Empty = Auto-detect
    @Published public var autoSubmitReturn: Bool = false
    
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
    
    // MARK: - Start Recording
    public func startRecording() {
        guard !isRecording else { return }
        
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
    
    // MARK: - Cloud Groq Whisper Transcription
    private func transcribeWithCloudWhisper() {
        let apiKey = groqApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
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
              audioData.count > 1000 else {
            notifyFailure("Audio too short")
            return
        }
        
        let targetModel: String
        if selectedModel == "custom" && !customModelId.isEmpty {
            targetModel = customModelId.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            targetModel = selectedModel
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15.0
        
        var body = Data()
        
        // Model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(targetModel)\r\n".data(using: .utf8)!)
        
        // Language field (if set)
        if !languageCode.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(languageCode)\r\n".data(using: .utf8)!)
        }
        
        // Response format: json
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)
        
        // Audio File field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                self.notifyFailure("Network Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                self.notifyFailure("Invalid Server Response")
                return
            }
            
            if let errorObj = json["error"] as? [String: Any],
               let msg = errorObj["message"] as? String {
                self.notifyFailure("Groq Error: \(msg)")
                return
            }
            
            if let text = json["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            
            // Auto paste into active application via Cmd + V
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                KeyboardShortcutController.shared.sendPaste()
                
                // If auto-submit is enabled, press Return
                if self.autoSubmitReturn {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
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
            GestureHUDState.shared.showGesture(.escape, label: message)
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
        if let key = d["groq_api_key"] as? String { groqApiKey = key }
        if let model = d["model"] as? String { selectedModel = model }
        if let customM = d["custom_model"] as? String { customModelId = customM }
        if let base = d["custom_base_url"] as? String { customBaseUrl = base }
        if let lang = d["language"] as? String { languageCode = lang }
        if let autoSub = d["auto_submit_return"] as? Bool { autoSubmitReturn = autoSub }
        
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
        d["groq_api_key"] = groqApiKey
        d["model"] = selectedModel
        d["custom_model"] = customModelId
        d["custom_base_url"] = customBaseUrl
        d["language"] = languageCode
        d["auto_submit_return"] = autoSubmitReturn
        json["dictation"] = d
        
        if let outData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) {
            try? outData.write(to: configPath)
        }
        setupAppleSpeechRecognizer()
    }
}
