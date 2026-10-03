# v1.2 asset delivery — 2026-10-02

## Meshy utility-prop follow-up — 2026-10-03

Second approved batch installed: **T4 sprayer tank, S2 refill barrels, S6 pickup**.
90 credits consumed of the approved 105-credit cap; remaining Meshy balance 1326.
No optional remesh or paid retry used. Original concepts were generated with the
built-in imagegen tool from fresh four-angle captures of the existing assets.
These are contemporary utility props, not claimed historical Karen artefacts;
no invented ethnic motifs or logos were added. Bamboo water containers retain
their existing role. Characters, tools T1/T2/T3/T5, vegetation, VFX and runtime
scripts remain unchanged.

Evidence root **M2**: `artifacts/meshy_props_batch2_20261003/`.

| Installed file | Tris / budget | Dimensions X/Y/Z m | Meshy task |
|---|---:|---|---|
| T4_sprayer_tank_a.glb | 1304 / 1500 quality | 0.360 / 0.460 / 0.2985 | 01a0ffbc-b020-710a-83c9-fb41a89d8d2d |
| S2_water_barrels_a.glb | 1470 / 1500 quality | 1.184 / 0.900 / 0.543 | 01a0ffbd-6630-74d5-9229-90c77eb64209 |
| S6_ranger_truck_a.glb | 1483 / 1500 standard | 2.003 / 1.890 / 3.735 | 01a0ffbd-770f-7613-875a-e8b233116865 |

All static, base-centred, Y up, flat normals and +Z front. No runtime offsets
change. T4's strap-side yaw required 180 degrees and its geometry was fitted to
the exact previous bounding envelope. Existing outlet stays
(0.150,0.055,-0.096750); Player tank placement and hose code are unchanged.
T4 generated albedo had a dark seam/noisy pixels, so the delivered Meshy geometry
uses four authored matte materials (yellow, charcoal, buckles, brass). The broad
shell relief remains; do not confuse this with the rejected textured candidate.
There are no shipping T4 texture maps. S2 and S6 each retain one 2K textured surface.
S6 required +90 degrees source yaw and a geometry fit to the exact old footprint
to preserve ending staging. S2 is about 0.147 m narrower and 0.125 m shallower
than the previous barrels; height and base origin remain exact, so no hook change
is needed. S2's bamboo tube mouths are simplified; this is not a certified
watertight or internally detailed water-container model.

Accepted candidate folders: `T4_style_candidate/`, `S2_candidate/`,
`S6_fit_candidate/`. Each contains run/validation JSON, script snapshots,
four-angle preview and installer rollback. Extra pre-normalization and textured
tank folders are rejected/intermediate evidence, not production.
Reviews: `held_final/tool_{0,1,2}_{front,back}.png` on actual player sockets;
`game/assets_{12,22,44}m.png` in Main's lighting for barrel/truck staging.
The installed truck was also checked in its live ending scene:
`ending/crackdown.png` and `ending_review.log`; no script errors.
Originals and hashes: `rollback/` and `baseline_hashes.json`. Provider tasks,
cost approval, concept hashes, prompts and CPU adapter sources are retained in M2.

Tests after the world-prop and tank installation batches:
`test_all_world.log` and `test_all_tank.log`, both **RESULT: OK (0 failures)**.
`test_equipment_motion.log`: **EQUIPMENT RESULT: 0 failures**; maximum hose
endpoint error 0.0000000149 m, palm/shaft contact metrics unchanged. These checks
test runtime transforms and transitions, not arbitrary finger-grip perfection.
Known corrupt-save JSON diagnostics and ObjectDB exit warnings remain.
All three final candidates passed the existing strict geometry/material validator.
The previously recorded V3 global-budget discrepancy is outside this batch.

## Meshy cultural-prop follow-up — 2026-10-03

First approved batch: 90 Meshy credits consumed of a 105-credit cap; balance
1416 after generation. No optional paid remesh or retry used. Three Meshy 7
single-image tasks, 2K base-colour textures, triangle topology, no PBR or Ultra.
Built-in imagegen prepared original isolated concepts using the researched
construction brief; source photographs are research-only. The leaf-roof granary
is an explicit traditional game adaptation of a photographed metal-roof rice bank.
References and limitations: `KAREN_PROP_REFERENCE_BRIEF_20261003.md`.

