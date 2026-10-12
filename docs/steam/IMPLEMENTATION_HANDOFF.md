# Steam product implementation handoff

Prepared 2026-10-03 from current source. This package prepares submission materials and source audits. **The bounded demo has not been implemented.** Do not treat the current full beta as a bounded demo.

Implementation update (2026-10-03): Thai/English UI switching, persisted locale and exact recorded-speech captions are now implemented in the game source. See [localization validation and release gates](../LOCALIZATION.md). This does not establish that public installers or an uploaded Steam product contain the bilingual build. Human English/cultural proofreading and release-build verification remain pending.

English voice update (2026-10-03): all 30 spoken clips now have ElevenLabs English
counterparts selected by the same language setting. See
[English voice provenance and playback checks](../../tools/audio_pipeline/ENGLISH_VOICE_HANDOFF.md).
Human listening/pronunciation review remains pending. Recheck interface, audio and
subtitle language columns against the actual uploaded product.

## Demo contract

Entry points: `scripts/GameState.gd` advance_to_next_plot / _complete_year, `scripts/VillageHearth.gd` _show_harvest / _close_harvest / _on_launch_pressed, `scripts/SaveGame.gd` _path / migrate_old_user_dir / load_into, `scripts/GameSettings.gd` _path, `scripts/PlaytestLog.gd`, `ui/TitleScreen.gd` Continue/new game, `tools/build.sh`, `export_presets.cfg`.

Use an export feature/build identity rather than a player-controlled setting. The demo permits Year 1's five plots and its harvest result; returning to the village after the last plot must show the outcome and a demo-complete state. It must not permit launch of a Year 2 plot through normal navigation, Continue/reload or imported full saves. Preserve defeat endings and restarting Year 1. Do not turn an unsuccessful campaign into a fabricated success result.

Separate the demo user-data identity from the full game. Current SaveGame migration copies historical Satellite Shadow saves automatically; explicitly prevent that migration in a demo and avoid importing full beta data. Settings and PlaytestLog have independent directory fields, so isolating only campaign.json is insufficient. Do not erase existing full/beta saves. No upgrade save migration is promised for v1.

The completion UI links to the base game only when a verified numeric App ID exists; until then it may say that store details are pending without a fake clickable action. The full build retains unlimited campaign advancement. Keep pending_harvest handling, save validation and existing game economics coherent at the boundary.

Tests required: complete five plots; check harvest then blocked Year 2; fresh/reloaded Continue; full save presented to demo; demo and full directories/settings/logs distinct; demo restart; full Year 2 progression unchanged; no injected test state left in shipped defaults. Follow AGENT.md headless checks and then exercise native Steam installations. Build full/demo separately with version/commit/hash provenance.

## Localization contract

`package/LOCALIZATION_INVENTORY.json` contains 382 quoted Thai source candidates with file and one-based line. It includes comments/internal strings and is not a definitive player-string list. Start by classifying, deduplicating and assigning stable keys. Audit unquoted strings, resource files, dynamically combined strings, embedded tool/control text, radio captions, warnings and numbers separately.

Use Godot translations for player text and a persisted locale in GameSettings/SettingsPanel. Preserve Thai as the original language and existing voice identity; add English subtitles. Review UITheme fonts and layout widths, warning timing, long subtitles, multiline harvest/endings and controller labels. Translate complete sentences with parameters instead of fragments where grammar would break.

Coverage: Title/new/continue/load errors; HowToPlay/FirstBurnTips; HUD phases, wind, tools, breath, water, refill and satellite result; VillageHearth radio, upgrades, exchange, rations and harvest; checkpoint/ending screens; Settings and platform controls; online opt-in/privacy/error states. Any AI-assisted translation retained in game belongs in the shipped-content AI disclosure inventory. Human language/cultural review remains required.

Acceptance: saved locale reloads; language switch works at permitted locations; English/Thai views fit supported resolutions; all required text/format parameters render; no missing keys or mixed-language dynamic alerts; speech subtitles match timing/content; font notices bundled. Mark Steam language columns only after the actual uploaded product supports them.

## Export-content audit

Current presets use `export_filter="all_resources"`. Review the actual PCK/imported resource contents before commercial export: references, concepts, test captures, internal docs/tools or candidate resources must not leak into the installed game simply because they live in the repo. Package size alone does not establish a clean export. Add a reviewed include/exclude policy with dependency tests, then inspect exported resources and native installs. Do not apply broad exclusions blindly that break runtime scene loads.

## Current validation from preparation

Five native-resolution production-scene screenshots were captured with isolated scratch saves via tools/steam/capture_store.gd. Clock and ignition/camera state are controlled by the harness; these are staged in-engine review captures, not evidence of a completed playtest or marketing claims about timing. Thermal mode is explicitly invoked for review. The capture exits 0 but logs 10 ObjectDB instances leaked at shutdown. The separate required 120-frame headless game smoke exits 0 without errors. Capture cleanup is tooling work; release QA remains separate.
