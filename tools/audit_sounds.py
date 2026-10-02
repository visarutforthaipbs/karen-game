"""Full SFX audit: measure every installed sound + map coverage vs game triggers.

For each assets/audio/*.wav: duration, peak/RMS/crest (dBFS), leading/trailing
silence, loop-point discontinuity (loops only), spectral centroid & HF ratio.
Flags anything outside the mix targets or with a bad loop seam.

Run: ~/.hermes/hermes-agent/venv/bin/python tools/audit_sounds.py
"""
import glob, os, wave

import numpy as np

AUD = "assets/audio"
SR = 44100

def load(path):
    w = wave.open(path)
    x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32767.0
    w.close()
    return x

def db(v):
    return 20 * np.log10(max(v, 1e-6))

def silence_edges(x, thresh=0.01):
    a = np.where(np.abs(x) > thresh)[0]
    if not len(a):
        return len(x) / SR, len(x) / SR
    return a[0] / SR, (len(x) - 1 - a[-1]) / SR

def loop_seam(x):
    """Energy of the sample jump at the loop boundary vs clip peak."""
    return abs(x[0] - x[-1]) / (np.max(np.abs(x)) or 1)

def centroid_hf(x):
    n = min(len(x), SR * 6)
    sp = np.abs(np.fft.rfft(x[:n] * np.hanning(n)))
    f = np.fft.rfftfreq(n, 1 / SR)
    c = float(np.sum(f * sp) / (np.sum(sp) or 1))
    hf = float(np.sum(sp[f > 8000]) / (np.sum(sp) or 1))
    return c, hf

# one-shot cache keys in the game -> which have a recorded override
SYNTH_KEYS = {  # keys that still fall back to synthesis
    "spray": "companion douse bursts", "gust": "orphaned? (wind shift now uses wind_shift)",
    "tapoh_call": "fallback only", "ui_focus": "gamepad focus tick",
    "wind_shift": "wind-turn whoosh", "bark_embers": "MISSING bark",
    "bark_rally_reply": "MISSING bark", "bark_cough": "MISSING bark",
}

print(f"{'file':26s} {'dur':>5s} {'peak':>6s} {'rms':>6s} {'crest':>5s} {'lead':>5s} {'tail':>5s} {'seam':>5s} {'cent':>6s} {'hf':>5s}  flags")
rows = []
for p in sorted(glob.glob(os.path.join(AUD, "*.wav"))):
    name = os.path.basename(p)
    x = load(p)
    dur = len(x) / SR
    peak, rms = float(np.max(np.abs(x))), float(np.sqrt(np.mean(x ** 2)))
    lead, tail = silence_edges(x)
    seam = loop_seam(x) if name.startswith("sfxloop_") else 0.0
    cent, hf = centroid_hf(x)
    flags = []
    if peak > 0.85:
        flags.append("HOT")
    if lead > 0.15:
        flags.append("lead-silence")
    if tail > 0.25 and not name.startswith("sfxloop_"):
        flags.append("dead-tail")
    if name.startswith("sfxloop_") and seam > 0.25:
        flags.append("LOOP-SEAM")
    if hf > 0.45:
        flags.append("hissy")
    if rms < 0.02 and peak < 0.2:
        flags.append("quiet?")
    print(f"{name:26s} {dur:5.2f} {db(peak):6.1f} {db(rms):6.1f} {db(peak)-db(rms):5.1f} "
          f"{lead:5.2f} {tail:5.2f} {seam:5.2f} {cent:6.0f} {hf:5.2f}  {','.join(flags)}")
    rows.append((name, dur, peak, rms, flags))

print("\n--- coverage: keys still synthesized ---")
have = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(AUD, "sfx_*.wav"))}
for key, why in sorted(SYNTH_KEYS.items()):
    status = "HAS override" if f"sfx_{key}" in have else "synth"
    print(f"{key:18s} {status:12s} {why}")

print("\n--- unused / extra files ---")
used_prefixes = ("sfx_", "sfxloop_", "tapoh_wind_warning", "radio_ch", "ta_poh_call", "bark_")
for p in sorted(glob.glob(os.path.join(AUD, "*.wav"))):
    name = os.path.basename(p)
    if not name.startswith(used_prefixes):
        print("unrecognised:", name)
    if name == "sfx_whistle_alt.wav":
        print("alternate, not wired:", name)
