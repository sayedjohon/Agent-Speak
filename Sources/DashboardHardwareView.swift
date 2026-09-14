import SwiftUI
import Cocoa

// MARK: - Dashboard Hardware & Menu Bar View
public struct DashboardHardwareView: View {
    @Binding var showTrayIcon: Bool
    let isAccessibilityTrusted: Bool
    let onSaveConfig: () -> Void
    @ObservedObject private var queueManager = SpeechQueueManager.shared
    
    public init(showTrayIcon: Binding<Bool>, isAccessibilityTrusted: Bool, onSaveConfig: @escaping () -> Void) {
        self._showTrayIcon = showTrayIcon
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.onSaveConfig = onSaveConfig
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Notch Section
            VStack(alignment: .leading, spacing: 10) {
                Text("DYNAMIC NOTCH HUD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "macbook.gen2")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Camera Notch Overlay")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Floats smoothly under the camera notch on MacBook Pro and Air")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Active")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                HStack {
                    Image(systemName: "escape")
                        .foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quick Silence Key (Esc)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Press Escape anywhere on macOS to immediately stop speech and close notch")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if isAccessibilityTrusted {
                        Text("Active 🟢")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Button(action: {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("Enable Accessibility")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.yellow)
                                .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
            
            // Menu Bar Tray Section
            VStack(alignment: .leading, spacing: 10) {
                Text("MENU BAR STATUS ICON")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .foregroundColor(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show Menu Bar Icon")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                        Text("Quickly access controls and settings from the top macOS status bar")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $showTrayIcon)
                        .toggleStyle(.switch)
                        .onChange(of: showTrayIcon) { newValue in
                            onSaveConfig()
                            AppDelegate.shared?.setTrayIconVisible(newValue)
                        }
                }
                
                Divider().background(Color.white.opacity(0.06))
                
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(queueManager.isSpeaking ? Color.green : Color(red: 0.2, green: 0.85, blue: 0.5))
                            .frame(width: 7, height: 7)
                        Text(queueManager.isSpeaking ? "Menu Bar Status: Speaking (Active)" : "Menu Bar Status: Ready (Standby)")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(showTrayIcon ? "Visible in Menu Bar" : "Hidden")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(showTrayIcon ? .green : .secondary)
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
        }
    }
}
