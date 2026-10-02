"""Generate the 3 game music layers via the ElevenLabs Music REST API.

The MCP stdio server drops long-running music calls, so this drives the same
API directly. Writes music_l0/l1/l2.mp3 into artifacts/sfx_elevenlabs/gen/.

Run: ELEVENLABS_API_KEY=... python3 tools/gen_music_layers.py
"""
import json, os, sys, time
import urllib.request

KEY = os.environ["ELEVENLABS_API_KEY"]
OUT = "artifacts/sfx_elevenlabs/gen"
STATUS = os.path.join(OUT, "music_status.txt")
ENDPOINTS = ["https://api.elevenlabs.io/v1/music", "https://api.elevenlabs.io/v1/music/compose"]

LAYERS = [
    ("music_l0", "gentle traditional Northern Thai highland music: khaen bamboo mouth organ soft drone with sparse bamboo harp phrases, calm meditative ambient, slow minimal, D minor pentatonic"),
    ("music_l1", "flowing traditional bamboo harp arpeggios, gentle Karen highland folk melody, light and airy, pentatonic, steady gentle rhythm, instrumental"),
    ("music_l2", "low ominous bamboo tube percussion heartbeat with a tense sustained drone, sparse, slowly rising tension, deep and dark, ritual, instrumental"),
]

def log(msg):
    with open(STATUS, "a") as f:
        f.write(msg + "\n")
    print(msg, flush=True)

def gen(name, prompt):
    body = json.dumps({"prompt": prompt, "music_length_ms": 16000, "force_instrumental": True}).encode()
    for ep in ENDPOINTS:
        req = urllib.request.Request(ep, data=body, method="POST", headers={
            "xi-api-key": KEY, "Content-Type": "application/json"})
        t0 = time.time()
        try:
            with urllib.request.urlopen(req, timeout=480) as r:
                data = r.read()
            if data[:3] == b"ID3" or data[:2] in (b"\xff\xfb", b"\xff\xf3", b"\xff\xf2"):
                open(os.path.join(OUT, name + ".mp3"), "wb").write(data)
                log(f"{name} {ep} -> OK {len(data)} bytes in {time.time()-t0:.0f}s")
                return True
            log(f"{name} {ep} -> 200 but not audio ({len(data)} bytes): {data[:120]!r}")
        except Exception as e:
            code = getattr(e, "code", None)
            body_txt = ""
            if hasattr(e, "read"):
                try:
                    body_txt = e.read()[:200].decode(errors="replace")
                except Exception:
                    pass
            log(f"{name} {ep} -> {code or 'ERR'} {body_txt}")
    return False

open(STATUS, "w").close()
ok = 0
for name, prompt in LAYERS:
    ok += gen(name, prompt)
log(f"DONE {ok}/3 layers")
