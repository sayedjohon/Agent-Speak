import Foundation
import Cocoa
import AVFoundation

// MARK: - Background Music Manager (100% Native Swift AVAudioEngine)
public class BackgroundMusicManager: ObservableObject {
    public static let shared = BackgroundMusicManager()
    
    // Published State
    @Published public var isEnabled: Bool = true
    @Published public var volume: Float = 0.20
    @Published public var randomOffset: Bool = true
    @Published public var shuffle: Bool = true
    @Published public var reverbEnabled: Bool = true
    @Published public var fadeOutDuration: Double = 2.5
    @Published public var fadeInDuration: Double = 0.8
    @Published public var isPlaying: Bool = false
    @Published public var isFadingOut: Bool = false
    @Published public var currentTrackTitle: String = ""
    @Published public var availableTracks: [URL] = []
    
    // CoreAudio / AVFoundation Objects
    private var engine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var reverb = AVAudioUnitReverb()
    private var activeAudioFile: AVAudioFile?
    
    private var fadeTimer: Timer?
    private let stateLock = NSLock()
    
    public var bgmFolderURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/bgm")
    }
    
    private init() {
        loadConfig()
        ensureBgmFolderExists()
        scanTracks()
        setupAudioNodes()
    }
    
    // MARK: - Node Initialization
    private func setupAudioNodes() {
        engine.attach(playerNode)
        engine.attach(reverb)
        
        reverb.loadFactoryPreset(.largeHall)
        reverb.wetDryMix = 30.0
    }
    
    // MARK: - Folder & Track Management
    public func ensureBgmFolderExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: bgmFolderURL.path) {
            try? fileManager.createDirectory(at: bgmFolderURL, withIntermediateDirectories: true)
        }
        
        // If directory has no audio files, try copying bundled/default tracks
        let tracks = listTracksInFolder()
        if tracks.isEmpty {
            restoreDefaultTrack()
        }
    }
    
    public func restoreDefaultTrack() {
        let defaultDest = bgmFolderURL.appendingPathComponent("AC_DC - Back In Black.mp3")
        if FileManager.default.fileExists(atPath: defaultDest.path) {
            return
        }
        
        let candidateSources = [
            Bundle.main.resourceURL?.appendingPathComponent("bgm/AC_DC - Back In Black.mp3"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents/DEV_AREA/ssh linux/agent-speak/Resources/bgm/AC_DC - Back In Black.mp3"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/AC_DC - Back In Black (Official 4K Video) [pAgnJDJN4VA].mp3")
        ]
        
        for candidate in candidateSources {
            guard let c = candidate, FileManager.default.fileExists(atPath: c.path) else { continue }
            try? FileManager.default.copyItem(at: c, to: defaultDest)
            break
        }
        scanTracks()
    }
    
    public func scanTracks() {
        let tracks = listTracksInFolder()
        DispatchQueue.main.async {
            self.availableTracks = tracks
        }
    }
    
    private func listTracksInFolder() -> [URL] {
        let supportedExts = Set(["mp3", "m4a", "wav", "aiff", "aac", "flac"])
        guard let files = try? FileManager.default.contentsOfDirectory(at: bgmFolderURL, includingPropertiesForKeys: [.fileSizeKey]) else {
            return []
        }
        return files.filter { supportedExts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
    
    public func addTrack(from sourceURL: URL) -> Bool {
        let dest = bgmFolderURL.appendingPathComponent(sourceURL.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: sourceURL, to: dest)
            scanTracks()
            return true
        } catch {
            return false
        }
    }
    
    public func deleteTrack(url: URL) {
        try? FileManager.default.removeItem(at: url)
        scanTracks()
    }
    
    public func openBgmFolderInFinder() {
        ensureBgmFolderExists()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: bgmFolderURL.path)
    }
    
    // MARK: - Playback Controls
    
    public func start() {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        guard isEnabled else { return }
        
        // If already playing during a speech queue
        if isPlaying {
            if isFadingOut {
                // Cancel pending fade out and smoothly recover target volume
                cancelFadeTimer()
                isFadingOut = false
                rampVolume(to: volume, duration: 0.4)
            }
            return
        }
        
        cancelFadeTimer()
        isFadingOut = false
        
        let tracks = listTracksInFolder()
        guard !tracks.isEmpty else { return }
        
        let chosenTrack: URL
        if shuffle {
            chosenTrack = tracks.randomElement() ?? tracks[0]
        } else {
            chosenTrack = tracks[0]
        }
        
        playTrack(url: chosenTrack)
    }
    
    private func playTrack(url: URL) {
        do {
            let file = try AVAudioFile(forReading: url)
            self.activeAudioFile = file
            
            // Disconnect and reconnect to match source format
            engine.stop()
            engine.disconnectNodeOutput(playerNode)
            engine.disconnectNodeOutput(reverb)
            
            let format = file.processingFormat
            engine.connect(playerNode, to: reverb, format: format)
            engine.connect(reverb, to: engine.mainMixerNode, format: format)
            
            reverb.bypass = !reverbEnabled
            reverb.wetDryMix = 25.0
            
            try engine.start()
            
            let sampleRate = format.sampleRate
            let totalSeconds = Double(file.length) / sampleRate
            
            var startFrame: AVAudioFramePosition = 0
            var frameCount: AVAudioFrameCount = AVAudioFrameCount(file.length)
            
            if randomOffset && totalSeconds > 20.0 {
                let maxStartSec = max(0.0, totalSeconds - 15.0)
                let randomSec = Double.random(in: 0.0...maxStartSec)
                startFrame = AVAudioFramePosition(randomSec * sampleRate)
                frameCount = AVAudioFrameCount(file.length - startFrame)
            }
            
            playerNode.volume = 0.0
            playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil) { [weak self] in
                // Handle looping if speech outlasts remaining track duration
                DispatchQueue.main.async {
                    guard let self = self, self.isPlaying, !self.isFadingOut else { return }
                    self.scheduleLoopingTrack()
                }
            }
            
            playerNode.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.currentTrackTitle = url.deletingPathExtension().lastPathComponent
            }
            
            // Smooth intro fade-in
            rampVolume(to: volume, duration: fadeInDuration)
            
        } catch {
            NSLog("[AgentSpeak BGM] Error starting playback: \(error)")
        }
    }
    
    private func scheduleLoopingTrack() {
        guard let file = activeAudioFile, isPlaying, !isFadingOut else { return }
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.isPlaying, !self.isFadingOut else { return }
                self.scheduleLoopingTrack()
            }
        }
    }
    
    public func stopWithFadeAndReverb(completion: (() -> Void)? = nil) {
        stateLock.lock()
        defer { stateLock.unlock() }
        
        guard isPlaying, !isFadingOut else {
            completion?()
            return
        }
        
        cancelFadeTimer()
        isFadingOut = true
        
        let startVol = playerNode.volume
        let startMix: Float = reverb.wetDryMix
        let targetMix: Float = reverbEnabled ? 65.0 : startMix
        
        let steps = 40
        let stepInterval = max(0.02, fadeOutDuration / Double(steps))
        var currentStep = 0
        
        DispatchQueue.main.async {
            self.fadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] t in
                guard let self = self else {
                    t.invalidate()
                    return
                }
                currentStep += 1
                let progress = Float(currentStep) / Float(steps)
                
                let curVol = max(0.0, startVol * (1.0 - progress))
                self.playerNode.volume = curVol
                
                if self.reverbEnabled {
                    self.reverb.wetDryMix = startMix + (targetMix - startMix) * progress
                }
                
                if currentStep >= steps {
                    t.invalidate()
                    self.fadeTimer = nil
                    self.stopImmediately()
                    completion?()
                }
            }
        }
    }
    
    public func stopImmediately() {
        cancelFadeTimer()
        playerNode.stop()
        engine.stop()
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.isFadingOut = false
            self.currentTrackTitle = ""
        }
    }
    
    private func cancelFadeTimer() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }
    
    private func rampVolume(to target: Float, duration: Double) {
        let steps = 20
        let stepInterval = max(0.01, duration / Double(steps))
        let initialVol = playerNode.volume
        var step = 0
        
        DispatchQueue.main.async {
            let t = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
                guard let self = self, self.isPlaying, !self.isFadingOut else {
                    timer.invalidate()
                    return
                }
                step += 1
                let progress = Float(step) / Float(steps)
                self.playerNode.volume = initialVol + (target - initialVol) * progress
                
                if step >= steps {
                    self.playerNode.volume = target
                    timer.invalidate()
                }
            }
            RunLoop.main.add(t, forMode: .common)
        }
    }
    
    // MARK: - Dynamic Volume Control
    public func setVolume(_ newVol: Float) {
        let clamped = max(0.0, min(1.0, newVol))
        DispatchQueue.main.async {
            self.volume = clamped
        }
        if isPlaying && !isFadingOut {
            playerNode.volume = clamped
        }
        saveConfig()
    }
    
    // MARK: - Configuration Persistence
    public func loadConfig() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let bgm = json["bgm"] as? [String: Any] else { return }
        
        if let en = bgm["enabled"] as? Bool { self.isEnabled = en }
        if let vol = bgm["volume"] as? Double { self.volume = Float(vol) }
        if let ro = bgm["random_offset"] as? Bool { self.randomOffset = ro }
        if let sh = bgm["shuffle"] as? Bool { self.shuffle = sh }
        if let fo = bgm["fade_out_duration"] as? Double { self.fadeOutDuration = fo }
        if let fi = bgm["fade_in_duration"] as? Double { self.fadeInDuration = fi }
        if let re = bgm["reverb_enabled"] as? Bool { self.reverbEnabled = re }
    }
    
    public func saveConfig() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        var bgm = json["bgm"] as? [String: Any] ?? [:]
        bgm["enabled"] = isEnabled
        bgm["volume"] = Double(volume)
        bgm["random_offset"] = randomOffset
        bgm["shuffle"] = shuffle
        bgm["fade_out_duration"] = fadeOutDuration
        bgm["fade_in_duration"] = fadeInDuration
        bgm["reverb_enabled"] = reverbEnabled
        
        json["bgm"] = bgm
        
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? updated.write(to: configPath)
        }
    }
}
