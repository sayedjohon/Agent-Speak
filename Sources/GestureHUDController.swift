import Cocoa
import SwiftUI

// MARK: - Gesture HUD State
public class GestureHUDState: ObservableObject {
    public static let shared = GestureHUDState()
    
    @Published public var isVisible: Bool = false
    @Published public var currentGesture: RecognizedGestureType = .none
    @Published public var gestureLabel: String = ""
    @Published public var isDictating: Bool = false
    
    private var fadeTimer: Timer?
    
    private init() {}
    
    public func showGesture(_ gesture: RecognizedGestureType, label: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.currentGesture = gesture
            self.gestureLabel = label
            self.isDictating = (gesture == .whisperFlowHold && label.contains("Holding"))
            self.isVisible = true
            
            self.fadeTimer?.invalidate()
            
            // If it's a persistent state like dictating or dragging, keep alive
            if !self.isDictating && gesture != .clickAndDrag && gesture != .smoothScroll {
                self.fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in
                    withAnimation(.easeOut(duration: 0.35)) {
                        self?.isVisible = false
                    }
                }
            }
        }
    }
    
    public func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.fadeTimer?.invalidate()
            withAnimation(.easeOut(duration: 0.25)) {
                self?.isVisible = false
            }
        }
    }
}

// MARK: - Gesture HUD View
public struct GestureHUDView: View {
    @ObservedObject var state = GestureHUDState.shared
    
    public init() {}
    
    public var body: some View {
        Group {
            if state.isVisible && state.currentGesture != .hoverPointer && state.currentGesture != .none {
                HStack(spacing: 10) {
                    Image(systemName: state.currentGesture.iconName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(iconColor)
                        .shadow(color: iconColor.opacity(0.6), radius: 6, x: 0, y: 0)
                    
                    Text(state.gestureLabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if state.isDictating {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.5), lineWidth: 4)
                                    .scaleEffect(1.4)
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color(white: 0.08, opacity: 0.82))
                        
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        iconColor.opacity(0.55),
                                        Color.white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                    }
                )
                .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 6)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state.isVisible)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: state.currentGesture)
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
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .floating
        win.ignoresMouseEvents = true
        win.hasShadow = false
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
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
        guard let win = hudWindow, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - (win.frame.width / 2.0)
        let y = screenFrame.maxY - 72.0
        win.setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    public func show() {
        repositionWindow()
        hudWindow?.orderFrontRegardless()
    }
    
    public func hide() {
        hudWindow?.orderOut(nil)
    }
}
