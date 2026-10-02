#!/usr/bin/env bash
# Generate Thai voice lines for Under Two Skies via OmniVoice-Thai on lighthouse-gpu01.
# Same engine as the stickman-reel project (Pop voice clone, lexicon respellings,
# best-of-N takes with Whisper QC, 24 kHz wavs).
#
#   ./tools/tts/gen_game_voices.sh request.json [out_dir]
#
# request.json: {"lines": ["...", ...], "seed": 42, "takes": 3}
# out_dir:      line_01.wav ... + result.json (text, spoken, CER, char timings)
#
# Install: rename wavs into assets/audio/ using the drop-in convention:
#   tapoh_wind_warning.wav / _2.wav / ...   Ta-poh wind warnings
#   radio_ch1_NN.wav                        FM 88.5 forestry / ranger chatter
#   radio_ch2_NN.wav                        FM 94.2 hill weather forecast
# then run `godot --headless --editor --quit --path .` to import.
# Keep the manifest + QC with the batch (artifacts/tts_batch/) for provenance.
set -euo pipefail

REQ="${1:?usage: gen_game_voices.sh request.json [out_dir]}"
OUT="${2:-artifacts/tts_batch/out}"
WORK="~/stickman-tts/game"

ssh gpu "mkdir -p $WORK"
scp -q "$REQ" "gpu:$WORK/req.json"
ssh gpu "cd $WORK && ~/laos-reel-tts/env/bin/python ~/stickman-tts/stickman_tts.py req.json out/ 2>&1 | tail -3"
mkdir -p "$OUT"
scp -q -r "gpu:$WORK/out/." "$OUT/"
echo "wavs + result.json -> $OUT"
