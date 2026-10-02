# HANDOFF — Game code, UI and balance

> **Renamed 2026-10-02:** the game is now **Under Two Skies** (subtitle
> ไร่หมุนเวียนใต้เงาดาวเทียม), per `SKU_PLAN.md` §0. Changed: `project.godot`
> name, title screen, Hearth header, README, export presets (product name,
> file names, bundle id `io.github.visarutforthaipbs.undertwoskies`) and
> `tools/build.sh`. Godot's user:// folder follows the project name, so
> `SaveGame.migrate_old_user_dir()` copies saves/settings/records/playtest log
> from the old "Satellite Shadow" folder once. **Logo:** `ui/TitleLogo.gd` is a live
> 3D title: faceted TextMesh letters (coarse curves, flat facets, straw-to-clay
> gradient) under a floating hill island (`assets/ui/logo/island.glb`, made with
> Meshy: swidden plots, field hut, bamboo, pines). The V3 satellite glides over
> the island with the title-screen pass (`phase`) and its real shadow sweeps the
> fields. `compact` shows the exported wordmark PNG (Hearth header). PNGs (logo,
> dark logo, wordmark, island icon = app icon) are in `assets/ui/logo/`; regenerate
> them with `tools/export_logo.gd` after any change. **V3 satellite is now a Meshy
> model** (5,335 tris, centred origin, wings ±X, lens −Y; the title pass tips it
> 0.55 rad so the flat wings read). The asset agent's old V3 is in
> `artifacts/logo_meshy/rollback/`; concepts and raw downloads are in
> `artifacts/logo_meshy/`. Meshy spend: 87 credits (balance 1,506). Internal pipeline comments and
> asset file names (e.g. `satellite_shadow_blue_hour_*.png`) keep the old name.

Last updated: 2026-10-02. Read this after `AGENT.md` and `PRD.md` when picking up
game-code work. Character/asset work has its own docs (`SOP.md`, `ASSETS.md`,
`tools/character_pipeline/`, `tools/asset_pipeline/`).

## 1. Who owns what

Two agents work in this folder, often at the same time.

| Area | Owner |
|---|---|
| `scripts/` game logic, `ui/`, `scenes/Main.tscn`, `scenes/VillageHearth.tscn`, `tests/test_all.gd`, `tests/balance_sim.gd` | Game-code agent (this handoff) |
| `tools/character_pipeline/`, `tools/asset_pipeline/`, `assets/`, `scenes/characters/`, `scripts/*ChibiAnimator.gd`, `scripts/CharacterToolFeedback.gd`, `tests/test_*motion*.gd`, `tests/test_skeletal_character.gd` | Character/asset agent |

The character agent also adds animation hooks inside `PlayerController.gd` and
`CompanionController.gd` (`set_work`, `_show_tool_feedback`, borrowed sprayer).
Both sides edit those two files, so merge carefully.

**Before editing a shared file:** run `git status` and `git diff <file>` and check
the mtime. Don't overwrite another agent's uncommitted change. Make string
replacements that must match exactly. Don't gate an edit on `git diff --quiet`:
once the other agent touches the file, the edit is silently skipped (this
happened once). **Commit only your own files** unless the user asks you to
commit everything.

## 2. Commands

```bash
godot --headless --path . --fixed-fps 60 --script res://tests/test_all.gd   # 64+ checks, ~1 min
godot --headless --path . --fixed-fps 60 --quit-after 120                    # smoke run
godot --headless --editor --quit --path .                                    # re-index new class_name scripts
godot --headless --import --path .                                           # import new assets (fonts etc.)
godot --headless --path . --script res://tests/balance_sim.gd                # fire balance probe, ~4 min
```