| ID/file | Tris | Height | Provider task | Review evidence under artifacts/meshy_props_20261003/ |
|---|---:|---:|---|---|
| S4_village_house_a.glb | 7115 / 8000 | 4 m | 01a0ffac-4d3e-70c7-911e-9c72a45d17ee | S4_a_candidate/preview.png; houses_game/assets_{12,22,44}m.png |
| S4_village_house_b.glb | 7381 / 8000 | 4 m | 01a0ffad-a9f3-739f-b0c8-1e3127bb051c | S4_b_candidate/preview.png; houses_game/assets_{12,22,44}m.png |
| S3_granary_a.glb | 5820 / 6000 | 3 m | 01a0ffb0-d87a-733f-bd9f-806518dcf40e | S3_a_front_candidate/preview.png; granary_compare.png; granary_game_front/assets_{12,22,44}m.png |

All three are installed through the existing reviewed installer, one embedded
textured surface each, flat normals, Y up, base-centred and +Z front. S3 required
an explicit -90-degree source yaw correction; no runtime placement offset is
needed. S4a bounds are 5.148 X × 4 Y × 6.210 Z m; S4b 4.461 X × 4 Y × 7.822 Z m.
Height matches the spec, which does not constrain the footprint. Check clearance
when placing houses; the stairs are included in the centred bounds.

S3 replaces the previously installed granary; its rollback copy is inside
S3_a_front_candidate/installation_*/previous.glb. S4a/b are **new deliveries**:
the manifest already requested them, but neither a previous GLB nor an S4 scene
call existed. AssetLibrary discovers them; GAME must add village placements.
The house review pictures are staged in Main's lighting, not evidence of existing
village placements. S3's enclosed storage hatch does not expose grain contents;
if the famine vignette needs a visibly open empty interior, request a separate
open-hatch variant or adjust the hook. No scripts/, ui/ or tests/test_all.gd edits.

House batch test: `test_all_houses.log`, RESULT: OK (0 failures). Granary batch
test: `test_all_granary.log`, RESULT: OK (0 failures). Existing
corrupt-save negative-test JSON errors and ObjectDB exit warnings remain in the
suite logs; do not describe these as clean error-free output.

Installed-set validation: all three delivered meshes pass. The broader validator
reports pre-existing V3 satellite issues (5335/4000 triangles, max extent 1.903 m
instead of 2 m and non-grounded origin). V3 was not changed in this batch; its
runtime bounding-box centring is already GAME-owned. See installed_validation.log.

GPU SSH was unavailable, so cleanup used local Blender 4.5.9 CPU with the existing
blender_cleanup.py and validator through build_static_mesh_local.py. Candidate
folders retain script snapshots, hashes, masters, stats, validation and rollback
records. Characters and tight-budget instanced vegetation were not changed.

Asset production only. Gameplay, UI and `tests/test_all.gd` remain GAME-owned.
Follow the updated ASSET_REQUESTS_v1.2.md and the user's approval: V3 remains
base-centred; GAME recentres its bounds at runtime. C6 is a static crowd, no rigs.
All models use flat facets, matte materials and the existing natural palette.

## Batch 1 — FX1–3

Installed `assets/vfx/flame_sheet.png` (512 square, 4×4 frames),
`smoke_sheet.png` (512 square, 2×2 variants), and `ember.png` (64 square).
All have actual alpha, exactly equal RGB channels, transparent frame padding,
and no baked orange. Flame baselines are aligned 8 pixels above the cell bottom.
Source: built-in imagegen; original files retained under
`artifacts/asset_update_v12/vfx/source/`. Technical export through
`tools/asset_pipeline/export_v12_vfx.gd`: cell packing, neutral RGB, dimensions,
and removal of imperceptible alpha speckles. No game material changes.

