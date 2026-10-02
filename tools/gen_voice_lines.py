"""Replace the OmniVoice radio/Ta-poh voice lines with ElevenLabs eleven_v3 Thai.

Same filenames as the drop-in convention expects (tapoh_wind_warning*.wav,
radio_ch1_*.wav, radio_ch2_*.wav), so the game needs no changes. Texts come
from artifacts/tts_batch/request.json (the reviewed line set).

Run: ELEVENLABS_API_KEY=... python3 tools/gen_voice_lines.py
"""
import json, os, subprocess, time, urllib.request
import numpy as np
import wave

KEY = os.environ["ELEVENLABS_API_KEY"]
OUT = "artifacts/sfx_elevenlabs/gen_voices"
AUD = "assets/audio"
SR = 44100
os.makedirs(OUT, exist_ok=True)

LINES = json.load(open("artifacts/tts_batch/request.json"))["lines"]
# voice ids: Bill (wise elder), Daniel (steady broadcaster), Sarah (reassuring)
TAPOH = "pqHfZKP75CvOlQylNhV4"
RANGER = "onwK4e9ZLuTAKqWW03F9"
WEATHER = "EXAVITQu4vr4xnSDxMaL"

PLAN = []
for i, text in enumerate(LINES):
    if i < 3:
        PLAN.append((f"tapoh_wind_warning{'' if i == 0 else '_' + str(i + 1)}.wav", TAPOH, text, 0.50, 0.4))
    elif i < 11:
        PLAN.append((f"radio_ch1_{i - 2:02d}.wav", RANGER, text, 0.45, 0.55))
    else:
        PLAN.append((f"radio_ch2_{i - 10:02d}.wav", WEATHER, text, 0.45, 0.55))

def log(m):
    print(m, flush=True)

def tts(voice_id, text, stability, style):
    body = json.dumps({
        "text": text, "model_id": "eleven_v3", "language_code": "th",
        "voice_settings": {"stability": stability, "similarity_boost": 0.75,
                           "style": style, "use_speaker_boost": True},
    }).encode()
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}",
        data=body, method="POST", headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()

def install(mp3_bytes, out_name, peak, tail_cap):
    raw = os.path.join(OUT, out_name + ".src.mp3")
    open(raw, "wb").write(mp3_bytes)
    wavp = os.path.join(OUT, out_name + ".src.wav")
    subprocess.run(["afconvert", "-f", "WAVE", "-d", "LEI16", "-c", "1", "-r", str(SR), raw, wavp], check=True)
    w = wave.open(wavp)
    x = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32767.0
    w.close()
    idx = np.where(np.abs(x) > 0.003)[0]
    if len(idx):
        lead = max(0, idx[0] - int(0.06 * SR))  # keep ~60 ms lead like the old set
        tail = idx[-1] + int(tail_cap * SR)
        x = x[lead:min(len(x), tail)]
    m = np.max(np.abs(x)) or 1.0
    x = np.clip(x * (peak / m), -1, 1)
    rel = int(0.008 * SR)
    x[-rel:] *= np.linspace(1, 0, rel)
    w = wave.open(os.path.join(AUD, out_name), "w")
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((x * 32767).astype("<i2").tobytes())
    w.close()
    log(f"{out_name:26s} {len(x)/SR:5.2f}s peak {peak}")

for out_name, voice, text, stability, style in PLAN:
    for attempt in (1, 2, 3):
        try:
            data = tts(voice, text, stability, style)
            install(data, out_name, 0.75, 0.15)
            break
        except Exception as e:
            body_txt = e.read()[:150].decode(errors="replace") if hasattr(e, "read") else ""
            log(f"{out_name} attempt {attempt}: {e} {body_txt}")
            time.sleep(3)
log("VOICE LINES DONE")
