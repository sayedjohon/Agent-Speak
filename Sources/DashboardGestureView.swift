import SwiftUI
import AVFoundation

// MARK: - Hand Skeleton Canvas View
struct HandSkeletonCanvasView: View {
    let hands: [HandSkeletonData]
    let anchorType: String
    
    var body: some View {
        Canvas { context, size in
            // Draw keyboard typing boundary line (hands below this elevation threshold are ignored)
            let thresholdY = (1.0 - GestureClassifier.shared.wristElevationThreshold) * size.height
            var linePath = Path()
            linePath.move(to: CGPoint(x: 10, y: thresholdY))
            linePath.addLine(to: CGPoint(x: size.width - 10, y: thresholdY))
            context.stroke(
                linePath,
                with: .color(Color.yellow.opacity(0.4)),
                style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
            )
            
            for hand in hands {
                let isIntentional = hand.isIntentional
                let color: Color = isIntentional ? (hand.isRightHand ? .cyan : .orange) : Color.gray.opacity(0.35)
                let glowColor: Color = isIntentional ? (hand.isRightHand ? Color.cyan.opacity(0.4) : Color.orange.opacity(0.4)) : Color.clear
                
                // Helper to transform normalized (0...1) camera coords to canvas coords
                func screenPt(_ pt: CGPoint) -> CGPoint {
                    let mx = 1.0 - pt.x // Mirror horizontally for natural webcam reflection
                    let my = 1.0 - pt.y // Vision Y is bottom-up (1.0 = top)
                    return CGPoint(x: mx * size.width, y: my * size.height)
                }
                
                let w = screenPt(hand.wrist)
                let tTip = screenPt(hand.thumbTip)
                let iTip = screenPt(hand.indexTip)
                let mTip = screenPt(hand.middleTip)
                let rTip = screenPt(hand.ringTip)
                let lTip = screenPt(hand.littleTip)
                
                let tIP = screenPt(hand.thumbIP)
                let iPIP = screenPt(hand.indexPIP)
                let mPIP = screenPt(hand.middlePIP)
                let rPIP = screenPt(hand.ringPIP)
                let lPIP = screenPt(hand.littlePIP)
                
                let tMP = screenPt(hand.thumbMP)
                let iMCP = screenPt(hand.indexMCP)
                let mMCP = screenPt(hand.middleMCP)
                let rMCP = screenPt(hand.ringMCP)
                let lMCP = screenPt(hand.littleMCP)
                
                let bones: [[CGPoint]] = [
                    [w, tMP, tIP, tTip],
                    [w, iMCP, iPIP, iTip],
                    [w, mMCP, mPIP, mTip],
                    [w, rMCP, rPIP, rTip],
                    [w, lMCP, lPIP, lTip],
                    [iMCP, mMCP, rMCP, lMCP]
                ]
                
                // Draw bone lines
                for bone in bones {
                    var path = Path()
                    path.addLines(bone)
                    if isIntentional {
                        context.stroke(path, with: .color(glowColor), lineWidth: 5)
                    }
                    context.stroke(path, with: .color(color), lineWidth: isIntentional ? 2 : 1)
                }
                
                // Draw joint nodes
                let allTips = [w, tTip, iTip, mTip, rTip, lTip, tIP, iPIP, mPIP, rPIP, lPIP, tMP, iMCP, mMCP, rMCP, lMCP]
                for node in allTips {
                    let rect = CGRect(x: node.x - 3.5, y: node.y - 3.5, width: 7, height: 7)
                    context.fill(Path(ellipseIn: rect), with: .color(isIntentional ? .white : Color(white: 0.3)))
                    context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.2)
                }
                
                // Highlight active tracking anchor on Right Hand with a prominent pulse ring ONLY if intentional
                if hand.isRightHand && isIntentional {
                    let activeAnchorPt: CGPoint
                    switch anchorType {
                    case "indexTip": activeAnchorPt = iTip
                    case "indexMCP": activeAnchorPt = iMCP
                    default: activeAnchorPt = w
                    }
                    
                    let ringRect = CGRect(x: activeAnchorPt.x - 9, y: activeAnchorPt.y - 9, width: 18, height: 18)
                    context.stroke(Path(ellipseIn: ringRect), with: .color(.green), lineWidth: 2.5)
                }
            }
        }
    }
}