Review: `artifacts/asset_update_v12/vfx/review/vfx_{12,22,44}m.png`, rendered
with actual FireGrid particle settings and game lighting. Numeric evidence:
`vfx/validation.json`; alpha transition MAE at the loop seam is 0.0184,
versus a maximum internal transition of 0.119. This is a seam check, not a
claim of temporal interpolation. Frames remain generated painted sprite animation.
Import/test logs: `vfx/import.log`, `vfx/test_all.log` under the same root.

## Delivery status

**All 29 required files installed: 25 GLBs and four PNGs.** Delivered in six
reviewed batches in priority order. Every batch passed `tests/test_all.gd` with
`RESULT: OK (0 failures)`. Optional mist and ash sprites are outside this pass.
Machine-readable final dimensions, triangle counts and hashes:
`artifacts/asset_update_v12/installed_inventory.json`.


## Batch 2 — landscape (installed)

All 11 GLBs installed through `install_asset.py --reviewed`; test log
`artifacts/asset_update_v12/test_landscape.log`: **RESULT: OK (0 failures)**.

| ID | Variants | Tris each | Dimensions / conventions |
|---|---|---:|---|
| E9 grass tuft | a–c | 40 | 0.30 m tall; one vertex-colour surface |
| E6 rock | a–d | 80 | 0.60 m tall; broad grey facets and sparse lichen |
| E7 terrace wall | a–b | 124 | X exactly −0.75 to +0.75; height 0.536 / 0.530 m, depth about 0.418 m; +Z downhill |
| E8 log | a–b | 140 | 1.50 m length; exposed ends, two branch stubs |

Evidence: `grass.png`, `rocks.png`, `walls_logs.png`, and
`landscape_world/assets_{12,22,44}m.png` under `artifacts/asset_update_v12/`.
E7's first regular-block attempt was rejected; the installed source has irregular
stone faces but unchanged matching end planes. No placement offset changes.

Batch 1 full suite also passed: **RESULT: OK (0 failures)**. The full suite
retains its known corrupt-save negative-test error and two ObjectDB exit warnings.

## Batch 3 — V3 satellite (installed)

`assets/props/V3_satellite_a.glb`: **878 triangles**, 2 m maximum span,
base-centred. Two symmetric solar wings along X, +Z flight, -Y scanner lens.
Panels are canted 32 degrees about the X boom so their broad surfaces remain
readable in the title camera. Gold faceted body, open dish and visible down lens.
No ground-centring pipeline changes. GAME's bounding-box recenter is in use.

Review: `satellite_v3.png`, `satellite_underside.png`, and
`satellite_title_v3_{3,5,7}.png` under `artifacts/asset_update_v12/`.
`test_satellite.log`: **RESULT: OK (0 failures)**.
The current title's warm haze/backlighting suppresses panel blue and foil gold;
GAME may tune lighting if more colour separation is desired.

## Batch 4 — C6 villagers (installed)

Registered C6 in the manifest. Four static, unrigged, matte walking poses at
1.15 m, base-centred, +Z front. Simplified everyday tunics and broad woven bands;
these are background crowd assets, not new hero-character fidelity models.

| Variant | Character | Triangles |
|---|---|---:|
| a | Man, indigo tunic, red headwrap | 1810 |
| b | Woman, indigo long garment with woven bands, tied hair | 2098 |
| c | Elder, cream tunic, muted headwrap, grey moustache | 1842 |
| d | Teenager, cream tunic, short side-swept hair | 1766 |

Review: `villagers_v2.png`, `villagers_world/assets_{12,22,44}m.png`,
`villagers_bundle_adjusted/assets_{12,22,44}m.png` under the evidence root.
The latter compares all four against Kha-nae in actual game lighting.
`test_villagers.log`: **RESULT: OK (0 failures)**.

**GAME adjustment needed:** S7 is base-centred and 0.46 m tall. At requested
`(0,0.72,-0.2)` it covers the back of the head. Reviewed attachment is
**`(0,0.40,-0.20)`** on all four C6 variants. Their upper backs are clear.
Only the review script uses this correction; `ui/EndingScene.gd` is untouched.

## Batch 5 — U4 Hearth painting (installed)

