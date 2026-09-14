#!/usr/bin/env bash
# ==============================================================================
# Agent Speak — 1-Click Universal Native Swift Installer for macOS
# ==============================================================================

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "\n${CYAN}${BOLD}✦ Welcome to the Agent Speak Installer (100% Native Swift) ✦${NC}"
echo -e "${BLUE}Zero Python dependencies • Universal AI Support • Native Apple Silicon${NC}\n"

if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${YELLOW}Error: Agent Speak requires macOS.${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/Applications"
CONFIG_DIR="$HOME/.agentspeak"

mkdir -p "$BIN_DIR"
mkdir -p "$APPS_DIR/Agent Speak.app/Contents/MacOS"
mkdir -p "$APPS_DIR/Agent Speak.app/Contents/Resources"
mkdir -p "$CONFIG_DIR"

# 1. Stop any previous instances
pkill -9 -f "AgentSpeak" 2>/dev/null || true
pkill -9 -f "AntigravityJarvis" 2>/dev/null || true
pkill -9 -f "speech-bar" 2>/dev/null || true

# 2. Compile Unified Application (Sources/*.swift)
echo -e "${CYAN}→ Compiling Agent Speak application (Swift)...${NC}"
swiftc -O "$SCRIPT_DIR"/Sources/*.swift -o "$APPS_DIR/Agent Speak.app/Contents/MacOS/AgentSpeak"
cp "$SCRIPT_DIR/dashboard/Info.plist" "$APPS_DIR/Agent Speak.app/Contents/Info.plist"
chmod +x "$APPS_DIR/Agent Speak.app/Contents/MacOS/AgentSpeak"

# Copy Resources (AppIcon, Tray Icons, Brand Assets)
if [[ -d "$SCRIPT_DIR/Resources" ]]; then
    echo -e "${CYAN}→ Installing custom brand assets & icons...${NC}"
    cp -R "$SCRIPT_DIR/Resources/"* "$APPS_DIR/Agent Speak.app/Contents/Resources/"
fi
touch "$APPS_DIR/Agent Speak.app"

# Also keep a copy in bin/
mkdir -p "$SCRIPT_DIR/bin"
cp "$APPS_DIR/Agent Speak.app/Contents/MacOS/AgentSpeak" "$SCRIPT_DIR/bin/AgentSpeak"

# 3. Compile Native Swift CLI (CLI/main.swift)
echo -e "${CYAN}→ Compiling 'agentspeak' CLI controller...${NC}"
swiftc -O "$SCRIPT_DIR/CLI/main.swift" -o "$BIN_DIR/agentspeak"
chmod +x "$BIN_DIR/agentspeak"
cp "$BIN_DIR/agentspeak" "$SCRIPT_DIR/bin/agentspeak"

# Create symlink 'aspk'
ln -sf "$BIN_DIR/agentspeak" "$BIN_DIR/aspk"

# Ensure ~/.local/bin in PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    if [[ -f "$HOME/.zshrc" ]] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.zshrc"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
    fi
fi

# 4. Install Default Configuration
if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
    cp "$SCRIPT_DIR/config/default_config.json" "$CONFIG_DIR/config.json"
fi

# 5. Add to macOS Login Items for Auto-Start on Boot
echo -e "${CYAN}→ Registering Agent Speak as a macOS Login Item...${NC}"
osascript -e '
tell application "System Events"
    set appPath to (POSIX file "'"$APPS_DIR/Agent Speak.app"'") as text
    if not (exists login item "Agent Speak") then
        make new login item at end with properties {path:appPath, hidden:true, name:"Agent Speak"}
    end if
end tell
' 2>/dev/null || true

# 6. Launch Application
echo -e "${CYAN}→ Launching Agent Speak...${NC}"
open "$APPS_DIR/Agent Speak.app"

echo -e "\n${GREEN}${BOLD}✓ Agent Speak installed successfully!${NC}"
echo -e "${BLUE}• Application:${NC}     $APPS_DIR/Agent Speak.app"
echo -e "${BLUE}• CLI Controller:${NC}  $BIN_DIR/agentspeak (alias: aspk)"
echo -e "${BLUE}• Voice Engine:${NC}    Default System Voice (Natural macOS)"
echo -e "${BLUE}• Permissions:${NC}     Single Accessibility item: 'Agent Speak.app'"
echo -e "${BLUE}• Auto-Start:${NC}      Registered in macOS Login Items\n"

sleep 1
"$BIN_DIR/agentspeak" say "Agent Speak is installed and running with your natural system voice."
