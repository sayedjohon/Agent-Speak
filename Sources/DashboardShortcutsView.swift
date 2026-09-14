import SwiftUI

// MARK: - Apple HIG Shortcuts & CLI Reference Tab
public struct DashboardShortcutsView: View {
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Keyboard Shortcuts Deck
            VStack(alignment: .leading, spacing: 8) {
                Text("GLOBAL KEYBOARD SHORTCUTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                VStack(spacing: 8) {
                    shortcutRow(keys: "⌃ S", title: "Speak Selection", desc: "Highlight any text in any macOS app and press to speak")
                    Divider()
                    shortcutRow(keys: "⌃ P", title: "Speak Clipboard", desc: "Instantly speak text currently copied to clipboard")
                    Divider()
                    shortcutRow(keys: "⌃ ,", title: "Open Settings", desc: "Open this Agent Speak configuration dashboard")
                    Divider()
                    shortcutRow(keys: "⌃ G", title: "Toggle Gestures", desc: "Instantly turn camera vision gesture tracking on or off")
                    Divider()
                    shortcutRow(keys: "⌃ X", title: "Stop Speech & Fade Music", desc: "Instantly stops speech and triggers 2.5s cinematic reverb fade-out")
                    Divider()
                    shortcutRow(keys: "Esc", title: "Quick Dismiss", desc: "Silences voice and dismisses notch HUD with spatial reverb decay")
                    Divider()
                    shortcutRow(keys: "⌘ Q", title: "Quit Application", desc: "Exit and terminate Agent Speak completely")
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            }
            
            // CLI Commands Deck
            VStack(alignment: .leading, spacing: 8) {
                Text("TERMINAL CLI COMMANDS (aspk / agentspeak)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                
                VStack(spacing: 8) {
                    cliRow(cmd: "aspk gesture on | off | status", desc: "Control real-time camera gesture tracking engine")
                    Divider()
                    cliRow(cmd: "aspk gesture list", desc: "Print cheat sheet of all 10-finger hand poses and mappings")
                    Divider()
                    cliRow(cmd: "aspk pb", desc: "Speak text currently copied to clipboard")
                    Divider()
                    cliRow(cmd: "aspk say <text>", desc: "Speak any custom message through notch player")
                    Divider()
                    cliRow(cmd: "aspk bgm on | off", desc: "Toggle background soundtrack playback")
                    Divider()
                    cliRow(cmd: "aspk bgm vol <0-100>", desc: "Set music volume percentage (e.g. aspk bgm vol 25)")
                    Divider()
                    cliRow(cmd: "aspk bgm test", desc: "Preview background music with 2.5s reverb fade-out")
                    Divider()
                    cliRow(cmd: "aspk settings", desc: "Open this Settings dashboard window")
                    Divider()
                    cliRow(cmd: "aspk stop", desc: "Silence voice and fade out background music")
                    Divider()
                    cliRow(cmd: "aspk tray on | off", desc: "Show or hide the menu bar status icon")
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
            }
        }
    }
    
    private func shortcutRow(keys: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(keys)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
    }
    
    private func cliRow(cmd: String, desc: String) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(cmd)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
                Text(desc)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}