`assets/ui/hearth/hearth_night_1920x1080.png`: 1920×1080. Faceted ridge village,
cold blue night, small warm central hearth and faint satellite streak. Central
and lower areas remain dark for the UI. Built-in imagegen used the existing title
painting as a style reference; original and prompt brief/hash are retained in
`artifacts/asset_update_v12/hearth/source.png` and `image_provenance.json`.
Technical cover export uses `export_title_canvas.gd`.

Reviews: `hearth/review_{1280x720,1280x800,960x720}.png` with actual UI;
`hearth/crop_{1280x720,1280x800,960x720}.png` through actual HearthBackdrop drawing.
Art composition survives all three cover crops. At 960×720 the existing Hearth
UI's minimum width clips the right column; GAME owns this layout issue. The
background crop itself retains the fire, village and satellite.
`hearth/test_all.log`: **RESULT: OK (0 failures)**.
The temporary concurrent AudioManager parse error resolved before final review
and installation; it is not an outstanding delivery blocker.

## Batch 6 — stumps, tools, tank and camera (installed)

| ID | Variants | Triangles each | Dimensions / conventions |
|---|---|---:|---|
| E4 bamboo stump | a–b | 72 | 0.40 m; one vertex-colour surface |
| E5 root collar | a–b | 58 | 0.30 m; one vertex-colour surface |
| T1 drip torch | a | 200 | 0.90 m; canister, separate front handle, curved spout |
| T3 rake | a | 124 | 1.40 m; rake teeth and opposing hoe plate |
| T5 sprayer wand | a | 92 | 0.80 m; brass nozzle and hose inlet |
| T4 sprayer tank | a | 184 | 0.46 m tall, 0.2742 m deep; straps toward +Z |
| V2 thermal camera housing | a | 120 | maximum horizontal span 0.50 m, height 0.411 m; lens +Z, base origin |

All held-tool handles include local Y=0.22 m; their X/Z grip centrelines are
within 1 mm of zero after normalization. The existing player offset of -0.22 Y
therefore works. The original off-centre torch/rake/wand candidates were revised
before installation. V2 supplies the housing only; GAME supplies its pole.
E4/E5 retain one surface for the game's ember/ash overrides.

Review: `stumps.png`, `equipment_v2.png`, `equipment_world/assets_{12,22,44}m.png`,
and `held_tools/tool_{0,1,2}_{front,back}.png`. Actual player hand sockets and
material loading were exercised. `test_equipment.log`: **RESULT: OK (0 failures)**.

### GAME attachment follow-up

1. **C6/S7:** lower the bundle attachment to `(0,0.40,-0.20)`, as above.
2. **T4 player tank:** a base-centred tank attached at zero to the current back
   socket covers the head and meets the hat. Reviewed correction is
   `tank.position.y = -0.23 / animator.base_scale` after reparenting to that
   socket, retaining the current scale. Compare
   `held_tools/tool_2_back.png` with
   `held_tools_tank_adjusted/tool_2_back.png`. For the non-skeletal root-position
   fallback, the equivalent reduction is Y 0.85 → 0.62; that fallback is not
   separately visually certified. Keep the geometry base-centred.
3. **Companion tools/tanks:** `SkeletalChibiAnimator._setup_separate_equipment`
   and `CompanionController.configure_borrowed_sprayer` attach T5 without the
   player's -0.22 Y grip adjustment. Apply the matching grip convention in those
   paths. Their separate-equipment tank path explicitly uses
   `CharacterEquipment.sprayer_tank()` instead of T4, so the new tank does not
   automatically replace every crew tank. Decide whether to retain the authored
   character equipment or use T4 with a calibrated base-centred socket offset.
   These are identified from code; borrowed-sprayer animation placement is not
   claimed to have passed a live review.

No `scripts/`, `ui/` or `tests/test_all.gd` edits were made by this asset pass.
The corrections above are review-only demonstrations and a handoff to GAME.

## Reproduction and final checks

- Source generator: `tools/asset_pipeline/gpu/build_v12_props.py` beside
  `build_cohesive_set.py`; uses `palette.json`, CPU Blender, no neural VRAM job.
  The optional final argument filters IDs, e.g. `E9,E6`.
