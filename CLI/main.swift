import Foundation
import Cocoa

let socketPath = "/tmp/agentspeak.sock"

func sendSocketMessage(_ text: String) -> Bool {
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return false }
    defer { close(fd) }
    
    var addr = sockaddr_un()
    addr.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathBytes = socketPath.utf8CString
    withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
        _ = pathBytes.withUnsafeBufferPointer { buf in
            memcpy(ptr, buf.baseAddress!, buf.count)
        }
    }
    
    let addrLen = socklen_t(MemoryLayout<sockaddr_un>.size)
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
      selected    Speak highlighted or selected text (alias: sel)
      pb          Speak copied clipboard text (alias: clipboard)
      settings    Open the Agent Speak Settings window (alias: dashboard)
      tray        Toggle or set menu bar tray icon (tray on | off | toggle)
      voice       Manage voices and volume (status | list | set | vol <1-200> | install | clone)
      bgm         Manage Iron Man background soundtrack (on | off | vol | test | open | status)
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
    let socketResponds = sendSocketMessage("__PING__")
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

case "dashboard", "settings":
    if ensureAppRunningAndSend("__CMD_SHOW_DASHBOARD__") {
        print("[Agent Speak] Showing Agent Speak Settings...")
    } else {
        print("Error: Could not launch Agent Speak Settings.")
    }

