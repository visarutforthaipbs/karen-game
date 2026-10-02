"""Regenerate the full SFX set under the paid ElevenLabs plan (commercial-safe)
and install with the audit fixes baked in: silence trims, de-hiss, loudness
targets. Prompts are the reviewed ones from the original batch.

Run: ELEVENLABS_API_KEY=... python3 tools/regen_sfx_starter.py
"""
import json, os, subprocess, time, wave
import urllib.request

KEY = os.environ["ELEVENLABS_API_KEY"]
GEN = "artifacts/sfx_elevenlabs/gen2"
AUD = "assets/audio"
os.makedirs(GEN, exist_ok=True)
STATUS = os.path.join(GEN, "regen_status.txt")

# name, prompt, seconds, loop, target_peak, tail_cap_s, dehisse_hz (0=off), dehisse_db
JOBS = [
    ("sfx_beep", "soft gentle rounded confirmation ding, quiet single tone, smooth and warm, not harsh or electronic-sounding", 0.5, False, 0.60, 0.25, 0, 0),
    ("sfx_camera", "short urgent two-tone electronic alarm chirp, clean digital surveillance camera alert, compact, not distorted", 0.7, False, 0.55, 0.25, 0, 0),
    ("sfx_cough", "a man coughing twice, dry hacking cough, close microphone, no speech, no words", 1.5, False, 0.55, 0.20, 0, 0),
    ("sfx_step_brush", "single footstep crunching on dry grass and small twigs, light boot, outdoor hillside, one step", 0.5, False, 0.55, 0.20, 0, 0),
    ("sfx_step_ash", "single soft footstep on loose grey wood ash, dull muffled thud with a faint fine sizzle, one step", 0.5, False, 0.45, 0.20, 0, 0),
    ("sfx_pop", "green bamboo stalk bursting open with a sharp steam-explosion crack, wet woody snap, single pop", 0.7, False, 0.70, 0.25, 0, 0),
    ("sfx_thunder", "distant thunder rumble rolling across a mountain valley, low and long, no rain", 4.0, False, 0.70, 0.30, 0, 0),
    ("sfx_ui_click", "tiny soft wooden user interface click, short round knock on hollow wood, quiet", 0.5, False, 0.50, 0.25, 0, 0),
    ("sfx_tool_clack", "small wooden tool handle clack, two pieces of hardwood tapping together once", 0.5, False, 0.55, 0.05, 0, 0),
    ("sfx_ember_tick", "tiny hot ember landing on dry ground and sizzling out, faint sharp crackle tick", 0.5, False, 0.50, 0.20, 8000, 8),
    ("sfx_shutter", "small quadcopter camera shutter click with a faint quick servo whir, mechanical", 0.5, False, 0.60, 0.25, 0, 0),
    ("sfx_tune", "tuning an old transistor radio, brief static sweep passing a faint station fragment, ending in soft static", 0.7, False, 0.55, 0.25, 0, 0),
    ("sfx_ping", "single clean satellite sonar ping, deep pure tone with a long smooth decay tail, precise, like a submarine sonar ping", 1.0, False, 0.65, 0.25, 0, 0),
    ("sfx_wind_shift", "gust of valley wind swelling through dry bamboo, rising then fading", 1.2, False, 0.55, 0.25, 0, 0),
    ("sfx_spray", "short burst of pressurized water spraying from a brass nozzle", 0.5, False, 0.55, 0.20, 0, 0),
    ("sfxloop_siren", "eerie distant siren wail, slow rising and falling tone, ominous warning, clean, seamless loop", 3.0, True, 0.50, 0, 0, 0),
    ("sfxloop_crackle", "campfire crackle and small pops, dry brush and twigs burning steadily, seamless loop", 3.0, True, 0.35, 0, 0, 0),
    ("sfxloop_drone_hum", "quadcopter drone hovering steadily, four propellers humming, mid distance, seamless loop", 2.0, True, 0.45, 0, 0, 0),
    ("sfxloop_static", "am radio static hiss with faint carrier hum, empty frequency, seamless loop", 2.0, True, 0.30, 0, 0, 0),
    ("sfxloop_wind", "gentle valley wind blowing through open mountain air and distant trees, calm outdoor ambience, seamless loop", 4.0, True, 0.22, 0, 0, 0),
    ("sfxloop_cicada", "cicada chorus on a hot afternoon in a forest, shimmering insect drone, seamless loop", 3.0, True, 0.18, 0, 0, 0),
    ("sfxloop_spray", "pressurized water spraying from a brass nozzle in a steady hiss, continuous spray, seamless loop", 2.0, True, 0.32, 0, 10000, 5),
    ("sfxloop_torch", "drip torch flame burning with a soft roaring whoosh, small steady fire, seamless loop", 2.0, True, 0.34, 0, 0, 0),
    ("sfxloop_rake", "raking dry brush and twigs off bare soil, rhythmic earthy scraping strokes, seamless loop", 2.0, True, 0.28, 0, 10000, 5),
    ("sfxloop_refill", "water gurgling and bubbling into a tank through a bamboo tube, pouring fill, seamless loop", 2.0, True, 0.30, 0, 0, 0),
    ("pluck_harp", "single warm note plucked on a bamboo harp, wooden and mellow, one clean pluck with natural decay, no words", 1.0, False, 0.65, 0.30, 0, 0),
]

def log(m):
    with open(STATUS, "a") as f:
        f.write(m + "\n")
    print(m, flush=True)

def generate(name, prompt, secs, loop):
    body = json.dumps({"text": prompt, "duration_seconds": secs, "loop": loop}).encode()
    req = urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation",
        data=body, method="POST", headers={"xi-api-key": KEY, "Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=300) as r:
        data = r.read()
    open(os.path.join(GEN, name + ".mp3"), "wb").write(data)
    log(f"{name}: {len(data)} bytes in {time.time()-t0:.0f}s")

open(STATUS, "w").close()
for name, prompt, secs, loop, *_ in JOBS:
    for attempt in (1, 2):
        try:
            generate(name, prompt, secs, loop)
            break
        except Exception as e:
            log(f"{name} attempt {attempt}: {e}")
            time.sleep(3)
log("GENERATION DONE")
