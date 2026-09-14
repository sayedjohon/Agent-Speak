#!/usr/bin/env python3
import sys
import os
import re
import json
import shutil
import argparse
import subprocess
from pathlib import Path

# Set NO_PROXY to * to prevent httpx from crashing on macOS default ::1/128 CIDR
os.environ["NO_PROXY"] = "*"
os.environ["no_proxy"] = "*"

BASE_DIR = Path(__file__).resolve().parent
DEFAULT_VOICES_DIR = BASE_DIR / "voices"
if not DEFAULT_VOICES_DIR.exists():
    DEFAULT_VOICES_DIR = BASE_DIR / "pocket_tts_lab" / "voices"
DEFAULT_VOICES_DIR.mkdir(parents=True, exist_ok=True)

OUTPUTS_DIR = BASE_DIR / "outputs"
OUTPUTS_DIR.mkdir(parents=True, exist_ok=True)

CONFIG_PATH = Path.home() / ".agentspeak" / "config.json"

def trim_trailing_silence(samples, sample_rate, silence_thresh=0.008, pad=0.25):
    import numpy as np
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


def get_audio_duration(file_path: Path) -> float:
    ffprobe_bin = shutil.which("ffprobe") or "/opt/homebrew/bin/ffprobe"
    if not os.path.exists(ffprobe_bin):
        return 0.0
    cmd = [ffprobe_bin, "-v", "quiet", "-print_format", "json", "-show_format", str(file_path)]
    res = subprocess.run(cmd, capture_output=True, text=True)
    try:
        data = json.loads(res.stdout)
        return float(data["format"]["duration"])
    except Exception:
        return 0.0

def find_best_speech_window(file_path: Path, target_duration: float = 15.0):
    import numpy as np
    ffmpeg_bin = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
    total_sec = get_audio_duration(file_path)
    if total_sec <= target_duration or not os.path.exists(ffmpeg_bin):
        return 0.0, min(total_sec, target_duration) if total_sec > 0 else target_duration
    
    cmd = [ffmpeg_bin, "-i", str(file_path), "-ar", "8000", "-ac", "1", "-f", "s16le", "-"]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if not res.stdout:
        return 0.0, target_duration
        
    samples = np.frombuffer(res.stdout, dtype=np.int16).astype(np.float32) / 32768.0
    chunk_size = 4000 # 0.5 sec
    n_chunks = len(samples) // chunk_size
    window_chunks = int(target_duration * 2)
    if n_chunks <= window_chunks:
        return 0.0, total_sec
        
    rms = np.array([np.sqrt(np.mean(samples[i*chunk_size:(i+1)*chunk_size]**2)) for i in range(n_chunks)])
    best_start = 0.0
    best_score = -1.0
    for i in range(n_chunks - window_chunks + 1):
        win_rms = rms[i:i+window_chunks]
        active_ratio = np.mean(win_rms > 0.015)
        mean_energy = np.mean(win_rms)
        score = active_ratio * 0.7 + min(mean_energy, 0.2) * 1.5
        if score > best_score:
            best_score = score
            best_start = i * 0.5
            
    return float(best_start), float(min(target_duration, total_sec - best_start))

def preprocess_audio(input_file: Path, out_wav: Path, start_time: float = 0.0, duration: float = 20.0, auto_trim: bool = False):
    ffmpeg_bin = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
    if not os.path.exists(ffmpeg_bin):
        raise RuntimeError("ffmpeg is required for audio preprocessing")

    actual_start = start_time
    actual_dur = duration

    if auto_trim:
        actual_start, actual_dur = find_best_speech_window(input_file, target_duration=duration)
    else:
        total_sec = get_audio_duration(input_file)
        if total_sec > 0:
            actual_start = max(0.0, min(actual_start, max(0.0, total_sec - 5.0)))
            actual_dur = min(duration, max(5.0, total_sec - actual_start))

    cmd = [
        ffmpeg_bin, "-y",
        "-ss", f"{actual_start:.2f}",
        "-t", f"{actual_dur:.2f}",
        "-i", str(input_file),
        "-af", "highpass=f=80,volume=1.0",
        "-ar", "24000",
        "-ac", "1",
        "-c:a", "pcm_s16le",
        str(out_wav)
    ]
    res = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        raise RuntimeError(f"ffmpeg conversion failed: {res.stderr}")
        
    return actual_start, actual_dur

