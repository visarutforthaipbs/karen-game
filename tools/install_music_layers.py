"""Install ElevenLabs music layers as seamless game loops.

Folds the tail onto the head (equal-power crossfade) for a clean loop point,
normalizes to the procedural layers' peak targets, and writes
assets/audio/sfxloop_music<0|1|2>.wav drop-ins (AudioManager._music_stream
picks them up automatically; synthesized layers remain fallback).

Run: ~/.hermes/hermes-agent/venv/bin/python tools/install_music_layers.py
"""
import glob, json, os, struct, subprocess, wave

import numpy as np

GEN = "artifacts/sfx_elevenlabs/gen"
AUD = "assets/audio"
SR = 44100
XFADE = int(0.3 * SR)
# peaks matching AudioManager's procedural layer normalization [0.7, 0.6, 0.7]
TARGETS = {"music_l0": (0.7, "sfxloop_music0.wav"),
           "music_l1": (0.6, "sfxloop_music1.wav"),
           "music_l2": (0.7, "sfxloop_music2.wav")}

def mp3_to_array(mp3):
    raw = "/tmp/_music_tmp.wav"
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", "-c", "1", "-r", str(SR), mp3, raw], check=True)
    w = wave.open(raw)
    x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32767.0
    w.close()
    return x

manifest_path = os.path.join(GEN, "music_manifest.json")
manifest = []
for base, (peak, out_name) in TARGETS.items():
    src = os.path.join(GEN, base + ".mp3")
    if not os.path.isfile(src):
        print("MISSING", src)
        continue
    x = mp3_to_array(src)
    if len(x) > XFADE * 2:
        t = np.linspace(0, np.pi / 2, XFADE)
        head = x[:XFADE] * np.sin(t)
        tail = x[-XFADE:] * np.cos(t)
        x = np.concatenate([head + tail, x[XFADE:-XFADE]])
    # rotate the loop start to a sustained loud region so the loop restart
    # does not hitch through the songs' soft intros (seam stays continuous)
    win = int(0.5 * SR)
    env = np.convolve(x ** 2, np.ones(win) / win, mode="same")
    x = np.roll(x, -int(np.argmax(env)))
    m = np.max(np.abs(x)) or 1.0
    x = np.clip(x * (peak / m), -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    w = wave.open(os.path.join(AUD, out_name), "w")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(data); w.close()
    manifest.append({"file": out_name, "from": base + ".mp3", "duration_s": round(len(x) / SR, 3),
                     "peak": peak, "xfade_s": round(XFADE / SR, 2)})
    print(f"{out_name:20s} {len(x)/SR:5.2f}s peak {peak}  <- {base}.mp3")

json.dump(manifest, open(manifest_path, "w"), indent=2)
print("manifest ->", manifest_path)
