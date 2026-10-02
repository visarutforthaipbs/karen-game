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

> **Status 2026-10-02 (GAME):** 1, 3, 4 and 5 are **fixed** with tests in
> `tests/test_all.gd`. 1: a famine harvest card leads to the ending. 3: atomic
> save with a `.bak` fallback, and `SaveGame.valid_campaign` checks every field
> before `from_dict`. 4: the clean-burn bonus needs ≥60% ash
> (`GameState.CLEAN_BURN_MIN_YIELD`). 5: `FireGrid.is_cover()` is used by the
> drone and the ranger. The Hearth audio card in 9 was removed earlier.
> 2 (mid-burn quit replays the burn) is still accepted.
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

---

# FINAL AUDIT — Fable, 2026-10-02 (HEAD `d31126e`)

Full re-audit of the finalized game, per the owner's request. Tree was clean at HEAD; everything below was verified by running it, not only by reading.

## Verified at HEAD
- `tests/test_all.gd`: **130 PASS, 0 FAIL**. Smoke run (`--quit-after 120`): clean.
- Character/asset suites: `test_gameplay_motion`, `test_skeletal_character`, `test_equipment_motion`, `test_ranger_assets`, `test_v31_assets` all pass headless. `test_motion_deformation` refuses headless by design (skinned meshes need a renderer) and **passes windowed**.
- Independent behavioural probe (temporary `tests/_audit_probe.gd`, removed after the run; copy in the session scratchpad) confirmed each earlier fix end-to-end:
  - famine at harvest shows the fatal card and leads to the Ending; a game-over Hearth redirects to the Ending;
  - unburned give-up now gets only the −10 drift (and still costs 25 rice);
  - malformed-but-valid JSON saves are rejected as "corrupt" with live state untouched; a damaged main save falls back to `.bak`;
  - `FireGrid.is_cover()` gives drone and ranger the same cover rule;
  - a 90-minute labour delay starts the clock at 15:30 (no int-division bug);
  - save migration from the old "Satellite Shadow" `user://` folder is guarded and test-safe.

## New findings (this pass)
- **N1 — Year-3 "threshold lowered to 25 TU" has no mechanical effect. CONFIRMED numerically.** Attainable cell heats are 100 (burning), 45→35 (smoldering; measured floor 35.02), 10 (ash), 0. Nothing ever lies in (25, 35), so `get_hotspot_cells(25)` ≡ `get_hotspot_cells(35)`. Yet the radio, Hearth brief and phase-4 goal all advertise the 25 TU escalation. Options: (a) make it real — lower `SMOLDER_END_HEAT` below 25 (e.g. 24), so embers that have cooled under 35 escape the Y1–2 scan but are caught from Y3; this genuinely shrinks the cooling window year-over-year, but eases Y1–2 and **must** be re-balanced (`balance_sim.gd` + Monte Carlo, PRD_UPDATE rule 3 forbids silent balance changes); or (b) stay honest cheaply — stop advertising a threshold change. Owner's call. **FIXED (option b): dead config removed, threshold is 35 for all years; option (a) recorded as a P2 design item in HANDOFF.md.**
- **N2 — `spot_fires_started` undercounts.** `_ignite_border` increments it only when no border cell is alight; simultaneous or overlapping spot fires count as one in stats/playtest CSV. Minor telemetry skew only.
- **N3 — CI gap remains.** `.github/workflows/test.yml` still runs only `test_all.gd` + smoke. The five headless-capable character/asset suites are green and cheap; add them. Document that `test_motion_deformation` is windowed-only.
- **N4 — Performance still unmeasured** (`_update_visuals()` full-grid loop per tick and per tool action; Steam Deck P0-9 open). Unchanged from baseline; now the biggest unknown before beta.
- **N5 — Cosmetics:** old name survives only in two `tools/` script comments; `README`/presets/bundle id are renamed. Still no `LICENSE` (owner decision pending). Sprayer refill continues while input is disabled at the 20:00 pass (harmless).
- **Accepted-risk unchanged:** mid-burn quit replays the burn (HANDOFF known issue #2).

## Verdict
Core loop, campaign accounting, save integrity, endings and escalation logic hold up under behavioural testing. **No release blocker found.** Ship the beta after deciding N1 (fix or stop advertising) and running one real playthrough on a second machine. N4 is the main thing the beta itself should measure (ask testers for FPS via the F3 overlay).
