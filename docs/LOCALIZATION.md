# Thai / English game localization

Implemented 2026-10-03 at the owner's request for Steam preparation.

Players can choose English or ไทย at the top of Settings, from the title, village
or paused gameplay. The choice applies to already-open menus, HUD messages,
reports and captions immediately and is saved in `settings.cfg` under
`[accessibility] locale`. Existing installations default to Thai. The title's
bilingual Settings label makes the switch discoverable to English readers.

## Coverage and identity

The catalog covers title/load errors, the guide and first-burn tips, controls,
HUD/tools/breath/water/wind, companion status, surveillance alerts and satellite
reports, village preparation, radio forecasts, rations/mutual aid/upgrades,
harvest, checkpoints, ending captions, run records, settings and online-board
privacy text. Existing Kanit and Chakra Petch fonts support both languages;
font licenses remain bundled. Fire rules, balances, animation, timers and campaign
state are unchanged.

The selected language now chooses Thai or English spoken recordings as well as
text. English uses the same five ElevenLabs voice identities as the Thai cast,
covering all 30 current spoken clips. Switching immediately stops an old-language
line and clears its caption, including while paused; the next event uses the new
language. Music, ambience, coughs and work sounds are preserved. A missing English
clip falls back individually to its Thai counterpart.

The owner-approved v4 upgrade now replaces both Thai and English recordings,
preserving all five speakers and the existing transcripts. See
[`VOICE_V4_HANDOFF.md`](../tools/audio_pipeline/VOICE_V4_HANDOFF.md).
`voice_subtitles.json`
maps all 30 installed spoken clips to their production transcript and English
translation. AudioManager publishes the exact accepted clip, not a generic line
for the event. Captions clear on interruption, scene audio reset, playback stop
or completion; skipped/rate-limited speech does not create a caption. Forecast
radio text and actual spoken captions are separate.

Player-entered names, campaign identities and saved gameplay enums remain
unchanged. English is display text; it is never a replacement save format.

## Authoring convention

`localization/messages.json` holds stable review IDs and Thai/English pairs.
Keep IDs when editing a translation; do not regenerate or renumber the catalog.
Native Godot Controls retain canonical Thai source text and translate on draw,
so an already-open UI switches without reloading its scene.

Static Control text can use the original Thai directly. For formatted text use
`L10n.format(template, arguments)`; for composed sentences/reports use
`L10n.join(parts, separator)` or `L10n.concat(parts)`. These register the complete
rendered Thai sentence and its English counterpart before returning the Thai
source. This also handles nested forecasts and reports after a live switch.
Use `translate_args=false` for leaderboard formats containing player-entered
names. Name inputs explicitly disable automatic translation.

Runtime translations are retained for already-open/cached messages. Identical
registration is skipped. The source catalog is loaded once. Both catalogs are
explicitly included in all three export presets, since JSON read with FileAccess
is not automatically an imported Godot translation resource.

## Validation

Run from the game root:

```sh
python3 tools/localization/validate_catalog.py
godot --headless --editor --quit --path .
godot --headless --path . --fixed-fps 60 --script res://tests/test_localization.gd
godot --headless --path . --script res://tests/test_localized_gameplay.gd
godot --headless --path . --script res://tests/test_localized_ui.gd
godot --headless --path . --script res://tests/test_voice_subtitles.gd
godot --headless --path . --script res://tests/test_voice_locales.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_all.gd
godot --headless --path . --fixed-fps 60 --quit-after 120
```

The voice test must use normal wall time: `--fixed-fps` accelerates game timers
but does not accelerate audio playback. Tests use separate settings/save folders.
The main suite intentionally feeds malformed save JSON to test recovery, so those
negative fixtures print parse errors even when the final result passes.

Native screenshots can be reproduced with:

```sh
godot --path . --script res://tools/localization/capture_localization.gd -- artifacts/localization_20261003
```

They use real production scenes with staged state and isolated saves, at
1280×720. They are layout evidence, not proof of player experience or final Steam
store screenshots. Responsive checks cover Thai/English at scales 1.0 and 1.3,
scroll/focus reachability, long controls and reports, pinned action buttons and
live switches. Export verification loads the actual generated PCK from an empty
working directory, checks both JSON files, English text, the language picker and
30 recorded-speech captions.

Export-resource check (use an empty working directory to prevent source fallback):

```sh
godot --headless --path . --export-pack Linux artifacts/localization_20261003/localization-export.pck
# Then run from an empty directory, with both paths absolute:
godot --headless --main-pack /absolute/game/artifacts/localization_20261003/localization-export.pck --script /absolute/game/tools/localization/verify_export.gd
```

The source build supports interface text, subtitles and spoken dialogue in both
languages. English recordings are generated with ElevenLabs; their text, cast,
hashes and validation are in [the English voice handoff](../tools/audio_pipeline/ENGLISH_VOICE_HANDOFF.md).
Verify these columns
again against the actual uploaded Steam build before selecting them in Steamworks.

## Release qualification

Manager decision (2026-10-03): **GO for bilingual source testing.** Four focused
agent workstreams handled settings, UI, gameplay/subtitles and independent review.
The final checks passed: 149 existing gameplay checks, 18 localization checks,
281 gameplay controls, 167 UI checks, recorded-voice tests, native Thai/English
screenshots and a source-independent exported-resource check. Evidence and logs
are retained under `artifacts/localization_20261003/verification.json`.

English copy and captions are AI-assisted drafts;
human English proofreading, Pga K'nyau/Karen cultural review and listening review
remain necessary before final Steam submission. Include retained AI-assisted
localization in the shipped-content disclosure inventory.

This change does not rebuild, notarize, publish or replace the public beta
installers. Release binaries and Steam language columns must be verified against
the actual bilingual build; the existing public Thai beta is still a separate
artifact. The bounded Steam demo remains another implementation task.
