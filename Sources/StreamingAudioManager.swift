import Cocoa
import SwiftUI
import AVFoundation
import NaturalLanguage
import QuartzCore

// MARK: - Chunker Utility
func splitTextIntoChunks(text: String) -> [String] {
    return SpeechLanguageDetector.splitTextIntoChunks(text: text)
}

// MARK: - Audio Chunk Model
struct AudioChunk {
    let index: Int
    let text: String
    let filePath: String
    var duration: Double = 0.0
    var startTime: Double = 0.0
    var isReady: Bool = false
    var isFailed: Bool = false
    var player: AVAudioPlayer?
}

// MARK: - Streaming Audio Manager
class StreamingAudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var globalCurrentTime: Double = 0.0
    @Published var globalTotalDuration: Double = 1.0
    @Published var isDragging = false
    @Published var currentChunkIndex: Int = 0
    @Published var totalChunksCount: Int = 1
    @Published var skipSeconds: Int = 5
    
    var chunks: [AudioChunk] = []
    var timer: Timer?
    var displayLink: CADisplayLink?
    var onClose: (() -> Void)?
    
    private var isCancelled = false
    private var activeRenderProcesses: [Process] = []
    private let processesLock = NSLock()
    private let renderQueue = DispatchQueue(label: "com.agentspeak.speech.render", qos: .userInitiated, attributes: .concurrent)
    private var documentLanguage: String = "en"
    
    private var renderingIndices = Set<Int>()
    private let renderStateLock = NSLock()
    private let maxLookahead = 6
    private let maxConcurrentRenders = 2
    private var fullSpokenText: String = ""
    
    private func registerProcess(_ proc: Process) {
        processesLock.lock()
        activeRenderProcesses.append(proc)
        processesLock.unlock()
    }
    
    private func unregisterProcess(_ proc: Process) {
        processesLock.lock()
        activeRenderProcesses.removeAll(where: { $0 === proc })
        processesLock.unlock()
    }
    
    static func loadSkipSeconds() -> Int {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audio = json["audio"] as? [String: Any],
              let s = audio["skip_seconds"] as? Int else {
            return 5
        }
        return s
    }
    
    public static func estimateDuration(for text: String) -> Double {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let est = Double(words.count) / 2.8
        return max(1.5, min(12.0, est))
    }
    
    init(text: String, onClose: (() -> Void)?) {
        self.onClose = onClose
        self.skipSeconds = StreamingAudioManager.loadSkipSeconds()
        self.fullSpokenText = text
        
        let docRec = NLLanguageRecognizer()
        docRec.processString(text)
        self.documentLanguage = docRec.dominantLanguage?.rawValue ?? "en"
        
        super.init()
        
        let sessionId = UInt32.random(in: 1000...9999)
        let textChunks = splitTextIntoChunks(text: text)
        if textChunks.isEmpty {
            DispatchQueue.main.async { [weak self] in
                self?.close()
            }
            return
        }
        
        self.totalChunksCount = textChunks.count
        self.chunks = textChunks.enumerated().map { idx, chunkText in
            var c = AudioChunk(index: idx, text: chunkText, filePath: "/tmp/speech_chunk_\(sessionId)_\(idx).wav")
            c.duration = StreamingAudioManager.estimateDuration(for: chunkText)
            return c
        }
        self.updateTimelineDurations()
        
        // Render Chunk 0 asynchronously on userInitiated queue (zero main thread stall)
        renderStateLock.lock()
        renderingIndices.insert(0)
        renderStateLock.unlock()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.renderChunk(index: 0)
            
            self.renderStateLock.lock()
            self.renderingIndices.remove(0)
            self.renderStateLock.unlock()
            
            DispatchQueue.main.async {
                guard !self.isCancelled else { return }
                if let p = self.chunks[0].player {
                    p.play()
                    self.isPlaying = true
                    self.currentChunkIndex = 0
                    self.updateTimelineDurations()
                    self.startTimer()
                    self.triggerLookaheadRendering()
                } else {
                    self.close()
                }
            }
        }
        
        // Immediately kick off parallel lookahead for upcoming chunks while chunk 0 renders
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.triggerLookaheadRendering()
        }
    }
    
    init(audioFilePath: String, onClose: (() -> Void)?) {
        self.onClose = onClose
        super.init()
        
        self.totalChunksCount = 1
        var chunk = AudioChunk(index: 0, text: "", filePath: audioFilePath)
        if FileManager.default.fileExists(atPath: audioFilePath) {
            VoiceVolumeManager.shared.applyGainIfNeeded(filePath: audioFilePath)
            if let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: audioFilePath)) {
                p.volume = VoiceVolumeManager.shared.playerVolume
                p.delegate = self
                p.isMeteringEnabled = true
                p.prepareToPlay()
                chunk.player = p
                chunk.duration = p.duration
                chunk.isReady = true
                self.chunks = [chunk]
                self.globalTotalDuration = max(1.0, p.duration)
                p.play()
                self.isPlaying = true
                self.currentChunkIndex = 0
                self.startTimer()
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.close()
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.close()
            }
        }
    }
    
    private func renderChunk(index: Int) {
        guard index < chunks.count, !isCancelled else { return }
        let c = chunks[index]
        
        // Read audio engine preference from config
        var engine = "macos_default"
        var voice = "Jarvis_Best"
        var macosVoice = "default"
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        if let data = try? Data(contentsOf: configPath),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let audio = json["audio"] as? [String: Any] {
            engine = audio["engine"] as? String ?? "macos_default"
            macosVoice = audio["macos_voice"] as? String ?? "default"
            if let ptts = audio["pocket_tts"] as? [String: Any],
               let v = ptts["voice"] as? String {
                voice = v
            }
        }
        
        var renderedSuccessfully = false
        
        // 1. If Pocket-TTS extension is selected, verify language compatibility
        let pocketSupported = SpeechLanguageDetector.isPocketTTSSupported(text: c.text, documentLanguage: self.documentLanguage)
        
        if engine == "pocket_tts" && pocketSupported {
            if let script = PocketTTSManager.shared.activeScriptPath,
               let py = PocketTTSManager.shared.activePythonPath {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: py)
                proc.arguments = [script, c.text, "--voice", voice, "--output", c.filePath, "--no-play", "--no-gain"]
                self.registerProcess(proc)
                try? proc.run()
                proc.waitUntilExit()
                self.unregisterProcess(proc)
                
                if FileManager.default.fileExists(atPath: c.filePath),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: c.filePath),
                   (attrs[.size] as? Int64 ?? 0) > 1000 {
                    renderedSuccessfully = true
                }
            }
        }
        
        // 2. Native Apple Silicon voice (macos_default or automatic multilingual fallback)
        if !renderedSuccessfully && !isCancelled {
            let sayVoice = SpeechLanguageDetector.resolveNativeVoice(
                for: c.text,
                documentLanguage: self.documentLanguage,
                macosVoice: macosVoice,
                pocketVoice: voice,
                engine: engine
            )
            
            let runSay = { (voiceName: String?) -> Bool in
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                var args = ["--file-format=WAVE", "--data-format=LEI16@22050"]
                if let v = voiceName, !v.isEmpty && v != "default" {
                    args.append(contentsOf: ["-v", v])
                }
                args.append(contentsOf: ["-o", c.filePath, c.text])
                proc.arguments = args
                
                self.registerProcess(proc)
                try? proc.run()
                proc.waitUntilExit()
                self.unregisterProcess(proc)
                
                if FileManager.default.fileExists(atPath: c.filePath),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: c.filePath),
                   (attrs[.size] as? Int64 ?? 0) > 400 {
                    return true
                }
                return false
            }
            
            // Attempt 1: Try with resolved voice
            if runSay(sayVoice) {
                renderedSuccessfully = true
            } else if sayVoice != nil && !self.isCancelled {
                // Attempt 2: If specific voice failed, retry with system default voice
                NSLog("[AgentSpeak] Voice '%@' failed for chunk %d. Retrying with system default.", sayVoice ?? "", index)
                if runSay(nil) {
                    renderedSuccessfully = true
                }
            }
            
            // Attempt 3: Native AIFF with afconvert fallback
            if !renderedSuccessfully && !self.isCancelled {
                let tmpAiff = "/tmp/speech_fallback_\(UInt32.random(in: 1000...9999)).aiff"
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                var aiffArgs = ["-o", tmpAiff]
                if let v = sayVoice, !v.isEmpty && v != "default" {
                    aiffArgs.insert(contentsOf: ["-v", v], at: 0)
                }
                aiffArgs.append(c.text)
                proc.arguments = aiffArgs
                self.registerProcess(proc)
                try? proc.run()
                proc.waitUntilExit()
                self.unregisterProcess(proc)
                
                if FileManager.default.fileExists(atPath: tmpAiff) {
                    let conv = Process()
                    conv.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
                    conv.arguments = ["-f", "WAVE", "-d", "LEI16@22050", tmpAiff, c.filePath]
                    self.registerProcess(conv)
                    try? conv.run()
                    conv.waitUntilExit()
                    self.unregisterProcess(conv)
                    try? FileManager.default.removeItem(atPath: tmpAiff)
                    
                    if FileManager.default.fileExists(atPath: c.filePath),
                       let attrs = try? FileManager.default.attributesOfItem(atPath: c.filePath),
                       (attrs[.size] as? Int64 ?? 0) > 400 {
                        renderedSuccessfully = true
                    }
                }
            }
        }
        
        // 3. Initialize player safely on main thread with retry for filesystem write flush
        if !isCancelled && FileManager.default.fileExists(atPath: c.filePath) {
            // Apply analog soft-saturation decibel gain if volume > 100%
            VoiceVolumeManager.shared.applyGainIfNeeded(filePath: c.filePath)
            
            var playerCandidate: AVAudioPlayer?
            for _ in 0..<3 {
                if let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: c.filePath)) {
                    p.volume = VoiceVolumeManager.shared.playerVolume
                    playerCandidate = p
                    break
                }
                usleep(25_000) // 25ms filesystem sync buffer
            }
            
            if let p = playerCandidate {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }
                    p.delegate = self
                    p.isMeteringEnabled = true
                    p.prepareToPlay()
                    self.chunks[index].player = p
                    self.chunks[index].duration = p.duration
                    self.chunks[index].isReady = true
                    self.updateTimelineDurations()
                }
                return
            }
        }
        
        // If synthesis failed completely, mark as failed on main thread so player can skip smoothly
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.chunks[index].isFailed = true
            self.chunks[index].isReady = true
            NSLog("[AgentSpeak] Warning: Chunk %d failed to render audio file.", index)
        }
    }
    
    private func triggerLookaheadRendering() {
        guard !isCancelled else { return }
        
        let targetEnd = min(currentChunkIndex + maxLookahead, chunks.count - 1)
        guard currentChunkIndex + 1 <= targetEnd else { return }
        
        for idx in (currentChunkIndex + 1)...targetEnd {
            renderStateLock.lock()
            if isCancelled {
                renderStateLock.unlock()
                break
            }
            if renderingIndices.count >= maxConcurrentRenders {
                renderStateLock.unlock()
                break
            }
            if chunks[idx].isReady || renderingIndices.contains(idx) {
                renderStateLock.unlock()
                continue
            }
            renderingIndices.insert(idx)
            renderStateLock.unlock()
            
            renderQueue.async { [weak self] in
                guard let self = self, !self.isCancelled else {
                    self?.renderStateLock.lock()
                    self?.renderingIndices.remove(idx)
                    self?.renderStateLock.unlock()
                    return
                }
                self.renderChunk(index: idx)
                
                self.renderStateLock.lock()
                self.renderingIndices.remove(idx)
                self.renderStateLock.unlock()
                
                // Once this chunk is ready, check if another chunk in lookahead window needs pre-rendering
                DispatchQueue.main.async {
                    guard !self.isCancelled else { return }
                    self.triggerLookaheadRendering()
                }
            }
        }
    }
    
    private func updateTimelineDurations() {
        var total: Double = 0.0
        for i in 0..<chunks.count {
            chunks[i].startTime = total
            if chunks[i].isReady {
                total += chunks[i].duration
            } else {
                total += StreamingAudioManager.estimateDuration(for: chunks[i].text)
            }
        }
        self.globalTotalDuration = max(1.0, total)
    }
    
    func startTimer() {
        stopTimer()
        if #available(macOS 14.0, *), let screen = NSScreen.main {
            let l = screen.displayLink(target: self, selector: #selector(displayTick))
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            l.add(to: .main, forMode: .common)
            self.displayLink = l
        } else {
            let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                self?.tick()
            }
            RunLoop.main.add(t, forMode: .common)
            self.timer = t
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func displayTick() {
        tick()
    }
    
    private func tick() {
        guard !isDragging else { return }
        guard currentChunkIndex < chunks.count, let p = chunks[currentChunkIndex].player, p.isPlaying else {
            AudioLevelMeter.shared.decay()
            return
        }
        let chunkStart = chunks[currentChunkIndex].startTime
        let newCurrentTime = chunkStart + p.currentTime
        if abs(newCurrentTime - globalCurrentTime) >= 0.03 {
            globalCurrentTime = newCurrentTime
        }
        
        // Dynamic JIT 6-second Lookahead Trigger
        let remaining = p.duration - p.currentTime
        if remaining <= 6.0 {
            triggerLookaheadRendering()
        }
        
        if p.isMeteringEnabled {
            p.updateMeters()
            let power = p.averagePower(forChannel: 0)
            let norm = max(0.0, min(1.0, Double(power + 44.0) / 44.0))
            AudioLevelMeter.shared.update(targetLevel: Float(norm))
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let actualIndex = chunks.firstIndex(where: { $0.player === player }) ?? currentChunkIndex
        let nextIndex = actualIndex + 1
        if nextIndex < chunks.count {
            currentChunkIndex = nextIndex
            playChunkWhenReady(index: nextIndex)
            triggerLookaheadRendering()
        } else {
            finishPlayback()
        }
    }
    
    private func playChunkWhenReady(index: Int, attempts: Int = 0) {
        guard index < chunks.count, !isCancelled else { return }
        
        if chunks[index].isReady {
            if let p = chunks[index].player {
                p.currentTime = 0
                p.volume = VoiceVolumeManager.shared.playerVolume
                if p.play() {
                    isPlaying = true
                    triggerLookaheadRendering()
                    return
                } else {
                    p.prepareToPlay()
                    if p.play() {
                        isPlaying = true
                        triggerLookaheadRendering()
                        return
                    }
                }
            }
            
            // If player is nil or chunk marked failed, advance to next chunk immediately
            NSLog("[AgentSpeak] Chunk %d could not play or was empty, advancing.", index)
            let nextIndex = index + 1
            if nextIndex < chunks.count {
                currentChunkIndex = nextIndex
                playChunkWhenReady(index: nextIndex)
                triggerLookaheadRendering()
            } else {
                finishPlayback()
            }
            return
        }
        
        // Ensure background rendering is actively triggered
        triggerLookaheadRendering()
        
        // Wait for background chunk rendering with 8.0s watchdog timeout (80 * 100ms)
        if attempts < 80 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.playChunkWhenReady(index: index, attempts: attempts + 1)
            }
        } else {
            NSLog("[AgentSpeak] Chunk %d timed out waiting for audio render, advancing.", index)
            let nextIndex = index + 1
            if nextIndex < chunks.count {
                currentChunkIndex = nextIndex
                playChunkWhenReady(index: nextIndex)
                triggerLookaheadRendering()
            } else {
                finishPlayback()
            }
        }
    }
    
    private func finishPlayback() {
        isPlaying = false
        stopTimer()
        
        let validPaths = self.chunks.filter { $0.isReady && FileManager.default.fileExists(atPath: $0.filePath) }.map { $0.filePath }
        if !validPaths.isEmpty && !self.fullSpokenText.isEmpty {
            LastVoiceManager.shared.recordVoice(text: self.fullSpokenText, chunkFilePaths: validPaths)
        }
        
        let cb = onClose
        onClose = nil
        cb?()
    }
    
    func togglePlayPause() {
        guard currentChunkIndex < chunks.count, let p = chunks[currentChunkIndex].player else { return }
        if p.isPlaying {
            p.pause()
            isPlaying = false
        } else {
            p.play()
            isPlaying = true
        }
    }
    
    func skip(seconds: Double) {
        seek(to: globalCurrentTime + seconds)
    }
    
    func seek(to targetGlobalTime: Double) {
        let clamped = max(0.0, min(globalTotalDuration, targetGlobalTime))
        globalCurrentTime = clamped
        
        for (idx, c) in chunks.enumerated() {
            let chunkDuration = c.isReady ? c.duration : StreamingAudioManager.estimateDuration(for: c.text)
            let chunkEnd = c.startTime + chunkDuration
            if clamped >= c.startTime && clamped <= chunkEnd {
                if idx != currentChunkIndex {
                    chunks[currentChunkIndex].player?.stop()
                    currentChunkIndex = idx
                }
                if let p = chunks[idx].player, c.isReady {
                    let offsetInChunk = clamped - c.startTime
                    p.currentTime = min(p.duration, max(0.0, offsetInChunk))
                    if isPlaying { p.play() }
                    triggerLookaheadRendering()
                } else if !c.isReady {
                    // Prioritize rendering target chunk immediately
                    renderStateLock.lock()
                    if !renderingIndices.contains(idx) {
                        renderingIndices.insert(idx)
                        renderStateLock.unlock()
                        renderQueue.async { [weak self] in
                            guard let self = self, !self.isCancelled else { return }
                            self.renderChunk(index: idx)
                            self.renderStateLock.lock()
                            self.renderingIndices.remove(idx)
                            self.renderStateLock.unlock()
                            
                            DispatchQueue.main.async {
                                if self.currentChunkIndex == idx {
                                    self.playChunkWhenReady(index: idx)
                                    self.triggerLookaheadRendering()
                                }
                            }
                        }
                    } else {
                        renderStateLock.unlock()
                    }
                }
                break
            }
        }
    }
    
    func updateVolume() {
        let vol = VoiceVolumeManager.shared.playerVolume
        for i in 0..<chunks.count {
            chunks[i].player?.volume = vol
        }
    }
    
    func close() {
        guard !isCancelled else { return }
        isCancelled = true
        
        processesLock.lock()
        for proc in activeRenderProcesses {
            proc.terminate()
            let pid = proc.processIdentifier
            if pid > 0 {
                kill(pid, SIGKILL)
            }
        }
        activeRenderProcesses.removeAll()
        processesLock.unlock()
        
        renderStateLock.lock()
        renderingIndices.removeAll()
        renderStateLock.unlock()
        
        for c in chunks {
            c.player?.stop()
        }
        stopTimer()
        DispatchQueue.main.async {
            self.isPlaying = false
            SpeechQueueManager.shared.audioLevel = 0.0
        }
        let cb = onClose
        onClose = nil
        cb?()
        
        // Record valid synthesized chunks that were actually rendered before cancel
        let validPaths = self.chunks.filter { $0.isReady && FileManager.default.fileExists(atPath: $0.filePath) }.map { $0.filePath }
        if !validPaths.isEmpty && !self.fullSpokenText.isEmpty {
            LastVoiceManager.shared.recordVoice(text: self.fullSpokenText, chunkFilePaths: validPaths)
        }
        
        // Clean up temporary chunks after giving LastVoiceManager time to read and merge
        let chunksToClean = self.chunks
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5.0) {
            for c in chunksToClean {
                if c.filePath.hasPrefix("/tmp/") {
                    try? FileManager.default.removeItem(atPath: c.filePath)
                }
            }
        }
    }
}
