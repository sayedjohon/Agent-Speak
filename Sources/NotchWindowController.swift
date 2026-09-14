import Cocoa
import SwiftUI
import AVFoundation
import Carbon
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
    private var activeRenderProcess: Process?
    private let renderQueue = DispatchQueue(label: "com.agentspeak.speech.render", qos: .userInitiated)
    private var documentLanguage: String = "en"
    
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
    
    init(text: String, onClose: (() -> Void)?) {
        self.onClose = onClose
        self.skipSeconds = StreamingAudioManager.loadSkipSeconds()
        
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
            AudioChunk(index: idx, text: chunkText, filePath: "/tmp/speech_chunk_\(sessionId)_\(idx).wav")
        }
        
        // Render Chunk 0 asynchronously on userInitiated queue (zero main thread stall)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.renderChunk(index: 0)
            
            DispatchQueue.main.async {
                guard !self.isCancelled else { return }
                if let p = self.chunks[0].player {
                    p.play()
                    self.isPlaying = true
                    self.currentChunkIndex = 0
                    self.updateTimelineDurations()
                    self.startTimer()
                } else {
                    self.close()
                }
            }
            
            if self.chunks.count > 1 {
                self.startBackgroundRenderingPipeline(fullText: text)
            } else if self.chunks.count == 1 {
                if FileManager.default.fileExists(atPath: self.chunks[0].filePath) {
                    LastVoiceManager.shared.recordVoice(text: text, chunkFilePaths: [self.chunks[0].filePath])
                }
            }
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
                self.activeRenderProcess = proc
                try? proc.run()
                proc.waitUntilExit()
                self.activeRenderProcess = nil
                
                if FileManager.default.fileExists(atPath: c.filePath),
                   let attrs = try? FileManager.default.attributesOfItem(atPath: c.filePath),
                   (attrs[.size] as? Int64 ?? 0) > 1000 {
                    renderedSuccessfully = true
                }
            }
        }
        
        // 2. Native Apple Silicon voice (macos_default or automatic multilingual fallback)
        if !renderedSuccessfully && !isCancelled {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            
            let sayVoice = SpeechLanguageDetector.resolveNativeVoice(
                for: c.text,
                documentLanguage: self.documentLanguage,
                macosVoice: macosVoice,
                pocketVoice: voice,
                engine: engine
            )
            
            if let v = sayVoice {
                proc.arguments = ["-v", v, "-o", c.filePath, c.text]
            } else {
                // Default system voice
                proc.arguments = ["-o", c.filePath, c.text]
            }
            
            self.activeRenderProcess = proc
            try? proc.run()
            proc.waitUntilExit()
            self.activeRenderProcess = nil
            
            if FileManager.default.fileExists(atPath: c.filePath),
               let attrs = try? FileManager.default.attributesOfItem(atPath: c.filePath),
               (attrs[.size] as? Int64 ?? 0) > 400 {
                renderedSuccessfully = true
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
    
    private func startBackgroundRenderingPipeline(fullText: String) {
        renderQueue.async { [weak self] in
            guard let self = self else { return }
            for idx in 1..<self.chunks.count {
                if self.isCancelled { break }
                self.renderChunk(index: idx)
            }
            if !self.isCancelled {
                let paths = self.chunks.map { $0.filePath }
                LastVoiceManager.shared.recordVoice(text: fullText, chunkFilePaths: paths)
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
                total += 4.5
            }
        }
        self.globalTotalDuration = max(1.0, total)
    }
    
    func startTimer() {
        stopTimer()
        if #available(macOS 14.0, *), let screen = NSScreen.main {
            let l = screen.displayLink(target: self, selector: #selector(displayTick))
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
            l.add(to: .main, forMode: .common)
            self.displayLink = l
        } else {
            let t = Timer.scheduledTimer(withTimeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
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
        globalCurrentTime = chunkStart + p.currentTime
        
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
                    return
                } else {
                    p.prepareToPlay()
                    if p.play() {
                        isPlaying = true
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
            } else {
                finishPlayback()
            }
            return
        }
        
        // Wait for background chunk rendering with 8.0s watchdog timeout (160 * 50ms)
        if attempts < 160 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.playChunkWhenReady(index: index, attempts: attempts + 1)
            }
        } else {
            NSLog("[AgentSpeak] Chunk %d timed out waiting for audio render, advancing.", index)
            let nextIndex = index + 1
            if nextIndex < chunks.count {
                currentChunkIndex = nextIndex
                playChunkWhenReady(index: nextIndex)
            } else {
                finishPlayback()
            }
        }
    }
    
    private func finishPlayback() {
        isPlaying = false
        stopTimer()
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
            let chunkEnd = c.startTime + (c.isReady ? c.duration : 4.5)
            if clamped >= c.startTime && clamped <= chunkEnd {
                if idx != currentChunkIndex {
                    chunks[currentChunkIndex].player?.stop()
                    currentChunkIndex = idx
                }
                if let p = chunks[idx].player, c.isReady {
                    let offsetInChunk = clamped - c.startTime
                    p.currentTime = min(p.duration, max(0.0, offsetInChunk))
                    if isPlaying { p.play() }
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
        activeRenderProcess?.terminate()
        for c in chunks {
            c.player?.stop()
        }
        stopTimer()
        DispatchQueue.main.async {
            SpeechQueueManager.shared.audioLevel = 0.0
        }
        let cb = onClose
        onClose = nil
        cb?()
        
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

// MARK: - Keyable Floating Panel
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            DispatchQueue.main.async {
                SpeechQueueManager.shared.stopCurrent()
            }
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Notch Window Controller
public class NotchWindowController {
    public static let shared = NotchWindowController()
    
    private var window: KeyablePanel?
    private var audioManager: StreamingAudioManager?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalKeyMonitor: Any?
    private var localKeyMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    
    private init() {}
    
    public func presentSpeech(text: String, project: String = "Agent Speak", onFinished: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismiss()
            
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
            
            let hasNotch: Bool
            if #available(macOS 12.0, *) {
                hasNotch = targetScreen.safeAreaInsets.top > 0 || targetScreen.auxiliaryTopLeftArea != nil
            } else {
                hasNotch = false
            }
            
            let notchWidth: CGFloat = 185.0
            let barHeight: CGFloat = 30.0
            let windowWidth = notchWidth + 24.0
            let windowHeight = barHeight + 20.0
            
            let x = targetScreen.frame.origin.x + (targetScreen.frame.width - windowWidth) / 2
            let topOfScreen = targetScreen.frame.origin.y + targetScreen.frame.height
            let topOfVisible = targetScreen.visibleFrame.origin.y + targetScreen.visibleFrame.height
            
            let y: CGFloat
            if hasNotch {
                let notchHeight: CGFloat = targetScreen.safeAreaInsets.top > 0 ? targetScreen.safeAreaInsets.top : 32.0
                y = topOfScreen - notchHeight - windowHeight
            } else {
                if topOfVisible < topOfScreen - 5 {
                    y = topOfVisible - windowHeight - 4.0
                } else {
                    y = topOfScreen - windowHeight - 8.0
                }
            }
            
            let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
            let panel = KeyablePanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar + 1
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            
            self.audioManager = StreamingAudioManager(text: text) { [weak self] in
                self?.dismiss()
                onFinished?()
            }
            
            let hosting = NSHostingView(
                rootView: PointyTopNotchBarView(state: self.audioManager!, hasNotch: hasNotch)
            )
            hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
            hosting.wantsLayer = true
            panel.contentView = hosting
            panel.orderFront(nil)
            self.window = panel
            
            // Watchdog: dismiss if speech synthesis fails completely after timeout
            let targetMgr = self.audioManager
            DispatchQueue.main.asyncAfter(deadline: .now() + 25.0) { [weak self] in
                guard let self = self, let mgr = self.audioManager, mgr === targetMgr else { return }
                if !mgr.isPlaying && mgr.currentChunkIndex == 0 && mgr.chunks.first?.player == nil {
                    self.dismiss()
                }
            }
            
            self.setupEscapeKeyTap()
            self.registerGlobalEscapeHotKey()
        }
    }
    
    public func presentAudioFile(filePath: String, project: String = "Jarvis", onFinished: (() -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.dismiss()
            
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
            
            let hasNotch: Bool
            if #available(macOS 12.0, *) {
                hasNotch = targetScreen.safeAreaInsets.top > 0 || targetScreen.auxiliaryTopLeftArea != nil
            } else {
                hasNotch = false
            }
            
            let notchWidth: CGFloat = 185.0
            let barHeight: CGFloat = 30.0
            let windowWidth = notchWidth + 24.0
            let windowHeight = barHeight + 20.0
            
            let x = targetScreen.frame.origin.x + (targetScreen.frame.width - windowWidth) / 2
            let topOfScreen = targetScreen.frame.origin.y + targetScreen.frame.height
            let topOfVisible = targetScreen.visibleFrame.origin.y + targetScreen.visibleFrame.height
            
            let y: CGFloat
            if hasNotch {
                let notchHeight: CGFloat = targetScreen.safeAreaInsets.top > 0 ? targetScreen.safeAreaInsets.top : 32.0
                y = topOfScreen - notchHeight - windowHeight
            } else {
                if topOfVisible < topOfScreen - 5 {
                    y = topOfVisible - windowHeight - 4.0
                } else {
                    y = topOfScreen - windowHeight - 8.0
                }
            }
            
            let frame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
            let panel = KeyablePanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .statusBar + 1
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            
            self.audioManager = StreamingAudioManager(audioFilePath: filePath) { [weak self] in
                self?.dismiss()
                onFinished?()
            }
            
            let hosting = NSHostingView(
                rootView: PointyTopNotchBarView(state: self.audioManager!, hasNotch: hasNotch)
            )
            hosting.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)
            hosting.wantsLayer = true
            panel.contentView = hosting
            panel.orderFront(nil)
            self.window = panel
            
            // Instant Autoplay Verification
            let targetMgr = self.audioManager
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self, let mgr = self.audioManager, mgr === targetMgr else { return }
                if !mgr.isPlaying {
                    if let p = mgr.chunks.first?.player {
                        p.play()
                        mgr.isPlaying = true
                        mgr.startTimer()
                    } else {
                        self.dismiss()
                    }
                }
            }
            
            self.setupEscapeKeyTap()
            self.registerGlobalEscapeHotKey()
        }
    }
    
    private var isDismissing = false
    public func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true
        defer { isDismissing = false }
        
        unregisterGlobalEscapeHotKey()
        
        let mgr = audioManager
        audioManager = nil
        mgr?.close()
        
        window?.orderOut(nil)
        window = nil
    }
    
    public func updateVolume() {
        DispatchQueue.main.async { [weak self] in
            self?.audioManager?.updateVolume()
        }
    }
    
    public func setupEscapeKeyTap() {
        // 1. CoreGraphics Global Event Tap (Active interceptor)
        if eventTap == nil {
            let eventMask = (1 << CGEventType.keyDown.rawValue)
            let refcon = Unmanaged.passUnretained(self).toOpaque()
            
            if let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(eventMask),
                callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        if let refcon = refcon {
                            let controller = Unmanaged<NotchWindowController>.fromOpaque(refcon).takeUnretainedValue()
                            if let t = controller.eventTap {
                                CGEvent.tapEnable(tap: t, enable: true)
                            }
                        }
                        return nil
                    }
                    
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    if keyCode == 53 { // Escape
                        if let refcon = refcon {
                            let controller = Unmanaged<NotchWindowController>.fromOpaque(refcon).takeUnretainedValue()
                            if controller.window != nil || SpeechQueueManager.shared.isSpeaking {
                                DispatchQueue.main.async {
                                    SpeechQueueManager.shared.stopCurrent()
                                }
                                return nil // Swallows Escape so background windows aren't affected
                            }
                        }
                    }
                    return Unmanaged.passUnretained(event)
                },
                userInfo: refcon
            ) {
                let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                self.eventTap = tap
                self.runLoopSource = source
                NSLog("[AgentSpeak] CGEventTap for Escape key installed.")
            } else {
                NSLog("[AgentSpeak] Warning: CGEventTap could not be created. Using NSEvent monitors.")
            }
        } else if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        
        // 2. Global Event Monitor (Passive fallback for when active tap is bypassed)
        if globalKeyMonitor == nil {
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // Escape
                    guard let self = self else { return }
                    if self.window != nil || SpeechQueueManager.shared.isSpeaking {
                        DispatchQueue.main.async {
                            SpeechQueueManager.shared.stopCurrent()
                        }
                    }
                }
            }
        }
        
        // 3. Local Key Monitor (Active when notch window or application has focus)
        if localKeyMonitor == nil {
            localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { // Escape
                    guard let self = self else { return event }
                    if self.window != nil || SpeechQueueManager.shared.isSpeaking {
                        DispatchQueue.main.async {
                            SpeechQueueManager.shared.stopCurrent()
                        }
                        return nil
                    }
                }
                return event
            }
        }
    }
    
    // MARK: - 4. Carbon Global HotKey (0 Permissions Required — macOS System-Wide Native Dispatch)
    public func registerGlobalEscapeHotKey() {
        guard hotKeyRef == nil else { return }
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let target = GetEventDispatcherTarget()
        
        let status = InstallEventHandler(target, { (handler, event, userData) -> OSStatus in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if hotKeyID.id == 53 {
                DispatchQueue.main.async {
                    SpeechQueueManager.shared.stopCurrent()
                }
                return noErr
            }
            return noErr
        }, 1, &eventType, nil, &eventHandlerRef)
        
        let hotKeyID = EventHotKeyID(signature: 0x4153504B, id: 53) // "ASPK", 53
        let regStatus = RegisterEventHotKey(UInt32(kVK_Escape), 0, hotKeyID, target, 0, &hotKeyRef)
        if regStatus == noErr {
            NSLog("[AgentSpeak] Carbon Global Escape HotKey registered (Zero permissions required).")
        } else {
            NSLog("[AgentSpeak] Carbon RegisterEventHotKey returned code \(regStatus).")
        }
    }
    
    public func unregisterGlobalEscapeHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
