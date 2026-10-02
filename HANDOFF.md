# HANDOFF — Game code, UI and balance

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

**The full build plan is now [`PRD_UPDATE_v1.1.md`](PRD_UPDATE_v1.1.md)**: an audit plus P0/P1/P2 requirements with owners and acceptance criteria (title, pause, save, settings, endings, the Ranger, tool reach, telemetry, builds, Steam Deck, CI). The list below is the short version.

1. **Playtest the balance:** whether 8 s is enough to reach a spot fire, how
   drone sweeps feel, burn speed (`base_spread_chance`), and the hold-to-cut
   time. Each is one constant (§4).
2. **The GitHub repo stays public** (user decision, 2026-10-02):
   https://github.com/visarutforthaipbs/karen-game. It still needs a README, and
   a LICENSE once the user picks the terms. The **Ranger foot patrol is
   approved** (PRD_UPDATE_v1.1 P1-2).
3. **Builds:** there are no export presets. A Linux build is needed for the
   Steam Deck test (still open, along with frame rate with the landscape) and a
   Mac build for testers. The Thai line-break data setting is already on.
4. **Translation review:** have a native Thai and ideally Karen (ปกาเกอะญอ)
   speaker check the radio script, proverbs and names.
5. **CI:** a GitHub Action that runs `test_all.gd` on push.
6. **Possible design follow-ups:** companions taking cover from drones;
   drip-torch fuel; showing hold-to-cut progress on the cell marker (it turns red
   when out of reach, but shows no progress).


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