- Every final GLB went through `build_asset.py --mesh`, technical validation,
  four-angle/game-distance review and `install_asset.py --reviewed`.
  Final candidates use E7 `_v2`, V3 `_v3`, C6 `_v2`, and T1/T3/T5 `_v2` folders;
  all other final candidates use the unversioned folder in the v1.2 evidence root.
- Full installed set validates with `validate_assets.py --profile quality`:
  `validate_installed.log`. Required-file audit verifies all 29 hashes, exact
  terrace width, E9's 40-triangle/one-surface ceiling, C6's height and budget,
  and tank depth. Sprite alpha/channel/frame checks are in `vfx/validation.json`.
- Final 120-frame headless smoke: `final_smoke.log`.
- PNG provenance: `image_provenance.json`; production-side README files in
  `assets/vfx/` and `assets/ui/hearth/`.

## C6 replacement — Meshy cast delivery, 2026-10-02

The user moved character assets to Meshy. C6 a–d are now the reviewed Meshy man,
woman, elder and teenager, at 2,785 / 2,784 / 2,785 / 2,786 triangles, static
walking poses, +Z front and ~1.15 m tall. Variant b is 0.784 mm taller than the
nominal height. No other offsets changed. The existing S7 bundle hook at
`(0, 0.40, -0.2)` passed four-angle review on all four. The crowd install passed
`tests/test_all.gd` with zero failures. The earlier v1.2 inventory is historical
for these four files; current hashes are in
`tools/character_pipeline/installed_meshy_cast.json`.

Review image: `artifacts/character_candidates/meshy_cast_20261002/crowd_installed_review.png`.
Full source/rejection/test/rollback record:
`tools/character_pipeline/MESHY_CAST_HANDOFF.md`.
Non-character v1.2 assets retain their existing local pipeline.


## Subsequent asset polish — installed 2026-10-02

Nineteen prop replacements and X1/X5/X6 effects are now installed. Current counts,
normalised equipment anchor offsets, review paths and four passing batch tests:
[ASSET_POLISH_HANDOFF_20261002.md](ASSET_POLISH_HANDOFF_20261002.md).
This supersedes the earlier numeric/visual entries for E1/E2/E3/E8, T1/T3/T4/T5,
S3/S6/S7 and flame; optional mist and ash are now delivered. Cast files, C6,
E7 wall mating planes, 40-triangle grass and V3 orientation are unchanged.


## Meshy expansion — 2026-10-03

V3 repaired locally; V1, V2 and S5 replaced with reviewed Meshy derivatives.
All 47 installed static props now pass strict quality validation. Two install
batches each passed `tests/test_all.gd` with zero failures. Counts, provider IDs,
exact bounds, attachment offsets, rejection evidence and review image paths:
[MESHY_EXPANSION_HANDOFF_20261003.md](MESHY_EXPANSION_HANDOFF_20261003.md).

S8 radio, S9 workbench, S10 hollow bamboo basket and S11 open empty granary are
delivered separately in `future_library/`, with reserved contracts in
`future_asset_manifest.json`. They are not registered or placed in production.
No character file or runtime script was changed by this expansion.

## Village completion — 2026-10-03

S4 and S8–S16 now have live Village Hearth placements; S11 is installed in the famine ending. The user authorized runtime integration. Five new props and compatible Idle/Talk/Scan overlays are installed, with the borrowed hose and thermal indicator corrected. Full per-ID triangles, dimensions, offsets, credits, review paths and passing checks: [completion handoff](VILLAGE_COMPLETION_HANDOFF_20261003.md). This supersedes earlier notes that GAME still needs to place these village props.

## Follow-up rig/animation delivery — 2026-10-03

The six character files now use refined skin weights and 22 updated motion records; all 34 named clips pass deformation/grounding and game integration checks. Asset geometry, UVs and albedo match the preceding approved cast. Additional spend 12 credits, balance 996. Review paths and exact per-character hashes/metrics: [rig and animation handoff](../character_pipeline/RIG_ANIMATION_HANDOFF_20261003.md).
