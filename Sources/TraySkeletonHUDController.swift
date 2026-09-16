import Cocoa
import SwiftUI

// MARK: - Tray Hand Skeleton HUD Controller (16:9 Clean Minimalist)
public class TraySkeletonHUDController: NSWindowController {
    public static let shared = TraySkeletonHUDController()
    
    private var hudWindow: NSPanel?
    private var hasBeenDraggedByUser: Bool = false
    
    // Exact 16:9 Aspect Ratio (240x135)
    public let boxWidth: CGFloat = 240.0
    public let boxHeight: CGFloat = 135.0
    
    public init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 135),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.ignoresMouseEvents = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        
        let hosting = NSHostingView(rootView: TraySkeletonHUDView())
        panel.contentView = hosting
        
        super.init(window: panel)
        self.hudWindow = panel
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func repositionUnderTray(force: Bool = false) {
        guard let win = hudWindow else { return }
        if hasBeenDraggedByUser && !force { return }
        
        if let trayRect = AppDelegate.shared?.getTrayButtonScreenFrame(), trayRect.width > 0 {
            let targetScreen = AppDelegate.shared?.statusItem?.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
            var x = trayRect.midX - (boxWidth / 2.0)
            let y = trayRect.minY - boxHeight - 8.0
            
            // Constrain horizontally within screen visible frame
            let minX = targetScreen.visibleFrame.minX + 8.0
            let maxX = targetScreen.visibleFrame.maxX - boxWidth - 8.0
            x = max(minX, min(x, maxX))
            
            win.setFrame(NSRect(x: x, y: y, width: boxWidth, height: boxHeight), display: true)
        } else {
            let targetScreen = NSScreen.main ?? NSScreen.screens[0]
            let x = targetScreen.visibleFrame.maxX - boxWidth - 18.0
            let y = targetScreen.visibleFrame.maxY - boxHeight - 8.0
            win.setFrame(NSRect(x: x, y: y, width: boxWidth, height: boxHeight), display: true)
        }
    }
    
    public func resetPosition() {
        hasBeenDraggedByUser = false
        repositionUnderTray(force: true)
    }
    
    public func markDragged() {
        hasBeenDraggedByUser = true
    }
    
    public func show() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let win = self.hudWindow else { return }
            self.repositionUnderTray()
            win.alphaValue = 0.0
            win.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                win.animator().alphaValue = 1.0
            }
        }
    }
    
    public func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let win = self.hudWindow else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.18
                win.animator().alphaValue = 0.0
            }, completionHandler: {
                win.orderOut(nil)
            })
        }
    }
    
    public func toggle() {
        if hudWindow?.isVisible == true {
            hide()
        } else {
            show()
        }
    }
    
    public var isVisible: Bool {
        return hudWindow?.isVisible ?? false
    }
}

// MARK: - Minimalist 16:9 Hand Skeleton View (Zero Text, Pure Form)
public struct TraySkeletonHUDView: View {
    @ObservedObject var manager = CameraGestureManager.shared
    @State private var isHovered = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Live Hand Skeleton Canvas (16:9 full viewport)
            HandSkeletonCanvasView(
                hands: manager.detectedHands,
                anchorType: "indexMCP",
                showGateLine: false
            )
            .padding(6)
            
            // Minimal hover close control in top-right
            if isHovered {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            TraySkeletonHUDController.shared.hide()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 14, height: 14)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .frame(width: 240, height: 135)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.07, green: 0.08, blue: 0.10).opacity(0.80))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.30),
                            Color.cyan.opacity(0.16),
                            Color.white.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        )
        .shadow(color: Color.black.opacity(0.40), radius: 10, x: 0, y: 5)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            // Double click opens Settings Dashboard
            AppDelegate.shared?.showDashboard()
        }
    }
}
