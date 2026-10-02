# Asset requests v1.2: graphics pass (GPU free) — 2026-10-02

From GAME to CHAR (the asset agent). Everything below is **pre-wired**: drop a
validated file at the exact path and it shows up in the game with no code change.
Until a file exists the game keeps its procedural fallback, so items can land one
at a time in any order.

Read first: `tools/asset_pipeline/README.md` (art direction, routes, budgets),
`tools/asset_pipeline/asset_manifest.json` (IDs already specified),
`tools/asset_pipeline/V11_ASSET_HANDOFF.md` (format of the last delivery).

## Shared rules (same as v1.1)

- **Style:** PRD §9.1 stylized low-poly. Flat-shaded visible facets, broad muted
  natural colour areas, matte. No photorealism, no microtexture, no gloss, no text,
  no real insignia, flags or logos.
- **Props:** metre-scale, base-centred origin, +Y up, **+Z front**, GLB at
  `assets/props/<ID>_<name>_<variant>.glb` (`_a`, `_b`, … for variants). Loaded
  through `AssetLibrary` (`mesh_or` / `variants_or` / `meshes`); it flattens the
  scene, so **static meshes only** (no rigs, no animation) unless noted.
- **Triangle budgets** are ceilings from the manifest; instanced items (E-series)
  must stay at or under them, since they are drawn hundreds to thousands of times.
- **Review:** four-angle render and an in-game view at gameplay distance, as for
  v1.1, then `install_asset.py`. Run `godot --headless --path . --fixed-fps 60
  --script res://tests/test_all.gd` and expect `RESULT: OK` after installing.
- Do not edit `scripts/`, `ui/` or `tests/test_all.gd`; if a hook is wrong for your
  asset, note it in your handoff and GAME will adjust it.

## Priority list