case "selected", "sel":
    if ensureAppRunningAndSend("__CMD_SPEAK_SELECTED__") {
        print("[Agent Speak] Capturing and speaking selected text...")
    } else {
        print("Error: Could not connect to Agent Speak socket.")
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

case "voice":
    let sub = args.count > 2 ? args[2].lowercased() : "status"
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let extPython = "\(home)/.agentspeak/extensions/pocket-tts/venv/bin/python"
    let extDir = "\(home)/.agentspeak/extensions/pocket-tts"
    let isExtInstalled = FileManager.default.fileExists(atPath: extPython)
    let info = getActiveConfigInfo()

    if sub == "status" || sub == "info" {
        print("─── Voice Engine Status ───")
        print("Active Engine:      \(info.engine == "pocket_tts" ? "Pocket-TTS Neural Extension" : "Default macOS System Voice")")
        print("Active Voice:       \(info.voice)")
        print("Neural Extension:   \(isExtInstalled ? "🟢 INSTALLED (\(extDir))" : "🟡 NOT INSTALLED (On-Demand)")")
        
        var voiceVol = 100
        let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
        if let data = try? Data(contentsOf: cfgURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let audio = json["audio"] as? [String: Any] {
            if let d = audio["volume"] as? Double {
                voiceVol = d <= 2.0 ? Int(round(d * 100.0)) : Int(d)
            } else if let i = audio["volume"] as? Int {
                voiceVol = i <= 2 ? i * 100 : i
            }
        }
        let boostText = voiceVol > 100 ? String(format: " (⚡ +%.1f dB Force Boost Active)", 20.0 * log10(Double(voiceVol) / 100.0)) : (voiceVol == 100 ? " (Standard Full)" : " (Soft)")
        print("Voice Volume:       \(voiceVol)%\(boostText)")
    } else if sub == "list" {
        print("─── Available System Voices (macOS) ───")
        print("• Default System Voice (macOS Auto)")
        print("• Daniel (British English)")
        print("• Samantha (American English)")
        print("• Rishi (Indian English)")
        print("\n─── Pocket-TTS Neural Extension Personas ───")
        if isExtInstalled {
            let voicesDir = "\(extDir)/voices"
            if let files = try? FileManager.default.contentsOfDirectory(atPath: voicesDir) {
                for f in files.sorted() where f.hasSuffix(".safetensors") {
                    let name = (f as NSString).deletingPathExtension
                    print("• \(name)")
                }
            }
        } else {
            print("(Extension not installed. Run 'aspk voice install' to download on-demand)")
        }
    } else if sub == "install" || sub == "install-extension" {
        print("[Agent Speak] Starting Pocket-TTS Neural Extension setup on your Mac...")
        let script = FileManager.default.fileExists(atPath: "\(extDir)/install.sh") ? "\(extDir)/install.sh" : "\(home)/Documents/DEV_AREA/ssh linux/agent-speak/config/install_pocket_tts.sh"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script]
        try? p.run()
        p.waitUntilExit()
    } else if sub == "clone" {
        guard args.count >= 5 else {
            print("Usage: aspk voice clone <PersonaName> <path_to_audio>")
            print("Example: aspk voice clone MyVoice ~/Downloads/sample.wav")
            exit(1)
        }
        let vName = args[3]
        let aPath = (args[4] as NSString).expandingTildeInPath
        let cloneScript = FileManager.default.fileExists(atPath: "\(extDir)/clone_voice.py") ? "\(extDir)/clone_voice.py" : "\(home)/Documents/DEV_AREA/ssh linux/pocket-tts/clone_voice.py"
        let py = isExtInstalled ? extPython : "\(home)/Documents/DEV_AREA/ssh linux/pocket-tts/venv/bin/python"
        
        guard FileManager.default.fileExists(atPath: py) else {
            print("Error: Pocket-TTS runtime not found. Run 'aspk voice install' first.")
            exit(1)
        }
        
        print("[Agent Speak] Cloning voice persona '\(vName)' from \(aPath)...")
        let p = Process()
        p.executableURL = URL(fileURLWithPath: py)
        p.arguments = [cloneScript, aPath, "--name", vName]
        try? p.run()
        p.waitUntilExit()
    } else if sub == "set" {
        guard args.count >= 4 else {
            print("Usage: aspk voice set <macos|pocket> [voice_name]")
            print("Example: aspk voice set pocket Sayed_Johon_Primary")
            print("Example: aspk voice set macos Daniel")
            exit(1)
        }
        let targetEngine = args[3].lowercased().contains("pocket") ? "pocket_tts" : "macos_default"
        let targetVoice = args.count >= 5 ? args[4] : (targetEngine == "pocket_tts" ? "Sayed_Johon_Primary" : "default")
        
        let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
        if let data = try? Data(contentsOf: cfgURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var audio = json["audio"] as? [String: Any] {
            audio["engine"] = targetEngine
            if targetEngine == "pocket_tts" {
                var ptts = audio["pocket_tts"] as? [String: Any] ?? [:]
                ptts["voice"] = targetVoice
                audio["pocket_tts"] = ptts
            } else {
                audio["macos_voice"] = targetVoice
            }
            json["audio"] = audio
            if let updatedData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                try? updatedData.write(to: cfgURL)
                print("[Agent Speak] Configuration updated: Engine = \(targetEngine), Voice = \(targetVoice)")
            }
        }
    } else if sub == "vol" || sub == "volume" {
        guard args.count >= 4, let intVal = Int(args[3]), intVal >= 1 && intVal <= 200 else {
            print("Usage: aspk voice vol <1-200>")
            print("Example: aspk voice vol 100   (Standard 100% Full Volume)")
            print("Example: aspk voice vol 150   (+3.5 dB Decibel Force Boost)")
            print("Example: aspk voice vol 200   (+6.0 dB Max Force Decibel Boost)")
            exit(1)
        }
        _ = sendSocketMessage("__CMD_VOICE_VOL_\(intVal)__")
        let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
        if let data = try? Data(contentsOf: cfgURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var audio = json["audio"] as? [String: Any] {
            audio["volume"] = intVal
            json["audio"] = audio
            if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                try? updated.write(to: cfgURL)
            }
        }
        let dbStr = intVal > 100 ? String(format: " (+%.1f dB Force Boost)", 20.0 * log10(Double(intVal) / 100.0)) : (intVal == 100 ? " (Standard Full)" : String(format: " (%.1f dB)", 20.0 * log10(Double(intVal) / 100.0)))
        print("[Agent Speak] Voice volume set to \(intVal)%\(dbStr).")
    } else {
        print("Unknown voice subcommand: \(sub)")
        print("Available subcommands: status, list, set, vol <1-200>, install, clone")
    }

case "bgm":
    let sub = args.count > 2 ? args[2].lowercased() : "status"
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
    let bgmDir = "\(home)/.agentspeak/bgm"
    
    if sub == "on" || sub == "enable" {
        _ = sendSocketMessage("__CMD_BGM_ON__")
        if let data = try? Data(contentsOf: cfgURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var bgm = json["bgm"] as? [String: Any] {
            bgm["enabled"] = true
            json["bgm"] = bgm
            if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                try? updated.write(to: cfgURL)
            }
        }
        print("[Agent Speak] Background music enabled.")
    } else if sub == "off" || sub == "disable" {
        _ = sendSocketMessage("__CMD_BGM_OFF__")
        if let data = try? Data(contentsOf: cfgURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var bgm = json["bgm"] as? [String: Any] {
            bgm["enabled"] = false
            json["bgm"] = bgm
            if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                try? updated.write(to: cfgURL)
            }
        }
        print("[Agent Speak] Background music disabled.")
    } else if sub == "toggle" {
        _ = sendSocketMessage("__CMD_BGM_TOGGLE__")
        print("[Agent Speak] Background music toggled.")
    } else if sub == "open" || sub == "folder" {
        _ = sendSocketMessage("__CMD_BGM_OPEN__")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: bgmDir)
        print("[Agent Speak] Opened background music folder: \(bgmDir)")
    } else if sub == "test" {
        if ensureAppRunningAndSend("__CMD_BGM_TEST__") {
            print("[Agent Speak] Testing background music: Playing 4s preview followed by 2.5s reverb decay...")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else if sub == "vol" || sub == "volume" {
        guard args.count >= 4, let intVal = Int(args[3]), intVal >= 0 && intVal <= 100 else {
            print("Usage: aspk bgm vol <0-100>")
            print("Example: aspk bgm vol 20")
            exit(1)
        }
        _ = sendSocketMessage("__CMD_BGM_VOL_\(intVal)__")
        if let data = try? Data(contentsOf: cfgURL),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           var bgm = json["bgm"] as? [String: Any] {
            bgm["volume"] = Double(intVal) / 100.0
            json["bgm"] = bgm
            if let updated = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
                try? updated.write(to: cfgURL)
            }
        }
        print("[Agent Speak] Background music volume set to \(intVal)%.")
    } else if sub == "status" || sub == "info" {
        print("─── Background Music Status ───")
        var isEnabled = true
        var vol = 0.20
        var randomOffset = true
        var shuffle = true
        var reverb = true
        if let data = try? Data(contentsOf: cfgURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let bgm = json["bgm"] as? [String: Any] {
            isEnabled = bgm["enabled"] as? Bool ?? true
            vol = bgm["volume"] as? Double ?? 0.20
            randomOffset = bgm["random_offset"] as? Bool ?? true
            shuffle = bgm["shuffle"] as? Bool ?? true
            reverb = bgm["reverb_enabled"] as? Bool ?? true
        }
        print("Enabled:        \(isEnabled ? "🟢 YES" : "🔴 NO")")
        print("Volume:         \(Int(vol * 100))%")
        print("Random Offset:  \(randomOffset ? "Active (Starts from random beat)" : "Inactive (Starts at 0:00)")")
        print("Shuffle:        \(shuffle ? "Active" : "Sequential")")
        print("Reverb Decay:   \(reverb ? "Active (2.5s Spatial Tail)" : "Disabled")")
        print("Music Folder:   \(bgmDir)")
        let files = (try? FileManager.default.contentsOfDirectory(atPath: bgmDir)) ?? []
        let audioFiles = files.filter { ["mp3", "m4a", "wav", "aiff", "aac", "flac"].contains(($0 as NSString).pathExtension.lowercased()) }
        print("Tracks Found:   \(audioFiles.count)")
        for f in audioFiles {
            print("  • \(f)")
        }
    } else {
        print("Unknown bgm subcommand: \(sub)")
        print("Available subcommands: on, off, toggle, vol <0-100>, test, open, status")
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
