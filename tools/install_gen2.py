"""Install the regenerated (paid-plan) SFX set with the audit fixes applied:
silence trims, targeted de-hiss, loudness targets. Also installs the TTS barks.

Run: ~/.hermes/hermes-agent/venv/bin/python tools/install_gen2.py
"""
import glob, json, os, subprocess, wave

import numpy as np

GEN = "artifacts/sfx_elevenlabs/gen2"
AUD = "assets/audio"
SR = 44100

# name -> (peak, tail_cap_s, dehiss_hz, dehiss_db)  (mirrors regen_sfx_starter.py)
JOBS = {
    "sfx_beep": (0.60, 0.25, 0, 0), "sfx_camera": (0.55, 0.25, 0, 0),
    "sfx_cough": (0.55, 0.20, 0, 0), "sfx_step_brush": (0.55, 0.20, 0, 0),
    "sfx_step_ash": (0.45, 0.20, 0, 0), "sfx_pop": (0.70, 0.25, 0, 0),
    "sfx_thunder": (0.70, 0.30, 0, 0), "sfx_ui_click": (0.50, 0.25, 0, 0),
    "sfx_tool_clack": (0.55, 0.05, 0, 0), "sfx_ember_tick": (0.50, 0.20, 8000, 8),
    "sfx_shutter": (0.60, 0.25, 0, 0), "sfx_tune": (0.55, 0.25, 0, 0),
    "sfx_ping": (0.65, 0.25, 0, 0), "sfx_wind_shift": (0.55, 0.25, 0, 0),
    "sfx_spray": (0.55, 0.20, 0, 0),
    "sfxloop_siren": (0.50, 0, 0, 0), "sfxloop_crackle": (0.35, 0, 0, 0),
    "sfxloop_drone_hum": (0.45, 0, 0, 0), "sfxloop_static": (0.30, 0, 0, 0),
    "sfxloop_wind": (0.22, 0, 0, 0), "sfxloop_cicada": (0.18, 0, 0, 0),
    "sfxloop_spray": (0.32, 0, 10000, 5), "sfxloop_torch": (0.34, 0, 0, 0),
    "sfxloop_rake": (0.28, 0, 10000, 5), "sfxloop_refill": (0.30, 0, 0, 0),
    # TTS barks (no de-hiss; tighter tails)
    "bark_embers": (0.65, 0.20, 0, 0), "bark_rally_reply": (0.65, 0.20, 0, 0),
    "ta_poh_call": (0.65, 0.25, 0, 0),
}

def load(mp3):
    raw = "/tmp/_gen2_tmp.wav"
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", "-c", "1", "-r", str(SR), mp3, raw], check=True)
    w = wave.open(raw)
    x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32767.0
    w.close()
    return x

def dehiss(x, f0, db_cut):
    n = len(x)
    sp = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    gain = np.ones_like(f)
    ramp = np.clip((f - f0) / max(1.0, 44100 / 2 - f0), 0, 1)
    gain = 10 ** (-db_cut * ramp / 20.0)
    return np.fft.irfft(sp * gain, n)

manifest = []
for name, (peak, tail_cap, hz, cut) in sorted(JOBS.items()):
    mp3 = os.path.join(GEN, name + ".mp3")
    if not os.path.isfile(mp3):
        print("MISSING", name)
        continue
    x = load(mp3)
    # trim: 5 ms lead, cap the tail after the last audible sample
    idx = np.where(np.abs(x) > 0.003)[0]
    if len(idx):
        lead = max(0, idx[0] - int(0.005 * SR))
        tail_end = idx[-1] + int(min(tail_cap if tail_cap else 0.25, 3.0) * SR)
        x = x[lead:min(len(x), tail_end)]
    if hz:
        x = dehiss(x, hz, cut)
    m = np.max(np.abs(x)) or 1.0
    x = np.clip(x * (peak / m), -1, 1)
    rel = int(0.008 * SR)
    x[-rel:] *= np.linspace(1, 0, rel)
    out = os.path.join(AUD, name + ".wav")
    w = wave.open(out, "w")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x * 32767).astype("<i2").tobytes())
    w.close()
    manifest.append({"file": name + ".wav", "duration_s": round(len(x) / SR, 3), "peak": peak,
                     "tail_cap": tail_cap, "dehiss": [hz, cut] if hz else None})
    print(f"{name:22s} {len(x)/SR:5.2f}s peak {peak}{' dehiss' if hz else ''}")

json.dump(manifest, open(os.path.join(GEN, "install_manifest.json"), "w"), indent=2)
print("installed", len(manifest), "files")
