"""Build game-ready stingers from a generated Tena-harp pluck sample.

Pitch-shifts one recorded pluck to the game's D-minor pentatonic scale and
assembles the stinger cues with the same note sequences/timings as
AudioManager's synthesized recipes. Also installs the radio-tune and
satellite-ping takes. Writes into assets/audio/ as sfx_<key>.wav drop-ins.

Run: ~/.hermes/hermes-agent/venv/bin/python tools/build_stingers.py
"""
import glob, json, os, struct, subprocess, wave

import numpy as np
from fractions import Fraction

GEN = "artifacts/sfx_elevenlabs/gen"
AUD = "assets/audio"
SR = 44100

def mp3_to_array(mp3):
    raw = "/tmp/_sting_tmp.wav"
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", "-c", "1", "-r", str(SR), mp3, raw], check=True)
    w = wave.open(raw)
    n = w.getnframes()
    x = np.frombuffer(w.readframes(n), dtype="<i2").astype(np.float64) / 32767.0
    w.close()
    return x

def write_wav(path, x, peak):
    m = np.max(np.abs(x)) or 1.0
    x = np.clip(x * (peak / m), -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    w = wave.open(path, "w")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes(data)
    w.close()
    return np.max(np.abs(x))

def trim(x, thresh=0.01):
    idx = np.where(np.abs(x) > thresh)[0]
    return x[idx[0]:idx[-1] + 1] if len(idx) else x

def f0_estimate(x):
    """Autocorrelation pitch of the loudest 40 ms window."""
    w = int(0.04 * SR)
    s = int(np.argmax(np.abs(x)))
    seg = x[s:s + w] if s + w < len(x) else x[-w:]
    seg = seg - seg.mean()
    ac = np.correlate(seg, seg, "full")[len(seg) - 1:]
    lo, hi = int(SR / 900), int(SR / 120)  # 120..900 Hz
    return SR / (lo + int(np.argmax(ac[lo:hi])))

def pitch_shift(x, ratio):
    """Resample by ratio (>1 raises pitch)."""
    n_out = max(2, int(len(x) / ratio))
    t_out = np.linspace(0, len(x) - 1, n_out)
    return np.interp(t_out, np.arange(len(x)), x)

def mix_into(buf, clip, at):
    end = min(len(buf), at + len(clip))
    if end > at:
        buf[at:end] += clip[:end - at]

# ---- build stingers from the harp pluck ------------------------------------
pluck = trim(mp3_to_array(os.path.join("artifacts/sfx_elevenlabs/gen2", "pluck_harp.mp3")), thresh=0.003)
base_f = f0_estimate(pluck)
print(f"harp pluck: {len(pluck)/SR:.2f}s, base F0 ≈ {base_f:.1f} Hz")

# cache pitch-shifted notes; the raw pluck decays fast, so give each note the
# same ring-out the synthesized recipes had (exponential release)
notes = {}
def note(freq, ring):
    key = (round(freq, 2), ring)
    if key not in notes:
        y = pitch_shift(pluck, freq / base_f)
        n = int(ring * SR)
        if len(y) < n:
            y = np.pad(y, (0, n - len(y)))
        y = y[:n] * np.exp(-np.arange(n) / (ring * SR / 3.5))
        rel = int(0.02 * SR)
        y[-rel:] *= np.linspace(1, 0, rel)
        notes[key] = y
    return notes[key]

def build(name, seq, times, amps, total, peak, ring=1.2, harsh_tail=False):
    buf = np.zeros(int(total * SR))
    for f, t, a in zip(seq, times, amps):
        mix_into(buf, note(f, ring) * a, int(t * SR))
    if harsh_tail:
        n = int(1.2 * SR)
        tt = np.arange(n) / SR
        tail = np.sign(np.sin(2 * np.pi * 180 * tt)) * np.exp(-tt * 3.0) * 0.12
        mix_into(buf, tail, 0)
    got = write_wav(os.path.join(AUD, name), buf, peak)
    report.append((name, "harp-pluck", total, round(float(got), 3), 0))

SCALE = [293.66, 349.23, 392.0, 440.0, 587.33, 698.46]
# phase stingers: sequences from AudioManager._phase_stinger
for idx in range(1, 5):
    seq = [[2, 4], [1, 3, 5], [4, 5], [3, 5, 3], [0, 2, 4]][min(idx, 4)]
    freqs = [SCALE[i] for i in seq]
    times = [k * 0.22 for k in range(len(seq))]
    build(f"sfx_sting_{idx}.wav", freqs, times, [0.5] * len(seq), 1.6, 0.6)
# day start: low root + rising run (AudioManager._day_start_stinger)
S7 = [293.66, 349.23, 392.0, 440.0, 587.33, 698.46, 783.99]
build("sfx_day_start.wav", [146.83] + S7[1:6], [0.0] + [k * 0.18 for k in range(5)],
      [0.5] + [0.42] * 5, 2.4, 0.6, ring=1.8)
# endings
build("sfx_end_famine.wav", [146.83, 138.59, 116.54], [0.0, 0.5, 1.0], [0.55] * 3, 2.6, 0.62, ring=1.8)
build("sfx_end_crackdown.wav", [110.0, 103.83, 98.0], [0.0, 0.5, 1.0], [0.55] * 3, 2.6, 0.62, ring=1.8, harsh_tail=True)
# harvest chime
build("sfx_chime.wav", [293.66, 349.23, 392.0, 440.0, 587.33], [k * 0.18 for k in range(5)],
      [0.5] * 5, 2.2, 0.6, ring=1.6)

print(f"{'file':24s} {'src':26s} {'dur':>5s} {'peak':>5s} {'tail':>5s}")
for name, src, dur, peak, tail in report:
    print(f"{name:24s} {src:26s} {dur:5.2f} {peak:5.2f} {tail:5.2f}")
