#!/usr/bin/env bash
# ==============================================================================
# Agent Speak — Pocket-TTS Neural Extension On-Demand Installer
# ==============================================================================

set -e

BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

EXT_DIR="$HOME/.agentspeak/extensions/pocket-tts"
VENV_DIR="$EXT_DIR/venv"
VOICES_DIR="$EXT_DIR/voices"
CONFIG_FILE="$HOME/.agentspeak/config.json"

echo -e "\n${CYAN}${BOLD}✦ Pocket-TTS Neural Extension Installer ✦${NC}"
echo -e "${BLUE}Zero-Latency • 100% Offline Neural Voice Cloning • Apple Silicon${NC}\n"

mkdir -p "$EXT_DIR"
mkdir -p "$VOICES_DIR"

# 1. Detect Python 3.10 - 3.13
echo -e "${CYAN}→ [1/5] Detecting compatible Python runtime...${NC}"
PYTHON_BIN=""

# Check potential locations
CANDIDATES=(
    "/opt/homebrew/bin/python3.11"
    "/opt/homebrew/bin/python3.12"
    "/opt/homebrew/bin/python3.10"
    "$(which python3.11 2>/dev/null || true)"
    "$(which python3.12 2>/dev/null || true)"
    "$(which python3.10 2>/dev/null || true)"
    "/usr/local/bin/python3"
    "$(which python3 2>/dev/null || true)"
)

for cand in "${CANDIDATES[@]}"; do
    if [[ -x "$cand" ]]; then
        VER=$("$cand" -c 'import sys; print(sys.version_info[0]*10 + sys.version_info[1])' 2>/dev/null || echo "0")
        if [[ "$VER" -ge 310 && "$VER" -le 313 ]]; then
            PYTHON_BIN="$cand"
            break
        fi
    fi
done

if [[ -z "$PYTHON_BIN" ]]; then
    echo -e "${YELLOW}Compatible Python (3.10 - 3.12) not detected.${NC}"
    if command -v brew >/dev/null 2>&1; then
        echo -e "${CYAN}→ Installing python@3.11 via Homebrew...${NC}"
        brew install python@3.11
        PYTHON_BIN="/opt/homebrew/bin/python3.11"
    else
        echo -e "${RED}Error: Python 3.10+ or Homebrew required to install neural extension.${NC}"
        echo -e "Please run: brew install python@3.11"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Using Python: $PYTHON_BIN ($($PYTHON_BIN --version))${NC}"

# 2. Virtual Environment Setup
echo -e "${CYAN}→ [2/5] Setting up isolated Python virtual environment...${NC}"
if [[ ! -f "$VENV_DIR/bin/python" ]]; then
    "$PYTHON_BIN" -m venv "$VENV_DIR"
fi
echo -e "${GREEN}✓ Virtual environment created at $VENV_DIR${NC}"

# 3. Pip Packages
echo -e "${CYAN}→ [3/5] Installing neural engine libraries (pocket-tts, scipy, safetensors, soundfile)...${NC}"
"$VENV_DIR/bin/pip" install --quiet --upgrade pip
"$VENV_DIR/bin/pip" install --quiet pocket-tts scipy safetensors soundfile
echo -e "${GREEN}✓ Neural engine dependencies installed successfully.${NC}"

# 4. Copy scripts into extension dir
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_POCKET_DIR="$(cd "$SCRIPT_DIR/../../pocket-tts" 2>/dev/null && pwd || echo "")"

if [[ -f "$SCRIPT_DIR/../pocket-tts/speak.py" ]]; then
    cp "$SCRIPT_DIR/../pocket-tts/speak.py" "$EXT_DIR/speak.py"
    cp "$SCRIPT_DIR/../pocket-tts/clone_voice.py" "$EXT_DIR/clone_voice.py"
elif [[ -n "$DEV_POCKET_DIR" && -f "$DEV_POCKET_DIR/speak.py" ]]; then
    cp "$DEV_POCKET_DIR/speak.py" "$EXT_DIR/speak.py"
    cp "$DEV_POCKET_DIR/clone_voice.py" "$EXT_DIR/clone_voice.py"
fi
chmod +x "$EXT_DIR/speak.py" "$EXT_DIR/clone_voice.py" 2>/dev/null || true

# 5. Pre-cache standard voices
echo -e "${CYAN}→ [4/5] Pre-caching neural personas (Alba, George, Cosette, Marius, Sayed Johon)...${NC}"
"$VENV_DIR/bin/python" -c "
import os
os.environ.pop('NO_PROXY', None)
os.environ.pop('no_proxy', None)
from pocket_tts import TTSModel
from pocket_tts.models.model_state import export_model_state
from pathlib import Path

vdir = Path('$VOICES_DIR')
vdir.mkdir(parents=True, exist_ok=True)
model = TTSModel.load_model(language='english')

for name in ['alba', 'george', 'cosette', 'marius']:
    target = vdir / f'{name}.safetensors'
    if not target.exists():
        try:
            state = model.get_state_for_audio_prompt(name)
            export_model_state(state, str(target))
        except Exception:
            pass

# Also ensure Jarvis is mapped to clean butler state
jarvis_target = vdir / 'Jarvis.safetensors'
george_target = vdir / 'george.safetensors'
if not jarvis_target.exists() and george_target.exists():
    import shutil
    shutil.copy(str(george_target), str(jarvis_target))
"

# Copy Sayed Johon Primary if exists in dev
if [[ -n "$DEV_POCKET_DIR" && -f "$DEV_POCKET_DIR/pocket_tts_lab/voices/Sayed_Johon_Primary.safetensors" ]]; then
    cp "$DEV_POCKET_DIR/pocket_tts_lab/voices/Sayed_Johon_Primary.safetensors" "$VOICES_DIR/"
fi

# 6. Verification and Config Update
echo -e "${CYAN}→ [5/5] Testing neural synthesis and updating config...${NC}"
"$VENV_DIR/bin/python" "$EXT_DIR/speak.py" "Pocket-TTS neural extension is ready." --voice alba --no-play

# Update config.json
if [[ -f "$CONFIG_FILE" ]]; then
    "$VENV_DIR/bin/python" -c "
import json
from pathlib import Path
p = Path('$CONFIG_FILE')
if p.exists():
    cfg = json.load(open(p))
    ptts = cfg.setdefault('audio', {}).setdefault('pocket_tts', {})
    ptts['enabled'] = True
    vdir = Path('$VOICES_DIR')
    voices = ['Sayed_Johon_Primary', 'Jarvis', 'alba', 'george', 'cosette', 'marius']
    for f in vdir.glob('*.safetensors'):
        if f.stem not in voices:
            voices.append(f.stem)
    ptts['available_voices'] = sorted(list(set(voices)))
    json.dump(cfg, open(p, 'w'), indent=2)
"
fi

echo -e "\n${GREEN}${BOLD}✓ Pocket-TTS Neural Extension successfully installed!${NC}"
echo -e "${BLUE}• Extension Location:${NC} $EXT_DIR"
echo -e "${BLUE}• Status:${NC}             Ready & 100% Offline"
echo -e "${BLUE}• Personas:${NC}           Sayed Johon, Jarvis, Alba, George, Cosette, Marius\n"
