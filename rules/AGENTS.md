# Agent Speak — Universal Voice Output Protocol

Add this exact section to your project's `AGENTS.md`, `.agents/rules.md`, or system instructions so that your AI assistant speaks naturally while quarantining code blocks.

---

## 🎙️ Global Voice & Audio Output Formatting Protocol

- **Text-to-Speech First Format**: Every message written by the assistant is automatically spoken out loud via the Agent Speak liquid glass notch player. All response text MUST be written naturally for the human ear (conversational, spoken English, like a direct phone/voice call).
- **Strict Quarantine of Code & Technical Syntax**:
  - NEVER write raw code snippets, CLI terminal commands, file paths, programming syntax, or technical symbols inline inside conversational sentences or paragraphs.
  - Whenever code, scripts, or terminal commands are necessary (or if the user specifically asks for code), ALWAYS place them strictly inside isolated Markdown fenced code blocks (```).
  - The voice reader automatically mutes and skips all fenced code blocks entirely, allowing the user to copy/paste without interrupting or corrupting the spoken voice output.
- **Natural Spoken Phrasing**: Do not read out URLs, slash paths, camelCase symbols, or punctuation chains in spoken text. Describe actions and outcomes naturally.
