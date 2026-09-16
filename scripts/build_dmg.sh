#!/usr/bin/env bash
# ==============================================================================
# Agent Speak — Automated macOS DMG Packaging Engine
# ==============================================================================

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "\n${CYAN}${BOLD}✦ Agent Speak — DMG Packaging Engine ✦${NC}"
echo -e "${BLUE}Native Apple Silicon • Gatekeeper Helper • Universal Packaging${NC}\n"

if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "${RED}Error: DMG packaging requires macOS.${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/dist"
DMG_ROOT="$DIST_DIR/dmg_root"
APP_NAME="Agent Speak.app"
APP_SOURCE="$HOME/Applications/$APP_NAME"
DMG_NAME="Agent-Speak.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"

# Step 1: Ensure application binary is built and up to date
if [[ ! -d "$APP_SOURCE" || "$1" == "--rebuild" ]]; then
    echo -e "${CYAN}→ Building Agent Speak from source...${NC}"
    "$PROJECT_DIR/install.sh"
fi

if [[ ! -d "$APP_SOURCE" ]]; then
    echo -e "${RED}Error: '$APP_SOURCE' does not exist. Run ./install.sh first.${NC}"
    exit 1
fi

echo -e "${CYAN}→ Preparing DMG staging directory...${NC}"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"

# Step 2: Copy App Bundle
echo -e "${CYAN}→ Copying $APP_NAME into DMG staging...${NC}"
cp -R "$APP_SOURCE" "$DMG_ROOT/"

# Step 3: Create Applications Symlink
echo -e "${CYAN}→ Creating Applications shortcut symlink...${NC}"
ln -s /Applications "$DMG_ROOT/Applications"

# Step 4: Add Clear Installation Instructions
echo -e "${CYAN}→ Writing installation instructions...${NC}"
cat << 'INSTRUCTIONS' > "$DMG_ROOT/INSTALL_INSTRUCTIONS.txt"
==============================================================================
✦ Agent Speak — Installation & Quick Start Guide ✦
The Liquid Glass Voice Companion for AI Coding Agents on macOS
==============================================================================

1. INSTALLATION:
   Drag "Agent Speak.app" into the "Applications" shortcut icon inside this window.

2. FIRST TIME SETUP (GATEKEEPER BYPASS):
   Because Agent Speak is an open-source, independently distributed app without
   an Apple Developer ID certificate ($99/year), macOS Gatekeeper will block
   it by default with a warning:
   "Agent Speak is damaged and can't be opened" OR
   "cannot be opened because it is from an unidentified developer".

   OPTION A — RECOMMENDED (1-CLICK):
   Double-click the "Setup & Bypass Gatekeeper.command" file in this window.
   It will automatically remove the quarantine flag and configure the CLI.

   OPTION B — MANUAL TERMINAL COMMAND:
   Open Terminal and execute:
   xattr -cr "/Applications/Agent Speak.app"

3. PERMISSIONS REQUIRED:
   To enable all companion features, open macOS System Settings > Privacy & Security:
   - Accessibility: Required for global hotkeys (Control+S to read highlighted text,
     Control+P for clipboard, Escape to instantly silence audio).
   - Camera: Required only if you enable dual-hand 10-finger camera gesture tracking.
   - Microphone: Required only if you use Push-to-Talk Fn dictation.

4. CLI CONTROLLER (OPTIONAL):
   You can control Agent Speak directly from any terminal or agent prompt:
   mkdir -p ~/.local/bin
   ln -sf "/Applications/Agent Speak.app/Contents/MacOS/AgentSpeak" ~/.local/bin/agentspeak
   ln -sf "/Applications/Agent Speak.app/Contents/MacOS/AgentSpeak" ~/.local/bin/aspk

   CLI Commands:
   • agentspeak status              # Check daemon and voice engine state
   • agentspeak say "Hello world"   # Speak text via notch player
   • agentspeak hologram blend screen # Set hologram blending mode
   • agentspeak gesture on          # Enable camera hand tracking
   • agentspeak voice list          # List all available neural & system voices
   • agentspeak settings            # Open settings dashboard

For full documentation, architecture, and multi-agent guides, visit:
https://github.com/sayedjohon/Agent-Speak
==============================================================================
INSTRUCTIONS

# Step 5: Add 1-Click Gatekeeper Helper Script
echo -e "${CYAN}→ Creating 1-click Gatekeeper bypass helper...${NC}"
cat << 'HELPER' > "$DMG_ROOT/Setup & Bypass Gatekeeper.command"
#!/bin/bash
# ==============================================================================
# Agent Speak — 1-Click Gatekeeper Bypass & CLI Setup Helper
# ==============================================================================

clear
echo "=================================================================="
echo "    ✦ Agent Speak — 1-Click Setup & Gatekeeper Helper ✦"
echo "=================================================================="
echo ""

APP_PATH="/Applications/Agent Speak.app"

if [ ! -d "$APP_PATH" ]; then
    echo "⚠️  'Agent Speak.app' was not found in your Applications folder."
    echo "Please drag 'Agent Speak.app' into Applications first, then run this helper."
    echo ""
    read -p "Press [Enter] to exit..."
    exit 1
fi

echo "→ [1/3] Removing macOS Gatekeeper quarantine attributes..."
xattr -cr "$APP_PATH" 2>/dev/null || true
echo "  ✓ Gatekeeper quarantine cleared successfully."
echo ""

echo "→ [2/3] Setting up CLI controller ('agentspeak' & 'aspk')..."
USER_BIN="$HOME/.local/bin"
mkdir -p "$USER_BIN"
ln -sf "$APP_PATH/Contents/MacOS/AgentSpeak" "$USER_BIN/agentspeak"
ln -sf "$APP_PATH/Contents/MacOS/AgentSpeak" "$USER_BIN/aspk"

if [ -w "/usr/local/bin" ]; then
    ln -sf "$APP_PATH/Contents/MacOS/AgentSpeak" /usr/local/bin/agentspeak 2>/dev/null || true
    ln -sf "$APP_PATH/Contents/MacOS/AgentSpeak" /usr/local/bin/aspk 2>/dev/null || true
fi
echo "  ✓ CLI commands installed to $USER_BIN"
echo ""

echo "→ [3/3] Launching Agent Speak..."
open "$APP_PATH"
echo "  ✓ Agent Speak application started."
echo ""
echo "=================================================================="
echo "🎉 Setup complete! You can now close this terminal window."
echo "Tip: Grant Accessibility in System Settings > Privacy & Security"
echo "so global hotkeys (Control+S, Control+P, Escape) can function."
echo "=================================================================="
echo ""
read -p "Press [Enter] to exit..."
HELPER

chmod +x "$DMG_ROOT/Setup & Bypass Gatekeeper.command"

# Step 6: Create DMG using hdiutil
echo -e "${CYAN}→ Creating DMG image ($DMG_NAME)...${NC}"
rm -f "$DMG_PATH"

hdiutil create \
    -volname "Agent Speak" \
    -srcfolder "$DMG_ROOT" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Step 7: Generate SHA256 Checksum
echo -e "${CYAN}→ Generating SHA256 checksum...${NC}"
cd "$DIST_DIR"
shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
SHA_VALUE=$(cut -d ' ' -f 1 "$DMG_NAME.sha256")

echo -e "\n${GREEN}${BOLD}✓ DMG generated successfully!${NC}"
echo -e "• File:     $DMG_PATH"
echo -e "• Size:     $DMG_SIZE"
echo -e "• SHA256:   $SHA_VALUE"
echo -e "• Checksum: $DIST_DIR/$DMG_NAME.sha256\n"
