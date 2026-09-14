import Foundation
import AVFoundation

public class VoiceVolumeManager: ObservableObject {
    public static let shared = VoiceVolumeManager()
    
    /// Voice volume level from 1% to 200%. 100% is standard full volume.
    @Published public var volume: Int = 100
    
    private let configPath: URL
    
    public var isBoosted: Bool {
        return volume > 100
    }
    
    public var gainRatio: Float {
        return max(0.01, Float(volume) / 100.0)
    }
    
    public var decibelBoost: Float {
        guard volume > 100 else { return 0.0 }
        return 20.0 * log10(gainRatio)
    }
    
    public var decibelFormatted: String {
        if volume == 100 {
            return "0.0 dB (Standard)"
        } else if volume < 100 {
            let db = 20.0 * log10(gainRatio)
            return String(format: "%.1f dB", db)
        } else {
            return String(format: "+%.1f dB Boost", decibelBoost)
        }
    }
    
    /// The volume multiplier for AVAudioPlayer. Clamped between 0.01 and 1.0.
    /// When boosted (> 100%), the gain is baked directly into the PCM audio buffer,
    /// so the player's volume remains at 1.0 to preserve maximum dynamic headroom.
    public var playerVolume: Float {
        if volume > 100 {
            return 1.0
        } else {
            return max(0.01, min(1.0, Float(volume) / 100.0))
        }
    }
    
    private init() {
        self.configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".agentspeak/config.json")
        loadConfig()
    }
    
    public func setVolume(_ newVolume: Int) {
        let clamped = max(1, min(200, newVolume))
        guard clamped != self.volume else { return }
        DispatchQueue.main.async {
            self.volume = clamped
            self.saveConfig()
            NotchWindowController.shared.updateVolume()
            LastVoiceManager.shared.updateVolume()
        }
    }
    
    public func loadConfig() {
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audio = json["audio"] as? [String: Any] else { return }
        
        if let d = audio["volume"] as? Double {
            if d <= 2.0 {
                self.volume = max(1, min(200, Int(round(d * 100.0))))
            } else {
                self.volume = max(1, min(200, Int(d)))
            }
        } else if let i = audio["volume"] as? Int {
            if i <= 2 {
                self.volume = max(1, min(200, i * 100))
            } else {
                self.volume = max(1, min(200, i))
            }
        }
    }
    
    public func saveConfig() {
        try? FileManager.default.createDirectory(at: configPath.deletingLastPathComponent(), withIntermediateDirectories: true)
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configPath),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = parsed
        }
        var audio = json["audio"] as? [String: Any] ?? [:]
        audio["volume"] = self.volume
        json["audio"] = audio
        
        if let updatedData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? updatedData.write(to: configPath)
        }
    }
    
    /// Applies soft-knee analog saturation gain in-place to an uncompressed audio file (WAV / AIFF / CAF).
    /// Prevents digital square-wave clipping by smoothly compressing peaks approaching 0 dBFS using tanh.
    @discardableResult
    public func applyGainIfNeeded(filePath: String) -> Bool {
        guard isBoosted else { return false }
        guard FileManager.default.fileExists(atPath: filePath) else { return false }
        
        let fileUrl = URL(fileURLWithPath: filePath)
        do {
            let file = try AVAudioFile(forReading: fileUrl)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return false
            }
            try file.read(into: buffer)
            
            let gain = self.gainRatio
            let channels = Int(format.channelCount)
            let threshold: Float = 0.85
            let headroom: Float = 1.0 - threshold
            
            if let floatData = buffer.floatChannelData {
                for ch in 0..<channels {
                    let channelPtr = floatData[ch]
                    let count = Int(buffer.frameLength)
                    for i in 0..<count {
                        let sample = channelPtr[i] * gain
                        if sample > threshold {
                            channelPtr[i] = threshold + headroom * tanh((sample - threshold) / headroom)
                        } else if sample < -threshold {
                            channelPtr[i] = -threshold + (-headroom) * tanh((sample - -threshold) / (-headroom))
                        } else {
                            channelPtr[i] = sample
                        }
                    }
                }
            }
            
            // Write to temporary sibling file first for atomic replacement
            let tempUrl = fileUrl.deletingLastPathComponent()
                .appendingPathComponent("gain_\(UUID().uuidString).\(fileUrl.pathExtension)")
            let outFile = try AVAudioFile(forWriting: tempUrl, settings: file.fileFormat.settings)
            try outFile.write(from: buffer)
            
            _ = try? FileManager.default.removeItem(at: fileUrl)
            try FileManager.default.moveItem(at: tempUrl, to: fileUrl)
            return true
        } catch {
            NSLog("[VoiceVolumeManager] Gain processing error for %@: %@", filePath, error.localizedDescription)
            return false
        }
    }
}
