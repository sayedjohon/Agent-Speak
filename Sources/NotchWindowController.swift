import Cocoa
import SwiftUI
import AVFoundation
import Carbon
import NaturalLanguage

// MARK: - Multilingual Script Detector & Chunker
enum ScriptType: Equatable {
    case bengali, devanagari, arabic, cjk, latin, common
}

func scriptType(of char: Character) -> ScriptType {
    for scalar in char.unicodeScalars {
        let val = scalar.value
        if (0x0980...0x09FF).contains(val) { return .bengali }
        if (0x0900...0x097F).contains(val) { return .devanagari }
        if (0x0600...0x06FF).contains(val) { return .arabic }
        if (0x3040...0x30FF).contains(val) || (0x4E00...0x9FFF).contains(val) { return .cjk }
        if (0x0041...0x005A).contains(val) || (0x0061...0x007A).contains(val) || (0x00C0...0x024F).contains(val) {
            return .latin
        }
    }
    return .common
}

func splitTextIntoChunks(text: String) -> [String] {
    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty { return [] }
    
    // 1. Sentence & phrase boundary split
    var rawSentences: [String] = []
    var cur = ""
    for char in clean {
        cur.append(char)
        if char == "." || char == "!" || char == "?" || char == "\n" || char == ":" || char == ";" {
            let s = cur.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty && s.contains(where: { $0.isLetter || $0.isNumber }) {
                rawSentences.append(s)
            }
            cur = ""
        }
    }
    let rem = cur.trimmingCharacters(in: .whitespacesAndNewlines)
    if !rem.isEmpty && rem.contains(where: { $0.isLetter || $0.isNumber }) {
        rawSentences.append(rem)
    }
    if rawSentences.isEmpty {
        rawSentences = clean.contains(where: { $0.isLetter || $0.isNumber }) ? [clean] : []
    }
    
    // 2. Sub-segment mixed scripts (code-switching between Bengali, Hindi, English, etc.)
    var chunks: [String] = []
    for sentence in rawSentences {
        var segments: [String] = []
        var curScript: ScriptType = .common
        var buf = ""
        
        for char in sentence {
            let s = scriptType(of: char)
            if s == .common {
                buf.append(char)
            } else if s == curScript {
                buf.append(char)
            } else {
                if curScript != .common && !buf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append(buf.trimmingCharacters(in: .whitespacesAndNewlines))
                    buf = ""
                }
                curScript = s
                buf.append(char)
            }
        }
        if !buf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            segments.append(buf.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        if segments.isEmpty {
            chunks.append(sentence)
        } else {
            chunks.append(contentsOf: segments)
        }
    }
    
    return chunks
}

// MARK: - Audio Chunk Model
struct AudioChunk {
    let index: Int
    let text: String
    let filePath: String
    var duration: Double = 0.0
    var startTime: Double = 0.0
    var isReady: Bool = false
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
    var onClose: (() -> Void)?
    
