#!/usr/bin/env bash
# ==============================================================================
# Agent Speak — Clean 1-Click Uninstaller
# ==============================================================================

set -e

echo "Uninstalling Agent Speak..."

# Stop running processes
pkill -9 -f "AgentSpeak" 2>/dev/null || true

# Remove Login Item
osascript -e '
tell application "System Events"
    if exists login item "Agent Speak" then
        delete login item "Agent Speak"
    end if
end tell
' 2>/dev/null || true

# Remove binaries and application
rm -f "$HOME/.local/bin/agentspeak"
rm -f "$HOME/.local/bin/aspk"
rm -rf "$HOME/Applications/Agent Speak.app"

# Clean up sockets and temp files
rm -f /tmp/agentspeak.*
rm -f /tmp/speech_chunk_*

echo "Agent Speak has been completely removed."
