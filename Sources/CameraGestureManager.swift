import Cocoa
import AVFoundation
import Vision
import Combine

// MARK: - Camera Device Model
public struct CameraDeviceItem: Identifiable, Hashable {
    public var id: String
    public var name: String
    public var isBuiltIn: Bool
    
    public init(id: String, name: String, isBuiltIn: Bool) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
    }
}

// MARK: - Camera Gesture Manager
public class CameraGestureManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    public static let shared = CameraGestureManager()
    
    // Published states for UI
    @Published public var isRunning: Bool = false
    @Published public var isCameraAuthorized: Bool = false
    @Published public var availableCameras: [CameraDeviceItem] = []
    @Published public var selectedCameraId: String = "default"
    @Published public var detectedHands: [HandSkeletonData] = []
    @Published public var lastGesture: RecognizedGestureType = .none
    @Published public var lastGestureLabel: String = "Standby"
    @Published public var currentFPS: Double = 0.0
    @Published public var isHUDEnabled: Bool = true
    
    // AVCapture pipeline
    private var captureSession: AVCaptureSession?
    private var activeDeviceInput: AVCaptureDeviceInput?
    private let captureQueue = DispatchQueue(label: "com.agentspeak.gesture.capture", qos: .userInteractive)
    
    // Vision Request
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    
    // Performance & FPS tracking
    private var frameCount: Int = 0
    private var lastFpsUpdateTime: TimeInterval = 0
    private var lastUiPublishTime: TimeInterval = 0
    
    public override init() {
        super.init()
        handPoseRequest.maximumHandCount = 2
        discoverAvailableCameras()
        checkCameraAuthorization()
    }
    
    // MARK: - Authorization
    public func checkCameraAuthorization() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.isCameraAuthorized = (status == .authorized)
        }
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isCameraAuthorized = granted
                    if granted {
                        self?.discoverAvailableCameras()
                    }
                }
            }
        }
    }
    
    // MARK: - Hardware Discovery
    public func discoverAvailableCameras() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            deviceTypes.append(.external)
            deviceTypes.append(.continuityCamera)
        }
        
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        
        let devices = discovery.devices.map { dev in
            CameraDeviceItem(
                id: dev.uniqueID,
                name: dev.localizedName,
                isBuiltIn: dev.deviceType == .builtInWideAngleCamera
            )
        }
        
        DispatchQueue.main.async {
            self.availableCameras = devices
        }
    }
    
    // MARK: - Start & Stop Tracking
    public func start(persist: Bool = true) {
        guard !isRunning else { return }
        checkCameraAuthorization()
        
        if persist {
            saveStatePreference(enabled: true)
        }
        
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            self.setupCaptureSession()
            self.captureSession?.startRunning()
            
            DispatchQueue.main.async {
                self.isRunning = true
                if self.isHUDEnabled {
                    GestureHUDController.shared.show()
                }
            }
            NSLog("[CameraGestureManager] Started camera gesture tracking session.")
        }
    }
    
    public func stop(persist: Bool = true) {
        guard isRunning else { return }
        
        if persist {
            saveStatePreference(enabled: false)
        }
        
        captureQueue.async { [weak self] in
            guard let self = self else { return }
            self.captureSession?.stopRunning()
            self.captureSession = nil
            self.activeDeviceInput = nil
            
            GestureClassifier.shared.reset()
            MouseCursorController.shared.resetSmoothing()
            KeyboardShortcutController.shared.releaseAllHeldModifiers()
            
            DispatchQueue.main.async {
                self.isRunning = false
                self.detectedHands = []
                self.lastGesture = .none
                self.lastGestureLabel = "Stopped"
                self.currentFPS = 0.0
                GestureHUDController.shared.hide()
            }
            NSLog("[CameraGestureManager] Stopped camera gesture tracking.")
        }
    }
    
    public func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }
    
    private func saveStatePreference(enabled: Bool) {
        let configPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".agentspeak/config.json")
        var json: [String: Any] = [:]
        if let data = try? Data(contentsOf: configPath),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json = existing
        }
        
        var gestures: [String: Any] = json["gestures"] as? [String: Any] ?? [:]
        gestures["enabled"] = enabled
        json["gestures"] = gestures
        
        if let outData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]) {
            try? outData.write(to: configPath)
        }
    }
    
    public func selectCamera(deviceId: String) {
        selectedCameraId = deviceId
        if isRunning {
            captureQueue.async { [weak self] in
                self?.setupCaptureSession()
            }
        }
    }
    
    // MARK: - Session Setup
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .vga640x480 // Ultra-fast 60 FPS, negligible CPU usage
        
        // Find selected device
        let targetDevice: AVCaptureDevice?
        if selectedCameraId == "default" || selectedCameraId.isEmpty {
            targetDevice = AVCaptureDevice.default(for: .video)
        } else {
            targetDevice = AVCaptureDevice(uniqueID: selectedCameraId) ?? AVCaptureDevice.default(for: .video)
        }
        
        guard let device = targetDevice,
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            NSLog("[CameraGestureManager] Failed to create AVCaptureDeviceInput")
            session.commitConfiguration()
            return
        }
        
        session.addInput(input)
        self.activeDeviceInput = input
        
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        output.setSampleBufferDelegate(self, queue: captureQueue)
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        session.commitConfiguration()
        self.captureSession = session
    }
    
    // MARK: - Frame Delegate & Vision Processing
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
            guard let observations = handPoseRequest.results else { return }
            
            var skeletons: [HandSkeletonData] = []
            for obs in observations {
                if var skeleton = parseHandObservation(obs) {
                    skeleton.isIntentional = GestureClassifier.shared.isIntentionalHand(skeleton)
                    skeletons.append(skeleton)
                }
            }
            
            // Execute gesture classification and input synthesis
            GestureClassifier.shared.processHands(hands: skeletons) { [weak self] gesture, label in
                guard let self = self else { return }
                
                if self.isHUDEnabled {
                    GestureHUDState.shared.showGesture(gesture, label: label)
                }
                
                DispatchQueue.main.async {
                    self.lastGesture = gesture
                    self.lastGestureLabel = label
                }
            }
            
            // FPS and UI updates
            updateFPSAndUI(skeletons: skeletons)
            
        } catch {
            NSLog("[CameraGestureManager] Hand pose request error: %@", error.localizedDescription)
        }
    }
    
    private func updateFPSAndUI(skeletons: [HandSkeletonData]) {
        frameCount += 1
        let now = Date().timeIntervalSince1970
        
        if now - lastFpsUpdateTime >= 1.0 {
            let fps = Double(frameCount) / (now - lastFpsUpdateTime)
            frameCount = 0
            lastFpsUpdateTime = now
            
            DispatchQueue.main.async {
                self.currentFPS = fps
            }
        }
        
        // Throttled UI Landmark Publishing (30 FPS for smooth preview without main thread load)
        if now - lastUiPublishTime > 0.033 {
            lastUiPublishTime = now
            DispatchQueue.main.async {
                self.detectedHands = skeletons
            }
        }
    }
    
    // MARK: - Landmark Extraction
    private func parseHandObservation(_ obs: VNHumanHandPoseObservation) -> HandSkeletonData? {
        guard let recognizedPoints = try? obs.recognizedPoints(.all) else { return nil }
        
        func pt(_ key: VNHumanHandPoseObservation.JointName) -> CGPoint {
            guard let point = recognizedPoints[key], point.confidence > 0.25 else {
                return .zero
            }
            return CGPoint(x: CGFloat(point.location.x), y: CGFloat(point.location.y))
        }
        
        let wrist = pt(.wrist)
        guard wrist != .zero else { return nil }
        
        let thumbTip = pt(.thumbTip)
        let indexTip = pt(.indexTip)
        let middleTip = pt(.middleTip)
        let ringTip = pt(.ringTip)
        let littleTip = pt(.littleTip)
        
        let thumbIP = pt(.thumbIP)
        let indexPIP = pt(.indexPIP)
        let middlePIP = pt(.middlePIP)
        let ringPIP = pt(.ringPIP)
        let littlePIP = pt(.littlePIP)
        
        let thumbMP = pt(.thumbMP)
        let indexMCP = pt(.indexMCP)
        let middleMCP = pt(.middleMCP)
        let ringMCP = pt(.ringMCP)
        let littleMCP = pt(.littleMCP)
        
        // Determine chirality (Left vs Right Hand)
        var isRight = true
        if #available(macOS 14.0, *) {
            if obs.chirality == .left {
                isRight = false
            } else if obs.chirality == .right {
                isRight = true
            } else {
                // Fallback geometry: In mirror view, right hand thumb points to the right of index MCP
                isRight = (thumbTip.x > indexMCP.x)
            }
        } else {
            isRight = (thumbTip.x > indexMCP.x)
        }
        
        var jointsDict: [String: CGPoint] = [:]
        for (key, val) in recognizedPoints where val.confidence > 0.25 {
            jointsDict[key.rawValue.rawValue] = CGPoint(x: CGFloat(val.location.x), y: CGFloat(val.location.y))
        }
        
        return HandSkeletonData(
            isRightHand: isRight,
            confidence: obs.confidence,
            wrist: wrist,
            thumbTip: thumbTip,
            indexTip: indexTip,
            middleTip: middleTip,
            ringTip: ringTip,
            littleTip: littleTip,
            thumbIP: thumbIP,
            indexPIP: indexPIP,
            middlePIP: middlePIP,
            ringPIP: ringPIP,
            littlePIP: littlePIP,
            thumbMP: thumbMP,
            indexMCP: indexMCP,
            middleMCP: middleMCP,
            ringMCP: ringMCP,
            littleMCP: littleMCP,
            allJoints: jointsDict
        )
    }
}
