import Foundation
import Cocoa

let socketPath = "/tmp/agentspeak.sock"

func sendSocketMessage(_ text: String) -> Bool {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }
    
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = socketPath.utf8CString
    withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
        _ = pathBytes.withUnsafeBufferPointer { buf in
            memcpy(ptr, buf.baseAddress!, buf.count)
        }
    }
    
    let addrLen = socklen_t(MemoryLayout<sa_family_t>.size + socketPath.utf8.count + 1)
    let res = withUnsafePointer(to: &addr) { ptr in
        ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
            connect(fd, saPtr, addrLen)
        }
    }
    
    guard res == 0 else { return false }
    
    let data = text.data(using: .utf8)!
    _ = data.withUnsafeBytes { ptr in
        write(fd, ptr.baseAddress!, data.count)
    }
    return true
}

func printHelp() {
    print("""
    Agent Speak CLI — 100% Native Swift
    
    Commands:
      status      Check if Agent Speak is running
      say <text>  Speak text through the Liquid Glass notch player (Default System Voice)
      pb          Speak copied clipboard text (perfect for ChatGPT, web, or any app)
      dashboard   Open the CleanMyMac-style 3D Visualizer Dashboard
      tray        Toggle or set menu bar tray icon (tray on | off | toggle)
      test-jarvis Test playback of the Jarvis voice sample in the Notch Player
      stop        Stop current speech and dismiss the notch player
      quit        Terminate the Agent Speak application
    """)
}

let args = CommandLine.arguments

guard args.count > 1 else {
    printHelp()
    exit(0)
}

let cmd = args[1].lowercased()

func getActiveConfigInfo() -> (engine: String, voice: String) {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
    guard let data = try? Data(contentsOf: cfgURL),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let audio = json["audio"] as? [String: Any] else {
        return ("macos_default", "System Voice")
    }
    let engine = audio["engine"] as? String ?? "macos_default"
    var voice = "System Default"
    if engine == "pocket_tts",
       let ptts = audio["pocket_tts"] as? [String: Any],
       let v = ptts["voice"] as? String {
        voice = v
    }
    return (engine, voice)
}

func ensureAppRunningAndSend(_ message: String) -> Bool {
    if sendSocketMessage(message) { return true }
    
    // Clean stale socket if process not alive
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentspeak.app")
    if apps.isEmpty && FileManager.default.fileExists(atPath: socketPath) {
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    print("Agent Speak is starting up...")
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let appURL = URL(fileURLWithPath: "\(home)/Applications/Agent Speak.app")
    if FileManager.default.fileExists(atPath: appURL.path) {
        NSWorkspace.shared.open(appURL)
        // Poll for socket for up to 3 seconds
        for _ in 0..<30 {
            usleep(100_000)
            if sendSocketMessage(message) {
                return true
            }
        }
    }
    return false
}

switch cmd {
case "status":
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentspeak.app")
    let isRunning = !apps.isEmpty
    let socketResponds = sendSocketMessage("")
    let info = getActiveConfigInfo()
    if isRunning {
        print("Agent Speak Status: 🟢 RUNNING (100% Native Swift)")
        print("Voice Engine:       \(info.engine == "pocket_tts" ? "Pocket-TTS Neural Extension" : "Default System Voice (macOS)")")
        print("Active Voice:       \(info.voice)")
        print("IPC Socket:         \(socketPath) (\(socketResponds ? "Healthy" : "Connecting..."))")
    } else {
        if FileManager.default.fileExists(atPath: socketPath) {
            try? FileManager.default.removeItem(atPath: socketPath)
        }
        print("Agent Speak Status: 🔴 NOT RUNNING")
        print("Run 'open -a \"Agent Speak\"' or 'agentspeak dashboard' to launch.")
    }

case "say":
    let text = args.dropFirst(2).joined(separator: " ")
    guard !text.isEmpty else {
        print("Error: Please provide text to speak. Example: agentspeak say 'Hello world'")
        exit(1)
    }
    if ensureAppRunningAndSend(text) {
        print("[Agent Speak] Sent to speech queue via Swift IPC.")
    } else {
        print("Error: Could not connect to Agent Speak socket.")
    }

case "dashboard":
    if ensureAppRunningAndSend("__CMD_SHOW_DASHBOARD__") {
        print("[Agent Speak] Showing Agent Speak Dashboard...")
    } else {
        print("Error: Could not launch Agent Speak Dashboard.")
    }

case "test-jarvis":
    if ensureAppRunningAndSend("__CMD_TEST_JARVIS__") {
        print("[Agent Speak] Presenting Jarvis voice sample in the Notch Player...")
    } else {
        print("Error: Could not trigger Jarvis test sample.")
    }

case "pb", "clipboard", "pasteboard":
    if let pbText = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !pbText.isEmpty {
        if ensureAppRunningAndSend(pbText) {
            print("[Agent Speak] Speaking clipboard text through notch player...")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else {
        print("Error: Clipboard is empty or contains no text.")
    }

case "tray":
    let sub = args.count > 2 ? args[2].lowercased() : "toggle"
    if sub == "on" || sub == "show" {
        if ensureAppRunningAndSend("__CMD_TRAY_ON__") {
            print("[Agent Speak] Menu bar tray icon enabled.")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else if sub == "off" || sub == "hide" {
        if ensureAppRunningAndSend("__CMD_TRAY_OFF__") {
            print("[Agent Speak] Menu bar tray icon hidden.")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else {
        if ensureAppRunningAndSend("__CMD_TOGGLE_TRAY__") {
            print("[Agent Speak] Menu bar tray icon toggled.")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    }

case "stop":
    _ = sendSocketMessage("__CMD_STOP_SPEECH__")
    print("[Agent Speak] Speech stopped.")

case "quit":
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentspeak.app")
    for a in apps {
        a.terminate()
    }
    print("[Agent Speak] Application terminated.")

default:
    print("Unknown command: \(cmd)")
    printHelp()
}
