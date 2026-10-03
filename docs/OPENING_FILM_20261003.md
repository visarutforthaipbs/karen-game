# The Line on the Mountain — first-time opening

Implemented 2026-10-03 after the owner approved the revised concept. Local game
implementation and review assets; no installer publication is part of this pass.

## Player experience

The first **New Game** opens a roughly 63-second, in-engine low-poly introduction.
Ta-poh narrates in the selected Thai or English language. The language control
can change it during playback; only the current sentence restarts. Subtitles are
always visible. Pause, Skip and controller Back are available immediately.

Four scenes explain established-field rotation and fallow regrowth, community
food needs, bare-soil firebreaks and windborne embers, then hot coals and cooling
before the game's satellite scan. Actual shipped Meshy cast, S3 granary, vegetation,
T3 rake, Mu-naw's tank/wand/hose and V3 satellite are reused. No character meshes,
textures or rigs were regenerated. No GPU node or Meshy credits were required.

Completion **or Skip** persists `onboarding/intro_seen` in `settings.cfg`, separately
from campaign saves. New campaigns keep it. A replay button in How to play is
available through Title, preparation and Pause help. Replays do not change campaign
state. Existing Continue saves do not trigger the opening. Removing local settings
can make the introduction appear again; no account/cloud seen-state is promised.

The opening pauses the underlying scene and its audio, restores the prior pause,
audio and focus on close, and uses the player's speech/music/ambience/SFX buses.
Warm plucked music, mountain wind and distant cicadas accompany the film. The
satellite scan crossfades to a restrained pulse and reduces the natural ambience;
the warm bed returns for the closing goals. Rake, fire and spray sounds follow
the illustrated actions. Music drops 5 dB during speech, ambience 2 dB and work
sounds 3 dB, with smooth fades and a gentle rise between sentences. The existing
ElevenLabs instrumental/effect sources are reused; no new generation or voice
processing was added. The score is a game underscore inspired by rural textures,
not a claimed authentic traditional performance. Looping uses private copies of
existing audio resources. All layers pause and release together.
Scene teardown before completion restores everything without falsely marking it
seen. New Game proceeds to preparation after the film without another compulsory
full rules card. Full Help, HUD goals/tool hints and first-burn contextual tips
remain available, including after Skip. The film does not replace those controls
instructions or change burn balance, water, fire simulation or surveillance.

## Script and teaching decisions

Canonical bilingual script: `localization/opening.json`. Narration minimum timing
and each installed recording length determine cue duration; speech is never cut
to force an arbitrary one-minute limit. Current v4 durations: Thai 63.3 s; English
63.6 s, followed by a user-dismissed recap of cooled ash ≥75%, zero hot spots and
the 20:00 game deadline. The review video holds that recap for four seconds.

- Fallow is described as several years; seven years is not declared universal.
- Ash returns **some** nutrients; sunlight is not described as a mineral source.
- The boundary is cleared to exposed soil without prescribing digging to hardpan
  (`ดินดาน`) or a universally safe metre width.
- A firebreak interrupts fuel; airborne embers can cross it. No guarantee that
  forest fire is impossible is made.
- The exact 20:00 pass is explicitly an **in-game** rule. Satellite heat detection
  cannot infer people's purpose. The sequence is an illustrative game diagram,
  not a real satellite product or prescribed field-burning procedure.
- Four characters retain the approved identities: ขะแน, ตาโพ, มูนอ, แม่ลู.

Research informing the revision:

