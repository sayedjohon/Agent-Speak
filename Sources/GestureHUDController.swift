import Cocoa
import SwiftUI

// MARK: - Gesture HUD State
public class GestureHUDState: ObservableObject {
    public static let shared = GestureHUDState()
    
    @Published public var isVisible: Bool = false
    @Published public var currentGesture: RecognizedGestureType = .none
    @Published public var gestureLabel: String = ""
    @Published public var isDictating: Bool = false
    @Published public var hasNotch: Bool = true
    @Published public var notchWidth: CGFloat = 185.0
    
    private var fadeTimer: Timer?
    
    private init() {}
    
    public func showGesture(_ gesture: RecognizedGestureType, label: String) {
        if gesture == .none || gesture == .hoverPointer || gesture == .clutch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.isVisible && self.currentGesture == .smoothScroll {
                    self.fadeTimer?.invalidate()
                    self.fadeTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                        withAnimation(.easeOut(duration: 0.20)) {
                            self?.isVisible = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                            GestureHUDController.shared.hide()
                        }
                    }
                }
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentGesture = gesture
            self.gestureLabel = label
            self.isDictating = (gesture == .whisperFlowHold && (label.contains("Holding") || label.contains("Listening") || label.contains("Dictating") || label.contains("Record")))
            self.isVisible = true
            
            // Bring the liquid glass notch extension to the front above all windows
            GestureHUDController.shared.show()
            
            self.fadeTimer?.invalidate()
            
            // Auto dismiss non-persistent gestures (click, swipe, etc.)
            if !self.isDictating && gesture != .clickAndDrag && gesture != .smoothScroll {
                let duration: TimeInterval = label.contains("Transcribing") ? 2.5 : 1.4
                self.fadeTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    withAnimation(.easeOut(duration: 0.25)) {
                        self?.isVisible = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if !(self?.isVisible ?? false) {
                            GestureHUDController.shared.hide()
                        }
                    }
                }
            }
        }
    }
    
    public func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.fadeTimer?.invalidate()
            withAnimation(.easeOut(duration: 0.20)) {
                self?.isVisible = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                GestureHUDController.shared.hide()
            }
        }
    }
}

// MARK: - Ultra-Slender Harmonic Wave Bars (Compact 26pt Notch Bar Scale)
public struct SlenderWaveBarsView: View {
    public init() {}
    
    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.2) {
                ForEach(0..<4) { i in
                    let offset = Double(i) * 1.1
                    let h = 3.5 + 6.5 * abs(sin(time * 7.0 + offset))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.65, blue: 0.2),
                                    Color(red: 1.0, green: 0.35, blue: 0.1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2.0, height: CGFloat(h))
                }
            }
            .frame(height: 12)
        }
    }
}

// MARK: - Liquid Glass Mini Notch Bar View
public struct GestureHUDView: View {
    @ObservedObject var state = GestureHUDState.shared
    
    var hasNotch: Bool { state.hasNotch }
    var notchWidth: CGFloat { state.notchWidth }
    var barHeight: CGFloat { 28.0 }
    
