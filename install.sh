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

# 1. Stop any previous instances and unload launchd service
PLIST_PATH="$HOME/Library/LaunchAgents/com.agentspeak.app.plist"
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -9 -f "AgentSpeak" 2>/dev/null || true
pkill -9 -f "AntigravityJarvis" 2>/dev/null || true
pkill -9 -f "speech-bar" 2>/dev/null || true

# 2. Compile Unified Application (Sources/*.swift)
echo -e "${CYAN}→ Compiling Agent Speak application (Swift)...${NC}"
swiftc -O "$SCRIPT_DIR"/Sources/*.swift -o "/tmp/AgentSpeakBinary"
mv "/tmp/AgentSpeakBinary" "$APPS_DIR/Agent Speak.app/Contents/MacOS/AgentSpeak"
cp "$SCRIPT_DIR/dashboard/Info.plist" "$APPS_DIR/Agent Speak.app/Contents/Info.plist"
chmod +x "$APPS_DIR/Agent Speak.app/Contents/MacOS/AgentSpeak"

# Copy Resources (AppIcon, Tray Icons, Brand Assets)
if [[ -d "$SCRIPT_DIR/Resources" ]]; then
    echo -e "${CYAN}→ Installing custom brand assets & icons...${NC}"
    cp -R "$SCRIPT_DIR/Resources/"* "$APPS_DIR/Agent Speak.app/Contents/Resources/"
fi

# Clean extended attributes (prevents 'resource fork detritus' codesign error)
xattr -cr "$APPS_DIR/Agent Speak.app"

# Deep Codesign to bind bundle ID and seal resources for TCC / Accessibility
echo -e "${CYAN}→ Signing Agent Speak.app bundle (com.agentspeak.app)...${NC}"
codesign --force --deep --sign - --identifier "com.agentspeak.app" "$APPS_DIR/Agent Speak.app"

# Register LaunchServices so Finder displays AppIcon.icns
echo -e "${CYAN}→ Registering custom application icon in macOS Finder...${NC}"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APPS_DIR/Agent Speak.app" 2>/dev/null || true
touch "$APPS_DIR/Agent Speak.app"

# Configure menu bar tray position (distance 360pt from right, safely away from notch)
defaults write com.agentspeak.app "NSStatusItem Preferred Position AgentSpeakTray" -float 360
defaults write com.agentspeak.app "NSStatusItem Preferred Position Item-0" -float 360

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

# 4. Install Default Configuration & BGM tracks
mkdir -p "$CONFIG_DIR/bgm"
if [[ -f "$SCRIPT_DIR/Resources/bgm/AC_DC - Back In Black.mp3" && ! -f "$CONFIG_DIR/bgm/AC_DC - Back In Black.mp3" ]]; then
    cp "$SCRIPT_DIR/Resources/bgm/AC_DC - Back In Black.mp3" "$CONFIG_DIR/bgm/AC_DC - Back In Black.mp3"
fi
if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
    cp "$SCRIPT_DIR/config/default_config.json" "$CONFIG_DIR/config.json"
fi

# 5. Clean Obsolete Legacy LaunchAgents & Register 24/7 Daemon
echo -e "${CYAN}→ Registering Agent Speak as a permanent background service...${NC}"
launchctl unload "$HOME/Library/LaunchAgents/com.sayedjohon.antigravity-voice-watcher.plist" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.sayedjohon.antigravity-voice-watcher.plist"
launchctl unload "$HOME/Library/LaunchAgents/com.antigravity.jarvis.plist" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.antigravity.jarvis.plist"
pkill -9 -f "antigravity_voice_watcher" 2>/dev/null || true

PLIST_PATH="$HOME/Library/LaunchAgents/com.agentspeak.app.plist"
launchctl unload "$PLIST_PATH" 2>/dev/null || true

cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.agentspeak.app</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APPS_DIR/Agent Speak.app/Contents/MacOS/AgentSpeak</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>
    <key>StandardOutPath</key>
    <string>/tmp/agentspeak.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/agentspeak_err.log</string>
</dict>
</plist>
EOF

chmod 644 "$PLIST_PATH"
launchctl load -w "$PLIST_PATH"

echo -e "\n${GREEN}${BOLD}✓ Agent Speak installed successfully!${NC}"
echo -e "${BLUE}• Application:${NC}     $APPS_DIR/Agent Speak.app"
echo -e "${BLUE}• CLI Controller:${NC}  $BIN_DIR/agentspeak (alias: aspk)"
echo -e "${BLUE}• Voice Engine:${NC}    Default System Voice (Natural macOS)"
echo -e "${BLUE}• Background:${NC}      Launchd KeepAlive 24/7 (com.agentspeak.app)\n"

sleep 1.5
"$BIN_DIR/agentspeak" status
"$BIN_DIR/agentspeak" say "Agent Speak is installed and running with your natural system voice."
