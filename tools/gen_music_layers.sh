#!/usr/bin/env bash
# Generate the 3 game music layers via the ElevenLabs Music REST API directly
# (the MCP stdio server drops long-running music calls; curl is robust).
set -u
KEY="${ELEVENLABS_API_KEY:?need ELEVENLABS_API_KEY}"
OUT="/Users/lighthouse-control/Desktop/hill-blackmirror/artifacts/sfx_elevenlabs/gen"
STATUS="$OUT/music_status.txt"
: > "$STATUS"

gen() { # $1=name $2=prompt
  for ep in "https://api.elevenlabs.io/v1/music" "https://api.elevenlabs.io/v1/music/compose"; do
    code=$(curl -s -m 480 -o "$OUT/$1.mp3" -w "%{http_code}" -X POST "$ep" \
      -H "xi-api-key: $KEY" -H "Content-Type: application/json" \
      -d "$(python3 -c "import json,sys; print(json.dumps({'prompt': sys.argv[1], 'music_length_ms': 16000, 'force_instrumental': True}))" "$2")")
    echo "$1 $ep -> HTTP $code $(stat -f%z "$OUT/$1.mp3" 2>/dev/null || echo 0) bytes" >> "$STATUS"
    [ "$code" = "200" ] && return 0
  done
  return 1
}

gen music_l0 "gentle traditional Northern Thai highland music: khaen bamboo mouth organ soft drone with sparse bamboo harp phrases, calm meditative ambient, slow minimal, D minor pentatonic"
gen music_l1 "flowing traditional bamboo harp arpeggios, gentle Karen highland folk melody, light and airy, pentatonic, steady gentle rhythm, instrumental"
gen music_l2 "low ominous bamboo tube percussion heartbeat with a tense sustained drone, sparse, slowly rising tension, deep and dark, ritual, instrumental"
echo DONE >> "$STATUS"
