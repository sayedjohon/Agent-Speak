# <div align="center">

<img src="docs/assets/banner.png" alt="Agent Speak Banner" width="100%" style="border-radius: 12px; margin-bottom: 24px;" />

<img src="docs/assets/logo.png" alt="Agent Speak Logo" width="96" height="96" style="margin-bottom: 12px;" />

# Agent Speak
### The Liquid Glass Voice Companion for AI Coding Agents on macOS

[![macOS](https://img.shields.io/badge/macOS-14.0%2B%20Sonoma%20%7C%20Sequoia-000000?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![ProMotion](https://img.shields.io/badge/ProMotion-120_FPS-4E54C8?style=for-the-badge&logo=apple&logoColor=white)](#-liquid-glass-notch-player-120-fps-promotion)
[![Zero CPU](https://img.shields.io/badge/Engine-Zero_CPU_Native-success?style=for-the-badge)](#-dual-engine-audio-architecture)
[![Pocket-TTS](https://img.shields.io/badge/Offline_Cloning-Pocket--TTS-blueviolet?style=for-the-badge)](#-pocket-tts-neural-engine--voice-cloning-studio)
[![Release](https://img.shields.io/github/v/release/sayedjohon/Agent-Speak?style=for-the-badge&color=orange)](https://github.com/sayedjohon/Agent-Speak/releases)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

<p align="center">
  <b>Give your AI coding agents a voice without burning CPU or sacrificing privacy.</b><br>
  Agent Speak docks fluidly under your MacBook Pro notch at 120 FPS, watches your active agent sessions in real time, and brings voice cloning, system hotkeys, holographic overlays, camera hand gestures, and ambient focus music into one unified native macOS app.
</p>

[Download DMG](#-download--installation) •
[Key Highlights](#-key-highlights) •
[Holographic Reactor](#-holographic-arc-reactor--blending-modes) •
[Camera Gestures](#-dual-hand-10-finger-camera-gesture-control) •
[Global Hotkeys](#-global-hotkeys) •
[Developer CLI](#-developer-cli-agentspeak--aspk) •
[Agent System Prompt](#-agent-integration--voice-first-protocol) •
[Permissions & Gatekeeper](#-macos-permissions--gatekeeper-bypass)

---

</div>

## 📦 Download & Installation

### Option 1: Download Pre-Built DMG (Recommended)

1. Download the latest **`Agent-Speak.dmg`** from the [**GitHub Releases**](https://github.com/sayedjohon/Agent-Speak/releases) page.
2. Open the disk image and drag **`Agent Speak.app`** into your **`Applications`** folder.
3. **Bypass Gatekeeper**: Because Agent Speak is an open-source, independently distributed app without an Apple Developer ID ($99/year), macOS Gatekeeper will flag it on first launch:
   - **1-Click Helper**: Double-click the **`Setup & Bypass Gatekeeper.command`** included inside the DMG.
   - **Terminal Alternative**: Run this command to remove the quarantine flag:
     ```bash
     xattr -cr "/Applications/Agent Speak.app"
     ```
4. Launch **Agent Speak** from your Applications folder or menu bar.

---

### Option 2: Build from Source (1-Click Terminal Setup)

If you prefer building directly on your Mac:

```bash
git clone https://github.com/sayedjohon/Agent-Speak.git
cd Agent-Speak
./install.sh
```

The installer will:
1. Compile the native Swift application (`Sources/*.swift`) and CLI (`CLI/main.swift`) using the Apple Silicon compiler.
2. Sign the bundle with local ad-hoc credentials and configure LaunchServices.
3. Link `agentspeak` and `aspk` to `~/.local/bin/`.
4. Register a permanent 24/7 background service via launchd (`com.agentspeak.app`).

---

## 🌟 Key Highlights

### 🛸 Liquid Glass Notch Player (120 FPS ProMotion)
- **Zero-Flicker Hardware Sync**: Driven by native `CADisplayLink` running at 120 frames per second on Apple Silicon displays.
- **Dynamic Display Adaptability**: Seamlessly hugs your physical camera notch with zero-radius top corners, or floats as a pill on external monitors.
- **JIT Rolling Lookahead Engine**: Audio is synthesized just-in-time with a lookahead buffer capped at 2 chunks ahead, slashing background CPU by 95% with zero playback latency.
- **Dual-Transcript Ingestion**: Resilient file tailing automatically resolves untruncated content from full logs, preventing clipped audio on long agent outputs.
- **Real-Time Audio Waveform**: Fluid frequency visualizer reacts directly to synthesized speech.

### ⚛️ Holographic Arc Reactor & Blending Modes
- **Cinema-Grade Floating Visualizer**: Floats dead-center across your display with 100% click-through transparency (clicks pass directly to apps underneath).
- **7 Professional Blending Modes**:
  - `Screen`: Lightens and blends seamlessly with dark IDE code editors.
  - `Additive` (`Plus Lighter`): Maximum holographic plasma glow.
  - `Multiply`: Deepens tones against bright white documents.
  - `Overlay`: Balances contrast dynamically.
  - `Color Dodge`: High-intensity neon illumination.
  - `Luminosity`: Retains background hue while modulating brightness.
  - `Normal`: Solid rendering with adjustable opacity.
- **6 Vibrant Color Palettes**: Golden Amber (Stark Mk 42), Arc Reactor Cyan, Matrix Emerald, Crimson Ruby, Neon Violet, and Diamond Ice.
- **Adjustable Opacity**: Dial intensity anywhere from 10% to 100%.
- **DaVinci Resolve-Style 3-Axis Transform Controls**: Fine-tune Zoom (Scale Z up to 2.8x expanding beyond monitor bounds), Horizontal Position X (-1000px to +1000px), Vertical Position Y (-800px to +800px), and an animated Master Reset button for custom ultra-wide or portrait displays.
- **Live Preview Auto-Dismiss & Stop**: 5-second auto-exit preview with dynamic Stop Preview controls in the settings inspector.

### 🖐️ Dual-Hand 10-Finger Camera Gesture Control
- **On-Device Vision Tracking**: Powered by Apple Vision framework (`VNDetectHumanHandPoseRequest`) running on the Apple Silicon Neural Engine at 60-120 FPS.
- **Precision Cursor Flight**: Jitter-free cursor flight calibrated with adaptive One-Euro filtering.
- **Natural Interaction**:
  - **Index-Thumb Pinch**: Left click.
  - **Pinch & Hold**: Drag windows, select code, or reorder files.
  - **Middle-Thumb Pinch**: Right click.
  - **Two-Finger Vertical Scroll**: Fluidly scroll pages up or down by moving your index and middle fingers together.
  - **Left Fist Hold**: Holds `Command` or dictation mode; opening your fist releases and commits text.
- **Live Skeletal HUD**: Floating feedback pill and skeletal hand joint rendering confirm detected gestures in real time.
- **Instant Hotkey Toggle**: Press `Control + G` to toggle camera tracking on or off at any time.

### 🎙️ Pocket-TTS Neural Engine & Voice Cloning Studio
- **100% Offline Local Inference**: Kyutai FlowLM models run directly on Apple Silicon. Zero cloud calls, zero monthly subscriptions, complete privacy.
- **24 Curated & Cloned Personas**: Includes Jarvis (Best & Classic), Sayed Johon Primary, Male Peace, Storyteller, Narrator, alba, cosette, george, marius, and more.
- **1-Click Voice Cloning Studio**: Drop in any 10 to 25 second audio recording, scrub timestamps with the waveform trimmer, and audition your cloned persona instantly.
- **Synchronous Engine Detection**: Instant zero-lag status checks when launching the dashboard.

### 🎵 Ambient Focus Soundtrack (Iron Man BGM)
- Integrated ambient background soundtrack engine that plays during thinking and speech phases.
- Smart auto-ducking with smooth logarithmic cross-fading and 2.5-second spatial reverb tails.

### 🎤 Push-to-Talk Fn Dictation
- Hold the physical `Fn` (Globe) key to speak your prompt or query.
- Instant cloud transcription via Groq Whisper API (or local speech recognition fallback) injects transcribed text directly into your active IDE or terminal.

---

## ⌨️ Global Hotkeys

| Shortcut | Function | Description |
| :--- | :--- | :--- |
| **`Control + S`** | **Speak Selection** | Highlight any paragraph in any app and speak it aloud immediately. |
| **`Control + P`** | **Speak Clipboard** | Speaks whatever text is currently stored in your clipboard buffer. |
| **`Control + G`** | **Toggle Camera Gestures** | Turn camera hand tracking on or off without opening settings. |
| **`Fn` (Hold)** | **Push-to-Talk Dictation** | Speak while holding `Fn`; transcribed text is typed directly into your active window. |
| **`Escape`** | **Instant Silence** | Low-level event tap that immediately halts speech and dismisses the notch player. |

---

## 💻 Developer CLI (`agentspeak` / `aspk`)

Agent Speak provides a comprehensive CLI utility installed at `~/.local/bin/agentspeak` (and aliased to `aspk`):

```bash
# Check service health, active engine, and socket status
agentspeak status

# Speak custom text through the notch player
agentspeak say "Deployment completed successfully. All tests passing."

# Speak highlighted text or current clipboard
agentspeak selected
agentspeak pb

# Open the settings dashboard
agentspeak dashboard

# Manage the Holographic Arc Reactor
agentspeak hologram on
agentspeak hologram off
agentspeak hologram blend screen     # normal, screen, additive, multiply, overlay, colordodge, luminosity
agentspeak hologram blends           # list all supported blending modes
agentspeak hologram opacity 80       # 10 to 100 percent
agentspeak hologram color cyan       # amber, cyan, green, red, purple, white
agentspeak hologram zoom 0.5         # set scale / zoom (0.0 to 1.0, 0.5 = 100% normal)
agentspeak hologram pos 0 0          # set X and Y pixel offsets
agentspeak hologram reset            # reset HUD transform to factory defaults
agentspeak hologram preview          # 5-second live visualizer test
agentspeak hologram stop             # instantly stop and dismiss live preview

# Camera Hand Tracking
agentspeak gesture status
agentspeak gesture on
agentspeak gesture off
agentspeak gesture toggle
agentspeak gesture hud on/off        # toggle floating gesture feedback HUD

# Voice Engine & Personas
agentspeak voice status
agentspeak voice list                # list all 24 neural and macOS system voices
agentspeak voice set Jarvis_Best
agentspeak voice vol 120             # volume from 1 to 200 percent

# Background Music (Iron Man BGM)
agentspeak bgm on
agentspeak bgm off
agentspeak bgm vol 50

# Dictation
agentspeak dictation status
agentspeak dictation toggle

# Signature Greeting
agentspeak greet                     # trigger active persona's intro greeting

# Silence & Lifecycle
agentspeak stop                      # immediately stop speech
agentspeak quit                      # terminate the background service
```

---

## 🤖 Agent Integration & Voice-First Protocol

To make your AI coding assistants speak naturally without reading code blocks or syntax, configure them with the **Voice-First Output Protocol**:

### System Prompt for AI Agents
Add this block to your agent configuration (`CLAUDE.md`, `.cursorrules`, `AGENTS.md`, or system prompt):

```markdown
# Voice-First & Text-to-Speech Output Protocol (Agent Speak)

- **Voice-First Prose (Text-to-Speech Optimized)**:
  All conversational text is automatically read aloud by macOS Text-to-Speech and Agent Speak. Every message MUST be written purely for the human ear (natural spoken English, as if speaking on a call).
  - Speak in a concise, warm, conversational tone.
  - Never read out raw URLs, long directory paths, camelCase identifiers, or punctuation chains in spoken text.

- **Strict Code & Command Quarantine (CRITICAL RULE)**:
  - NEVER write code snippets, terminal commands, file paths, programming syntax, or technical symbols inline inside conversational sentences or paragraphs.
  - Whenever code, scripts, or terminal commands are necessary, ALWAYS place them strictly inside isolated Markdown fenced code blocks (```).
  - The voice reader automatically skips and mutes all code blocks completely, allowing the user to copy/paste without interrupting the spoken voice.

- **Digestible Formatting**:
  - Use bullet points or tables for key updates, status items, and suggested options.
  - Keep conversational explanations concise and actionable.
```

*(See [SYSTEM_PROMPT.md](SYSTEM_PROMPT.md) for full documentation and tool-specific setup guides).*

---

## 🔌 Socket Protocol Reference (`/tmp/agentspeak.sock`)

Agent Speak runs a high-speed UNIX domain socket at `/tmp/agentspeak.sock`. Any terminal script or custom agent can send commands:

```bash
# Queue speech synthesis
echo "say:Task finished successfully" | nc -U /tmp/agentspeak.sock

# Immediately silence playback
echo "stop" | nc -U /tmp/agentspeak.sock

# Query daemon status JSON
echo "status" | nc -U /tmp/agentspeak.sock

# Switch voice engine
echo "engine:pocket_tts" | nc -U /tmp/agentspeak.sock

# Change hologram blending mode
echo "hologram:blend:screen" | nc -U /tmp/agentspeak.sock
```

---

## 🏗️ Architecture Overview

```
[Agent Transcripts / Hotkeys / CLI / Fn Dictation]
                       │
                       ▼
            /tmp/agentspeak.sock (UNIX Domain Socket)
                       │
                       ▼
             [TextSanitizer.swift] (Markdown tables, code quarantine, URLs)
                       │
                       ▼
          [SpeechQueueManager.swift] (FIFO sequential queue)
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
           • Full-Screen Holographic Arc Reactor (6 Themes, 7 Blending Modes)
```

---

## 🛡️ macOS Permissions & Gatekeeper Bypass

### Gatekeeper Quarantine Removal
If you downloaded `Agent-Speak.dmg` directly from GitHub Releases, macOS Gatekeeper may show:
*"Agent Speak is damaged and can't be opened"* or *"cannot be opened because it is from an unidentified developer"*.

Run this command once in Terminal to clear the quarantine flag:
```bash
xattr -cr "/Applications/Agent Speak.app"
```
*(Or double-click `Setup & Bypass Gatekeeper.command` inside the DMG).*

### System Permissions
Open **macOS System Settings > Privacy & Security**:
- **Accessibility**: Required for global hotkeys (`Control+S` to read selection, `Control+P` for clipboard, `Escape` to silence).
- **Camera**: Required only if you enable dual-hand 10-finger camera gesture tracking.
- **Microphone**: Required only if you use Push-to-Talk Fn dictation.

---

## 📁 Repository Structure

```
Agent-Speak/
├── .github/
│   └── workflows/
│       └── release.yml          # Automated DMG release CI/CD workflow
├── docs/
│   └── assets/                  # Banner and logo visual assets
├── Resources/
│   ├── Agent-Speak-Banner.png   # App banner
│   ├── Agent-Speak-logo.png     # 1024x1024 application icon
│   ├── bgm/                     # Iron Man focus soundtrack
│   ├── install_pocket_tts.sh    # On-demand neural engine installer
│   └── voices/                  # 24 neural cloned voice profiles (.safetensors)
├── Sources/
│   ├── main.swift               # App entrypoint and lifecycle
│   ├── AppDelegate.swift        # Tray item, hotkey bindings, global event taps
│   ├── DashboardView.swift      # Modern Raycast-grade SwiftUI settings window
│   ├── NotchWindowController.swift # 120 FPS ProMotion liquid glass notch HUD
│   ├── HologramManager.swift    # Hologram overlay lifecycle & blending modes
│   ├── CameraGestureManager.swift # Apple Vision 10-finger hand tracking
│   ├── GestureClassifier.swift  # Pinch, drag, two-finger scroll classifier
│   ├── StreamingAudioManager.swift # JIT lookahead streaming audio synthesizer
│   ├── PocketTTSManager.swift   # Kyutai FlowLM offline neural cloner
│   ├── VoiceCloningStudioView.swift # Interactive voice cloning studio
│   ├── FnDictationController.swift # Push-to-Talk Fn key dictation
│   ├── BackgroundMusicManager.swift # Ambient focus soundtrack engine
│   ├── TextSanitizer.swift      # Code block quarantine and prose cleaner
│   └── SpeechQueueManager.swift # Sequential thread-safe speech FIFO queue
├── CLI/
│   └── main.swift               # Native Swift CLI controller (`agentspeak`)
├── scripts/
│   └── build_dmg.sh             # Automated DMG packaging script
├── SYSTEM_PROMPT.md             # AI Agent Voice-First prompt guide
├── AGENTS.md                    # Developer and AI agent reference
├── install.sh                   # Native build and background service installer
└── uninstall.sh                 # Complete system uninstaller
```

---

## 🔒 Privacy & On-Device Security

- **100% On-Device Execution**: All synthesis, neural cloner inference, and hand gesture vision tracking run locally on Apple Silicon.
- **Zero Cloud Network Calls**: Your code, transcripts, and voice data never leave your computer.
- **Zero Analytics**: No telemetry, trackers, or hidden tracking.

---

## 📄 License

Agent Speak is open-source software licensed under the [MIT License](LICENSE).