| # | ID | What | Path | Where it shows | Prio |
|---|---|---|---|---|---|
| 1 | FX1–3 | Fire VFX sprite sheets | `assets/vfx/*.png` | Every burn, the whole game | **P0** |
| 2 | E9 | Grass tufts | `assets/props/E9_grass_tuft_{a,b,c}.glb` | Fallows around the plot | **P0** |
| 3 | E6 | Rocks | `assets/props/E6_rock_{a..d}.glb` | Fallows, slash, burned ground | **P0** |
| 4 | E7 | Terrace wall segments | `assets/props/E7_terrace_wall_{a,b}.glb` | Old fallows, in contour runs | **P0** |
| 5 | E8 | Fallen logs | `assets/props/E8_log_{a,b}.glb` | Forest edge, slash | **P0** |
| 6 | V3 | Satellite hero model | `assets/props/V3_satellite_a.glb` | Title screen (the game's concept) | **P0** |
| 7 | C6 | Villagers (crowd) | `assets/props/C6_villager_{a..d}.glb` | Famine ending, checkpoint | **P0** |
| 8 | U4 | Hearth night painting | `assets/ui/hearth/hearth_night_1920x1080.png` | Village Hearth between plots | P1 |
| 9 | E4, E5 | Charred stumps, root collars | `assets/props/E4_bamboo_stump_{a,b}.glb`, `E5_root_collar_{a,b}.glb` | The plot after the burn | P1 |
| 10 | T1, T3, T5 | Held tools | `assets/props/T1_drip_torch_a.glb` … | In the player's hand all game | P1 |
| 11 | T4 | Backpack sprayer tank | `assets/props/T4_sprayer_tank_a.glb` | On every crew back | P1 |
| 12 | V2 | Thermal camera housing | `assets/props/V2_thermal_camera_housing_a.glb` | Year 2+ ground cameras | P1 |

---

## 1. FX1–3 Fire VFX sprite sheets (P0)

The fire, the game's core, currently uses one soft round dot for flames, smoke and
sparks. Hook: `FireGrid.apply_sprite_sheet()` (`scripts/FireGrid.gd`); it switches
on particle animation when the file exists.

| File | Layout | Content | Notes |
|---|---|---|---|
| `assets/vfx/flame_sheet.png` | 512×512, **4×4 frames**, read left→right, top→bottom | One flame tongue licking up, looping (frame 16 → 1 must not pop) | **Greyscale + alpha**: white-hot core, mid-grey edges. The game multiplies it by its own colour ramp (amber → orange → deep red over each particle's life), so baked colour would turn muddy. Soft alpha edge; faceted/painterly, not photo fire. Base at bottom-centre of each frame. |
| `assets/vfx/smoke_sheet.png` | 512×512, **2×2 variants** (not animation; each particle picks one) | Four different low-poly puff shapes | **White/light grey + alpha**: the game tints it (light grey by day, brown haze under the 18:00 inversion). Soft, chunky, faceted silhouettes. |
| `assets/vfx/ember.png` | 64×64 | One spark | White-hot centre + alpha falloff; the game tints it orange. |

Nice to have (needs a small GAME hook, tell me if you make them):
`assets/vfx/mist_sheet.png` (2×2, water spray puffs, white+alpha) and
`assets/vfx/ash_flake.png` (64×64, grey flake).

## 2–5. Landscape set dressing (P0)

The hillside outside the plot is terrain colour plus trees, which reads as blocks.
Hook: `Landscape._scatter_set_dressing()` / `_scatter_terraces()`
(`scripts/Landscape.gd`). Each variant becomes its own chunked MultiMesh. Already
smoke-tested with stand-in meshes.

| ID | Budget | Spec | Placement the game does |
|---|---|---|---|
| E9 grass tuft | **≤40 tris**, 3 variants, ~0.3 m, **one vertex-colour surface** | Dry mountain grass, straw + faded green blades; must read at 20–40 m | 1,600 samples on young/mid fallow and slash, scale 0.8–1.5, random yaw, no shadows, drawn to 110 m. Skipped on the Low landscape setting. Model it procedurally (`--mesh`), as for E2. |
| E6 rock | ≤150 tris, 4 variants, ~0.6 m | Weathered grey granite, a few big flat facets, a little lichen tint | 520 samples, scale 0.8–1.6, random yaw, sunk 0.15 m into the ground. |
| E7 terrace wall | ≤150 tris, 2 variants, **1.5 m wide (X), ~0.5 m tall, ~0.4 m deep** | Old dry-stone retaining wall, stacked flat stones, slightly overgrown top | Runs of 3–7 segments laid edge to edge along rings around the plot, **local +Z faces the plot** (downhill face toward +Z). Segments must butt together cleanly at X = ±0.75. |
| E8 log | ≤150 tris, 2 variants, ~1.5 m | Fallen dry log, a few broken branch stubs, bark facets | 260 samples, scale 0.9–1.3, random yaw. |

## 6. V3 satellite hero model (P0)

The title screen is "Satellite Shadow" made literal: a huge satellite passes over
the plot and its shadow and thermal scan sweep the fields. A procedural placeholder
is in `scripts/SatelliteModel.gd`; your model replaces it via `mesh_or("V3")`.

- **Orientation is critical:** wings/solar panels along **local X**, flight
  direction **+Z**, the radiometer/scanner looking **down (-Y)**, origin at the
  body centre (an exception to base-centred, since it flies).
- **Scale:** any size. The game fits its X span to the staged ~16 m wingspan
  (`SatelliteModel.fit_scale`), so the manifest's 2 m is fine.
- Budget: quality route, ≤4,000 tris. It fills about a third of the frame, so
  the silhouette matters most: gold-foil body, two long solar wings (not one; the
  ground shadow is a symmetric two-wing silhouette), a dish, a visible lens.
  Fictional and generic: no agency logos, no real satellite replica.
- Seen from below and the side at blue hour, lit by a low sun.

## 7. C6 villagers (P0)

The famine ending (families walking away down the road) and the Year 4+
checkpoint currently show capsule placeholders. Hook:
`EndingScene.villager_node()` (`ui/EndingScene.gd`), also used by
`ui/CheckpointScene.gd`.

- **New ID: add C6 to `asset_manifest.json`.** 4 variants `_a.._d`: man, woman,
  elder, teenager. Karen everyday dress in simplified form (handwoven tunic shapes,
  head wrap on some, broad colour areas). Respectful; no costume caricature.
- **Static mesh** in a walking pose, ~1.15 m chibi proportions matching the crew
  and rangers (1.25 m), +Z front, base-centred, ≤3,000 tris each, matte.
- The game straps the S7 bundle on at local **(0, 0.72, -0.2)**: leave the upper
  back clear, or tell me the right offset for your model.
- Optional later: if you would rather deliver rigged walkers, put them under
  `scenes/characters/` with the chibi animator API and tell me; GAME will switch
  the hook.

## 8. U4 Hearth night painting (P1)

The Village Hearth (between plots) draws a procedural night scene. Hook:
`HearthBackdrop.PAINTING` (`ui/HearthBackdrop.gd`); it is drawn cover-cropped, with
the game's ember glow added on top.

- `assets/ui/hearth/hearth_night_1920x1080.png`, 1920×1080, same faceted painted
  style as `assets/ui/title/satellite_shadow_blue_hour_1920x1080.png`.
- Night, village on the ridge, a hearth fire in the lower centre, warm firelight
  against a cold blue sky, a faint satellite streak overhead.
- **Keep the middle 60% of the width and the bottom 45% calm and darker:** cards,
  the crew roster and buttons sit there. No baked text. Any crop to 16:10 or 4:3
  must still work (keep the key content central).

## 9. E4 / E5 stumps (P1)

The cells left on the burned plot. Hook: `FireGrid` lines ~341–356.

- E4: cluster of cut bamboo culm stumps, ~0.4 m. E5: tree root collar with gnarled
  roots, ~0.3 m. 2 variants each, **≤80 tris, one surface**.
- **The game overrides the material** (glowing ember shader while smouldering, ash
  grey after), so only the shape counts: chunky readable silhouette, no fine roots.

## 10–11. Tools T1 / T3 / T5 and tank T4 (P1)

Held or worn all game by the player and the crew. Hooks: `PlayerController` and
`CompanionController` (`_create_tool_rig`, tool switch).

- T1 drip torch (canister + curved spout, ~0.9 m), T3 rake-hoe (~1.4 m),
  T5 sprayer wand with brass nozzle (~0.8 m), T4 15 L yellow backpack tank (~0.46 m).
- **Grip convention:** tools stand on their base (+Y up). The game moves them
  **0.22 m down** in the hand socket, so put the hand grip **0.22 m above the
  origin**. T2 (delivered) is the reference for style.
- T4 sits on the back at (0, 0.85, -0.3) from the character root: straps toward
  +Z (the body), keep it ≤0.3 m deep so it doesn't clip.
- Thin shapes: build procedurally (`--mesh`), per README.

## 12. V2 thermal camera housing (P1)

Year 2+ ground cameras. Hook: `ThermalCamera.gd`: the housing sits on the game's
own pole at 2.58 m, base at origin, lens facing +Z. Grey weatherproof box, small
dark-red lens, sun hood, a little solar panel on top. ≤1,500 tris. Unmarked.

---

## Delivered and already integrated (v1.1, for reference)

| Asset | Where GAME uses it now |
|---|---|
| T2 mida knife | Crackdown ending (confiscated tools) |
| S3 granary | Famine ending |
| S5 checkpoint | Checkpoint scene, at the roadside next to GAME's animated barrier arm |
| S6 ranger truck | Crackdown ending (GAME adds headlights) |
| S7 travel bundle | On C6 villagers' backs (once C6 lands) |
| C5 ranger + slate variant | Patrols alternate olive/slate; endings and checkpoint play Scan, Point, Photograph, RadioTalk, Escort |
| Portraits | HUD crew chips, elder banner, ranger alerts |
| Title art | README cover |

Still open from v1.1 (not new asset work): **T2 on Kha-nae's belt/off hand**
(CharacterEquipment, CHAR side) and the **A2 bark listening review** (the user
needs to listen before they are wired in).

## Handoff back

When done, append a section to this file or write `V12_ASSET_HANDOFF.md` next to
the v1.1 one: IDs installed, triangle counts, any offset that differs from the
spec above, review image paths. GAME will then take screenshots and tune placement.
