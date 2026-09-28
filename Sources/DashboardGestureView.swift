import SwiftUI
import Cocoa
import AVFoundation

// MARK: - Dashboard Gesture View
public struct DashboardGestureView: View {
    @ObservedObject var manager = CameraGestureManager.shared
    @ObservedObject var whisperManager = GroqWhisperManager.shared
    
    @State private var cursorSpeed: Double = 1.2
    @State private var scrollSpeed: Double = 1.0
    @State private var smoothing: Double = 0.85
    @State private var pinchDist: Double = 0.055
    @State private var trackingAnchor: String = "wrist"
    @State private var isHudActive: Bool = true
    @State private var isSkeletonHudActive: Bool = true
    @State private var isTestingRecord: Bool = false
    @State private var customEndpointTestStatus: String? = nil
    @State private var isTestingCustomEndpoint: Bool = false
    @State private var isRecordingKey: Bool = false
    @State private var keyRecordingMonitor: Any? = nil
    
    private let supportedLanguages: [(code: String, name: String)] = [
        ("", "Auto-detect (All Languages)"),
        ("en", "English"),
        ("bn", "Bengali (বাংলা)"),
        ("es", "Spanish (Español)"),
        ("fr", "French (Français)"),
        ("de", "German (Deutsch)"),
        ("it", "Italian (Italiano)"),
        ("pt", "Portuguese (Português)"),
        ("ru", "Russian (Русский)"),
        ("ja", "Japanese (日本語)"),
        ("ko", "Korean (한국어)"),
        ("zh", "Chinese (中文)"),
        ("ar", "Arabic (العربية)"),
        ("hi", "Hindi (हिन्दी)"),
        ("tr", "Turkish (Türkçe)"),
        ("nl", "Dutch (Nederlands)"),
        ("id", "Indonesian (Bahasa Indonesia)")
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headerBanner
            cameraPreviewCard
            controlsAndSlidersCard
            GestureTogglesCardView()
            dictationEngineCard
            GestureTestGridCardView()
            GestureReferenceGuideCardView()
        }
        .onAppear {
            loadGesturePreferences()
        }
        .onDisappear {
            stopKeyRecording()
        }
    }
    
    // MARK: - Header
    private var headerBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vision & Hand Gestures")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("100% on-device dual-hand tracking on Apple Silicon. Control your cursor, click, drag, scroll, and dictate hands-free.")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                manager.toggle()
                saveGesturePreferences()
            }) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(manager.isRunning ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    
                    Text(manager.isRunning ? "Stop Camera" : "Enable Gestures")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(manager.isRunning ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.18))
                .foregroundColor(manager.isRunning ? .red : .accentColor)
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(manager.isRunning ? Color.red.opacity(0.35) : Color.accentColor.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Live Preview Card
    private var cameraPreviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live Hand Landmark Feed", systemImage: "hand.raised.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if manager.isRunning {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("FPS:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", manager.currentFPS))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Hands:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("\(manager.detectedHands.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(manager.detectedHands.isEmpty ? .secondary : .cyan)
                        }
                    }
                }
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.06, blue: 0.08))
                    .frame(height: 220)
                
                if manager.isRunning {
                    HandSkeletonCanvasView(hands: manager.detectedHands, anchorType: trackingAnchor)
                        .frame(height: 220)
                    
                    if manager.detectedHands.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 28))
                                .foregroundColor(.gray.opacity(0.6))
                            Text("Raise your hands in front of the camera")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Camera is currently off. Click 'Enable Gestures' to start.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
            
            // Camera device picker
            HStack {
                Text("Camera Source:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $manager.selectedCameraId) {
                    Text("System Default Camera").tag("default")
                    ForEach(manager.availableCameras) { cam in
                        Text(cam.name).tag(cam.id)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 260)
                .onChange(of: manager.selectedCameraId) { _, newId in
                    manager.selectCamera(deviceId: newId)
                    saveGesturePreferences()
                }
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Sliders & Tuning Card
    private var controlsAndSlidersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tracking & Sensitivity Tuning")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                // Tracking Anchor (Wrist vs Knuckle vs Tip)
                GridRow {
                    Text("Tracking Anchor")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $trackingAnchor) {
                        Text("Wrist Joint (Rock-Solid / No Click Drift)").tag("wrist")
                        Text("Knuckle Base (Index MCP)").tag("indexMCP")
                        Text("Index Fingertip").tag("indexTip")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: trackingAnchor) { _, val in
                        GestureClassifier.shared.trackingAnchor = val
                        saveGesturePreferences()
                    }
                    
                    Text("📍")
                        .frame(width: 45, alignment: .trailing)
                }
                
                GridRow {
                    Text("Cursor Speed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Slider(value: $cursorSpeed, in: 0.6...2.4, step: 0.1)
                        .onChange(of: cursorSpeed) { _, val in
                            MouseCursorController.shared.cursorSpeed = CGFloat(val)
                            saveGesturePreferences()
                        }
                    Text(String(format: "%.1fx", cursorSpeed))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 45, alignment: .trailing)
                }
                
                GridRow {
                    Text("Scroll Speed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Slider(value: $scrollSpeed, in: 0.5...3.0, step: 0.1)
                        .onChange(of: scrollSpeed) { _, val in
                            GestureClassifier.shared.scrollSensitivity = CGFloat(val)
                            saveGesturePreferences()
                        }
                    Text(String(format: "%.1fx", scrollSpeed))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 45, alignment: .trailing)
                }
                
                GridRow {
                    Text("Jitter Smoothing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Slider(value: $smoothing, in: 0.5...0.98, step: 0.02)
                        .onChange(of: smoothing) { _, val in
                            MouseCursorController.shared.smoothingFactor = val
                            saveGesturePreferences()
                        }
                    Text(String(format: "%d%%", Int(smoothing * 100)))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 45, alignment: .trailing)
                }
                
                GridRow {
                    Text("Pinch Threshold")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Slider(value: $pinchDist, in: 0.035...0.085, step: 0.005)
                        .onChange(of: pinchDist) { _, val in
                            GestureClassifier.shared.pinchThreshold = CGFloat(val)
                            saveGesturePreferences()
                        }
                    Text(String(format: "%.3f", pinchDist))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 45, alignment: .trailing)
                }
            }
            
            Divider()
            
            // Floating HUD toggle
            Toggle(isOn: $isHudActive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Floating Gesture HUD")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text("Displays immediate visual status badge whenever a gesture triggers.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: isHudActive) { _, active in
                manager.isHUDEnabled = active
                if !active { GestureHUDController.shared.hide() }
                saveGesturePreferences()
            }
            
            // Floating Hand Skeleton Box Under Tray
            Toggle(isOn: $isSkeletonHudActive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Hand Skeleton Box Under Tray")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    Text("Compact floating square box underneath the icon tray showing live two-hand skeleton tracking.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: isSkeletonHudActive) { _, active in
                manager.isSkeletonPreviewEnabled = active
                if active && manager.isRunning {
                    TraySkeletonHUDController.shared.show()
                } else {
                    TraySkeletonHUDController.shared.hide()
                }
                saveGesturePreferences()
            }
            
            if isSkeletonHudActive {
                HStack {
                    Spacer()
                    Button(action: {
                        TraySkeletonHUDController.shared.resetPosition()
                        if manager.isRunning {
                            TraySkeletonHUDController.shared.show()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Box Under Tray")
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.cyan)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Voice Dictation & Whisper Settings Card
    private var dictationEngineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Voice Dictation & Whisper Engine", systemImage: "waveform.badge.mic")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 5) {
                    Circle()
                        .fill(whisperManager.fnHoldDictationEnabled ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(whisperManager.dictationTriggerName)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
            
            // Push-to-Talk Toggle
            Toggle(isOn: $whisperManager.fnHoldDictationEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Hold Key to Dictate (Push-to-Talk)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(whisperManager.dictationTriggerName)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text("Hold down your assigned key to record speech. Release to transcribe with Whisper and auto-paste directly into your active app.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: whisperManager.fnHoldDictationEnabled) { _, val in
                whisperManager.saveConfig()
                if val {
                    FnDictationController.shared.start()
                }
            }
            
            // Dictation Trigger Key Selector & Custom Assignment
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center) {
                    Text("Trigger Key Assignment:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        if isRecordingKey {
                            stopKeyRecording()
                        } else {
                            startKeyRecording()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isRecordingKey ? "record.circle.fill" : "keyboard")
                                .font(.system(size: 10))
                                .foregroundColor(isRecordingKey ? .red : .teal)
                            Text(isRecordingKey ? "Press any key..." : "Assign Key")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(isRecordingKey ? .red : .teal)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isRecordingKey ? Color.red.opacity(0.18) : Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isRecordingKey ? Color.red : Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Picker("", selection: Binding(
                    get: { whisperManager.dictationTriggerKey },
                    set: { newKeyId in
                        if let preset = DictationKeyPreset.standardPresets.first(where: { $0.id == newKeyId }) {
                            whisperManager.setPresetTriggerKey(preset)
                        }
                    }
                )) {
                    ForEach(DictationKeyPreset.standardPresets) { preset in
                        Text("\(preset.name) (\(preset.symbol)) — \(preset.note)").tag(preset.id)
                    }
                    if whisperManager.dictationTriggerKey == "custom" {
                        Text("Custom Key: \(whisperManager.dictationTriggerName)").tag("custom")
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if isRecordingKey {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        Text("Listening for key press... Press any key on your keyboard, or Escape to cancel.")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 2)
                } else {
                    Text("Mac Mini keyboards lack the MacBook Fn button. Right Option (⌥), Right Command (⌘), or Right Control (⌃) are ideal for 1-hand push-to-talk.")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary)
                }
            }
            .padding(10)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.18))
            .cornerRadius(8)
            
            Divider()
            
            // Engine Mode Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Dictation Engine:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $whisperManager.engineMode) {
                    ForEach(DictationEngineMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: whisperManager.engineMode) { _, _ in
                    whisperManager.saveConfig()
                }
            }
            
            // Engine-specific options
            switch whisperManager.engineMode {
            case .groqCloud:
                groqSettingsSection
            case .appleOnDevice:
                appleOnDeviceSection
            case .localEndpoint:
                localEndpointSection
            case .modifierHold:
                modifierHoldSection
            }
            
            Divider()
            
            // Language & Auto-Submit options
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spoken Language:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $whisperManager.languageCode) {
                        ForEach(supportedLanguages, id: \.code) { lang in
                            Text(lang.name).tag(lang.code)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 220)
                    .onChange(of: whisperManager.languageCode) { _, _ in
                        whisperManager.saveConfig()
                    }
                }
                
                Spacer()
                
                Toggle(isOn: $whisperManager.autoSubmitReturn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Submit (Return ↵)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Press Return after pasting text")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: whisperManager.autoSubmitReturn) { _, _ in
                    whisperManager.saveConfig()
                }
            }
            
            // Test Dictation Button & Status
            HStack {
                Button(action: {
                    if whisperManager.isRecording {
                        whisperManager.stopRecordingAndTranscribe()
                        isTestingRecord = false
                    } else {
                        whisperManager.startRecording()
                        isTestingRecord = true
                    }
                }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(whisperManager.isRecording ? Color.red : Color.blue)
                            .frame(width: 8, height: 8)
                        
                        Text(whisperManager.isRecording ? "Stop & Transcribe" : "Test Voice Dictation")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(whisperManager.isRecording ? Color.red.opacity(0.2) : Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                    .foregroundColor(whisperManager.isRecording ? .red : .primary)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(whisperManager.statusMessage)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(whisperManager.isRecording ? .red : (whisperManager.isTranscribing ? .yellow : .secondary))
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Groq Cloud Settings Section
    private var groqSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Standalone Interactive API Key Manager Component
            ApiKeyManagerCardView(whisperManager: whisperManager)
            
            // Model Selector
            HStack {
                Text("Model:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
                
                Picker("", selection: $whisperManager.selectedModel) {
                    Text("Whisper Large v3 (Highest Accuracy)").tag("whisper-large-v3")
                    Text("Whisper Large v3 Turbo (Blazing Fast)").tag("whisper-large-v3-turbo")
                    Text("Distil Whisper Large v3 (English Only)").tag("distil-whisper-large-v3-en")
                    Text("Custom Model ID...").tag("custom")
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: whisperManager.selectedModel) { _, _ in whisperManager.saveConfig() }
            }
            
            // Custom Model ID (if selected)
            if whisperManager.selectedModel == "custom" {
                HStack {
                    Text("Custom Model:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 110, alignment: .leading)
                    
                    TextField("e.g. whisper-large-v3 or custom ID", text: $whisperManager.customModelId)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: whisperManager.customModelId) { _, _ in whisperManager.saveConfig() }
                }
            }
        }
    }
    
    // MARK: - Apple On-Device Section (100% Offline)
    private var appleOnDeviceSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "applelogo")
                .font(.system(size: 24))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("100% On-Device Neural Engine Dictation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Zero cloud calls, zero monthly subscriptions, complete offline privacy. Dictation is recognized natively by Apple Silicon.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .quaternaryLabelColor).opacity(0.18))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Local Endpoint Section
    private var localEndpointSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Base URL:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
                
                TextField("http://localhost:8080/v1/audio/transcriptions", text: $whisperManager.customBaseUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: whisperManager.customBaseUrl) { _, _ in whisperManager.saveConfig() }
            }
            
            HStack {
                Text("Model ID:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
                
                TextField("whisper-large-v3", text: $whisperManager.customModelId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: whisperManager.customModelId) { _, _ in whisperManager.saveConfig() }
            }
            
            HStack {
                Text("Custom API Key:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)
                
                SecureField("Optional Bearer Token (sk-...)", text: $whisperManager.customApiKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: whisperManager.customApiKey) { _, _ in whisperManager.saveConfig() }
            }
            
            // Test Custom Endpoint Button & Feedback
            HStack {
                Spacer()
                if let status = customEndpointTestStatus {
                    Text(status)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(status.contains("Reachable") ? .green : .red)
                }
                
                Button(action: testCustomEndpoint) {
                    HStack(spacing: 4) {
                        if isTestingCustomEndpoint {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 10, height: 10)
                        } else {
                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 10))
                        }
                        Text(isTestingCustomEndpoint ? "Testing..." : "Test Endpoint")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isTestingCustomEndpoint || whisperManager.customBaseUrl.isEmpty)
            }
        }
    }
    
    // MARK: - Modifier Hold Section
    private var modifierHoldSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("External Whisper App Modifier Hold")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text("Holds down the Command key while your left fist is closed for external apps like Whisper Flow.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("⌘ Command")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                .cornerRadius(6)
        }
    }
    
    // MARK: - Preferences I/O
    private func loadGesturePreferences() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gestures = json["gestures"] as? [String: Any] else { return }
        
        if let speed = gestures["cursor_speed"] as? Double { cursorSpeed = speed }
        if let sc = gestures["scroll_speed"] as? Double {
            scrollSpeed = sc
            GestureClassifier.shared.scrollSensitivity = CGFloat(sc)
        }
        if let sm = gestures["smoothing_factor"] as? Double { smoothing = sm }
        if let p = gestures["pinch_threshold"] as? Double { pinchDist = p }
        if let h = gestures["hud_enabled"] as? Bool { isHudActive = h }
        if let s = gestures["skeleton_preview_enabled"] as? Bool { isSkeletonHudActive = s }
        if let anchor = gestures["tracking_anchor"] as? String { trackingAnchor = anchor }
        if let cam = gestures["camera_device_id"] as? String { manager.selectedCameraId = cam }
        
        MouseCursorController.shared.cursorSpeed = CGFloat(cursorSpeed)
        MouseCursorController.shared.smoothingFactor = smoothing
        GestureClassifier.shared.pinchThreshold = CGFloat(pinchDist)
        GestureClassifier.shared.trackingAnchor = trackingAnchor
        manager.isHUDEnabled = isHudActive
        manager.isSkeletonPreviewEnabled = isSkeletonHudActive
    }
    
    private func saveGesturePreferences() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }
        
        var gestures: [String: Any] = json["gestures"] as? [String: Any] ?? [:]
        gestures["enabled"] = manager.isRunning
        gestures["cursor_speed"] = cursorSpeed
        gestures["scroll_speed"] = scrollSpeed
        gestures["smoothing_factor"] = smoothing
        gestures["pinch_threshold"] = pinchDist
        gestures["tracking_anchor"] = trackingAnchor
        gestures["hud_enabled"] = isHudActive
        gestures["skeleton_preview_enabled"] = isSkeletonHudActive
        gestures["camera_device_id"] = manager.selectedCameraId
        json["gestures"] = gestures
        
        if let outData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) {
            try? outData.write(to: configPath)
        }
    }
    
    private func testCustomEndpoint() {
        guard !whisperManager.customBaseUrl.isEmpty else { return }
        isTestingCustomEndpoint = true
        customEndpointTestStatus = nil
        whisperManager.testCustomEndpoint(url: whisperManager.customBaseUrl, apiKey: whisperManager.customApiKey) { success, result in
            isTestingCustomEndpoint = false
            customEndpointTestStatus = result
        }
    }
    
    // MARK: - Key Recording Helpers
    private func startKeyRecording() {
        stopKeyRecording()
        isRecordingKey = true
        keyRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .keyDown && event.keyCode == 53 { // Escape
                self.stopKeyRecording()
                return nil
            }
            
            let code = Int64(event.keyCode)
            let isMod = DictationKeyPreset.isModifierKeyCode(code)
            let (name, symbol) = DictationKeyPreset.nameForKeyCode(code)
            
            self.whisperManager.setCustomTriggerKey(code: code, name: "\(name) (\(symbol))", isModifier: isMod)
            self.stopKeyRecording()
            return nil
        }
    }
    
    private func stopKeyRecording() {
        if let m = keyRecordingMonitor {
            NSEvent.removeMonitor(m)
            keyRecordingMonitor = nil
        }
        isRecordingKey = false
    }
}
