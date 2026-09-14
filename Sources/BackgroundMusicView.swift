import SwiftUI
import Cocoa
import AVFoundation

public struct BackgroundMusicView: View {
    @ObservedObject var bgmManager = BackgroundMusicManager.shared
    @State private var previewPlayer: AVAudioPlayer?
    @State private var isTestingReverbFade: Bool = false
    @State private var testTimer: Timer?
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hero Status Card
            heroStatusCard
            
            // Volume Adjustment Card (User Priority)
            volumeControlCard
            
            // Playback Options Card
            playbackOptionsCard
            
            // Interactive Preview & Reverb Test
            previewTestCard
            
            // Music Library & Folder Manager
            trackLibraryCard
        }
        .onAppear {
            bgmManager.loadConfig()
            bgmManager.scanTracks()
        }
    }
    
    // MARK: - 1. Hero Status Card
    private var heroStatusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(bgmManager.isEnabled ? Color.purple.opacity(0.20) : Color.white.opacity(0.06))
                    .frame(width: 48, height: 48)
                
                Image(systemName: bgmManager.isPlaying ? "waveform.path.badge.plus" : "music.quarternote.3")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(bgmManager.isEnabled ? Color.purple : Color.secondary)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Iron Man Soundtrack Mode")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    
                    if bgmManager.isPlaying {
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("NOW PLAYING")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(4)
                    }
                }
                
                Text(bgmManager.isPlaying ? "Playing: \(bgmManager.currentTrackTitle)" : "Plays your favorite background tracks automatically behind speech.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { bgmManager.isEnabled },
                set: { val in
                    bgmManager.isEnabled = val
                    bgmManager.saveConfig()
                    if !val {
                        bgmManager.stopImmediately()
                    }
                }
            ))
            .toggleStyle(SwitchToggleStyle(tint: .purple))
            .labelsHidden()
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.12, blue: 0.16))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(bgmManager.isEnabled ? Color.purple.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - 2. Volume Adjustment Card
    private var volumeControlCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MUSIC VOLUME")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                Spacer()
                Text("\(Int(bgmManager.volume * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(5)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Slider(
                    value: Binding(
                        get: { Double(bgmManager.volume) },
                        set: { val in
                            bgmManager.setVolume(Float(val))
                        }
                    ),
                    in: 0.0...1.0,
                    step: 0.01
                )
                .accentColor(.purple)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Quick Volume Presets
            HStack(spacing: 8) {
                presetButton(title: "Subtle 12%", val: 0.12)
                presetButton(title: "Balanced 20%", val: 0.20)
                presetButton(title: "Rocking 35%", val: 0.35)
                presetButton(title: "Epic 50%", val: 0.50)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.12, blue: 0.16))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func presetButton(title: String, val: Float) -> some View {
        let isSelected = abs(bgmManager.volume - val) < 0.03
        return Button(action: {
            bgmManager.setVolume(val)
        }) {
            Text(title)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(isSelected ? Color.purple.opacity(0.35) : Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.purple : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 3. Playback Options Card
    private var playbackOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PLAYBACK BEHAVIOR")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
            
            // Random Offset Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start from Random Position")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text("Starts audio from a random point in the song instead of beginning at 0:00 every time.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { bgmManager.randomOffset },
                    set: { val in
                        bgmManager.randomOffset = val
                        bgmManager.saveConfig()
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .purple))
                .labelsHidden()
            }
            
            Divider().background(Color.white.opacity(0.06))
            
            // Shuffle Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shuffle Playlist")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Text("Picks a random song from your music folder whenever speech begins.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { bgmManager.shuffle },
                    set: { val in
                        bgmManager.shuffle = val
                        bgmManager.saveConfig()
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .purple))
                .labelsHidden()
            }
            
            Divider().background(Color.white.opacity(0.06))
            
            // Reverb Fade Out Toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Cinematic Reverb Fade-Out")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("2.5s Decay")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.12))
                            .cornerRadius(4)
                    }
                    Text("When speech stops or user hits Escape / Ctrl+X, dissolves music with lush spatial reverb.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { bgmManager.reverbEnabled },
                    set: { val in
                        bgmManager.reverbEnabled = val
                        bgmManager.saveConfig()
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .purple))
                .labelsHidden()
            }
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.12, blue: 0.16))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - 4. Preview & Reverb Test Card
    private var previewTestCard: some View {
        HStack(spacing: 12) {
            Button(action: triggerTestFadeOut) {
                HStack(spacing: 7) {
                    Image(systemName: isTestingReverbFade ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(isTestingReverbFade ? "Stop Test" : "Test Play & Reverb Fade-Out")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(isTestingReverbFade ? .red : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isTestingReverbFade ? Color.red.opacity(0.15) : Color.purple.opacity(0.25))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isTestingReverbFade ? Color.red.opacity(0.5) : Color.purple.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Text("Plays 4 seconds of music then executes the 2.5s spatial reverb dissolution.")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(12)
        .background(Color(red: 0.09, green: 0.10, blue: 0.13))
        .cornerRadius(8)
    }
    
    private func triggerTestFadeOut() {
        if isTestingReverbFade || bgmManager.isPlaying {
            testTimer?.invalidate()
            testTimer = nil
            isTestingReverbFade = false
            bgmManager.stopImmediately()
            return
        }
        
        isTestingReverbFade = true
        bgmManager.start()
        
        testTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            bgmManager.stopWithFadeAndReverb {
                DispatchQueue.main.async {
                    self.isTestingReverbFade = false
                    self.testTimer = nil
                }
            }
        }
    }
    
    // MARK: - 5. Music Library Card
    private var trackLibraryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MUSIC LIBRARY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                
                Spacer()
                
                Text("\(bgmManager.availableTracks.count) \(bgmManager.availableTracks.count == 1 ? "track" : "tracks")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Track list
            VStack(spacing: 6) {
                if bgmManager.availableTracks.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Text("No music files found in ~/.agentspeak/bgm")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Button(action: { bgmManager.restoreDefaultTrack() }) {
                                Text("Restore Iron Man Theme")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.purple)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                } else {
                    ForEach(bgmManager.availableTracks, id: \.path) { trackURL in
                        trackRow(url: trackURL)
                    }
                }
            }
            
            Divider().background(Color.white.opacity(0.06))
            
            // Actions
            HStack(spacing: 10) {
                Button(action: pickAudioFile) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                        Text("Add Track...")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { bgmManager.openBgmFolderInFinder() }) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 11))
                        Text("Open in Finder")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(action: { bgmManager.restoreDefaultTrack() }) {
                    Text("Restore Iron Man Theme")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.12, blue: 0.16))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func trackRow(url: URL) -> some View {
        let name = url.deletingPathExtension().lastPathComponent
        let sizeStr: String = {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let bytes = attrs[.size] as? Int64 {
                let mb = Double(bytes) / (1024 * 1024)
                return String(format: "%.1f MB", mb)
            }
            return ""
        }()
        let isCurrent = bgmManager.currentTrackTitle == name && bgmManager.isPlaying
        
        return HStack(spacing: 10) {
            Image(systemName: "music.note")
                .font(.system(size: 12))
                .foregroundColor(isCurrent ? .purple : .secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 11, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isCurrent ? .purple : .white)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Text(url.pathExtension.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                    if !sizeStr.isEmpty {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Text(sizeStr)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if bgmManager.availableTracks.count > 1 {
                Button(action: {
                    bgmManager.deleteTrack(url: url)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isCurrent ? Color.purple.opacity(0.12) : Color.white.opacity(0.04))
        .cornerRadius(6)
    }
    
    private func pickAudioFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.audio, .mp3]
        panel.prompt = "Import to Agent Speak"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                _ = bgmManager.addTrack(from: url)
            }
        }
    }
}
