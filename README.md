# Agent Speak 🎙️✨

> **Universal 100% Native Swift Voice Companion for AI Coding Agents on macOS.**  
> Speaks your AI assistant's responses out loud in real time directly beneath your MacBook Pro camera notch or floating on external displays, using your Mac's natural default system voice.

---

## 🌟 Highlights

- 🍏 **100% Pure Native Swift**: Built exclusively in Swift, SwiftUI, and AppKit. Zero Python dependencies, zero background scripts, zero external runtimes.
- 🎙️ **Natural Default System Voice**: Automatically adopts your MacBook's natural system voice with zero manual configuration.
- 🛸 **Adaptive Liquid Glass Notch Bar**: Hugs your MacBook camera notch (0pt sharp top corners), or contracts into a sleek 10pt floating pill on external displays. Automatically tracks your cursor across multiple monitors.
- ⚡ **50ms Zero-Latency Engine**: Dynamically chunks text with intelligent buffer runway for instant audio playback.
- 🤖 **Universal Multi-Agent Support**:
  - **Antigravity IDE**: Real-time transcript watching (`~/.gemini/antigravity/brain`).
  - **Claude Code & Desktop**: Interactive session tracking (`~/.claude/projects`).
  - **OpenCode, Aider & Cloud Agents**: Open session watching (`~/.opencode/sessions`).
  - **Universal UNIX Socket & CLI**: Direct IPC pipe (`/tmp/agentspeak.sock`) and native Swift CLI `agentspeak say`.
- 🎛️ **CleanMyMac-Style Dashboard**: Menu bar resident with an interactive 3D animated resonance orb, active workspace toggles, and live controls.
- 🔐 **Single Unified Permission**: Everything runs inside a single app bundle (`Agent Speak.app`). No separate helper tools or multiple accessibility prompts.
- ⌨️ **Global Escape Key Dismiss**: Press Escape from any application to dismiss playback in 0ms via a low-level macOS Event Tap.
- 🛡️ **Strict Code Block Quarantine**: Skips fenced code blocks, filepaths, and technical symbols so only natural spoken English is read aloud.

---

## 🚀 Quick Install (1-Line)

Clone the repository and run the installer:

```bash
git clone https://github.com/your-username/agent-speak.git
cd agent-speak
./install.sh
```

---

## 🎛️ Swift CLI Commands

Agent Speak includes a native CLI tool `agentspeak` (alias: `aspk`):

```bash
# Check running status
agentspeak status

# Speak text through the notch player using your default system voice
agentspeak say "Hello! Agent Speak is running smoothly."

# Open the CleanMyMac-style 3D Visualizer Dashboard
agentspeak dashboard

# Stop current speech
agentspeak stop

# Quit Agent Speak
agentspeak quit
```

---

## 📖 Pairing Agent Speak with Your AI Agents

### For Antigravity (`AGENTS.md`)
Add this section to `AGENTS.md` or `.agents/rules.md`:

```markdown
## 🎙️ Global Voice & Audio Output Formatting Protocol
- **Text-to-Speech First Format**: All response text MUST be written naturally for the human ear (conversational, spoken English, like a direct phone call).
- **Strict Quarantine of Code**: NEVER write raw code snippets, terminal commands, or file paths inline inside sentences.
- **Fenced Code Blocks ONLY**: Always place all code, scripts, or terminal commands strictly inside isolated Markdown fenced code blocks (```). The voice reader automatically mutes and skips all fenced code blocks.
```

### For Claude Code (`CLAUDE.md`)
Add this section to `CLAUDE.md`:

```markdown
## Voice-First Audio Protocol (Agent Speak)
1. **Spoken Tone**: Write conversational responses in natural, spoken English.
2. **Code Quarantine**: Never write inline code or paths inside prose.
3. **Fenced Blocks**: Place all code snippets and shell commands exclusively inside triple-backtick fenced blocks so they are muted in speech.
```

### For OpenCode & Aider
Add this snippet to your agent configuration:

```markdown
Format conversational prose for text-to-speech listening via Agent Speak. Keep all code blocks strictly inside isolated Markdown triple backticks.
```

---

## 📁 Repository Structure

```
agent-speak/
├── README.md               # Master documentation & quickstart
├── install.sh              # 1-click installer & Login Item setup
├── uninstall.sh            # Clean uninstaller
├── Sources/
│   ├── main.swift          # App entry point
│   ├── AppDelegate.swift   # Menu bar status item & dashboard manager
│   ├── DashboardView.swift # CleanMyMac-style 3D visualizer dashboard
│   ├── NotchWindowController.swift # In-process Liquid Glass notch player
│   ├── TranscriptWatcher.swift     # Multi-app transcript scanner & socket
│   ├── TextSanitizer.swift         # Pure Swift markdown & code stripper
│   └── SpeechQueueManager.swift    # In-process sequential playback queue
├── CLI/
│   └── main.swift          # Native Swift CLI tool source ('agentspeak')
├── config/
│   └── default_config.json # User settings & preferences
└── rules/
    ├── AGENTS.md           # Antigravity rules snippet
    ├── CLAUDE.md           # Claude Code rules snippet
    ├── OPENCODE.md         # OpenCode rules snippet
    └── SYSTEM_PROMPT.md    # Universal system prompt
```

---

## 📄 License

MIT License © 2026 Agent Speak Contributors.
