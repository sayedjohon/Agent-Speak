import SwiftUI

// MARK: - Raycast-grade Shortcuts & CLI Reference Tab
public struct DashboardShortcutsView: View {
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Keyboard Shortcuts Deck
            VStack(alignment: .leading, spacing: 10) {
                Text("GLOBAL KEYBOARD SHORTCUTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                
                VStack(spacing: 8) {
                    shortcutRow(keys: "⌃ S", title: "Speak Selection", desc: "Highlight any text in any macOS app and press to speak")
                    Divider().background(Color.white.opacity(0.04))
                    shortcutRow(keys: "⌃ P", title: "Speak Clipboard", desc: "Instantly speak text currently copied to clipboard")
                    Divider().background(Color.white.opacity(0.04))
                    shortcutRow(keys: "⌃ ,", title: "Open Settings", desc: "Open this Agent Speak configuration dashboard")
                    Divider().background(Color.white.opacity(0.04))
                    shortcutRow(keys: "⌃ X", title: "Stop Speech & Fade Music", desc: "Instantly stops speech and triggers 2.5s cinematic reverb fade-out")
                    Divider().background(Color.white.opacity(0.04))
                    shortcutRow(keys: "Esc", title: "Quick Dismiss", desc: "Silences voice and dismisses notch HUD with spatial reverb decay")
                    Divider().background(Color.white.opacity(0.04))
                    shortcutRow(keys: "⌘ Q", title: "Quit Application", desc: "Exit and terminate Agent Speak completely")
                }
            }
            .padding(14)
            .background(Color(red: 0.11, green: 0.12, blue: 0.15))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
            
            // CLI Commands Deck
            VStack(alignment: .leading, spacing: 10) {
                Text("TERMINAL CLI COMMANDS (aspk / agentspeak)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
                
                VStack(spacing: 8) {
                    cliRow(cmd: "aspk pb", desc: "Speak text currently copied to clipboard")
                    Divider().background(Color.white.opacity(0.04))
                    cliRow(cmd: "aspk say <text>", desc: "Speak any custom message through notch player")
                    Divider().background(Color.white.opacity(0.04))
                    cliRow(cmd: "aspk bgm on | off", desc: "Toggle background soundtrack playback")
                    Divider().background(Color.white.opacity(0.04))
                    cliRow(cmd: "aspk bgm vol <0-100>", desc: "Set music volume percentage (e.g. aspk bgm vol 25)")
                    Divider().background(Color.white.opacity(0.04))
                    cliRow(cmd: "aspk bgm test", desc: "Preview background music with 2.5s reverb fade-out")
                    Divider().background(Color.white.opacity(0.04))
                    cliRow(cmd: "aspk settings", desc: "Open this Settings dashboard window")
                    Divider().background(Color.white.opacity(0.04))
                    cliRow(cmd: "aspk stop", desc: "Silence voice and fade out background music")
                    Divider().background(Color.white.opacity(0.04))
                    cliRow(cmd: "aspk tray on | off", desc: "Show or hide the menu bar status icon")
                }
            }
            .padding(14)
            .background(Color(red: 0.11, green: 0.12, blue: 0.15))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.18, green: 0.19, blue: 0.24), lineWidth: 1))
        }
    }
    
    private func shortcutRow(keys: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
            }
            
            Spacer()
            
            Text(keys)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(red: 0.16, green: 0.17, blue: 0.22))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(red: 0.25, green: 0.27, blue: 0.35), lineWidth: 1))
        }
    }
    
    private func cliRow(cmd: String, desc: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(cmd)
                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.5))
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(red: 0.55, green: 0.56, blue: 0.62))
            }
            
            Spacer()
        }
    }
}
