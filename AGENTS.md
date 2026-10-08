# AGENTS.md — Agent Speak Developer & AI Agent Guide

> **Project**: Agent Speak  
> **Platform**: macOS 14.0+ (Sonoma & Sequoia)  
> **Core Stack**: Pure Swift, SwiftUI, AppKit, AVFoundation, Metal/ProMotion CADisplayLink, Apple Vision  
> **Status**: Active Production (v1.5.1)  
> **Last Updated**: 2026-10-09 05:25:00  

---

## 🎯 Project Overview

Agent Speak is an ultra-fluid, zero-lag voice companion for macOS designed specifically for developers and AI coding agents (Antigravity, Claude Code, Cursor, Windsurf, Roo Code, Cline, Aider). It provides a liquid glass HUD docking directly underneath the MacBook Pro display notch (or floating on external monitors) that visualizes and speaks conversational text while quarantining code blocks.

---

## 🎙️ Global Voice & Prose Protocol (Mandatory for AI Agents)

All conversational text produced by AI agents interacting with the user is read aloud by macOS Text-to-Speech:
1. **Conversational First**: Write responses naturally for the human ear (spoken English style, as if on a call).
2. **Strict Code Quarantine**: NEVER write code snippets, file paths, terminal commands, shell syntax, or technical symbols inline inside sentences.
3. **Fenced Code Blocks**: Place all code snippets, terminal commands, scripts, and paths strictly inside triple-backtick fenced blocks (` ``` `). The audio player automatically detects and skips all fenced code blocks.
4. **Digestible Formats**: Use bullet points, status lists, or tables for key updates. Keep spoken prose concise.

See `SYSTEM_PROMPT.md` for copy-paste prompts for Cursor, Claude, and Antigravity.

---

## 🏛️ System Architecture

```
[Agent Transcripts / Hotkeys / CLI / Fn Dictation]
                       │
                       ▼
            /tmp/agentspeak.sock (UNIX Domain Socket)
                       │
                       ▼
             [TextSanitizer.swift] (Filters markdown tables, code fences, URLs)
                       │
                       ▼
          [SpeechQueueManager.swift] (FIFO queue & state management)
            │                     │
            ▼                     ▼
   [Apple AVFoundation]  [Pocket-TTS Neural Extension]
     (Zero-CPU Native)     (24 Offline Cloned Personas)
            │                     │
            └──────────┬──────────┘
                       │
                       ▼
          [StreamingAudioManager.swift] (JIT Rolling Lookahead Engine, 95% CPU savings)
                       │
                       ▼
         [NotchWindowController.swift] & [HologramManager.swift]
           • 120 FPS Liquid Glass Notch HUD (ProMotion)
           • Full-Screen Holographic Arc Reactor (6 Palettes, 7 Blending Modes)
           • DaVinci Resolve-Style 3-Axis Transform Controls (Zoom Z, Pos X, Pos Y)
```

---

## 📂 Subsystem Directory Map

### 1. Core Lifecycle & Audio Routing
- `Sources/main.swift`: Application initialization and daemon lifecycle.
- `Sources/AppDelegate.swift`: Menu bar tray icon, dynamic last speech re-listen menu, hotkey bindings (Control+S speak selection, Control+P speak clipboard, Control+R replay, Escape silence).
- `Sources/LastVoiceManager.swift`: Single-segment audio cache and prompt persistence for zero-latency replay and interruption recovery.
- `Sources/SpeechQueueManager.swift`: Central sequential speech dispatch and engine coordination.
- `Sources/TextSanitizer.swift`: Markdown table, code block quarantine, link sanitization, and unclosed block containment.
- `Sources/SpeechLanguageDetector.swift`: Clause segmentation and smart chunk subdivision.
- `Sources/StreamingAudioManager.swift`: Just-in-Time (JIT) lookahead audio synthesizer, pre-buffering up to 2 chunks, eliminating background CPU spikes.

### 2. HUD & Holographic Visualizers
- `Sources/NotchWindowController.swift`: 120 FPS ProMotion liquid glass notch HUD docking window.
- `Sources/NotchBarView.swift`: Waveform frequency visualizer, scrub bar, speed and replay buttons.
- `Sources/HologramManager.swift`: Full-screen overlay window controller with 100% click-through transparency and 3-axis transform state.
- `Sources/HologramSkinModels.swift`: Skin presets, color palettes, and 7 blending modes (Screen, Multiply, Additive, Overlay, Color Dodge, Luminosity, Normal).
- `Sources/HUDTransformCardView.swift`: DaVinci Resolve-style 3-axis transform controls (Z-Zoom up to 2.8x, X-Pos, Y-Pos, and Master Reset).
- `Sources/HologramLifecycleTracker.swift`: Audio sync and ambient reverb fade-out.
- `Sources/Skin*.swift`: Specialized shader and canvas renderers for Jarvis, Ultron, Gemini, and GLM visualizer skins.

### 3. Dual-Hand 10-Finger Vision Camera Gesture Control
- `Sources/CameraGestureManager.swift`: AVCaptureSession and Apple Vision `VNDetectHumanHandPoseRequest` pipeline.
- `Sources/GestureClassifier.swift`: Index finger cursor flight, pinch click, drag, two-finger vertical scrolling, and fist-hold dictation.
- `Sources/MouseCursorController.swift`: Adaptive One-Euro filter for jitter-free pointer tracking.
- `Sources/HandSkeletonCanvasView.swift` & `Sources/TraySkeletonHUDController.swift`: Live skeletal joint visualizers.
- `Sources/GestureHUDController.swift`: Floating feedback pill for real-time gesture status.
- `Sources/GestureReferenceCardView.swift`: Interactive gesture reference and visual cheat sheet.

### 4. Neural Voice Cloning & Audio Inputs
- `Sources/PocketTTSManager.swift`: Kyutai FlowLM offline neural engine with 24 voice personas.
- `Sources/VoiceCloningStudioView.swift` & `Sources/AudioWaveformTrimmerView.swift`: 1-click zero-shot voice cloning from audio snippets.
- `Sources/PersonaGreetingManager.swift`: Signature persona greetings and profile registry.
- `Sources/FnDictationController.swift`: Push-to-Talk hardware dictation with CoreGraphics single-channel event engine.
- `Sources/GroqWhisperManager.swift`: High-speed cloud Whisper transcription with local fallback & persistent audio backup.
- `Sources/DictationNotchBarView.swift`: Liquid glass notch HUD for dictation errors, 1-click retry reload button, and clipboard copy confirmation.
- `Sources/BackgroundMusicManager.swift` & `Sources/BackgroundMusicView.swift`: Iron Man ambient focus soundtrack with auto-ducking.

### 5. Multi-Agent Workspace Watchers
- `Sources/TranscriptWatcher.swift`: Multi-agent session tailing (Antigravity, Claude Code, OpenCode).
- `Sources/UniversalConnectorWatcher.swift` & `Sources/UniversalConnectorModels.swift`: Declarative watcher for Cursor, Cline, Windsurf, Roo Code, Aider, Hermes.

### 6. Settings Dashboard
- `Sources/DashboardView.swift`: SwiftUI preferences window.
- `Sources/DashboardGestureView.swift`, `DashboardHardwareView.swift`, `DashboardShortcutsView.swift`, `DashboardWorkspacesView.swift`.
- `Sources/ApiKeyManagerCardView.swift`, `GestureTogglesCardView.swift`, `StartupGreetingCardView.swift`, `VoiceVolumeCardView.swift`.

### 7. CLI & Packaging
- `CLI/main.swift`: Master command-line utility (`agentspeak` / `aspk`).
- `install.sh`: Native Swift compilation and launchd background daemon installer.
- `scripts/build_dmg.sh`: Automated macOS DMG packaging engine with Gatekeeper bypass helper.
- `.github/workflows/release.yml`: GitHub Actions automated release pipeline.

---

## 🔌 Socket Protocol Reference (`/tmp/agentspeak.sock`)

The daemon exposes a lightweight UNIX domain socket at `/tmp/agentspeak.sock`. Any tool or script can send commands:

| Command | Description | Example |
| :--- | :--- | :--- |
| `say:<text>` | Queues text for speech synthesis | `echo "say:Build succeeded" \| nc -U /tmp/agentspeak.sock` |
| `stop` | Halts current speech and clears queue | `echo "stop" \| nc -U /tmp/agentspeak.sock` |
| `replay` | Replays the last spoken or interrupted audio | `echo "replay" \| nc -U /tmp/agentspeak.sock` |
| `dictation:retry` | Retries failed dictation and copies text to clipboard | `echo "dictation:retry" \| nc -U /tmp/agentspeak.sock` |
| `status` | Returns JSON status of daemon | `echo "status" \| nc -U /tmp/agentspeak.sock` |
| `dashboard` | Opens settings dashboard | `echo "dashboard" \| nc -U /tmp/agentspeak.sock` |
| `engine:<name>`| Switches active engine (`native` or `pocket-tts`) | `echo "engine:pocket_tts" \| nc -U /tmp/agentspeak.sock` |
| `hologram:blend:<mode>` | Sets hologram blending mode | `echo "hologram:blend:screen" \| nc -U /tmp/agentspeak.sock` |
| `gesture:toggle` | Toggles camera gesture tracking | `echo "gesture:toggle" \| nc -U /tmp/agentspeak.sock` |

---

## 🛠️ Developer Commands

### Build & Reinstall Locally
```bash
./install.sh
```

### Build Distribution DMG
```bash
./scripts/build_dmg.sh
```

### Test CLI Controller
```bash
agentspeak status
agentspeak say "Testing audio output."
agentspeak hologram blend screen
agentspeak gesture on
agentspeak voice list
```
