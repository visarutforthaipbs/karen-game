"""Generate the 3 crew barks via ElevenLabs TTS (eleven_v3, Thai) over REST."""
import json, os, time
import urllib.request

KEY = os.environ["ELEVENLABS_API_KEY"]
OUT = "artifacts/sfx_elevenlabs/gen2"
os.makedirs(OUT, exist_ok=True)

BARKS = [
    ("bark_embers", "SOYHLrjzK2X1ezoPC6cr", "[shouts urgently] ลูกไฟ!"),          # Harry - Fierce Warrior
    ("bark_rally_reply", "TX3LPaxmHKxFdv7VOQHJ", "[shouts] มาแล้ว!"),            # Liam - Energetic
    ("ta_poh_call", "pqHfZKP75CvOlQylNhV4", "[shouts, drawn out and urgent] โอ๊ย!"),  # Bill - Wise elder
]

for name, voice_id, text in BARKS:
    body = json.dumps({
        "text": text,
        "model_id": "eleven_v3",
        "language_code": "th",
        "voice_settings": {"stability": 0.4, "similarity_boost": 0.75, "style": 0.6, "use_speaker_boost": True},
    }).encode()
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}",
        data=body, method="POST", headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            data = r.read()
        open(os.path.join(OUT, name + ".mp3"), "wb").write(data)
        print(f"{name}: {len(data)} bytes in {time.time()-t0:.0f}s")
    except Exception as e:
        body_txt = e.read()[:300].decode(errors="replace") if hasattr(e, "read") else ""
        print(f"{name}: FAILED {e} {body_txt}")
