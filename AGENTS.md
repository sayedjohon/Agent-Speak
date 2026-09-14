# AGENTS.md — Agent Speak Developer & AI Agent Guide

> **Project**: Agent Speak  
> **Platform**: macOS 14.0+ (Sonoma & Sequoia)  
> **Core Stack**: Pure Swift, SwiftUI, AppKit, AVFoundation, Metal/ProMotion CADisplayLink  
> **Status**: Active Production  

---

## 🎯 Project Overview

Agent Speak is an ultra-fluid, zero-lag voice companion for macOS designed specifically for developers and AI coding agents (Antigravity, Claude Code, OpenCode, Cursor, Aider). It provides a liquid glass HUD docking directly underneath the MacBook Pro display notch (or floating on external monitors) that visualizes and speaks conversational text while quarantining code blocks.

---

## 🎙️ Global Voice & Prose Protocol (Mandatory)

All conversational text produced by AI agents interacting with the user is read aloud by macOS Text-to-Speech:
1. **Conversational First**: Write responses naturally for the human ear (spoken English style).
2. **Code Quarantine**: NEVER write code snippets, paths, shell syntax, or technical symbols inline inside sentences.
3. **Fenced Code Blocks**: Place all code snippets, terminal commands, and paths strictly inside triple-backtick fenced blocks (` ``` `). The audio player automatically detects and skips all fenced code blocks.

---

## 🏛️ System Architecture

```
[Agent Transcripts / Hotkeys / CLI]
               │
               ▼
      /tmp/agentspeak.sock (UNIX Domain Socket)
               │
               ▼
       [TextSanitizer.swift] (Filters markdown tables, code blocks, URLs)
               │
               ▼
     [SpeechQueueManager.swift] (Thread-safe sequential FIFO queue)
        │                 │
        ▼                 ▼
 [Apple AVFoundation]  [Pocket-TTS Neural Extension]
   (Zero-CPU Native)     (Offline Local Cloned Voice)
        │
        ▼
 [NotchWindowController.swift]
   (120 FPS CADisplayLink ProMotion Liquid Glass HUD)
```

---

## 📂 Codebase Directory Map

- `Sources/`
  - `main.swift`: Application initialization and daemon lifecycle.
  - `AppDelegate.swift`: Menu bar item, status icons, hotkey bindings, global event taps.
  - `NotchWindowController.swift`: 120 FPS ProMotion liquid glass notch HUD window.
  - `DashboardView.swift`: Modern Raycast-inspired SwiftUI settings window.
  - `PocketTTSExtensionCardView.swift`: Offline neural voice cloning extension interface.
  - `VoiceCloningStudioView.swift`: Interactive waveform trimming and voice clone studio.
  - `TranscriptWatcher.swift`: Multi-agent file tailing (Antigravity, Claude Code, OpenCode).
  - `TextSanitizer.swift`: Markdown table, code block, and symbol sanitization regex.
  - `SpeechQueueManager.swift`: Playback state coordination, ducking, and engine dispatch.
  - `SpeechLanguageDetector.swift`: Smart clause subdivision and chunk size control.
  - `AudioEngine.swift`: Audio output routing, volume control, and soundtrack cross-fading.
- `CLI/`
  - `main.swift`: Source for the `agentspeak` command-line utility.
- `Resources/`
  - `Agent-Speak-Banner.png`: Project banner art.
  - `Agent-Speak-logo.png`: 1024x1024 master app icon.
  - `bgm/`: Ambient focus background soundtrack tracks.
  - `voices/`: Registered voice profiles and reference audio snippets.
- `docs/assets/`
  - Image assets for README.md and GitHub presentation.

---

## 🔌 Socket Protocol Reference (`/tmp/agentspeak.sock`)

The daemon exposes a lightweight UNIX domain socket at `/tmp/agentspeak.sock`. Any tool or script can send commands:

| Command | Description | Example |
| :--- | :--- | :--- |
| `say:<text>` | Queues text for speech synthesis | `echo "say:Task complete" \| nc -U /tmp/agentspeak.sock` |
| `stop` | Immediately halts current speech and clears queue | `echo "stop" \| nc -U /tmp/agentspeak.sock` |
| `status` | Returns JSON status of daemon and current engine | `echo "status" \| nc -U /tmp/agentspeak.sock` |
| `dashboard` | Opens the SwiftUI settings window | `echo "dashboard" \| nc -U /tmp/agentspeak.sock` |
| `engine:<name>`| Switches active engine (`native` or `pocket-tts`) | `echo "engine:native" \| nc -U /tmp/agentspeak.sock` |

---

## 🛠️ Build & Installation Commands

### Full App Rebuild & Reinstall
```bash
./install.sh
```

### Manual Compile via Swift Compiler
```bash
swiftc -O -target arm64-apple-macos14.0 \
  -framework Cocoa -framework SwiftUI -framework AVFoundation -framework Carbon \
  Sources/*.swift -o bin/AgentSpeak
```

### Checking Daemon Logs
```bash
tail -f ~/Library/Logs/AgentSpeak.log
```

---

## ⚠️ Development Rules for AI Agents

1. **File Length Limit**: Keep every Swift and documentation file strictly under 900 lines.
2. **Smooth 120 FPS**: Never block the main AppKit thread. All audio processing, file watching, and socket operations must remain on background Grand Central Dispatch queues.
3. **Graceful Degradation**: If Pocket-TTS or Python environments are missing or fail, the app must smoothly fall back to the Zero-CPU native Apple Speech engine without crashing.
4. **No Slop Design**: Keep SwiftUI interfaces clean, aligned with native macOS human interface guidelines, and responsive to mouse hover and click hitboxes.
