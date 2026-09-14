#!/usr/bin/env python3
import sys
import os
import re

# Fix NO_PROXY bug in httpx where ::1 causes invalid port crash
os.environ["NO_PROXY"] = "*"
os.environ["no_proxy"] = "*"

import argparse
import subprocess
from pathlib import Path
import scipy.io.wavfile
import numpy as np

BASE_DIR = Path(__file__).resolve().parent
VOICES_DIR = BASE_DIR / "pocket_tts_lab" / "voices"
if not VOICES_DIR.exists():
    VOICES_DIR = BASE_DIR / "voices"
VOICES_DIR.mkdir(parents=True, exist_ok=True)

ALT_DIR = BASE_DIR / "saved_voices"
OUTPUTS_DIR = BASE_DIR / "outputs"
OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)

PREDEFINED_NAMES = [
    "alba", "george", "cosette", "marius", "eponine", "fantine", 
    "charles", "paul", "anna", "vera", "jane", "mary", "michael", "eve"
]

def sanitize_text_for_speech(text: str) -> str:
    # Convert pauses and stage directions to clean commas
    t = re.sub(r'\s*[\(\[]\s*(?:[bB]|pause|breath|breeth|silent|silence)\s*[\)\]]\s*', ', ', text)
    # Strip markdown symbols (*, #, `, _, ~)
    t = re.sub(r'[*#`_~]', '', t)
    # Strip URL links
    t = re.sub(r'https?://\S+', 'link', t)
    # Replace multiple spaces/newlines
    t = re.sub(r'\s+', ' ', t).strip()
    return t

def trim_trailing_silence(samples, sample_rate, silence_thresh=0.008, pad=0.25):
    win_size = int(sample_rate * 0.04) # 40ms
    n_windows = len(samples) // win_size
    if n_windows == 0:
        return samples
    last_speech_sample = len(samples)
    for i in range(n_windows - 1, -1, -1):
        chunk = samples[i * win_size : (i + 1) * win_size]
        rms = np.sqrt(np.mean(chunk**2))
        if rms > silence_thresh:
            last_speech_sample = min(len(samples), (i + 1) * win_size + int(sample_rate * pad))
            break
    return samples[:last_speech_sample]


def get_native_fallback_voice(text: str) -> str:
    for ch in text:
        v = ord(ch)
        if v == 0x0964 or v == 0x0965:
            continue
        if 0x0980 <= v <= 0x09FF:
            return "Piya"
        if 0x0900 <= v <= 0x097F:
            return "Lekha"
        if 0x0600 <= v <= 0x06FF or 0x0750 <= v <= 0x077F:
            return "Majed"
        if 0x3040 <= v <= 0x30FF:
            return "Kyoko"
        if 0xAC00 <= v <= 0xD7AF:
            return "Yuna"
        if 0x4E00 <= v <= 0x9FFF:
            return "Tingting"
        if 0x0400 <= v <= 0x04FF:
            return "Milena"
        if 0x0B80 <= v <= 0x0BFF:
            return "Vani"
        if 0x0C00 <= v <= 0x0C7F:
            return "Geeta"
        if 0x0C80 <= v <= 0x0CFF:
            return "Soumya"
        if 0x0E00 <= v <= 0x0E7F:
            return "Kanya"
        if 0x0590 <= v <= 0x05FF:
            return "Carmit"
        if 0x0370 <= v <= 0x03FF:
            return "Melina"
    return None

