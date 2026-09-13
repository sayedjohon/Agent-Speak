import Cocoa
import SwiftUI

public class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate!
    
    var statusItem: NSStatusItem?
    var dashboardWindow: NSWindow?
    
    public override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupDashboardWindow()
        
        TranscriptWatcher.shared.onSpeechRequest = { source, text in
            SpeechQueueManager.shared.enqueue(source: source, text: text)
        }
        TranscriptWatcher.shared.start()
        
        // Show dashboard window on launch
        showDashboard()
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showDashboard()
        return true
    }
    
    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Agent Speak")
        button.action = #selector(menuBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.target = self
    }
    
    @objc func menuBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu(button: sender)
        } else {
            toggleDashboard()
        }
    }
    
    func showContextMenu(button: NSStatusBarButton) {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Open Agent Speak Dashboard", action: #selector(showDashboard), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Test System Voice", action: #selector(testVoice), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Stop Speech", action: #selector(stopSpeech), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Agent Speak", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }
    
    func setupDashboardWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.title = "Agent Speak"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.backgroundColor = .clear
        
        let hostingView = NSHostingView(rootView: DashboardView())
        window.contentView = hostingView
        
        self.dashboardWindow = window
    }
    
    @objc public func showDashboard() {
        guard let window = dashboardWindow else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc public func toggleDashboard() {
        guard let window = dashboardWindow else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            showDashboard()
        }
    }
    
    @objc func testVoice() {
        SpeechQueueManager.shared.enqueue(
            source: "Agent Speak",
            text: "Testing the default system voice. Agent Speak is running smoothly."
        )
    }
    
    @objc func stopSpeech() {
        SpeechQueueManager.shared.stopCurrent()
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}