    private var isCancelled = false
    private var activeRenderProcess: Process?
    private let renderQueue = DispatchQueue(label: "com.agentspeak.speech.render", qos: .userInitiated)
    
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
            AudioChunk(index: idx, text: chunkText, filePath: "/tmp/speech_chunk_\(sessionId)_\(idx).aiff")
        }
        
        // Render Chunk 0 synchronously for instant start (~50-80ms)
        renderChunk(index: 0)
        if let p = self.chunks[0].player {
            p.play()
            self.isPlaying = true
            self.currentChunkIndex = 0
            self.updateTimelineDurations()
            self.startTimer()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.close()
            }
        }
        
        if self.chunks.count > 1 {
            self.startBackgroundRenderingPipeline()
        }
    }
    
    init(audioFilePath: String, onClose: (() -> Void)?) {
        self.onClose = onClose
        super.init()
        
        self.totalChunksCount = 1
        var chunk = AudioChunk(index: 0, text: "", filePath: audioFilePath)
        if FileManager.default.fileExists(atPath: audioFilePath),
           let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: audioFilePath)) {
            p.delegate = self
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
    }
    
    private func renderChunk(index: Int) {
        guard index < chunks.count, !isCancelled else { return }
        let c = chunks[index]
        
        // Read audio engine preference from config
        var engine = "macos_default"
        var voice = "Jarvis"
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
        
        // 1. If Pocket-TTS extension is selected, attempt synthesis
        if engine == "pocket_tts" {
            let possibleScripts = [
                FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/DEV_AREA/ssh linux/pocket-tts/speak.py",
                FileManager.default.homeDirectoryForCurrentUser.path + "/.agentspeak/extensions/pocket-tts/speak.py"
            ]
            let possiblePythons = [
                FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/DEV_AREA/ssh linux/pocket-tts/venv/bin/python",
                FileManager.default.homeDirectoryForCurrentUser.path + "/.agentspeak/extensions/pocket-tts/venv/bin/python"
            ]
            
            var scriptPath: String?
            var pythonPath: String?
            for s in possibleScripts { if FileManager.default.fileExists(atPath: s) { scriptPath = s; break } }
            for p in possiblePythons { if FileManager.default.fileExists(atPath: p) { pythonPath = p; break } }
            
            if let script = scriptPath, let py = pythonPath {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: py)
                proc.arguments = [script, c.text, "--voice", voice, "--output", c.filePath, "--no-play"]
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
        
        // 2. Native Apple Silicon voice (macos_default or fallback)
        if !renderedSuccessfully {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            
            var sayVoice: String? = nil
            if (voice == "Jarvis" || voice == "Daniel") && engine == "pocket_tts" {
                sayVoice = "Daniel"
            } else {
                // Multilingual Auto-Detection: Detect language of incoming sentence
                let recognizer = NLLanguageRecognizer()
                recognizer.processString(c.text)
                let lang = recognizer.dominantLanguage?.rawValue
                
                if let lang = lang, !lang.starts(with: "en"), lang != "und",
                   let matchVoice = AVSpeechSynthesisVoice(language: lang) {
                    sayVoice = matchVoice.name
                } else if macosVoice != "default" && !macosVoice.isEmpty {
                    sayVoice = macosVoice
                }
            }
            
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
        }
        
        if FileManager.default.fileExists(atPath: c.filePath),
           let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: c.filePath)) {
            p.delegate = self
            p.prepareToPlay()
            if Thread.isMainThread {
                self.chunks[index].player = p
                self.chunks[index].duration = p.duration
                self.chunks[index].isReady = true
                self.updateTimelineDurations()
            } else {
                DispatchQueue.main.async {
                    self.chunks[index].player = p
                    self.chunks[index].duration = p.duration
                    self.chunks[index].isReady = true
                    self.updateTimelineDurations()
                }
            }
        }
    }
    
    private func startBackgroundRenderingPipeline() {
        renderQueue.async { [weak self] in
            guard let self = self else { return }
            for idx in 1..<self.chunks.count {
                if self.isCancelled { break }
                self.renderChunk(index: idx)
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
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        guard !isDragging else { return }
        guard currentChunkIndex < chunks.count, let p = chunks[currentChunkIndex].player, p.isPlaying else {
            return
        }
        let chunkStart = chunks[currentChunkIndex].startTime
        globalCurrentTime = chunkStart + p.currentTime
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let finishedIndex = currentChunkIndex
        if finishedIndex < chunks.count {
            if chunks[finishedIndex].filePath.hasPrefix("/tmp/") {
                try? FileManager.default.removeItem(atPath: chunks[finishedIndex].filePath)
            }
        }
        
        let nextIndex = finishedIndex + 1
        if nextIndex < chunks.count {
            currentChunkIndex = nextIndex
            playChunkWhenReady(index: nextIndex)
        } else {
            isPlaying = false
            timer?.invalidate()
            timer = nil
            let cb = onClose
            onClose = nil
            cb?()
        }
    }
    
    private func playChunkWhenReady(index: Int) {
        guard index < chunks.count, !isCancelled else { return }
        if let p = chunks[index].player, chunks[index].isReady {
            p.currentTime = 0
            p.play()
            isPlaying = true
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.playChunkWhenReady(index: index)
            }
        }
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
    
    func close() {
        guard !isCancelled else { return }
        isCancelled = true
        activeRenderProcess?.terminate()
        for c in chunks {
            c.player?.stop()
            if c.filePath.hasPrefix("/tmp/") {
                try? FileManager.default.removeItem(atPath: c.filePath)
            }
        }
        timer?.invalidate()
        timer = nil
        let cb = onClose
        onClose = nil
        cb?()
    }
}

// MARK: - Pointy-Top Notch Bar View
struct PointyTopNotchBarView: View {
    @ObservedObject var state: StreamingAudioManager
    let hasNotch: Bool
    
    let notchWidth: CGFloat = 185.0
    let barHeight: CGFloat = 30.0
    
    var topRadius: CGFloat { hasNotch ? 0 : 10 }
    var bottomRadius: CGFloat { 10 }
    
    var body: some View {
        HStack(spacing: 5) {
            // Play / Pause
            Button(action: { state.togglePlayPause() }) {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            
            // Skip Back (Configurable Step)
            Button(action: { state.skip(seconds: -Double(state.skipSeconds)) }) {
                Image(systemName: "gobackward.\(state.skipSeconds)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            
            // Liquid Scrubber
            GeometryReader { geo in
                let w = geo.size.width
                let progress = state.globalTotalDuration > 0 ? CGFloat(state.globalCurrentTime / state.globalTotalDuration) : 0
                let clamped = max(0, min(1, progress))
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.28))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(3, w * clamped), height: 3)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 7.5, height: 7.5)
                        .shadow(color: Color.black.opacity(0.4), radius: 1.5, x: 0, y: 1)
                        .offset(x: max(0, min(w - 7.5, w * clamped - 3.75)))
                }
                .frame(height: 12)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            state.isDragging = true
                            let ratio = max(0, min(1, value.location.x / w))
                            state.globalCurrentTime = Double(ratio) * state.globalTotalDuration
                        }
                        .onEnded { value in
                            let ratio = max(0, min(1, value.location.x / w))
                            let target = Double(ratio) * state.globalTotalDuration
                            state.seek(to: target)
                            state.isDragging = false
                        }
                )
            }
            .frame(height: 12)
            
            // Skip Forward (Configurable Step)
            Button(action: { state.skip(seconds: Double(state.skipSeconds)) }) {
                Image(systemName: "goforward.\(state.skipSeconds)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            
            // Close Button
            Button(action: { state.close() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 5)
        .padding(.bottom, 4)
        .frame(width: notchWidth, height: barHeight)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: topRadius, bottomLeadingRadius: bottomRadius, bottomTrailingRadius: bottomRadius, topTrailingRadius: topRadius)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: topRadius, bottomLeadingRadius: bottomRadius, bottomTrailingRadius: bottomRadius, topTrailingRadius: topRadius)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.65)
        )
        .shadow(color: Color.black.opacity(0.40), radius: 10, x: 0, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                y = topOfScreen - notchHeight - barHeight + 0.5
            } else {
                if topOfVisible < topOfScreen - 5 {
                    y = topOfVisible - barHeight - 4.0
                } else {
                    y = topOfScreen - barHeight - 8.0
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
            panel.contentView = hosting
            panel.orderFront(nil)
            self.window = panel
            
            // Instant Autoplay Verification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self, let mgr = self.audioManager else { return }
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
                y = topOfScreen - notchHeight - barHeight + 0.5
            } else {
                if topOfVisible < topOfScreen - 5 {
                    y = topOfVisible - barHeight - 4.0
                } else {
                    y = topOfScreen - barHeight - 8.0
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
            panel.contentView = hosting
            panel.orderFront(nil)
            self.window = panel
            
            // Instant Autoplay Verification
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self, let mgr = self.audioManager else { return }
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
