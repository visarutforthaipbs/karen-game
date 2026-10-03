# Audio production pipeline — Under Two Skies

## Current speech model

The owner approved the dry Toto narrator pilot and requested replacement of
every old-model game voice on 2026-10-03. The active replacement plans are
`voice_v4_th_plan.json` and `voice_v4_en_plan.json`: 38 clips per language,
including eight opening sentences and 30 dialogue/radio lines. They use
`eleven_v4`, stability 0.7, similarity 0.65, and the existing five speaker IDs.
Use this model/settings direction for future speech candidates. The earlier
v3 plans and raw takes are historical evidence; do not reinstall them over v4
delivery. Music, effects, coughs and existing radio filtering are separate.

The approved sample establishes the narrator direction, not an acting approval
for every newly generated take. Keep exact transcript/source binding, PCM peak
checks, runtime language/subtitle tests and listening review. ASR cannot certify
the absence of echo. The baseline backups are under
`artifacts/audio_voice_v4_20261003/before/`.

## Previous audio upgrade

The 2026-10-03 pass installs **62 new/replacement WAV files**: 30 spoken clips,
three character cough effects, and 29 effects/ambience/music files. The production
library now contains 89 WAVs (39.54 MB). Existing isolated v1.1 candidates remain
separate. Detailed delivery: `artifacts/audio_upgrade_20261003/DELIVERY.md`.

## Current playback contract

- `RadioVoice` is the unfiltered parent controlled by the existing speech slider.
  `RadioFilter` feeds it and filters broadcasts/positional ranger reports. Crew
  speech has dedicated 2D/3D players, priority and a four-second event cooldown.
  Urgent speech can interrupt lower-priority speech; stale warnings are dropped.
- `UI` and `Drones` feed `SFX`. User gain is distinct from drone occlusion. Zero
  slider values mute buses. Active speech ducks music.
- `stop_all_loops()` resets radio/static/siren state, stops speech/one-shots,
  invalidates delayed reports and clears per-actor footsteps. Title, hearth and
  checkpoint explicitly establish their own audio state.
- `music_states.tres` marks the new complete-track crossfade workflow. Files
  `sfxloop_music0/1/2.wav` are calm/work/deadline tracks, about 57 seconds each.
  Phases 1–2 use the work track; phase 3 uses deadline. Without the marker,
  the existing layered fallback remains available. Do not stack independent
  generated songs as musical stems.
- Footstep banks use `sfx_step_brush_1..4.wav` and `sfx_step_ash_1..4.wav`.
  Immediate repeats are avoided. Coughs use `sfx_cough_khanae/tapoh/munaw.wav`.
- `spot_fire_extinguished` is emitted by FireGrid only when a protected-border
  fire is actually caught in time. Its success line refers to the extinguished
  spot, not the safety of the entire forest.
- Main's listener follows the player's position and camera orientation, so
  camera zoom cannot move hearing away from the player. Canopy muffling uses
  the same `FireGrid.is_cover` rule as surveillance mechanics.
- All dynamically added menu buttons share focus/click hooks. Village upgrades
  and rations have selective work/grain foley; the hearth has a subtle fire bed.
  Checkpoint has a daytime bed; crackdown has truck foley; ending walkers use
  distance-based 2D footsteps because their scene lives in a separate viewport.

## Generation and review

`production_plan.json`, `voice_plan.json`, and `revision_plan.json` record exact
prompts, selected voices, filenames, processing targets and spending caps.
Credentials are read from the existing ElevenLabs MCP entry in
`~/.codex/config.toml`; keys never belong in these files.

Use the installed MCP Python environment (contains mcp and numpy):

```sh
/Users/lighthouse-control/.local/share/uv/tools/elevenlabs-mcp/bin/python tools/audio_pipeline/produce.py tools/audio_pipeline/production_plan.json
/Users/lighthouse-control/.local/share/uv/tools/elevenlabs-mcp/bin/python tools/audio_pipeline/produce.py tools/audio_pipeline/voice_plan.json
/Users/lighthouse-control/.local/share/uv/tools/elevenlabs-mcp/bin/python tools/audio_pipeline/review_speech.py tools/audio_pipeline/voice_plan.json
/Users/lighthouse-control/.local/share/uv/tools/elevenlabs-mcp/bin/python tools/audio_pipeline/install.py tools/audio_pipeline/production_plan.json --install
/Users/lighthouse-control/.local/share/uv/tools/elevenlabs-mcp/bin/python tools/audio_pipeline/install.py tools/audio_pipeline/voice_plan.json --install
```

The local official MCP package has obsolete five-second validation for SFX.
The producer uses the documented REST v2 sound-generation route for SFX and MCP
for speech/music. Speech recognition uses a per-process MCP base path limited
to this workspace; the persistent MCP config is not broadened.

The ledger records request status and output paths. Completed jobs are skipped.
Explicitly rejected calls may be retried with `--retry-failed`; ambiguous paid
calls remain uncertain. A valid existing output may be recovered without another
paid request. Do not erase ledgers to force regeneration. Use a new revision ID
with the original installation filename, as shown in `revision_plan.json`.

