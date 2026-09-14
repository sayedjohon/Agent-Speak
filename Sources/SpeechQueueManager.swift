import Foundation
import Cocoa

public class SpeechQueueManager: ObservableObject {
    public static let shared = SpeechQueueManager()
    
    public var onSpeakingChanged: ((Bool) -> Void)?
    
    @Published public var isSpeaking: Bool = false {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onSpeakingChanged?(self.isSpeaking)
            }
        }
    }
    @Published public var queueCount: Int = 0
    @Published public var currentSpeakerSource: String = ""
    
    private var queue: [(source: String, text: String)] = []
    private let queueLock = NSLock()
    
    private init() {}
    
    public func enqueue(source: String, text: String) {
        queueLock.lock()
        queue.append((source, text))
        let count = queue.count
        queueLock.unlock()
        
        DispatchQueue.main.async {
            self.queueCount = count
            self.processNext()
        }
    }
    
    public func playAudioFile(filePath: String, source: String = "Jarvis") {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
            self?.currentSpeakerSource = source
            NotchWindowController.shared.presentAudioFile(filePath: filePath, project: source) {
                DispatchQueue.main.async {
                    self?.isSpeaking = false
                    self?.currentSpeakerSource = ""
                }
            }
        }
    }
    
    public func stopCurrent() {
        queueLock.lock()
        queue.removeAll()
        queueLock.unlock()
        
        DispatchQueue.main.async {
            NotchWindowController.shared.dismiss()
            self.isSpeaking = false
            self.queueCount = 0
            self.currentSpeakerSource = ""
        }
        cleanupTmpAudio()
    }
    
    private func processNext() {
        queueLock.lock()
        if isSpeaking || queue.isEmpty {
            queueLock.unlock()
            return
        }
        
        let item = queue.removeFirst()
        self.isSpeaking = true
        self.queueCount = self.queue.count
        self.currentSpeakerSource = item.source
        queueLock.unlock()
        
        DispatchQueue.main.async { [weak self] in
            var finishedOnce = false
            let finishHandler: () -> Void = {
                guard !finishedOnce else { return }
                finishedOnce = true
                
                self?.queueLock.lock()
                self?.isSpeaking = false
                self?.queueLock.unlock()
                
                DispatchQueue.main.async {
                    self?.currentSpeakerSource = ""
                    self?.queueCount = self?.queue.count ?? 0
                    self?.cleanupTmpAudio()
                    self?.processNext()
                }
            }
            
            let trimmed = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                finishHandler()
                return
            }
            
            // Watchdog timeout to prevent frozen queue state
            DispatchQueue.main.asyncAfter(deadline: .now() + 300) {
                finishHandler()
            }
            
            NotchWindowController.shared.presentSpeech(text: trimmed, project: item.source) {
                finishHandler()
            }
        }
    }
    
    private func cleanupTmpAudio() {
        let fileManager = FileManager.default
        let tmp = URL(fileURLWithPath: "/tmp")
        if let files = try? fileManager.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for f in files {
                let name = f.lastPathComponent
                if name.hasPrefix("speech_chunk_") || name.hasPrefix("speech_bar_") || name.hasPrefix("test_speech") {
                    try? fileManager.removeItem(at: f)
                }
            }
        }
    }
}
