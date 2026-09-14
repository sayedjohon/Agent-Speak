import Foundation
import Cocoa

// MARK: - Isolated 120Hz Audio Level Meter (Zero Dashboard Layout Thrashing)
public class AudioLevelMeter: ObservableObject {
    public static let shared = AudioLevelMeter()
    @Published public var level: Float = 0.0
    
    private init() {}
    
    public func update(targetLevel: Float) {
        let prev = level
        let factor: Float = targetLevel > prev ? 0.25 : 0.10
        level = prev * (1.0 - factor) + targetLevel * factor
    }
    
    public func decay() {
        if level > 0.01 {
            level *= 0.88
        } else {
            level = 0.0
        }
    }
    
    public func reset() {
        level = 0.0
    }
}

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
    
    /// Decoupled from @Published on SpeechQueueManager to prevent 120Hz layout thrashing across all observers.
    public var audioLevel: Float {
        get { AudioLevelMeter.shared.level }
        set { AudioLevelMeter.shared.level = newValue }
    }
    
    private var queue: [(source: String, text: String)] = []
    private let queueLock = NSLock()
    
    private init() {}
    
    public func enqueue(source: String, text: String, immediate: Bool = false) {
        queueLock.lock()
        if immediate {
            queue.removeAll()
        }
        queue.append((source, text))
        let count = queue.count
        queueLock.unlock()
        
        NSLog("[SpeechQueue] Enqueued item from '%@' (immediate: %d, queueCount: %d, length: %d)", source, immediate ? 1 : 0, count, text.count)
        
        DispatchQueue.main.async {
            self.queueCount = count
            if immediate && self.isSpeaking {
                NotchWindowController.shared.dismiss()
                self.isSpeaking = false
            }
            self.processNext()
        }
    }
    
    public func playAudioFile(filePath: String, source: String = "Jarvis") {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = true
            self?.currentSpeakerSource = source
            BackgroundMusicManager.shared.start()
            NotchWindowController.shared.presentAudioFile(filePath: filePath, project: source) {
                DispatchQueue.main.async {
                    self?.isSpeaking = false
                    self?.audioLevel = 0.0
                    self?.currentSpeakerSource = ""
                    BackgroundMusicManager.shared.stopWithFadeAndReverb()
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
            self.audioLevel = 0.0
            self.queueCount = 0
            self.currentSpeakerSource = ""
            BackgroundMusicManager.shared.stopWithFadeAndReverb()
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
        
        DispatchQueue.main.async {
            BackgroundMusicManager.shared.start()
        }
        
        DispatchQueue.main.async { [weak self] in
            var finishedOnce = false
            let finishHandler: () -> Void = {
                guard !finishedOnce else { return }
                finishedOnce = true
                
                self?.queueLock.lock()
                self?.isSpeaking = false
                let remaining = self?.queue.count ?? 0
                self?.queueLock.unlock()
                
                DispatchQueue.main.async {
                    if remaining == 0 {
                        BackgroundMusicManager.shared.stopWithFadeAndReverb()
                    }
                    self?.currentSpeakerSource = ""
                    self?.audioLevel = 0.0
                    self?.queueCount = remaining
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