// MARK: - Dashboard Gesture View
public struct DashboardGestureView: View {
    @ObservedObject var manager = CameraGestureManager.shared
    @ObservedObject var whisperManager = GroqWhisperManager.shared
    
    @State private var cursorSpeed: Double = 1.2
    @State private var smoothing: Double = 0.85
    @State private var pinchDist: Double = 0.055
    @State private var elevationThreshold: Double = 0.26
    @State private var trackingAnchor: String = "wrist"
    @State private var isHudActive: Bool = true
    @State private var isApiKeyVisible: Bool = false
    @State private var isTestingRecord: Bool = false
    
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
            dictationEngineCard
            gestureTestGridCard
            gestureReferenceGuideCard
        }
        .onAppear {
            loadGesturePreferences()
        }
    }
    
    // MARK: - Header
    private var headerBanner: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Vision & Hand Gestures")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("100% on-device dual-hand tracking on Apple Silicon. Control your cursor, click, drag, scroll, and dictate hands-free.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button(action: {
                manager.toggle()
                saveGesturePreferences()
            }) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(manager.isRunning ? Color.green : Color.gray)
                        .frame(width: 9, height: 9)
                    
                    Text(manager.isRunning ? "Stop Camera" : "Enable Gestures")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(manager.isRunning ? Color.red.opacity(0.15) : Color.blue.opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(manager.isRunning ? Color.red.opacity(0.4) : Color.blue.opacity(0.4), lineWidth: 1)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                if manager.isRunning {
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Text("FPS:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f", manager.currentFPS))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Hands:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.gray)
                            Text("\(manager.detectedHands.count)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(manager.detectedHands.isEmpty ? .gray : .cyan)
                        }
                    }
                }
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.05))
                    .frame(height: 220)
                
                if manager.isRunning {
                    HandSkeletonCanvasView(hands: manager.detectedHands, anchorType: trackingAnchor)
                        .frame(height: 220)
                    
                    if manager.detectedHands.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 30))
                                .foregroundColor(.gray.opacity(0.6))
                            Text("Raise your hands in front of the camera")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Camera is currently off. Click 'Enable Gestures' to start.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            
            // Camera device picker
            HStack {
                Text("Camera Source:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
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
        .padding(16)
        .background(Color(white: 0.1, opacity: 0.6))
        .cornerRadius(12)
    }
    
    // MARK: - Sliders & Tuning Card
    private var controlsAndSlidersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tracking & Sensitivity Tuning")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 14) {
                // Tracking Anchor (Wrist vs Knuckle vs Tip)
                GridRow {
                    Text("Tracking Anchor")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
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
                        .foregroundColor(.gray)
                    Slider(value: $cursorSpeed, in: 0.6...2.4, step: 0.1)
                        .onChange(of: cursorSpeed) { _, val in
                            MouseCursorController.shared.cursorSpeed = CGFloat(val)
                            saveGesturePreferences()
                        }
                    Text(String(format: "%.1fx", cursorSpeed))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 45, alignment: .trailing)
                }
                
                GridRow {
                    Text("Jitter Smoothing")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Slider(value: $smoothing, in: 0.5...0.98, step: 0.02)
                        .onChange(of: smoothing) { _, val in
                            MouseCursorController.shared.smoothingFactor = val
                            saveGesturePreferences()
                        }
                    Text(String(format: "%d%%", Int(smoothing * 100)))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 45, alignment: .trailing)
                }
                
                GridRow {
                    Text("Pinch Threshold")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Slider(value: $pinchDist, in: 0.035...0.085, step: 0.005)
                        .onChange(of: pinchDist) { _, val in
                            GestureClassifier.shared.pinchThreshold = CGFloat(val)
                            saveGesturePreferences()
                        }
                    Text(String(format: "%.3f", pinchDist))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 45, alignment: .trailing)
                }
                
                GridRow {
                    Text("Elevation Gate")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    Slider(value: $elevationThreshold, in: 0.15...0.40, step: 0.01)
                        .onChange(of: elevationThreshold) { _, val in
                            GestureClassifier.shared.wristElevationThreshold = CGFloat(val)
                            saveGesturePreferences()
                        }
                    Text(String(format: "%d%%", Int(elevationThreshold * 100)))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 45, alignment: .trailing)
                }
            }
            
            Divider().background(Color.white.opacity(0.1))
            
            // Floating HUD toggle
            Toggle(isOn: $isHudActive) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Floating Gesture HUD")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text("Displays immediate visual status badge whenever a gesture triggers.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            .onChange(of: isHudActive) { _, active in
                manager.isHUDEnabled = active
                if !active { GestureHUDController.shared.hide() }
                saveGesturePreferences()
            }
        }
        .padding(16)
        .background(Color(white: 0.1, opacity: 0.6))
        .cornerRadius(12)
    }
    
    // MARK: - Voice Dictation & Whisper Settings Card
    private var dictationEngineCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Voice Dictation & Whisper Engine", systemImage: "waveform.badge.mic")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("Triggered by Left Hand Closed Fist")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.orange)
            }
            
            // Engine Mode Picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Dictation Engine:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
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
            
            Divider().background(Color.white.opacity(0.1))
            
            // Language & Auto-Submit options
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spoken Language:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
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
                            .foregroundColor(.white)
                        Text("Press Return after pasting text")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
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
                    .background(whisperManager.isRecording ? Color.red.opacity(0.2) : Color.white.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                
                Text(whisperManager.statusMessage)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(whisperManager.isRecording ? .red : (whisperManager.isTranscribing ? .yellow : .gray))
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color(white: 0.1, opacity: 0.6))
        .cornerRadius(12)
    }
    
    // MARK: - Groq Cloud Settings Section
    private var groqSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // API Key field
            HStack {
                Text("Groq API Key:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 110, alignment: .leading)
                
                if isApiKeyVisible {
                    TextField("gsk_...", text: $whisperManager.groqApiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: whisperManager.groqApiKey) { _, _ in whisperManager.saveConfig() }
                } else {
                    SecureField("gsk_...", text: $whisperManager.groqApiKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: whisperManager.groqApiKey) { _, _ in whisperManager.saveConfig() }
                }
                
                Button(action: { isApiKeyVisible.toggle() }) {
                    Image(systemName: isApiKeyVisible ? "eye.slash" : "eye")
                        .foregroundColor(.gray)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Model Selector
            HStack {
                Text("Model:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
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
                        .foregroundColor(.gray)
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
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("100% On-Device Neural Engine Dictation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text("Zero cloud calls, zero monthly subscriptions, complete offline privacy. Dictation is recognized natively by Apple Silicon.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .cornerRadius(8)
    }
    
    // MARK: - Local Endpoint Section
    private var localEndpointSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Base URL:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 110, alignment: .leading)
                
                TextField("http://localhost:8080/v1/audio/transcriptions", text: $whisperManager.customBaseUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: whisperManager.customBaseUrl) { _, _ in whisperManager.saveConfig() }
            }
            
            HStack {
                Text("Model ID:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 110, alignment: .leading)
                
                TextField("whisper-large-v3", text: $whisperManager.customModelId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: whisperManager.customModelId) { _, _ in whisperManager.saveConfig() }
            }
        }
    }
    
    // MARK: - Modifier Hold Section
    private var modifierHoldSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("External Whisper App Modifier Hold")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                Text("Holds down the Command key while your left fist is closed for external apps like Whisper Flow.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("⌘ Command")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
        }
    }
    
    // MARK: - Live Gesture Test Grid
    private var gestureTestGridCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Interactive Gesture Monitor")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Perform gestures to see live illumination")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                ForEach(RecognizedGestureType.allCases.filter { $0 != .none }) { g in
                    let isCurrent = (manager.lastGesture == g)
                    HStack(spacing: 8) {
                        Image(systemName: g.iconName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(isCurrent ? .white : .cyan)
                        
                        Text(g.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isCurrent ? .white : .gray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if isCurrent {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(isCurrent ? Color.blue.opacity(0.45) : Color(white: 0.12, opacity: 0.5))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCurrent ? Color.cyan : Color.white.opacity(0.08), lineWidth: isCurrent ? 1.5 : 1)
                    )
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.1, opacity: 0.6))
        .cornerRadius(12)
    }
    
    // MARK: - Gesture Reference Guide
    private var gestureReferenceGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Two-Handed 10-Finger Command Map")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 8) {
                guideRow(hand: "Right", pose: "Wrist / Hand Glide", action: "Moves cursor smoothly with zero pinch drift")
                guideRow(hand: "Right", pose: "Index + Thumb Pinch", action: "Left click / focus input with position lock")
                guideRow(hand: "Right", pose: "Pinch & Hold (>200ms)", action: "Click and drag windows, text, or files")
                guideRow(hand: "Right", pose: "Middle + Thumb Pinch", action: "Right click context menu")
                guideRow(hand: "Right", pose: "2 Fingers Extended", action: "Smooth vertical and horizontal scroll")
                guideRow(hand: "Left", pose: "Closed Fist", action: "Records dictation (Groq Large v3 / Apple Silicon)")
                guideRow(hand: "Left", pose: "Open Fist", action: "Stops dictation, transcribes & auto-pastes text")
                guideRow(hand: "Left", pose: "Index Tap / Pinch", action: "Return / Enter (submits chat query)")
                guideRow(hand: "Left", pose: "V / Peace Sign", action: "Paste (Cmd + V)")
                guideRow(hand: "Left", pose: "C Hand Pose", action: "Copy (Cmd + C)")
                guideRow(hand: "Left", pose: "Open Palm Stop", action: "Escape / Dismiss active popup")
            }
        }
        .padding(16)
        .background(Color(white: 0.1, opacity: 0.6))
        .cornerRadius(12)
    }
    
    private func guideRow(hand: String, pose: String, action: String) -> some View {
        HStack(spacing: 12) {
            Text(hand)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(hand == "Right" ? .cyan : .orange)
                .frame(width: 44, alignment: .leading)
            
            Text(pose)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 170, alignment: .leading)
            
            Text(action)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Preferences I/O
    private func loadGesturePreferences() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        guard let data = try? Data(contentsOf: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let gestures = json["gestures"] as? [String: Any] else { return }
        
        if let speed = gestures["cursor_speed"] as? Double { cursorSpeed = speed }
        if let sm = gestures["smoothing_factor"] as? Double { smoothing = sm }
        if let p = gestures["pinch_threshold"] as? Double { pinchDist = p }
        if let elev = gestures["elevation_threshold"] as? Double {
            elevationThreshold = elev
            GestureClassifier.shared.wristElevationThreshold = CGFloat(elev)
        }
        if let h = gestures["hud_enabled"] as? Bool { isHudActive = h }
        if let anchor = gestures["tracking_anchor"] as? String { trackingAnchor = anchor }
        if let cam = gestures["camera_device_id"] as? String { manager.selectedCameraId = cam }
        
        MouseCursorController.shared.cursorSpeed = CGFloat(cursorSpeed)
        MouseCursorController.shared.smoothingFactor = smoothing
        GestureClassifier.shared.pinchThreshold = CGFloat(pinchDist)
        GestureClassifier.shared.trackingAnchor = trackingAnchor
        manager.isHUDEnabled = isHudActive
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
        gestures["smoothing_factor"] = smoothing
        gestures["pinch_threshold"] = pinchDist
        gestures["elevation_threshold"] = elevationThreshold
        gestures["tracking_anchor"] = trackingAnchor
        gestures["hud_enabled"] = isHudActive
        gestures["camera_device_id"] = manager.selectedCameraId
        json["gestures"] = gestures
        
        if let outData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) {
            try? outData.write(to: configPath)
        }
    }
}
