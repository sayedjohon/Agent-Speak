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
      code        Control code block speech (code on | off | toggle | status)
      hologram    Manage holographic reactor overlay (on | off | zoom <0-100> | pos <x> <y> | reset | blend | blends | opacity | skin | color | preview | status)
      voice       Manage voices and volume (status | list | set | vol <1-200> | install | clone)
      bgm         Manage Iron Man background soundtrack (on | off | vol | test | open | status)
      gesture     Control camera hand tracking (status | on | off | toggle | preview on/off | hud on/off | list)
      dictation   Control Push-to-Talk Fn dictation (status | on | off | toggle)
      greet       Speak active persona's signature greeting (alias: intro)
      replay      Re-listen / repeat the last spoken message (alias: repeat, relisten)
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
        print("Voice Engine:       \(info.engine == "pocket_tts" ? "Custom Voice (Neural AI)" : "Default System Voice (macOS)")")
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

case "code", "speak-code":
    let sub = args.count > 2 ? args[2].lowercased() : "status"
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
    
    func readSpeakCode() -> Bool {
        guard let data = try? Data(contentsOf: cfgURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let audio = json["audio"] as? [String: Any] else { return false }
        return audio["speak_code_blocks"] as? Bool ?? false
    }
    
    func writeSpeakCode(_ val: Bool) {
        guard let data = try? Data(contentsOf: cfgURL),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        var audio = json["audio"] as? [String: Any] ?? [:]
        audio["speak_code_blocks"] = val
        json["audio"] = audio
        if let updated = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? updated.write(to: cfgURL)
        }
    }

    if sub == "on" || sub == "enable" {
        writeSpeakCode(true)
        _ = sendSocketMessage("__CMD_SPEAK_CODE_ON__")
        print("[Agent Speak] Speak Code Blocks: ENABLED (Code snippets and markdown will be read aloud naturally)")
    } else if sub == "off" || sub == "disable" {
        writeSpeakCode(false)
        _ = sendSocketMessage("__CMD_SPEAK_CODE_OFF__")
        print("[Agent Speak] Speak Code Blocks: DISABLED (Code blocks stripped for natural conversational speech)")
    } else if sub == "toggle" {
        let cur = readSpeakCode()
        let next = !cur
        writeSpeakCode(next)
        _ = sendSocketMessage("__CMD_TOGGLE_SPEAK_CODE__")
        print("[Agent Speak] Speak Code Blocks: \(next ? "ENABLED" : "DISABLED")")
    } else {
        let cur = readSpeakCode()
        print("─── Code Speech Preference ───")
        print("Speak Code Blocks: \(cur ? "🟢 ENABLED" : "⚪ DISABLED (Default)")")
        print("When enabled, code blocks are read aloud with syntax markers, hashtags, and block noise cleaned.")
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
        print("Active Engine:      \(info.engine == "pocket_tts" ? "Custom Voice (Neural AI)" : "Default macOS System Voice")")
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
        print("\n─── Custom Voice Personas ───")
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
        print("[Agent Speak] Starting Custom Voice Neural Extension setup on your Mac...")
        let scriptCandidates = [
            "\(extDir)/install.sh",
            "\(home)/Applications/Agent Speak.app/Contents/Resources/install_pocket_tts.sh",
            "/Applications/Agent Speak.app/Contents/Resources/install_pocket_tts.sh"
        ]
        let script = scriptCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "\(extDir)/install.sh"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script]
        try? p.run()
        p.waitUntilExit()
    } else if sub == "clone" {
        guard args.count >= 5 else {
            print("Usage: aspk voice clone <PersonaName> <path_to_audio>")
            print("Example: aspk voice clone MyVoice /path/to/sample.wav")
            exit(1)
        }
        let vName = args[3]
        let aPath = (args[4] as NSString).expandingTildeInPath
        let cloneCandidates = [
            "\(extDir)/clone_voice.py",
            "\(home)/Applications/Agent Speak.app/Contents/Resources/clone_voice.py",
            "/Applications/Agent Speak.app/Contents/Resources/clone_voice.py"
        ]
        let cloneScript = cloneCandidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "\(extDir)/clone_voice.py"
        let py = extPython
        
        guard FileManager.default.fileExists(atPath: py) else {
            print("Error: Custom Voice runtime not found. Run 'aspk voice install' first.")
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
            print("Usage: aspk voice set <macos|custom> [voice_name]")
            print("Example: aspk voice set custom Jarvis_Best")
            print("Example: aspk voice set macos Daniel")
            exit(1)
        }
        let lowerEngine = args[3].lowercased()
        let targetEngine = (lowerEngine.contains("pocket") || lowerEngine.contains("custom")) ? "pocket_tts" : "macos_default"
        let targetVoice = args.count >= 5 ? args[4] : (targetEngine == "pocket_tts" ? "Jarvis_Best" : "default")
        
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

case "hologram", "holo":
    guard args.count > 2 else {
        print("Usage: agentspeak hologram <on | off | toggle | zoom <0-100> | pos <x> <y> | reset | blend <name> | blends | opacity <10-100> | skin <name> | skins | color <name> | preview | status>")
        print("Available colors: amber, cyan, green, red, purple, white")
        exit(0)
    }
    let sub = args[2].lowercased()
    if sub == "on" {
        _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_ON__")
        print("[Agent Speak] Hologram overlay: 🟢 ON")
    } else if sub == "off" {
        _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_OFF__")
        print("[Agent Speak] Hologram overlay: 🔴 OFF")
    } else if sub == "toggle" {
        _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_TOGGLE__")
        print("[Agent Speak] Toggled hologram overlay.")
    } else if sub == "preview" || sub == "test" {
        _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_PREVIEW__")
        print("[Agent Speak] Triggered 5-second hologram preview.")
    } else if sub == "stop" || sub == "dismiss" {
        _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_STOP__")
        print("[Agent Speak] Hologram overlay dismissed.")
    } else if sub == "zoom" || sub == "scale" {
        if args.count > 3 {
            let zStr = args[3].replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "x", with: "")
            if let val = Double(zStr), val >= 0 && val <= 100 {
                _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_ZOOM_\(Int(val))__")
                print("[Agent Speak] Hologram zoom scale set to: \(Int(val))% (Default: 50% = 1.0x)")
            } else {
                print("Invalid zoom: '\(args[3])'. Please enter a percentage between 0 and 100.")
            }
        } else {
            print("Usage: agentspeak hologram zoom <0-100>")
            print("Example: agentspeak hologram zoom 50  (1.0x native standard)")
            print("Example: agentspeak hologram zoom 100 (2.8x expands beyond monitor)")
        }
    } else if sub == "pos" || sub == "position" || sub == "offset" {
        if args.count > 4, let px = Double(args[3]), let py = Double(args[4]) {
            _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_POS_\(Int(px))_\(Int(py))__")
            print("[Agent Speak] Hologram position offset set to: X=\(Int(px))px, Y=\(Int(py))px")
        } else {
            print("Usage: agentspeak hologram pos <x_offset> <y_offset>")
            print("Example: agentspeak hologram pos 0 0        (center)")
            print("Example: agentspeak hologram pos 150 -50    (shift right 150px, up 50px)")
        }
    } else if sub == "reset" {
        _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_RESET__")
        print("[Agent Speak] Hologram transform reset to default (Zoom: 50% [1.0x], Pos: X=0, Y=0).")
    } else if sub == "blends" || sub == "list-blends" {
        print("─── Photoshop-Grade Holographic Blending Modes ───")
        print("• normal      : Normal (Default) — standard full-strength holographic projection")
        print("• screen      : Screen — transparent darks with luminous highlights (screen text visible)")
        print("• pluslighter : Linear Dodge (Add) — pure additive Stark neon rays")
        print("• overlay     : Overlay — high contrast highlights and shadows")
        print("• softlight   : Soft Light — subtle translucent wash (easiest to read screen text)")
        print("• hardlight   : Hard Light — punchy cinematic contrast")
        print("• colordodge  : Color Dodge — electrified high-saturation bloom")
        print("• multiply    : Multiply — absorptive darkening tint, reduces bright desktop glare")
        print("• difference  : Difference — inverted spectral contrast for sharp text edges")
    } else if sub == "blend" || sub == "blending" {
        if args.count > 3 {
            let blendName = args[3].lowercased()
            let valid = ["normal", "screen", "pluslighter", "overlay", "softlight", "hardlight", "colordodge", "multiply", "difference", "add", "dodge"]
            if valid.contains(blendName) {
                _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_BLEND_\(blendName)__")
                print("[Agent Speak] Hologram blending mode set to: \(blendName)")
            } else {
                print("Unknown blend mode: '\(blendName)'. Run 'agentspeak hologram blends' to view all modes.")
            }
        } else {
            print("Usage: agentspeak hologram blend <mode>")
            print("Run 'agentspeak hologram blends' to view all available blending modes.")
        }
    } else if sub == "opacity" || sub == "transparency" {
        if args.count > 3 {
            let opStr = args[3].replacingOccurrences(of: "%", with: "")
            if let val = Double(opStr), val >= 10 && val <= 100 {
                _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_OPACITY_\(Int(val))__")
                print("[Agent Speak] Hologram opacity set to: \(Int(val))%")
            } else {
                print("Invalid opacity: '\(args[3])'. Please enter a percentage between 10 and 100.")
            }
        } else {
            print("Usage: agentspeak hologram opacity <10-100>")
        }
    } else if sub == "skins" || sub == "list-skins" {
        print("─── Agent Speak Holographic Skins ───")
        print("• classicArc    : Tony Stark Arc Reactor [MASTER DEFAULT]")
        print("• googleJarvis  : Stark Cybernetic Vortex (Google AI Studio)")
        print("• googleUltron  : Ultron Crimson Geodesic (Google AI Studio)")
        print("• geminiJarvis  : Spherical Circuit Matrix (Gemini App)")
        print("• geminiUltron  : Mind Stone Synaptic Brain (Gemini App)")
        print("• glmJarvis     : 3D Gyroscopic Telemetry HUD (GLM)")
        print("• glmUltron     : Ultron Tactical Hexagon Core (GLM)")
        print("• chatgptJarvis : Orbital Particle HUD (ChatGPT)")
        print("• chatgptUltron : Crimson Ocular Iris (ChatGPT)")
    } else if sub == "skin" {
        if args.count > 3 {
            let skinName = args[3]
            let valid = ["classicarc", "googlejarvis", "googleultron", "geminijarvis", "geminiultron", "glmjarvis", "glmultron", "chatgptjarvis", "chatgptultron"]
            if valid.contains(skinName.lowercased()) {
                _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_SKIN_\(skinName)__")
                print("[Agent Speak] Hologram skin set to: \(skinName)")
            } else {
                print("Unknown skin: '\(skinName)'. Run 'agentspeak hologram skins' to view all skins.")
            }
        } else {
            print("Usage: agentspeak hologram skin <name>")
            print("Run 'agentspeak hologram skins' to view all available skins.")
        }
    } else if sub == "color" || sub == "theme" {
        if args.count > 3 {
            let colorName = args[3].lowercased()
            let valid = ["amber", "cyan", "green", "red", "purple", "white"]
            if valid.contains(colorName) {
                _ = ensureAppRunningAndSend("__CMD_HOLOGRAM_COLOR_\(colorName.uppercased())__")
                print("[Agent Speak] Hologram color set to: \(colorName.capitalized)")
            } else {
                print("Unknown color: '\(colorName)'. Available: amber, cyan, green, red, purple, white")
            }
        } else {
            print("Usage: agentspeak hologram color <amber | cyan | green | red | purple | white>")
        }
    } else if sub == "status" {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
        var isEnabled = true
        var theme = "amber"
        var skin = "classicArc"
        var blendMode = "normal"
        var opacity = 100
        var zoomScale = 50
        var offsetX = 0
        var offsetY = 0
        if let data = try? Data(contentsOf: cfgURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let holo = json["hologram"] as? [String: Any] {
            isEnabled = holo["enabled"] as? Bool ?? true
            theme = holo["theme"] as? String ?? "amber"
            skin = holo["skin"] as? String ?? "classicArc"
            blendMode = (holo["blend_mode"] as? String) ?? (holo["blendMode"] as? String) ?? "normal"
            if let op = holo["opacity"] as? Double {
                opacity = Int(round(op * 100.0))
            }
            if let sc = (holo["scale"] as? Double) ?? (holo["zoom"] as? Double) {
                zoomScale = Int(round(sc * 100.0))
            }
            if let ox = (holo["offsetX"] as? Double) ?? (holo["positionX"] as? Double) {
                offsetX = Int(round(ox))
            }
            if let oy = (holo["offsetY"] as? Double) ?? (holo["positionY"] as? Double) {
                offsetY = Int(round(oy))
            }
        }
        let scaleMult = zoomScale <= 50 ? (0.25 + Double(zoomScale) / 50.0 * 0.75) : (1.00 + Double(zoomScale - 50) / 50.0 * 1.80)
        print("Hologram Overlay: \(isEnabled ? "🟢 ENABLED" : "🔴 DISABLED")")
        print("Current Theme:    \(theme.capitalized)")
        print("Current Skin:     \(skin)")
        print("Blending Mode:    \(blendMode)")
        print("Opacity / Glow:   \(opacity)%")
        print("Zoom / Scale (Z): \(zoomScale)% (\(String(format: "%.2f", scaleMult))x)")
        print("Position Offset:  X: \(offsetX)px, Y: \(offsetY)px")
    } else {
        print("Unknown hologram subcommand: \(sub)")
        print("Available subcommands: on, off, toggle, zoom <0-100>, pos <x> <y>, reset, blend <name>, blends, opacity <10-100>, skin <name>, skins, color <name>, preview, status")
    }

case "gesture", "gestures":
    let sub = args.count > 2 ? args[2].lowercased() : "status"
    if sub == "on" {
        _ = ensureAppRunningAndSend("__CMD_GESTURE_ON__")
        print("[Agent Speak] Camera gesture tracking engine started.")
    } else if sub == "off" {
        _ = ensureAppRunningAndSend("__CMD_GESTURE_OFF__")
        print("[Agent Speak] Camera gesture tracking stopped.")
    } else if sub == "toggle" {
        _ = ensureAppRunningAndSend("__CMD_GESTURE_TOGGLE__")
        print("[Agent Speak] Toggled camera gesture tracking.")
    } else if sub == "hud" {
        let hudSub = args.count > 3 ? args[3].lowercased() : "toggle"
        if hudSub == "on" {
            _ = ensureAppRunningAndSend("__CMD_GESTURE_HUD_ON__")
            print("[Agent Speak] Floating gesture HUD enabled.")
        } else if hudSub == "off" {
            _ = ensureAppRunningAndSend("__CMD_GESTURE_HUD_OFF__")
            print("[Agent Speak] Floating gesture HUD disabled.")
        } else {
            print("Usage: agentspeak gesture hud on | off")
        }
    } else if sub == "preview" || sub == "box" || sub == "skeleton" {
        let prevSub = args.count > 3 ? args[3].lowercased() : "toggle"
        if prevSub == "on" {
            _ = ensureAppRunningAndSend("__CMD_GESTURE_PREVIEW_ON__")
            print("[Agent Speak] Floating skeleton tray preview enabled.")
        } else if prevSub == "off" {
            _ = ensureAppRunningAndSend("__CMD_GESTURE_PREVIEW_OFF__")
            print("[Agent Speak] Floating skeleton tray preview disabled.")
        } else {
            _ = ensureAppRunningAndSend("__CMD_GESTURE_PREVIEW_TOGGLE__")
            print("[Agent Speak] Toggled floating skeleton tray preview.")
        }
    } else if sub == "status" {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
        var isEnabled = false
        var speed = 1.2
        var smoothing = 0.85
        var anchor = "wrist"
        var dictMode = "Groq Whisper v3 (Cloud)"
        var dictModel = "whisper-large-v3"
        if let data = try? Data(contentsOf: cfgURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let g = json["gestures"] as? [String: Any] {
                isEnabled = g["enabled"] as? Bool ?? false
                speed = g["cursor_speed"] as? Double ?? 1.2
                smoothing = g["smoothing_factor"] as? Double ?? 0.85
                anchor = g["tracking_anchor"] as? String ?? "wrist"
            }
            if let d = json["dictation"] as? [String: Any] {
                dictMode = d["mode"] as? String ?? "Groq Whisper v3 (Cloud)"
                dictModel = d["model"] as? String ?? "whisper-large-v3"
            }
        }
        print("Vision Hand Gestures: \(isEnabled ? "🟢 ACTIVE" : "⚪ STANDBY (Off)")")
        print("Tracking Anchor:     \(anchor.capitalized) Joint (Rock-Solid)")
        print("Full-Frame Tracking: 100% Active (Zero Cutoff)")
        print("Cursor Speed:        \(String(format: "%.1fx", speed))")
        print("Jitter Smoothing:    \(Int(smoothing * 100))%")
        print("Dictation Engine:    \(dictMode)")
        print("Whisper Model:       \(dictModel)")
        print("Toggle Hotkey:       Control + G")
    } else if sub == "list" {
        print("""
        Agent Speak — Two-Handed 10-Finger Gesture Map
        
        RIGHT HAND (Optical Air Mouse & Pointer):
          • Index Finger Pointing     -> Optical Air Mouse (moves cursor relatively)
          • Open / Relax Hand         -> Lifts mouse off desk (cursor freezes in place)
          • Index + Thumb Pinch       -> Left click / focus text field (zero drift)
          • Pinch & Hold (> 200ms)    -> Click and drag windows, files, or text
          • Middle + Thumb Pinch      -> Right click context menu
          • Double Pinch              -> Double click
          • 2 Fingers Extended (Up/Dn)-> Smooth scroll (page scrolls with no cursor drop)
        
        LEFT HAND (Shortcuts, Modifiers & Dictation):
          • Closed Fist (Hold)        -> Holds Command key (Whisper Flow dictation)
          • Open Fist (Release)       -> Releases Command key (transcription pastes)
          • Index Tap / Pinch         -> Return / Enter (submits chat query / prompt)
          • "V" Pose (Peace Sign)     -> Paste (Cmd + V)
          • "C" Hand Pose             -> Copy (Cmd + C)
          • Open Palm (Stop Sign)     -> Escape / Dismiss active popup
          • Swipe Left / Right        -> Undo (Cmd + Z) / Redo (Cmd + Shift + Z)
          • 4-Finger Swipe Up         -> Mission Control
        
        SAFETY CLUTCH:
          • Tuck Thumb / Lower Hands  -> Pauses cursor tracking instantly
          • Control + G Hotkey        -> Toggle tracking engine on/off
        """)
    } else {
        print("Unknown gesture subcommand: \(sub)")
        print("Usage: agentspeak gesture <on | off | toggle | hud | status | list>")
    }

case "dictation", "fn", "ptt":
    let sub = args.count > 2 ? args[2].lowercased() : "status"
    if sub == "on" {
        if ensureAppRunningAndSend("__CMD_FN_DICTATION_ON__") {
            print("[Agent Speak] MacBook Fn Push-to-Talk Dictation: 🟢 ENABLED")
            print("Hold left Fn key to record; release to transcribe with Groq Whisper & auto-paste.")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else if sub == "off" {
        if ensureAppRunningAndSend("__CMD_FN_DICTATION_OFF__") {
            print("[Agent Speak] MacBook Fn Push-to-Talk Dictation: ⚪ DISABLED")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else if sub == "toggle" {
        if ensureAppRunningAndSend("__CMD_FN_DICTATION_TOGGLE__") {
            print("[Agent Speak] Toggled MacBook Fn Push-to-Talk Dictation.")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else if sub == "status" {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let cfgURL = URL(fileURLWithPath: "\(home)/.agentspeak/config.json")
        var isEnabled = true
        var dictMode = "Groq Whisper v3 (Cloud)"
        var dictModel = "whisper-large-v3"
        var autoSubmit = false
        if let data = try? Data(contentsOf: cfgURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let d = json["dictation"] as? [String: Any] {
            if let fnEn = d["fn_hold_dictation"] as? Bool { isEnabled = fnEn }
            dictMode = d["mode"] as? String ?? dictMode
            dictModel = d["model"] as? String ?? dictModel
            autoSubmit = d["auto_submit_return"] as? Bool ?? false
            let triggerName = d["dictation_trigger_name"] as? String ?? "Right Option (⌥)"
            print("Push-to-Talk Dictation: \(isEnabled ? "🟢 ACTIVE" : "⚪ DISABLED")")
            print("Hardware Trigger Key:   \(triggerName)")
            print("Dictation Engine:       \(dictMode)")
            print("Whisper Model:          \(dictModel)")
            print("Auto-Submit (Return):   \(autoSubmit ? "🟢 ON" : "⚪ OFF")")
            print("Actions:                Hold to record -> Release to transcribe & auto-paste")
            exit(0)
        }
        print("Push-to-Talk Dictation: \(isEnabled ? "🟢 ACTIVE" : "⚪ DISABLED")")
        print("Hardware Trigger Key:   Right Option (⌥)")
        print("Dictation Engine:       \(dictMode)")
        print("Whisper Model:          \(dictModel)")
        print("Auto-Submit (Return):   \(autoSubmit ? "🟢 ON" : "⚪ OFF")")
        print("Actions:                Hold to record -> Release to transcribe & auto-paste")
    } else if sub == "key" {
        if args.count < 4 {
            print("Usage: agentspeak dictation key <rightOption | rightCommand | rightControl | leftControl | leftOption | capsLock | fn | f12 | f6 | grave>")
            exit(1)
        }
        let keyArg = args[3]
        _ = sendSocketMessage("__CMD_DICTATION_KEY__:\(keyArg)")
        print("✓ Push-to-Talk trigger key updated to: \(keyArg)")
    } else if sub == "retry" {
        if ensureAppRunningAndSend("__CMD_DICTATION_RETRY__") {
            print("[Agent Speak] Retrying last dictation transcription from saved audio...")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else if sub == "test-error" {
        if ensureAppRunningAndSend("__CMD_DICTATION_TEST_ERROR__") {
            print("[Agent Speak] Displaying test dictation error bar in notch area.")
        } else {
            print("Error: Could not connect to Agent Speak socket.")
        }
    } else {
        print("Unknown dictation subcommand: \(sub)")
        print("Usage: agentspeak dictation <on | off | toggle | status | key <preset> | retry>")
    }

case "greet", "welcome", "intro":
    if ensureAppRunningAndSend("__CMD_GREET__") {
        print("[Agent Speak] Triggered persona signature greeting.")
    } else {
        print("Error: Could not connect to Agent Speak socket.")
    }

case "replay", "repeat", "relisten":
    if ensureAppRunningAndSend("__CMD_REPLAY__") {
        print("[Agent Speak] Replaying last spoken message.")
    } else {
        print("Error: Could not connect to Agent Speak socket.")
    }

case "stop":
    _ = sendSocketMessage("__CMD_STOP_SPEECH__")
    print("[Agent Speak] Speech stopped.")

case "quit":
    let uid = getuid()
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    proc.arguments = ["bootout", "gui/\(uid)/com.agentspeak.app"]
    try? proc.run()
    proc.waitUntilExit()
    
    let pidFile = "/tmp/agentspeak.pid"
    try? FileManager.default.removeItem(atPath: pidFile)
    
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.agentspeak.app")
    for a in apps {
        a.terminate()
    }
    print("[Agent Speak] Application quit cleanly. Background service stopped.")

default:
    print("Unknown command: \(cmd)")
    printHelp()
}
