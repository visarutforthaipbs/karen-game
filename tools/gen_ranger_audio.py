"""Ranger pack audio: radio squelch SFX + ranger report lines + Mae-Lu lines."""
import json, os, time
import urllib.request

KEY = os.environ["ELEVENLABS_API_KEY"]
OUT = "artifacts/sfx_elevenlabs/gen2"
os.makedirs(OUT, exist_ok=True)

DANIEL = "onwK4e9ZLuTAKqWW03F9"  # Steady Broadcaster -> ranger radio
BELLA = "hpp4J3VqNfWAUOO0d1Us"   # Professional, Bright, Warm -> Mae-Lu

TTS = [
    ("bark_report_flame", DANIEL, "ศูนย์ครับ พบเปลวไฟในแปลงเพาะปลูก บันทึกพิกัดแล้ว"),
    ("bark_report_crew", DANIEL, "ศูนย์ครับ พบชาวบ้านอยู่ข้างกองไฟ ขอดำเนินการ"),
    ("bark_maelu_1", BELLA, "ข้าวในยุ้งยังพอเลี้ยงคนทั้งหมู่บ้านได้ถึงหน้าฝน"),
    ("bark_maelu_2", BELLA, "ปีนี้หนักหน่อยนะลูก แต่เราเคยผ่านอะไรอย่างนี้มาแล้ว"),
]

SFX = [
    ("sfx_squelch", "walkie talkie squelch burst followed by a short roger beep, handheld two-way radio, brief", 0.6),
]

def log(m):
    print(m, flush=True)

for name, voice, text in TTS:
    body = json.dumps({"text": text, "model_id": "eleven_v3", "language_code": "th",
                       "voice_settings": {"stability": 0.5, "similarity_boost": 0.75,
                                          "style": 0.35, "use_speaker_boost": True}}).encode()
    req = urllib.request.Request(f"https://api.elevenlabs.io/v1/text-to-speech/{voice}",
        data=body, method="POST", headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    for attempt in (1, 2, 3):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                open(os.path.join(OUT, name + ".mp3"), "wb").write(r.read())
            log(f"{name}: OK")
            break
        except Exception as e:
            log(f"{name} attempt {attempt}: {e}")
            time.sleep(3)

for name, prompt, secs in SFX:
    body = json.dumps({"text": prompt, "duration_seconds": secs, "loop": False}).encode()
    req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation",
        data=body, method="POST", headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    for attempt in (1, 2, 3):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                open(os.path.join(OUT, name + ".mp3"), "wb").write(r.read())
            log(f"{name}: OK")
            break
        except Exception as e:
            log(f"{name} attempt {attempt}: {e}")
            time.sleep(3)
log("RANGER PACK DONE")
