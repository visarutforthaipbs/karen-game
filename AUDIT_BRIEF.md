# AUDIT BRIEF — Satellite Shadow (เงาเมฆา)

Prepared 2026-10-02 from a full read of the game code (`scripts/`, `ui/`, `scenes/`, `tests/test_all.gd`) plus the docs.
Audit the commit tagged `audit-baseline-1` (the commit that adds this file). Uncommitted work from the character/asset agent (title art, whistle SFX, `RangerRig.gd`) is outside the baseline.

## Verified at baseline
- `godot --headless --path . --fixed-fps 60 --script res://tests/test_all.gd`: 120 PASS, 0 FAIL (one exit-time ObjectDB leak warning, already known).
- `godot --headless --path . --fixed-fps 60 --quit-after 120`: no script or parse errors.

## Architecture in one page
- Godot 4.7, GDScript, Thai UI built in code. Main scene `Title.tscn`.
- Autoloads: `InputBindings`, `GameState` (campaign), `AudioManager` (procedural SFX/music + recorded voices). Autoload scripts must not declare `class_name`.
- Flow: Title → VillageHearth → (Checkpoint, Y4+) → Main burn → HUD report → Hearth …; game over → Ending → Title. After plot 5, a monsoon harvest leads into the next year.
- Burn: `MainController` wires `FireGrid` (40×40 cellular automaton), `GameClock` (14:00–20:00, 90 real s per game hour), `WindManager`, `ForestryDrone`, `ThermalCamera`, `RangerPatrol`, `SatelliteOverpass`, the crew and the HUD. Scrutiny is tallied per source and committed once to `GameState.record_plot_results` when the 20:00 sweep finishes.
- Judging at 20:00: ash ≥ 75% (65% with seeds favour) adds rice, < 60% costs 25; any cell at or above the VIIRS threshold (35 TU, 25 TU from Y3) adds scrutiny. End: rice ≤ 20 or scrutiny ≥ 100.
- Persistence in `user://`: `campaign.json` (Hearth autosave), `records.json`, `settings.cfg`, `playtest_log.csv`.
- Tunables are tabulated in `HANDOFF.md` §4; they match the code.

## Findings to verify and triage
1. **Year-end famine is not terminal.** `GameState._complete_year()` can apply −10 rice and leave rice ≤ 20. `VillageHearth` never checks `is_game_over()`, and `SaveGame.save` refuses to write in that state. Play continues until the next burn resolves; quitting loses the progress.
2. **Mid-burn quit replays the burn.** Quit-to-title, a force-quit mid-burn, or a force-quit on the fatal report reloads the pre-burn autosave. Known and accepted in `HANDOFF.md`. `EndingScene` is the only place that deletes the save.
3. **Save robustness.** Single slot, written non-atomically on every Hearth refresh. `SaveGame.load_into` only checks for a dictionary with a `campaign` key; `GameState.from_dict` indexes untrusted fields directly (`e.year`, `e.cell[0]`), so malformed-but-valid JSON would error instead of returning "corrupt", leaving the singleton half-loaded.
4. **"Give up this plot" can be farmed.** At 14:00 with nothing burned it scores 0 hotspots, which counts as a clean burn (scrutiny −20) at a cost of −25 rice.
5. **Ranger vs drone camouflage differs.** `ForestryDrone` ignores crew on BAMBOO or FOREST_BORDER cells; `RangerPatrol._scan` ignores only BAMBOO. Docs say "bamboo hides the crew".
6. **Doc drift.** PRD §4.2 base spread 0.28 (code 0.07). PRD §6 "+15 per hotspot" and "+20 drone" (code: base penalty, +1 per extra cell, cap 2×; drone 15 flame / 10 crew). `AGENT.md` says "no audio files" but WAVs exist. `HANDOFF.md` says "64+" checks (real: 120). `Main.tscn` still carries unused legacy sub-resources.
7. **CI coverage.** `.github/workflows/test.yml` runs only `test_all.gd` and the smoke run. `test_gameplay_motion`, `test_skeletal_character`, the v31 tests and the Python pipeline tests are not run.
8. **Performance unmeasured.** `FireGrid._update_visuals()` loops all 1,600 cells (several MultiMesh writes each) on every sim tick and every tool action. Steam Deck verification (P0-9) is not done; the "low" landscape detail setting exists but is untested on device.
9. **Smaller items.** Hearth has its own non-persistent 3-slider audio card beside the Settings panel. No `LICENSE` file on a public repo (README says all rights reserved). Debug F7 mutates campaign year and the Hearth then autosaves it (tester tools only). Native Thai and Pgakenyaw review of text, names and proverbs is pending.

## Not read in depth (audit these cold)
`AudioManager` synthesis internals, `Landscape`, `LowPoly`, `UITheme`/`FacetCard`/`LowPolyIcon`/`SegmentBar`, `SkeletalChibiAnimator` pose math, `tools/` Python pipelines, `export_presets.cfg` correctness on non-macOS targets.

## Out of scope for correctness
Art direction, character authenticity and style gates are governed by `SOP.md`, `ASSETS.md` and `tools/character_pipeline/character_direction_v3.1.md`.
