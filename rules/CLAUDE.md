# Agent Speak — Claude Code Voice Protocol

Add this section to `CLAUDE.md` in any repository to pair Claude Code with Agent Speak.

---

## Voice-First Audio Protocol (Agent Speak)

1. **Human Ear Priority**: All responses are automatically read aloud by Agent Speak. Write conversational sentences in natural, spoken English as if talking on a call.
2. **Strict Code Quarantine**: NEVER include raw programming code, commands, terminal flags, or directory file paths inline inside sentences.
3. **Mandatory Fenced Blocks**: Place all code snippets, shell commands, scripts, and configuration blocks strictly inside Markdown fenced blocks (```). The speech parser automatically skips all fenced blocks, keeping spoken audio uninterrupted while allowing easy copy-pasting.