def main():
    parser = argparse.ArgumentParser(description="Interactive Voice Cloner & Audition Studio for Pocket-TTS")
    parser.add_argument("audio", help="Path to input audio file (.wav, .mp3, .m4a, etc.)")
    parser.add_argument("--name", "-n", default="", help="Voice persona name (e.g. MyVoice)")
    parser.add_argument("--text", "-t", default="Hello! This is an audition of my newly cloned voice persona.", help="Test phrase to synthesize")
    parser.add_argument("--start-time", "-s", type=float, default=0.0, help="Start offset in seconds for trimming")
    parser.add_argument("--duration", "-l", type=float, default=20.0, help="Duration in seconds (default: 20)")
    parser.add_argument("--auto-trim", action="store_true", help="Automatically detect clearest speech window")
    parser.add_argument("--info", action="store_true", help="Get duration and best speech segment in JSON and exit")
    parser.add_argument("--play-source", action="store_true", help="Extract and play trimmed source audio and exit")
    parser.add_argument("--preview", action="store_true", help="Generate temporary audition preview without saving")
    parser.add_argument("--save", action="store_true", help="Permanently save persona to voice library")
    parser.add_argument("--play", "-p", action="store_true", help="Automatically play audition audio via afplay")
    parser.add_argument("--voices-dir", "-d", help="Custom directory to save .safetensors")
    args = parser.parse_args()

    input_file = Path(args.audio).expanduser().resolve()
    if not input_file.exists():
        print(json.dumps({"status": "error", "message": f"Audio file not found: {input_file}"}))
        sys.exit(1)

    # 1. Info Query Mode (Ultra-Fast: No model loading)
    if args.info:
        total_sec = get_audio_duration(input_file)
        best_start, best_dur = find_best_speech_window(input_file, target_duration=args.duration)
        print(json.dumps({
            "status": "success",
            "mode": "info",
            "duration": round(total_sec, 2),
            "auto_start": round(best_start, 2),
            "recommended_duration": round(best_dur, 2)
        }))
        sys.exit(0)

    # 2. Play Source Segment Mode (Ultra-Fast: Verifies trimmed clip before cloning)
    if args.play_source:
        temp_wav = Path("/tmp/temp_voice_input.wav")
        try:
            act_s, act_d = preprocess_audio(input_file, temp_wav, start_time=args.start_time, duration=args.duration, auto_trim=args.auto_trim)
            subprocess.run(["killall", "afplay"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.Popen(["afplay", str(temp_wav)])
            print(json.dumps({
                "status": "success",
                "mode": "play_source",
                "start_time": round(act_s, 2),
                "duration": round(act_d, 2),
                "message": f"Playing reference segment ({act_d:.1f}s from {act_s:.1f}s)"
            }))
            sys.exit(0)
        except Exception as e:
            print(json.dumps({"status": "error", "message": str(e)}))
            sys.exit(1)

    hf_token_file = Path.home() / ".cache" / "huggingface" / "token"
    if hf_token_file.exists():
        os.environ["HF_TOKEN"] = hf_token_file.read_text().strip()

    from pocket_tts import TTSModel
    from pocket_tts.models.model_state import export_model_state
    import scipy.io.wavfile

    model = TTSModel.load_model(language="english")
    has_full_cloning = getattr(model, "has_voice_cloning", False)

    # 3. Preview Mode: Audition test phrase before saving
    if args.preview or not args.save:
        temp_wav = Path("/tmp/temp_voice_input.wav")
        try:
            act_s, act_d = preprocess_audio(input_file, temp_wav, start_time=args.start_time, duration=args.duration, auto_trim=args.auto_trim)
        except Exception as e:
            print(json.dumps({"status": "error", "message": str(e)}))
            sys.exit(1)

        try:
            # Generate state
            state = model.get_state_for_audio_prompt(str(temp_wav), truncate=True)
            temp_safetensors = Path("/tmp/temp_voice_preview.safetensors")
            export_model_state(state, temp_safetensors)
            
            # Synthesize custom test phrase
            test_phrase = args.text.strip() if args.text.strip() else "Hello! This is an audition of my newly cloned voice persona."
            audio = model.generate_audio(state, test_phrase)
            arr = audio.numpy()
            arr = trim_trailing_silence(arr, model.sample_rate)
            
            preview_out = Path("/tmp/audition_preview.wav")
            scipy.io.wavfile.write(str(preview_out), model.sample_rate, arr)
            
            duration = len(arr) / model.sample_rate
            
            if args.play:
                subprocess.run(["killall", "afplay"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                subprocess.Popen(["afplay", str(preview_out)])

            print(json.dumps({
                "status": "success",
                "mode": "preview",
                "preview_wav": str(preview_out),
                "duration": round(duration, 2),
                "trim_start": round(act_s, 2),
                "trim_duration": round(act_d, 2),
                "has_full_cloning": has_full_cloning,
                "message": f"Audition preview generated ({duration:.1f}s) from source ({act_s:.1f}s–{act_s+act_d:.1f}s)."
            }))
            sys.exit(0)
        except Exception as e:
            print(json.dumps({"status": "error", "message": f"Preview failed: {str(e)}"}))
            sys.exit(1)

    # 4. Save Mode: Commit persona permanently to library
    if args.save:
        clean_name = re.sub(r'[^a-zA-Z0-9_\-]', '_', args.name.strip()).strip('_')
        if not clean_name:
            clean_name = re.sub(r'[^a-zA-Z0-9_\-]', '_', input_file.stem).strip('_')
        if not clean_name:
            clean_name = f"Custom_Voice_{int(os.path.getmtime(str(input_file)))}"

        voices_dir = Path(args.voices_dir).expanduser().resolve() if args.voices_dir else DEFAULT_VOICES_DIR
        voices_dir.mkdir(parents=True, exist_ok=True)

        target_wav = voices_dir / f"{clean_name}.wav"
        target_safetensors = voices_dir / f"{clean_name}.safetensors"

        temp_preview_safe = Path("/tmp/temp_voice_preview.safetensors")
        temp_input_wav = Path("/tmp/temp_voice_input.wav")

        if temp_preview_safe.exists() and temp_input_wav.exists():
            shutil.copy(str(temp_preview_safe), str(target_safetensors))
            shutil.copy(str(temp_input_wav), str(target_wav))
        else:
            try:
                preprocess_audio(input_file, target_wav, start_time=args.start_time, duration=args.duration, auto_trim=args.auto_trim)
                state = model.get_state_for_audio_prompt(str(target_wav), truncate=True)
                export_model_state(state, target_safetensors)
            except Exception as e:
                print(json.dumps({"status": "error", "message": f"Save failed: {str(e)}"}))
                sys.exit(1)

        # Register in config.json
        if CONFIG_PATH.exists():
            try:
                with open(CONFIG_PATH, "r") as f:
                    cfg = json.load(f)
                ptts = cfg.setdefault("audio", {}).setdefault("pocket_tts", {})
                vlist = ptts.setdefault("available_voices", [])
                if clean_name not in vlist:
                    vlist.append(clean_name)
                    vlist.sort()
                with open(CONFIG_PATH, "w") as f:
                    json.dump(cfg, f, indent=2)
            except Exception:
                pass

        print(json.dumps({
            "status": "success",
            "mode": "saved",
            "name": clean_name,
            "safetensors": str(target_safetensors),
            "wav": str(target_wav),
            "message": f"Persona '{clean_name}' saved to library successfully!"
        }))

if __name__ == "__main__":
    main()