Subscription usage is cached briefly to avoid rate limits; individual observed
account deltas are **not per-file prices**. Read fresh account usage after a batch.
Spending caps use observed account usage and can lag the provider's accounting.

`review_speech.py` reads the plan's `language_code` (ISO 639-3, default `tha`)
and `max_cer` (maximum character error ratio, default `0.10`). English plans
use `"language_code": "eng", "max_cer": 0` for exact normalized wording.
Comparison uses Unicode NFC normalization, case folding and removal of
spaces/punctuation, preserving Thai marks and the existing Thai comparison.
The final 30 installed spoken clips have exact normalized transcript matches;
two revisions replaced a wording ambiguity and an overbroad fire-out claim.
ASR establishes wording, not acting, pronunciation, cultural fidelity or voice
identity. Native-speaker/headphone listening remains necessary for final polish.
The coughs are SFX, not voice clones of their dialogue actors.

Reviews resume from `speech_review.json`. Matching wording/language/source
decisions are retained, including individual listening overrides. New reviews
store the source SHA-256; legacy Thai reviews remain readable. Changed text,
language or a known source hash invalidates the old acceptance before another
call. Tightening `max_cer` rechecks the cached transcript without another call;
any mismatches need a fresh individual listening decision. Retain the expected
text, actual transcript and CER when setting `accepted` after listening, and
record the specific rationale in `manual_review`; do not broadly accept a batch.

Before decoding any clip, `install.py` validates every accepted speech decision
against the exact plan text, the plan language (`tha` when omitted), and the
SHA-256 of the raw file named in the ledger. These bindings are mandatory for
Thai and English alike. A stale or unbound acceptance raises a clear error
before any candidate, backup or production file changes, even if the affected
job is later in the batch. Rejected/unreviewed clips remain skipped.

Legacy Thai decisions without `language_code` or `source_sha256` can be viewed
and resumed by the reviewer, but cannot authorize a new installation. Explicitly
listen/review the current raw take and record its exact wording, language and
source hash with the individual decision, or retain the old evidence and obtain
a fresh review. Do not add hashes blindly: hashing today's file does not prove
that an older listening decision evaluated those same bytes. Existing installed
Thai assets do not need reinstalling solely to migrate historical reviews.

Provider errors, missing files and empty transcripts never pass. Errors and
interrupted pending reviews are resumable rejected entries; only an explicit
`--retry-errors` permits another ASR attempt. Completed decisions require no
MCP connection/configuration read. ASR attempts can cost credits; the local
tests below use fake recognizers and make no requests.

## Preparation, installation and rollback

`install.py` decodes to mono 44.1 kHz PCM16, removes DC, applies a low high-pass,
folds loop boundaries with a crossfade, and matches RMS with a -3.1 dBFS sample
peak cap. Excessive isolated loop transients receive smooth saturation before
RMS matching. One-shot fades preserve breaths and consonant tails. Music loops
use a three-second fold; this is boundary editing, not measured beat alignment.

Candidates are retained under `prepared/`; first overwritten bytes are backed
up under each batch's `backup/`. Original production files replaced by the first
pass are in the main batch or voices batch backup. Revision backups contain the
first new takes. Keep all of them. The final manifest resolves revisions to the
actual installed file and hash; do not use a superseded first-take hash.

English speech uses `"file": "en/<same_basename>.wav"` and installs into
`assets/audio/en/`, with equivalent nested candidate/backup directories. Parent
directories are created when needed. All plan filenames are validated before
preparation or installation: absolute paths, parent traversal, Windows-style
paths and symlinks escaping a destination are rejected. Thai filenames and
normalization/first-byte backup behavior remain unchanged.

For asset rollback, restore the original byte backups, remove newly added files
only after consulting the final manifest, remove the state marker when returning
to old layered music, and reimport with Godot. Runtime changes should be reviewed
separately: several touched scene files also contain unrelated visual work.

## Validation

```sh
python3 -m unittest discover -s tools/audio_pipeline/tests -v
godot --headless --editor --quit --path /Users/lighthouse-control/Desktop/hill-blackmirror
godot --headless --path /Users/lighthouse-control/Desktop/hill-blackmirror --fixed-fps 60 --script res://tests/test_audio_upgrade.gd
godot --headless --path /Users/lighthouse-control/Desktop/hill-blackmirror --fixed-fps 60 --script res://tests/test_all.gd
godot --headless --path /Users/lighthouse-control/Desktop/hill-blackmirror --fixed-fps 60 --quit-after 120
```

The audio regression suite checks transition reset, bus routing, speech priority,
protection from footstep stealing, cancellation of old delayed reports, music
state selection, footstep variation and authoritative extinguish feedback.
The full suite intentionally exercises corrupt-save parsing; those fixture
errors are expected. Test teardown drains stopped audio before engine shutdown.
Current v4 delivery and verification: [`VOICE_V4_HANDOFF.md`](VOICE_V4_HANDOFF.md).