    var topRadius: CGFloat { hasNotch ? 0 : 10 }
    var bottomRadius: CGFloat { 10 }
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .top) {
            if state.isVisible && state.currentGesture != .hoverPointer && state.currentGesture != .none && state.currentGesture != .clutch {
                HStack(spacing: 8) {
                    if state.isDictating {
                        // macOS privacy-style breathing orange recording indicator
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.35))
                                .frame(width: 8.5, height: 8.5)
                            Circle()
                                .fill(Color(red: 1.0, green: 0.58, blue: 0.0))
                                .frame(width: 5.0, height: 5.0)
                        }
                        
                        // Ultra-slender harmonic wave bars
                        SlenderWaveBarsView()
                        
                        Text(compactLabel(state.gestureLabel))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                    } else if state.gestureLabel.contains("Transcribing") {
                        Image(systemName: "circle.dotted.and.circle")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.yellow)
                        
                        Text("Transcribing...")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                    } else if state.gestureLabel.contains("Pasted") || state.gestureLabel.contains("Transcribed") {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 0.2, green: 0.9, blue: 0.45))
                        
                        Text("Pasted")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                    } else {
                        // Compact Hand Gesture status
                        Image(systemName: state.currentGesture.iconName)
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(iconColor)
                        
                        Text(state.gestureLabel)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .frame(width: notchWidth, height: barHeight)
                .background(
                    ZStack {
                        UnevenRoundedRectangle(
                            topLeadingRadius: topRadius,
                            bottomLeadingRadius: bottomRadius,
                            bottomTrailingRadius: bottomRadius,
                            topTrailingRadius: topRadius
                        )
                        .fill(.ultraThinMaterial)
                        
                        UnevenRoundedRectangle(
                            topLeadingRadius: topRadius,
                            bottomLeadingRadius: bottomRadius,
                            bottomTrailingRadius: bottomRadius,
                            topTrailingRadius: topRadius
                        )
                        .fill(Color.black.opacity(0.60))
                    }
                )
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: topRadius,
                        bottomLeadingRadius: bottomRadius,
                        bottomTrailingRadius: bottomRadius,
                        topTrailingRadius: topRadius
                    )
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.32),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, x: 0, y: 3)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: state.isVisible)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: state.currentGesture)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: state.isDictating)
    }
    
    private func compactLabel(_ raw: String) -> String {
        if raw.contains("Listening") || raw.contains("Dictating") {
            return "Listening..."
        }
        if raw.contains("Transcribing") {
            return "Transcribing..."
        }
        if raw.contains("Pasted") || raw.contains("Transcribed") {
            return "Pasted"
        }
        return raw
    }
    
    private var iconColor: Color {
        switch state.currentGesture {
        case .whisperFlowHold: return Color.orange
        case .leftClick, .doubleClick: return Color.cyan
        case .clickAndDrag: return Color.yellow
        case .rightClick: return Color.purple
        case .returnKey: return Color.green
        case .copy, .paste, .cut: return Color.blue
        case .escape: return Color.red
        default: return Color.white
        }
    }
}

// MARK: - Gesture HUD Window Controller
public class GestureHUDController: NSWindowController {
    public static let shared = GestureHUDController()
    
    private var hudWindow: NSWindow?
    
    public init() {
        let win = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 210, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.isFloatingPanel = true
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .statusBar + 2 // Strictly above menu bar and full-screen spaces
        win.ignoresMouseEvents = true
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        
        let hosting = NSHostingView(rootView: GestureHUDView())
        win.contentView = hosting
        
        super.init(window: win)
        self.hudWindow = win
        
        repositionWindow()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func repositionWindow() {
        guard let win = hudWindow else { return }
        
        let mouseLoc = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
        
        let hasNotch: Bool
        if #available(macOS 12.0, *) {
            hasNotch = targetScreen.safeAreaInsets.top > 0 || targetScreen.auxiliaryTopLeftArea != nil
        } else {
            hasNotch = false
        }
        
        var calculatedNotchWidth: CGFloat = 185.0
        if #available(macOS 12.0, *) {
            if let left = targetScreen.auxiliaryTopLeftArea, let right = targetScreen.auxiliaryTopRightArea {
                let dynamicWidth = right.origin.x - (left.origin.x + left.size.width)
                if dynamicWidth > 50 && dynamicWidth < 400 {
                    calculatedNotchWidth = dynamicWidth
                }
            }
        }
        
        DispatchQueue.main.async {
            GestureHUDState.shared.hasNotch = hasNotch
            GestureHUDState.shared.notchWidth = calculatedNotchWidth
        }
        
        let barHeight: CGFloat = 28.0
        let windowWidth = calculatedNotchWidth + 24.0
        let windowHeight = barHeight + 16.0
        
        let x = targetScreen.frame.origin.x + (targetScreen.frame.width - windowWidth) / 2.0
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
        
        win.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }
    
    public func show() {
        repositionWindow()
        hudWindow?.orderFrontRegardless()
    }
    
    public func hide() {
        hudWindow?.orderOut(nil)
    }
}
