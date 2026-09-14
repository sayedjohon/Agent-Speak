import Foundation
import AVFoundation
import AppKit
import Combine
import QuartzCore

public class LastVoiceManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = LastVoiceManager()
    
    @Published public var hasVoice: Bool = false
    @Published public var audioFilePath: String? = nil
    @Published public var textPrompt: String = ""
    @Published public var totalDuration: Double = 0.0
    @Published public var currentTime: Double = 0.0
    @Published public var isPlaying: Bool = false
    @Published public var isSynthesizing: Bool = false
    @Published public var downloadStatusMessage: String? = nil
    
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var displayLink: CADisplayLink?
    private let storageDir: URL
    private let lastVoiceFile: URL
    private let metaFile: URL
    private let ioQueue = DispatchQueue(label: "com.agentspeak.lastvoice.io", qos: .userInitiated)
    
    override private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.storageDir = home.appendingPathComponent(".agentspeak")
        self.lastVoiceFile = storageDir.appendingPathComponent("last_voice.m4a")
        self.metaFile = storageDir.appendingPathComponent("last_voice.json")
        super.init()
        
        loadPersistedState()
    }
    
    // MARK: - Persistence & Restoration
    
    public func loadPersistedState() {
        guard FileManager.default.fileExists(atPath: lastVoiceFile.path) else {
            return
        }
        
        var savedText = "Last synthesized speech playback."
        var savedDuration: Double = 0.0
        
        if FileManager.default.fileExists(atPath: metaFile.path),
           let data = try? Data(contentsOf: metaFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            savedText = json["text"] as? String ?? savedText
            savedDuration = json["duration"] as? Double ?? 0.0
        }
        
        if savedDuration <= 0.0, let player = try? AVAudioPlayer(contentsOf: lastVoiceFile) {
            savedDuration = player.duration
        }
        
        self.hasVoice = true
        self.audioFilePath = lastVoiceFile.path
        self.textPrompt = savedText
        self.totalDuration = max(0.1, savedDuration)
        self.currentTime = 0.0
        self.isPlaying = false
        setupPlayer()
    }
    
    public func prepareForNewVoice(text: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isSynthesizing = true
            self?.textPrompt = text
            self?.pause()
        }
    }
    
    // MARK: - Save Audio Chunks to Last Voice M4A
    
    public func recordVoice(text: String, chunkFilePaths: [String]) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            
            let fileManager = FileManager.default
            try? fileManager.createDirectory(at: self.storageDir, withIntermediateDirectories: true)
            
            let validPaths = chunkFilePaths.filter { fileManager.fileExists(atPath: $0) }
            guard !validPaths.isEmpty else {
                DispatchQueue.main.async { self.isSynthesizing = false }
                return
            }
            
            let tempOutput = self.storageDir.appendingPathComponent("temp_voice_\(UInt32.random(in: 1000...9999)).m4a")
            try? fileManager.removeItem(at: tempOutput)
            
            var success = false
            
            if validPaths.count == 1 {
                // Fast path: native afconvert to convert single chunk directly to AAC M4A
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
                p.arguments = ["-f", "m4af", "-d", "aac", validPaths[0], tempOutput.path]
                try? p.run()
                p.waitUntilExit()
                
                if fileManager.fileExists(atPath: tempOutput.path),
                   let attrs = try? fileManager.attributesOfItem(atPath: tempOutput.path),
                   (attrs[.size] as? Int64 ?? 0) > 500 {
                    success = true
                }
            }
            
            // Multi-chunk merge or fallback via AVMutableComposition
            if !success {
                let comp = AVMutableComposition()
                if let track = comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                    var insertTime = CMTime.zero
                    for path in validPaths {
                        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
                        if let assetTrack = asset.tracks(withMediaType: .audio).first {
                            let duration = asset.duration
                            try? track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: assetTrack, at: insertTime)
                            insertTime = CMTimeAdd(insertTime, duration)
                        }
                    }
                    
                    if let export = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetAppleM4A) {
                        export.outputURL = tempOutput
                        export.outputFileType = .m4a
                        let sema = DispatchSemaphore(value: 0)
                        export.exportAsynchronously {
                            sema.signal()
                        }
                        _ = sema.wait(timeout: .now() + 15.0)
                        
                        if fileManager.fileExists(atPath: tempOutput.path),
                           let attrs = try? fileManager.attributesOfItem(atPath: tempOutput.path),
                           (attrs[.size] as? Int64 ?? 0) > 500 {
                            success = true
                        }
                    }
                }
            }
            
            guard success else {
                DispatchQueue.main.async { self.isSynthesizing = false }
                return
            }
            
            // Atomically replace destination last_voice.m4a
            try? fileManager.removeItem(at: self.lastVoiceFile)
            try? fileManager.moveItem(at: tempOutput, to: self.lastVoiceFile)
            
            var measuredDuration: Double = 1.0
            if let p = try? AVAudioPlayer(contentsOf: self.lastVoiceFile) {
                measuredDuration = p.duration
            }
            
            // Write metadata JSON
            let meta: [String: Any] = [
                "text": text,
                "timestamp": Date().timeIntervalSince1970,
                "duration": measuredDuration
            ]
            if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: .prettyPrinted) {
                try? metaData.write(to: self.metaFile)
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isSynthesizing = false
                self.hasVoice = true
                self.audioFilePath = self.lastVoiceFile.path
                self.textPrompt = text
                self.totalDuration = max(0.1, measuredDuration)
                self.currentTime = 0.0
                self.isPlaying = false
                self.setupPlayer()
            }
        }
    }
    
    // MARK: - Audio Preview & Scrubber Controls
    
    private func setupPlayer() {
        guard FileManager.default.fileExists(atPath: lastVoiceFile.path) else { return }
        if let p = try? AVAudioPlayer(contentsOf: lastVoiceFile) {
            p.delegate = self
            p.volume = VoiceVolumeManager.shared.playerVolume
            p.prepareToPlay()
            self.audioPlayer = p
            if totalDuration <= 0.1 {
                self.totalDuration = p.duration
            }
        }
    }
    
    public func updateVolume() {
        DispatchQueue.main.async { [weak self] in
            self?.audioPlayer?.volume = VoiceVolumeManager.shared.playerVolume
        }
    }
    
    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func play() {
        guard hasVoice else { return }
        if audioPlayer == nil {
            setupPlayer()
        }
        guard let p = audioPlayer else { return }
        p.volume = VoiceVolumeManager.shared.playerVolume
        
        if currentTime >= totalDuration - 0.05 {
            currentTime = 0.0
            p.currentTime = 0.0
        } else {
            p.currentTime = currentTime
        }
        
        p.play()
        isPlaying = true
        startTimer()
    }
    
    public func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    public func seek(to time: Double) {
        let clamped = max(0.0, min(time, totalDuration))
        currentTime = clamped
        audioPlayer?.currentTime = clamped
    }
    
    private func startTimer() {
        stopTimer()
        if #available(macOS 14.0, *), let screen = NSScreen.main {
            let link = screen.displayLink(target: self, selector: #selector(onDisplayLinkTick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 80, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        } else {
            let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
                guard let self = self, let p = self.audioPlayer else { return }
                self.currentTime = p.currentTime
            }
            RunLoop.main.add(t, forMode: .common)
            self.playbackTimer = t
        }
    }
    
    @objc private func onDisplayLinkTick() {
        guard let p = audioPlayer else { return }
        currentTime = p.currentTime
    }
    
    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        displayLink?.invalidate()
        displayLink = nil
    }
    
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.currentTime = 0.0
            self?.audioPlayer?.currentTime = 0.0
            self?.stopTimer()
        }
    }
    
    // MARK: - Download & Export Actions
    
    public func downloadAudio() {
        guard hasVoice, FileManager.default.fileExists(atPath: lastVoiceFile.path) else { return }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())
        
        // Build clean alphanumeric filename
        let words = textPrompt.prefix(25).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let slug = words.joined(separator: "_")
        let fileName = slug.isEmpty ? "AgentSpeak_Voice_\(timestamp).m4a" : "AgentSpeak_\(slug)_\(timestamp).m4a"
        
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let destinationURL = downloadsDir.appendingPathComponent(fileName)
        
        do {
            try? FileManager.default.removeItem(at: destinationURL)
            try FileManager.default.copyItem(at: lastVoiceFile, to: destinationURL)
            
            // Highlight in Finder
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
            
            DispatchQueue.main.async { [weak self] in
                self?.downloadStatusMessage = "Saved to ~/Downloads!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if self?.downloadStatusMessage == "Saved to ~/Downloads!" {
                        self?.downloadStatusMessage = nil
                    }
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.downloadStatusMessage = "Export failed."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self?.downloadStatusMessage = nil
                }
            }
        }
    }
    
    public func exportWithSavePanel() {
        guard hasVoice, FileManager.default.fileExists(atPath: lastVoiceFile.path) else { return }
        
        let panel = NSSavePanel()
        panel.title = "Save Synthesized Voice Audio"
        panel.nameFieldStringValue = "AgentSpeak_Voice_\(Int(Date().timeIntervalSince1970)).m4a"
        panel.allowedContentTypes = [.audio]
        panel.canCreateDirectories = true
        
        panel.begin { [weak self] response in
            guard let self = self, response == .OK, let targetURL = panel.url else { return }
            try? FileManager.default.removeItem(at: targetURL)
            try? FileManager.default.copyItem(at: self.lastVoiceFile, to: targetURL)
            
            DispatchQueue.main.async {
                self.downloadStatusMessage = "Exported successfully!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.downloadStatusMessage = nil
                }
            }
        }
    }
}