def main():
    parser = argparse.ArgumentParser(description="Pocket TTS Instant Voice Synthesizer & Player for macOS")
    parser.add_argument("text", nargs="*", help="Text to speak")
    parser.add_argument("--voice", "-v", default="Jarvis_Best", help="Voice name or filename (default: Jarvis_Best)")
    parser.add_argument("--play", "-p", action="store_true", default=True, help="Automatically play audio via afplay (default: True)")
    parser.add_argument("--no-play", action="store_false", dest="play", help="Do not play audio automatically")
    parser.add_argument("--output", "-o", help="Custom output wav path")
    args = parser.parse_args()

    raw_text = " ".join(args.text).strip()
    if not raw_text:
        if not sys.stdin.isatty():
            raw_text = sys.stdin.read().strip()
        else:
            print("Usage: python3 speak.py 'Your text to say' [--voice VoiceName]")
            sys.exit(1)

    text = sanitize_text_for_speech(raw_text)
    if not text:
        sys.exit(0)

    # Automatic Multilingual Fallback: If text is in an unsupported script, use macOS native voice
    native_voice = get_native_fallback_voice(text)
    if native_voice:
        out_file = Path(args.output) if args.output else (OUTPUTS_DIR / "last_spoken.wav")
        tmp_aiff = out_file.with_suffix(".aiff")
        subprocess.run(["/usr/bin/say", "-v", native_voice, "-o", str(tmp_aiff), text], check=True)
        if out_file.suffix.lower() == ".wav":
            subprocess.run(["/usr/bin/afconvert", "-f", "WAVE", "-d", "LEI16@24000", str(tmp_aiff), str(out_file)], check=True)
            if tmp_aiff.exists():
                tmp_aiff.unlink()
        elif tmp_aiff != out_file:
            tmp_aiff.rename(out_file)
        if args.play:
            subprocess.run(["killall", "afplay"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.Popen(["afplay", str(out_file)])
        print(f"[PocketTTS Native Fallback] Spoken via {native_voice} -> {out_file}")
        sys.exit(0)

    # Set Hugging Face token if present
    hf_token_file = Path.home() / ".cache" / "huggingface" / "token"
    if hf_token_file.exists():
        os.environ["HF_TOKEN"] = hf_token_file.read_text().strip()

    from pocket_tts import TTSModel
    from pocket_tts.models.model_state import export_model_state

    # Load model
    model = TTSModel.load_model(language="english")
    model.has_voice_cloning = True

    # Locate voice prompt
    voice_target = args.voice.strip()
    state = None
    
    # Check for direct .safetensors or .wav match across candidate directories
    voice_clean = voice_target.strip()
    voice_alt = voice_clean.replace("-", "_") if "-" in voice_clean else voice_clean.replace("_", "-")
    
    search_dirs = [
        VOICES_DIR,
        ALT_DIR,
        Path.home() / ".agentspeak" / "extensions" / "pocket-tts" / "voices",
        Path("/Applications/Agent Speak.app/Contents/Resources/voices"),
        Path.home() / "Applications/Agent Speak.app/Contents/Resources/voices",
        Path(__file__).resolve().parent / "voices",
        Path(__file__).resolve().parent.parent / "Resources" / "voices",
    ]
    
    candidates = []
    for d in search_dirs:
        for v in [voice_clean, voice_alt]:
            candidates.append(d / f"{v}.safetensors")
            candidates.append(d / f"{v}.wav")
            candidates.append(d / v)
    
    matched = None
    for cand in candidates:
        if cand.exists():
            matched = cand
            break
            
    if matched:
        state = model.get_state_for_audio_prompt(str(matched))
        # If matched was audio, auto-cache as safetensors for future instant loads
        if matched.suffix.lower() in [".wav", ".mp3", ".m4a"]:
            cache_target = VOICES_DIR / f"{matched.stem}.safetensors"
            try:
                export_model_state(state, cache_target)
            except Exception:
                pass
    elif voice_target.lower() in PREDEFINED_NAMES:
        # Predefined voice download and cache
        cached_safetensors = VOICES_DIR / f"{voice_target.lower()}.safetensors"
        if cached_safetensors.exists():
            state = model.get_state_for_audio_prompt(str(cached_safetensors))
        else:
            state = model.get_state_for_audio_prompt(voice_target.lower())
            try:
                export_model_state(state, str(cached_safetensors))
            except Exception:
                pass
    else:
        # Fall back to primary voice if available
        default_state = VOICES_DIR / "Sayed_Johon_Primary.safetensors"
        if not default_state.exists():
            default_state = ALT_DIR / "Sayed_Johon_Primary.safetensors"
        if default_state.exists():
            state = model.get_state_for_audio_prompt(str(default_state))
        else:
            # Fall back to alba
            state = model.get_state_for_audio_prompt("alba")

    # Generate
    audio = model.generate_audio(state, text)
    arr = audio.numpy()
    
    # Trim trailing silence/dead air
    arr = trim_trailing_silence(arr, model.sample_rate)
    
    out_file = Path(args.output) if args.output else (OUTPUTS_DIR / "last_spoken.wav")
    scipy.io.wavfile.write(str(out_file), model.sample_rate, arr)
    
    if args.play:
        # Stop any existing speech first
        subprocess.run(["killall", "afplay"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["killall", "say"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        # Play the newly generated speech
        subprocess.Popen(["afplay", str(out_file)])

    print(f"[PocketTTS] Synthesized {len(arr)/model.sample_rate:.2f}s -> {out_file}")

if __name__ == "__main__":
    main()
