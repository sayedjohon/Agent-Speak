import Cocoa
import SwiftUI
import AVFoundation

// MARK: - Sentence Chunker
func splitTextIntoChunks(text: String) -> [String] {
    let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty { return [] }
    
    var rawSentences: [String] = []
    var cur = ""
    for char in clean {
        cur.append(char)
        if char == "." || char == "!" || char == "?" || char == "\n" {
            let s = cur.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { rawSentences.append(s) }
            cur = ""
        }
    }
    let rem = cur.trimmingCharacters(in: .whitespacesAndNewlines)
    if !rem.isEmpty { rawSentences.append(rem) }
    
    if rawSentences.isEmpty { return [clean] }
    if rawSentences.count == 1 { return rawSentences }
    
    let minChunk0Words = 6
    var chunk0Sentences: [String] = []
    var chunk0WordCount = 0
    var remainingSentences: [String] = []
    var splitIndex = rawSentences.count
    
    for (idx, s) in rawSentences.enumerated() {
        let wCount = s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        chunk0Sentences.append(s)
        chunk0WordCount += wCount
        if chunk0WordCount >= minChunk0Words {
            splitIndex = idx + 1
            break
        }
    }
    
    if splitIndex < rawSentences.count {
        remainingSentences = Array(rawSentences[splitIndex...])
    }
    
    var chunks: [String] = [chunk0Sentences.joined(separator: " ")]
    var curChunk = ""
    var curWords = 0
    let targetWordsForSubsequent = 24
    
    for s in remainingSentences {
        let wCount = s.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        if curWords > 0 && (curWords + wCount) > targetWordsForSubsequent {
            chunks.append(curChunk.trimmingCharacters(in: .whitespacesAndNewlines))
            curChunk = s
            curWords = wCount
        } else {
            if curChunk.isEmpty { curChunk = s } else { curChunk += " " + s }
            curWords += wCount
        }
    }
    if !curChunk.isEmpty {
        chunks.append(curChunk.trimmingCharacters(in: .whitespacesAndNewlines))
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
    
    var chunks: [AudioChunk] = []
    var timer: Timer?
    var onClose: (() -> Void)?
    
    private var isCancelled = false
    private var activeRenderProcess: Process?
    private let renderQueue = DispatchQueue(label: "com.agentspeak.speech.render", qos: .userInitiated)
    
    init(text: String, onClose: (() -> Void)?) {
        self.onClose = onClose
        super.init()
        
        let sessionId = UInt32.random(in: 1000...9999)
        let textChunks = splitTextIntoChunks(text: text)
        self.totalChunksCount = max(1, textChunks.count)
        self.chunks = textChunks.enumerated().map { idx, chunkText in
            AudioChunk(index: idx, text: chunkText, filePath: "/tmp/speech_chunk_\(sessionId)_\(idx).aiff")
        }
        
        // Render Chunk 0 synchronously for instant start (~50-80ms)
        if !self.chunks.isEmpty {
            renderChunk(index: 0)
            if let p = self.chunks[0].player {
                p.play()
                self.isPlaying = true
                self.currentChunkIndex = 0
                self.updateTimelineDurations()
                self.startTimer()
            }
        }
        
        if self.chunks.count > 1 {
            self.startBackgroundRenderingPipeline()
        }
    }
    
    private func renderChunk(index: Int) {
        guard index < chunks.count, !isCancelled else { return }
        let c = chunks[index]
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        // No -v flag: Uses your Mac's natural default system voice!
        proc.arguments = ["-o", c.filePath, c.text]
        
        self.activeRenderProcess = proc
        try? proc.run()
        proc.waitUntilExit()
        self.activeRenderProcess = nil
        
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
            try? FileManager.default.removeItem(atPath: chunks[finishedIndex].filePath)
        }
        
        let nextIndex = finishedIndex + 1
        if nextIndex < chunks.count {
            currentChunkIndex = nextIndex
            playChunkWhenReady(index: nextIndex)
        } else {
            isPlaying = false
            timer?.invalidate()
            timer = nil
            onClose?()
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
        isCancelled = true
        activeRenderProcess?.terminate()
        for c in chunks {
            c.player?.stop()
            try? FileManager.default.removeItem(atPath: c.filePath)
        }
        timer?.invalidate()
        timer = nil
        onClose?()
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
            
            // Skip Back 15s
            Button(action: { state.skip(seconds: -15) }) {
                Image(systemName: "gobackward.15")
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
            
            // Skip Forward 15s
            Button(action: { state.skip(seconds: 15) }) {
                Image(systemName: "goforward.15")
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

// MARK: - Notch Window Controller
public class NotchWindowController {
    public static let shared = NotchWindowController()
    
    private var window: NSPanel?
    private var audioManager: StreamingAudioManager?
    private var eventTap: CFMachPort?
    
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
            let panel = NSPanel(
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
            
            self.setupEscapeKeyTap()
        }
    }
    
    public func dismiss() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
            eventTap = nil
        }
        audioManager?.close()
        audioManager = nil
        window?.orderOut(nil)
        window = nil
    }
    
    private func setupEscapeKeyTap() {
        guard eventTap == nil else { return }
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        
        if let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                if keyCode == 53 { // Escape
                    if let refcon = refcon {
                        let controller = Unmanaged<NotchWindowController>.fromOpaque(refcon).takeUnretainedValue()
                        DispatchQueue.main.async {
                            controller.dismiss()
                        }
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            self.eventTap = tap
        }
    }
}