- **Screenshots:** AeroSpace tiles Godot windows, so add the scene to a 1280x720
  (or 1368x720, the user's wide window) `SubViewport` from a `--script`
  SceneTree. Run windowed (`--resolution 640x360`) and save
  `vp.get_texture().get_image()`. Put the script in `tests/_something.gd` and
  delete it afterwards.
- **`--script` mode gotcha:** autoload globals aren't compiled in, so don't name a
  class that depends on them (e.g. `PlayerController`). Use
  `load("res://scripts/X.gd")`, instance properties, or the real scene's nodes.
- **Headless window size:** the window starts square (1280x1280). Set
  `root.size = Vector2i(1280, 720)` before testing on-screen framing.

## 3. What has been done (game-code side)

Commits: `97df1e5` (first), `71a6ede` (balance/landscape/camera/HUD), then the
camera fix.

1. **Thai low-poly UI** (`ui/`). All player-facing text is Thai. Character
   names: ขะแน / ตาโพ / มูนอ. Kanit is used for the village and Chakra Petch for
   the state's readouts (`assets/fonts`, OFL). Neither font has ○ ● ✓. UI is
   built in code: `UITheme` (palette, Theme, builders), `FacetCard` (triangulated
   panel), `LowPolyIcon`, `SegmentBar`, `WindCompass`, `HearthBackdrop`.
2. **How to win is explained.**
   - `ui/HowToPlay.gd`: opens on a new campaign and from the hearth's วิธีเล่น
     button.
   - HUD goal checklist: ash % against the target, hot embers, and the 17:16
     self-cooling deadline.
   - The round report shows one pass/fail line per goal plus a tip.
3. **Compact HUD** (`ui/HUD.gd`). Panels fade when the player or the cursor is
   behind them; Tab/Select hides the HUD. `track(camera, player)` is called by
   MainController.
4. **Camera** (`scripts/CameraRig.gd`).
   - Follows the player.
   - Zoom out fits the whole plot (computed for the current turn and window
     shape), then continues to a scenic horizon view.
   - Z/C turn the view 90°. Movement and the wind arrow are screen-relative.
   - The camera must not chase the cursor; see the gotchas.
5. **Landscape** (`scripts/Landscape.gd`).
   - Mountain terrain around the plot, with a swidden mosaic in burn-season
     stages, a forest belt, field huts, smoke, haze and valley mist.
   - Turns to cold ground in the satellite thermal view.
   - Uses lean 20–40-triangle meshes in chunked MultiMeshes. FireGrid's pedestal
     is hidden.
6. **Balance pass.** Everything was measured with `tests/balance_sim.gd` and a
   campaign Monte Carlo. Numbers are in §4.
7. **Knife fixes.**
   - A camera "aim lean" moved the cell under a still mouse, so hold-to-cut
     never finished. The lean was removed and a regression test added.
   - Then a plain click did nothing, because cutting needed the button held.
     A click now commits the cut. The user plays by clicking, so keep it that
     way. Verify with a windowed diagnostic that warps the mouse and presses
     `use_tool` (see §2).

Also: `project.godot` sets `filesystem/import/blender/enabled=false`; `.blend`
files blocked every headless import because Blender isn't installed on this Mac.

8. **PRD_UPDATE_v1.1 P0 and P1 build (2026-10-02).** All game-side P0 items and
   P1-2 to P1-6 are done. Each item below has tests in `test_all.gd`.
   - **Title** (`scenes/Title.tscn`, `ui/TitleScreen.gd`, `ui/SatelliteStreak.gd`):
     now the main scene, with a live dusk view of the plot and landscape as the
     backdrop.
   - **Save / continue** (`scripts/SaveGame.gd`, `GameState.to_dict/from_dict`):
     autosaves on every Hearth refresh to `user://campaign.json` (version 1).
     Game-over campaigns aren't saved; best run in `user://records.json`.
   - **Settings** (`scripts/GameSettings.gd`, `ui/SettingsPanel.gd`):
     `user://settings.cfg`. Five volume buses, fullscreen, UI scale (root
     `content_scale_factor`), landscape detail low/high (low = no far trees, no
     mist), camera zoom, hints, first-burn tips, tester tools.
   - **Pause** (`ui/PauseMenu.gd`, action `pause` = Esc / Start): sets
     `SceneTree.paused`. "Give up this plot" runs the 20:00 pass immediately.
     "Quit to title" keeps the pre-burn autosave.
   - **Endings** (`scenes/Ending.tscn`, `ui/EndingScene.gd`): a crackdown raid at
     night and a famine exodus at dawn, both skippable, then the run summary.
     `GameState.stats` collects the campaign tallies.
   - **Tool reach:** `PlayerController.tool_reach()`; the sprayer reaches 5.5 m,
     other tools 4 m.
   - **Playtest log** (`scripts/PlaytestLog.gd`): one CSV row per burn in
     `user://playtest_log.csv`. `MainController.breakdown` holds the per-burn
     scrutiny by source.
   - **Tester tools** (`ui/DebugOverlay.gd`): F3 overlay, F5–F10 cheats. Enabled
     from the editor build, or with settings → tester tools or `--debug-tools`.
   - **Builds:** `export_presets.cfg` (macOS universal with ad-hoc signing,
     Linux x86_64, Windows x86_64) and `tools/build.sh`, which writes
     `build/<date>-<commit>/`. Export templates 4.7.2 are installed on this Mac.
     macOS needs `import_etc2_astc=true` (set).
   - **Ranger patrol** (`scripts/RangerPatrol.gd`, `scripts/RangerFigure.gd`):
     Year 3+, 15:30–18:30, one ranger in Y3 and two in Y4+. The vision cone and
     marker draw through the canopy. Smoke blocks sight; bamboo hides the crew.
     One sighting per lap, +10 × penalty_mult. **Y3 ground cameras went from 2
     to 1** to keep good-player Y3 survival around 42% (Monte Carlo).
     `RangerFigure` is a placeholder until CHAR installs
     `scenes/characters/RangerChibi.tscn`; it's then used automatically, and the
     model should expose `update_animation(delta, velocity, face)` like the crew.
   - **Companions take cover** (`CompanionController` state `HIDING`, `threats`
     set by MainController): they hide from a drone on station within 15 m or a
     ranger within 14 m, but always break cover for a spot fire.
   - **Cut progress disc** (`PlayerController._show_cut_progress`) and
     **first-burn tips** (`scripts/FirstBurnTips.gd`, `HUD.show_tip`).
   - **Title "Satellite Shadow" pass** (`ui/TitleScreen.gd`,
     `scripts/SatelliteModel.gd`): a large low-poly VIIRS satellite (asset V3).
     It's procedural; a pipeline model at `assets/props/V3_*.glb` replaces it via
     `AssetLibrary.mesh_or("V3")`. It crosses the plot every 16 s with a projected
     cold shadow (Decal from `SatelliteModel.shadow_texture()`) and a VIIRS
     swath. Inside the swath the plot shows thermal colours with props hidden
     (`FireGrid.scan_active / scan_center / scan_half / scan_heading`, usable
     elsewhere, e.g. a 20:00 pass cinematic). The camera is fixed with a gentle
     drift, the plot sits right of the menu, and the pass runs left to right
     over the fire line.
   - **Ranger model:** CHAR installed `scenes/characters/RangerChibi.tscn`.
     `RangerFigure.create()` now uses it in the patrol and the crackdown ending.
   - **Year 4+ checkpoint** (`scenes/Checkpoint.tscn`, `ui/CheckpointScene.gd`):
     plays between the Hearth and the burn. Uses `AssetLibrary` "S5" with a
     procedural fallback.
   - **v1.1 assets integrated (GAME side):** S3 granary (famine), S5 at the
     checkpoint roadside, S6 truck and T2 knife (crackdown), slate ranger
     variant (`RangerFigure.create(flashlight, slate)`, patrols alternate),
     authored gestures via `RangerFigure.gesture(node, clip)`: the crackdown
     cues in `EndingScene._cues`, the checkpoint guard, RadioTalk when a patrol
     logs. Portraits via `UITheme.portrait(id, size)` in the HUD crew chips,
     the elder banner and ranger alerts (`show_drone_alert(msg, danger, from_ranger)`).
   - **v1.2 asset hooks, pre-wired (see [`ASSET_REQUESTS_v1.2.md`](ASSET_REQUESTS_v1.2.md)):**
     fire VFX sheets (`FireGrid.apply_sprite_sheet`, `assets/vfx/`), E6/E7/E8/E9
     set dressing (`Landscape._scatter_set_dressing` / `_scatter_terraces`),
     C6 villagers (`EndingScene.villager_node`), U4 Hearth painting
     (`HearthBackdrop.PAINTING`), V3 scale fit (`SatelliteModel.fit_scale`).
     Each one is a no-op until its file exists.
   - **v1.2 assets delivered and integrated** (all 29 files; CHAR's notes in
     `tools/asset_pipeline/V12_ASSET_HANDOFF.md`). GAME follow-ups applied: S7
     bundle on C6 at (0, 0.40, -0.2); pipeline T4 tank lowered (-0.23/base_scale
     on the back socket, 0.62 on the root fallback); T5 -0.22 and T2 -0.07 grip
     offsets for companions (`SkeletalChibiAnimator`, `CompanionController`).
     Mu-naw keeps the authored `CharacterEquipment` tank. Set dressing is
     oversized like the trees (rocks 1.1-2.4, grass 1.5-2.6 within 150 m,
     terrace walls 1.5 in 110 contour runs) so it reads from the game camera.
     The title satellite is on render layer 2 with its own cool fill light.
   - **Meshy cast (CHAR, `tools/character_pipeline/MESHY_CAST_HANDOFF.md`)
     reviewed in game.** One GAME fix in the CHAR-owned
     `SkeletalChibiAnimator._apply_motion_layers`: the idle/walk carry pose set
     the hand socket from the hand bone's *rest* basis, which tipped every tool
     sideways because the Meshy rigs rest in a T-pose. It now uses the current
     hand pose with an upright carry (slight forward lean; Ta-poh's knife still
     blade-down). Work poses are unchanged. Before/after screenshots:
     `artifacts/game_review_meshy/crew_*` and `fix_*`.

## 4. Rules and tunables (where to change them)

**How a plot is judged at 20:00:**
1. Cooled ash ≥ 75% (65% with the indigenous-seed favour) adds rice; below 60%
   loses 25.
2. No cell at or above the VIIRS threshold.

The campaign ends at rice ≤ 20% (famine) or scrutiny ≥ 100 (crackdown).

| Rule | Where | Value |
|---|---|---|
| Base spread per tick | `FireGrid.base_spread_chance` | 0.07 |
| Fuel dryness by time of day | `FireGrid.dryness_at_minute` | 14:00 0.35 → 15:30 0.95 → 16:30 1.0 → 18:30 0.55 → 20:00 0.4 |
| Burn / smoulder duration | `BURN_DURATION_TICKS` / `smolder_duration_ticks` | 12 / 480 ticks (1 tick = 0.5 s real = 20 s game). Self-cooling deadline 17:16, computed in `MainController.self_cool_deadline_minute()` and checked against `HowToPlay.SELF_COOL_DEADLINE` |
| Spot fires in the park | `BAMBOO_BURST_CHANCE`, `BORDER_CATCH_CHANCE`, `BORDER_SPREAD_FACTOR`, `ESCAPE_TICKS` | 0.3, 0.5, 0.5, 16 ticks (8 s to douse); spots don't spread until established |
| Firebreak cutting | `PlayerController.CLEAR_SECONDS` | 0.5 s per cell (blade upgrades shorten it). A **click commits** the cut (`_begin_cut` / `_update_firebreak_cut`): raking finishes on its own, cancelled only by leaving reach or switching tools. Holding and dragging rakes a line |
| Drones | `ForestryDrone.SWEEP_SECONDS`, `AWAY_SECONDS_*` | 45 s over the plot, 50–70 s away, at most one photo per sweep. Crew photographed only when beside open flames |
| Ground cameras | `ThermalCamera.tripped` | each post logs a burn once (+10 × penalty_mult) |
| Satellite detection | `SatelliteOverpass.scrutiny_for` | base penalty + 1 per extra hot cell, capped at 2× |
| Penalties | `MainController` | escape 30 × park strictness; drone flame 15 / crew 10; × `Escalation.penalty_mult` (Y1 0.75, Y2 0.9, Y3 1.0, Y4+ 1.25) |
| Scrutiny relief | `GameState.PLOT_SCRUTINY_DECAY`, `CLEAN_BURN_BONUS`, `MONSOON_SCRUTINY_RELIEF` | 10 per plot, +10 if clean, 45 per monsoon |

**Measured results** (`tests/balance_sim.gd`):
- Ring firebreak, then a drip-torch line along the bottom at 15:30, with sparks
  doused: 82–88% ash, 0 hotspots, 0–1 escapes in 8 runs.
- Lighting at 17:00 leaves 230–415 hotspots.
- Lighting at 14:00 stalls in damp fuel.

**Modelled campaign:** a good player survives Y1 100%, Y2 93%, Y3 38%. An
average player survives Y1 78%. The player profiles are estimates; playtesting
is the real check.

## 5. Gotchas found the hard way

- Hand-built `ArrayMesh` triangles must wind **clockwise seen from above**
  (Godot's front face). Otherwise lighting comes out dark and muddy.
- Vertex colours need `vertex_color_is_srgb = true` or they wash out.
  `LowPoly.vertex_color_material` doesn't set it, which is part of why plot props
  look pastel; the look is tuned around that, so don't change it casually.
- Don't instance the full `LowPoly` props across the landscape (1.6M triangles).
- `set_anchors_preset()` on a Control that's already in the tree collapses it to
  size 0. Use `set_anchors_and_offsets_preset()`.
- **Never** make the camera depend on the aim point (feedback loop; see §3.7).
- Don't run GDScript on WorkerThreadPool while scenes load (it stalled before).

## 6. Open items / next steps

The full plan is [`PRD_UPDATE_v1.1.md`](PRD_UPDATE_v1.1.md). Game-side P0 and
P1-2 to P1-6 are built (§3.8). What remains:

1. **Playtest the balance:** whether 8 s is enough to reach a spot fire, drone
   sweeps, ranger sightings, burn speed. Tune from `user://playtest_log.csv`.
   The constants are in §4.
2. **Steam Deck (P0-9):** needs the device. Run the Linux build from
   `tools/build.sh`, fill in the checklist in PRD_UPDATE_v1.1, and try landscape
   detail "low" if fps < 40.
3. **LICENSE:** the repo stays public; the licence terms are still the user's
   call. README says "all rights reserved until decided".
4. **CHAR v1.1 assets delivered:** C5 Ranger (two palettes, eight clips), S5
   checkpoint, T2 knife, S3 granary, S6 pickup, S7 travel bundle, T6 flashlight,
   T7 tablet, five U3 portraits and U6 title art. RangerFigure and the S5 lookup
   resolve the new assets automatically. GAME still owns remaining attachment,
   ending/UI placement and authored action calls. Nine A2 audio files are
   listening-review candidates. See the asset handoff below.
5. **Known issues:**
   - Quitting to the title mid-burn and continuing replays that burn from the
     Hearth (pre-burn autosave). It's a mild re-roll exploit; accepted for the
     playtest.
   - (Fixed) The Hearth's non-persistent audio card is gone; a "ตั้งค่า" header
     button opens the shared SettingsPanel. The Hearth's card columns sit in a
     ScrollContainer so the launch button is always on screen; at 1280×720
     everything fits without scrolling.
6. **Translation review** by a native Thai and ideally Pgakenyaw speaker.
6a. **Audit fixes (beta blockers), 2026-10-02:** AUDIT_BRIEF items 1, 3, 4 and 5
   are fixed with tests (see the status note there). Rule change for players:
   a clean burn now needs ≥60% ash; bamboo **and** forest edge hide the crew
   from drones and rangers alike.
6b. **Graphics pass assets** (ASSET_REQUESTS_v1.2) delivered and integrated
   (§3.8). Optional mist/ash sprites were not made; they would need a small hook.
7. **P2 polish:** see PRD_UPDATE_v1.1 §4.

## Character v3.1 installation handoff — 2026-10-02

All four new rigs are installed. Three field scenes set `separate_equipment=true`;
Mu-naw is now the free-armed young woman with dress controls and separate gear.
Mae-Lu's new character scene and live portrait are in the village granary card;
ration presses trigger a visual gesture without changing accounting. The shared
CompanionController change only selects the faceted tank for the new cast's
borrowed sprayer. VillageHearth retains the existing audio/UI changes.
Two explicit local types in AudioManager's mix-report loop fix parse errors
encountered during validation; its sound design was not altered by this rig pass.

Character tests, actual gameplay-motion tests, `test_all.gd` and the 120-frame
smoke run pass. Runtime deformation uses role-appropriate actions for all four;
`tests/test_motion_deformation.gd` now delegates to the manifest-capable v3.1
checker. Evidence, rejected builds, hashes and rollback are under
`artifacts/character_rigs_v31/`. Existing exit-time ObjectDB leak warnings remain.
See `tools/character_pipeline/CAST_V31_STATUS.md` for reference/animation limits.


## v1.1 asset delivery — 2026-10-02

Asset-only pass: no controller, patrol rule, UI flow or balance edits. Full paths,
metrics and attachment contracts are in
[`tools/asset_pipeline/V11_ASSET_HANDOFF.md`](tools/asset_pipeline/V11_ASSET_HANDOFF.md).

C5 is installed at `scenes/characters/RangerChibi.tscn`; the alternate cold
uniform is `RangerSlateChibi.tscn`. Each has 19,800 triangles, 19 bones and
Idle/Walk/Run/Scan/Photograph/Point/RadioTalk/Escort. The asset helper exposes
`update_animation(delta, velocity, face)` and `play_clip(name)`. It accepts the
existing RangerFigure flashlight and attaches the beam to the held lens.
GAME should call the authored action clips at patrol/ending events and may pick
the slate scene for crowd variety. Fingers and close-up contact are not fully rigged.

Seven reviewed props are installed (T2/S3/S5/S6/S7/T6/T7). The S6 truck is
1.96 × 1.89 × 3.5355 m; its earlier undersized candidate was replaced. T2 grip
is local Y 0.07. The source models, rejected candidates and installation hashes
are in `artifacts/asset_update_v11/`.

Five transparent 256 px portraits live in `assets/ui/portraits/`; the source
manifest records actual installed model hashes. The 1920 × 1080 title image is
`assets/ui/title/satellite_shadow_blue_hour_1920x1080.png`. Its generated original
is retained. UI/README placement remains GAME work.

`assets/audio/v11_candidates/` has four spoken Thai barks (exact ASR matches) and
five synthetic cough cues. Listening/acting review remains open; they are not
activated in AudioManager. Keep the existing fallbacks.

Validation: all seven props pass dimensions/triangle/material checks; both final
Ranger variants pass eight exported Godot clips, with unchanged animation timing
across palettes. `tests/test_ranger_assets.gd` passes (scene/API/gear/lens/portraits/
title contract); five skin-region regression tests pass; `test_all.gd` reports
zero failures; the 120-frame smoke run exits cleanly. `test_all.gd` still reports
its existing two exit-time ObjectDB leaks, plus the intentional corrupt-save JSON
parse diagnostic. No whole-PRD completion is claimed.


### Character equipment follow-up — 2026-10-02

At the user's request, CHAR fixed the player T4→T5 hose, Kha-nae's crossed rake
hold and Ta-poh's belt knife. Runtime changes are in `PlayerController.gd`,
`SkeletalChibiAnimator.gd`, and new `SprayerHose.gd`. Keep the player's corrected
`-0.22 / animator.base_scale` handle offset. Ta-poh draws his belted knife only
for clearing. No model regeneration or gameplay-rule change. Full suite and
focused motion checks pass. Review images, measured contact and limitations:
[Equipment motion handoff](tools/character_pipeline/EQUIPMENT_MOTION_HANDOFF_20261002.md).