- [Northern Thailand field study](https://www.frontiersin.org/journals/environmental-science/articles/10.3389/fenvs.2023.1117427/full): multiple fallow durations and differing post-fire changes in nutrients, carbon and nitrogen.
- [US Forest Service fireline definition](https://www.fs.usda.gov/rm/pubs/rmrs_rp009.pdf): litter/organic fuel removed to expose mineral soil.
- [NASA FIRMS](https://firms.modaps.eosdis.nasa.gov/map2/): active fires/thermal anomalies require contextual interpretation.

These support technical wording, not a cultural endorsement. Pgakenyaw/community
review, native listening for acting/pronunciation and fresh-player comprehension
testing remain human review items. There is no claim of lip synchronization or
new facial animation; the accepted gameplay rigs provide the movement.

## Narration evidence

ElevenLabs `eleven_v4`, same Ta-poh voice as current dialogue
(`RJIgSLB4fDJZtYZRUxqo`). Eight clips per language. Existing voices were reused;
no voice cloning or new music generation. `tools/onboarding/installed_voices.json`
binds final wording, plan, raw take, ASR review, duration and installed WAV hash.
All sixteen installed clips have exact normalized Scribe transcripts (CER 0).
Normalization ignores punctuation/spaces/case, preserving Thai marks. ASR checks
wording, not acting or pronunciation. Rejected takes and ledgers are retained.

Owner listening review rejected the original Thai narrator's echo, then approved
the replacement pilot and requested upgrading every old-model game voice.
`tools/onboarding/voice_th_dry_pilot.json` establishes the same Toto voice with
Eleven v4, stability 0.7 and similarity 0.65. These settings now supply the
sixteen installed opening recordings as part of the 76-clip v4 delivery. Game
narration uses the dry RadioVoice bus; no echo or reverb effect is added to it.
Individual take acting/pronunciation review remains distinct from ASR.
Pilot wording passed exact Scribe comparison (CER 0); its measured WAV is at
`artifacts/opening_20261003/audio_th_dry_pilot/prepared/opening/th/dry_pilot.wav`.
The original first two sentences, without the game mix, are retained at
`artifacts/opening_20261003/thai_original_voice_only.wav` for comparison.

Plans `voice_th/en.json` and their numbered revisions preserve the old generation
history. Current plans are `tools/audio_pipeline/voice_v4_th/en_plan.json` and
their selected revision delivery plans. Only accepted takes were installed.
Do not reinstall a superseded plan over the final recordings. Read the resolved
manifest for current provenance. Credentials never appear in plans or this doc.

## Review and reproduction

```sh
godot --headless --editor --quit --path .
python3 tools/localization/validate_catalog.py
godot --headless --path . --script res://tests/test_opening.gd
godot --headless --path . --script res://tests/test_localized_ui.gd
godot --headless --path . --script res://tests/test_ui_navigation.gd
godot --headless --path . --script res://tests/test_menu_ux.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_all.gd
godot --path . --script res://tools/onboarding/review_opening.gd
godot --path . --script res://tools/onboarding/play_opening.gd
# English standalone review: append -- --en
```

Visual evidence: `artifacts/opening_20261003/review/` (native 1280×720 Thai/English
states and compact recap). Earlier `opening_th.mp4`/`opening_en.mp4` review exports
contain narration but were cropped by desktop window tiling, omitting controls
and subtitles; they are not final presentation videos. The standalone movie
tool now fixes the review window size; `complete_probe.avi` confirms that its
capture includes captions and controls. The v4 voice delivery previews are
`artifacts/audio_voice_v4_20261003/opening_th_v4.mp4` (67.33 s) and
`opening_en_v4.mp4` (67.67 s), with four-second recaps and approved-model audio.
The current background mix previews are
`artifacts/opening_background_20261003/opening_th.mp4` and `opening_en.mp4`.
All show the full player interface and are native engine renders, not
AI-generated videos. Current validation: 92 opening checks, 20 audio regression
checks and the required 120-frame production smoke pass. All 76 installed voice
hashes and 68 existing non-speech WAVs remain unchanged in this mix pass.
Standalone capture/playback uses isolated settings and does not mark the owner's
profile seen. Regression covers first New Game, Skip, subsequent New Game, profile
reload, replay isolation, nested pause/focus, narration timing, language switching
while paused, and Thai/English captions/controls down to an 800×450 logical canvas.

## Fresh-player acceptance

Before declaring onboarding understood, observe new players without explaining
it yourself. They should explain why fields rest, why combustible litter is
cleared, why embers can cross, and why flames being out is not enough. Then watch
them clear a boundary and cool embers in the first burn. Technical passes and a
polished film do not establish learning effectiveness.
