# Whole-game asset audit — 2026-10-02

The installed set is technically sound, but the characters are now more polished
than many props and effects. Keep the approved character identities. The next
visual work should improve fire readability, held equipment and environment
variation rather than regenerate the cast or increase every triangle budget.

This is an audit, not an asset replacement pass. No production meshes, textures,
audio, gameplay scripts, UI scripts or test assertions were changed. ASSETS.md's
obsolete coverage and VFX notes were corrected. Evidence root **B** is
`artifacts/asset_audit_20261002/`.

## Coverage and evidence

- **45 static GLBs / 26 installed manifest IDs**, all passing strict quality
  budgets, scale, grounding, material/surface and geometry checks. The manifest
  has 27 IDs: only **S4 village house a/b** is absent. Every static variant was
  rendered from four angles through the game's material-preserving loader.
- **Six rigged GLBs**: Kha-nae, Ta-poh, Mu-naw, Mae-Lu and two ranger palettes.
  All six pass geometry, embedded texture, skin, bone, animation, height and
  orientation/grounding checks. Four-angle current cast review: `characters.png`.
- **Five matching portraits**, Hearth/title art, three VFX images, seven bundled
  font faces and their licence files. Icons and several UI illustrations are
  procedural; absence of PNGs for U1/U2/U5 is not a broken asset path.
- **58 top-level WAVs plus nine review candidates**. All 67 files were inspected
  for actual sample rate, channels, duration, peaks and clipping. This is a
  technical audio audit, not a listening or pronunciation approval.
- Current scene captures: title, 16:9 and 4:3 Hearth, year-3 plot-5 gameplay and
  burn, checkpoint, famine and crackdown. Fire sprites were also rendered at
  12/22/44 m with actual game materials. These are staged snapshots, not a
  frame-rate benchmark or proof of temporal animation quality.

Machine-readable evidence: `prop_inventory.json`, `character_validation.json`,
`file_inventory.json`, `audio_inventory.json`. Filenames in those inventories
give every reviewed variant; review sheets include each asset's ID and suffix.

## Recommended order

No new asset-level P0 blocker was found. P1 below means the next polish pass,
not a claim that the game cannot run.

| Order | Priority / owner | Improvement and concrete acceptance criterion |
|---|---|---|
| 1 | P1 ASSET + GAME | **Fire and extinguishing readability.** In `vfx/vfx_22m.png`, the flames read as thin translucent brown/gold ribbons against bright terrain. Make broader, simpler flame shapes with stronger core/edge value separation; keep greyscale plus alpha. Review the animated loop against day, inversion and night lighting, with GAME tuning tint/opacity only after the neutral source is reviewed. Add `mist_sheet.png` and `ash_flake.png` to the existing hooks. Distinguish burning, smouldering and cooled ground at the normal camera, not just close up. |
| 2 | P1 ASSET + GAME | **Held tools and sprayer continuity.** Keep T1–T5 dimensions and grip anchors, but strengthen readable handles, fittings and material breaks within current ceilings. The current open hands do not form convincing close-up grips. Kha-nae's player tank/wand path has no connecting hose; Mu-naw has a dynamic hose. Deliver fitting locations and per-tool grip references for GAME. Add the still-open T2 belt/off-hand detail only after agreeing its runtime hook. Test carry, work, run and cough, without changing faces or costumes. |
| 3 | P1 ASSET; placement GAME | **Vegetation and repeated silhouettes.** E1 variants are mostly different sizes of the same tiered cone; E2 has very sparse crowns; E8 variants are nearly identical logs. Give variants different branch/crown masses, bends and broken ends. E3's spherical clumps can have more varied broad outlines. Preserve E1 ≤300, E2 ≤400, E3/E8 ≤150 and E9 ≤40 triangles. Compare clusters from the normal camera; extra tiny leaves will not solve the repetition. |
| 4 | P1 AUDIO + GAME | **Music layer synchronization.** Current layer 0 is 15.713061 s; layers 1/2 are 15.765306 s, a 52.245 ms difference per wrap. Generation used separate prompts, and the installer rotates each loop independently. The mixer starts/stops each layer independently. These are not guaranteed phase-aligned stems. Deliver a shared-duration/bar-aligned set and have GAME preserve a shared playback phase; audition combinations and intensity transitions. No claim is made that a particular audible glitch was heard in this audit. |
| 5 | P2 ASSET | **Granary, truck and pack finish.** S3's roof/walls, S6's cab/wheels and T4/S7's large plain surfaces look simpler than the cast. Use intentional silhouette breaks, a restrained cloth/wood/metal palette and a few large construction details; do not add noisy photorealistic textures. Prioritize T4 because it is seen constantly; S6 is an ending prop. Preserve all pivots, dimensions and attachment conventions. |
| 6 | P2 ASSET + GAME | **Village house gap.** Create S4 a/b only once a current scene placement is identified. No S4 loader call was found in live scripts/UI/scenes; the Hearth uses a painting, while village scenery is procedural. Dropping two GLBs in assets/props alone will not make them visible. |
| 7 | P2 GAME/build, ASSET assists | **Export hygiene and texture memory.** Twelve superseded model/OBJ files (23.19 MiB raw source) remain in assets/models with no current scene/script references found. Export uses all_resources and does not exclude those paths or audio/v11_candidates. Review dependencies and move/archive or exclude them without losing rollback. Current six 2K albedo imports use lossless mode (`compress/mode=0`, `vram_texture=false`) with mipmaps: compare a platform texture-compression candidate, especially on handheld hardware. Raw file size is not measured package/VRAM saving. |
| 8 | P2 GAME/UI | **Hearth 4:3 clipping and background readability.** `hearth_4x3.png` still crops the right-hand card column. The background artwork itself is intact. Fix layout, not the painting. The 16:9 UI is readable and covers most of the art; new decorative panel art has little value until spacing is settled. |

## Asset-by-asset disposition

| IDs / variants | Current condition | Decision |
|---|---|---|
| C1 Kha-nae | 19,798 triangles; locked user-reference correction, gear restored; current tests pass | Keep identity. Refine grip/gear integration, not a new face. |
| C2 Ta-poh | 19,374 triangles; readable red/cream elder silhouette, current rig contract passes | Keep approved design; review borrowed-sprayer hose/grip as equipment work. |
| C3 Mu-naw | 19,541 triangles; 21 bones including garment controls; authored bamboo equipment remains intentional | Keep approved design; retain separate hose and tank. Do not force yellow T4 onto her. |
| C7 Mae-Lu | 19,436 triangles; 21 bones, six clips; actual village portrait works | Keep. Facial/finger animation is not delivered and is not necessary for current distant views. |
| C5 olive/slate ranger | 18,522 triangles each, eight clips; materials and equipment tests pass | Keep palettes and silhouettes. Refine tablet/flashlight hand contact only if close-up cinematics need it. |
| C6 a–d | 2,785 / 2,784 / 2,785 / 2,786 triangles; four static walking poses | Meets the explicit no-rig request. Faces/costumes resemble crew; optional future colour/hat diversity, no automatic rigging scope expansion. |
| E1 a–c | 260 each, readable but very similar tiered pines | Broaden silhouette variation within 300. |
| E2 a–c | 360 each, five-culm bamboo, thin sparse foliage | Reallocate existing leaf triangles into broader crown groups within 400. |
| E3 a–d | 136 each, dry/green palettes distinguish fuel | Keep palette roles; diversify clump outlines, reduce repeated ball shapes. |
| E4 a/b | 72 each, hollow cut culm groups | Keep; silhouette is adequate, material is deliberately overridden by burn state. |
| E5 a/b | 58 each, chunky root shapes | Keep for gameplay scale. No fine roots needed. |
| E6 a–d | 80 each, matte faceted grey rocks | Keep; optional more distinct tall/slab silhouettes after vegetation. |
| E7 a/b | 124 each, end planes at X ±0.75 | Keep dimensional contract. More irregular stone grouping is secondary. Curved placement, overlap and terrain gaps belong to GAME. |
| E8 a/b | 140 each, branch stubs and cut ends | Vary bend, diameter and branch direction within 150. |
| E9 a–c | 40 each, one vertex-colour surface | Keep strict ceiling. Current code attempts 5,000 placements before patch filtering, above the request's 1,600; do not treat that as 5,000 visible instances or raise the mesh budget. |
| S1 hut | 5,845 triangles, one textured surface; coherent stilts/roof, reads in game | Keep. Minor broad roof/wood palette polish only after everyday props. |
| S2 water barrels | 464, refill silhouette and blue cue readable | Keep. |
| S3 granary | 516, functionally clear but very plain flat roof/walls | Improve broad construction detail for ending close-ups. |
| S4 a/b | Absent | Backlog with placement dependency, not a current v1.2 delivery failure. |
| S5 checkpoint | 316, side barrier/sandbags, game adds moving arm | Keep mechanics and blank/unmarked convention. Stage dressing is sparse; GAME owns placement. |
| S6 truck | 380, highly box-like body/wheels, static by design | Polish silhouette within manifest budget; no wheel rig requested. |
| S7 bundle | 96, legible knot but plain blue bag | Optional restrained woven band/fold facets; current (0,.40,-.20) crowd attachment is resolved. |
| V1 drone | 428, separate game rotor discs | Keep. Actual geometry/mount checks pass with initialized patrol-state audit fixture; old standalone fixture needs maintenance. |
| V2 camera | 120, red lens/hood/panel, supplied pole by GAME | Keep; readable from gameplay distance. |
| V3 satellite | 878, symmetric X wings, down scanner, correct title placement | Keep orientation and recenter contract. Optional broad body/panel detailing for the large title view; no need to spend the full 4K ceiling. |
| T1 torch | 200, full current budget, grip at .22 m | Improve shape allocation, not triangle count. Review canister handle and outlet against hand/flame position. |
| T2 mida | 68, blade/handle clear, grip at .07 m | Keep Ta-poh use; Kha-nae belt detail remains unimplemented. |
| T3 rake | 124, identifiable head but very thin/plain shaft | Improve handle/head readability; solve two-hand contact with GAME. |
| T4 tank | 184, yellow faceted canister with straps | Highest everyday-prop polish opportunity; preserve base-centre and corrected lowered attachment. |
| T5 wand | 92, brass nozzle and black grip | Add/readably place hose fitting; preserve .22 m grip convention. |
| T6 flashlight | 104, simple clear silhouette and lens | Keep. Beam follows held prop. |
| T7 tablet | 24, intentionally blank screen | Keep current spec. Screen content would be GAME/UI scope. |
| X1–3 / FX1–3 | Flame/smoke/ember installed | Improve flame readability; preserve tintable source channels. Smoke stays soft enough to blend but chunky in outline. |
| X4–6 | Procedural steam, water and ash already exist | Dedicated mist/ash textures are the useful next deliverables; do not describe these actions as having no VFX. |
| U1/U2/U5 | Procedural icons/cards in current UI | Keep until a specific unreadable icon is identified. No blanket raster replacement needed. |
| U3 | Five 256px transparent portraits | Keep model-derived portraits; no independent face regeneration. |
| U4/U6 | Hearth painting and title illustration delivered; live title is a 3D scene | Keep. Illustration is also README art; new title painting will not fix the 3D satellite. |
| U7 | Kanit and Chakra Petch, seven font faces, OFL files | Keep Thai typography; review glyph coverage for any newly introduced symbols. No missing-glyph defect was established in these captures. |
| A1/A3 | Installed Thai warnings and radio catalogue | Preserve. This audit does not reassess acting or cultural pronunciation. |
| A2 | Active barks plus nine older review-only candidates | Avoid treating all candidates as shipped or replacing the active barks blindly. Listening review still needed for those candidates. |
| A4–6 | Recorded/synthesized drop-ins and fallbacks present | No PCM clipping found. Static/wind loop boundary ratios ~.102/.151 are listening leads, not proof of an audible click in noisy material. |
| A7 | Three installed generated music loops | Align musical structure, length and runtime phase, as above. |

## Existing integration fixes verified; do not reopen as missing work

GAME has already lowered the player T4 tank, applied companion grip offsets,
lowered S7 on C6, given the title satellite a fill light, and corrected upright
tool carry after the Meshy switch. Mu-naw's authored bamboo tank is intentional.
These are reflected in current code and scenes, despite older handoff warnings.

The remaining stylistic mismatch is not solved by smoothing every object or
adding microtexture. Keep matte facets, broad natural colours and gameplay-scale
readability. The cast's user-approved references stay locked.

## Validation limitations and harness findings

Current full suite: `test_all.log`, **RESULT: OK (0 failures)**. Character,
ranger, prop-material and character-material checks pass; 120-frame headless
smoke passes. Two known ObjectDB exit leaks remain in the full suite.

`tests/test_cohesive_props.gd` is stale against the current drone controller:
direct class loading caused an autoload-order compile error, and the manually
built drone did not initialize its new patrol state. A copy in B uses deferred
script loading and sets `on_station=true`, `_phase_left=10` before the same
rotor assertions; `test_cohesive_deferred.log` passes. This identifies a test
maintenance task, not evidence that the in-game rotors are broken. The original
test was not changed or represented as passing.

Initial audit scene harness attempts likewise loaded autoload-dependent classes
too early and did not reset campaign statistics before constructing endings.
The audit tool now dynamically loads those scenes and resets the isolated
campaign. Final scene logs have no script errors. Real player saves were not
used: all scene captures set save/settings/log directories under B/audit_save.

Rigs' detailed motion limits remain those in the character delivery handoffs:
no facial or individual finger rig, no arbitrary extreme-pose certification.
Performance checks here establish mesh budgets and import settings only;
Steam Deck GPU time, overdraw and memory require a device profiling pass.

## Visual index

All links below point to this audit's fresh captures.

- [All six rigged variants](../../artifacts/asset_audit_20261002/characters.png)
- [Tools/tank](../../artifacts/asset_audit_20261002/tools_1.png), [ranger equipment](../../artifacts/asset_audit_20261002/tools_2.png)
- [Structures](../../artifacts/asset_audit_20261002/structures_1.png), [travel bundle](../../artifacts/asset_audit_20261002/structures_2.png)
- [Pines/bamboo](../../artifacts/asset_audit_20261002/vegetation_1.png), [bamboo/brush](../../artifacts/asset_audit_20261002/vegetation_2.png)
- [Burnt stumps](../../artifacts/asset_audit_20261002/burnt_1.png)
- [Rocks/wall](../../artifacts/asset_audit_20261002/landscape_1.png), [wall/logs/grass](../../artifacts/asset_audit_20261002/landscape_2.png), [third grass](../../artifacts/asset_audit_20261002/landscape_3.png)
- [Surveillance](../../artifacts/asset_audit_20261002/surveillance_1.png), [crowd](../../artifacts/asset_audit_20261002/crowd_1.png)
- [Fire at 22m](../../artifacts/asset_audit_20261002/vfx/vfx_22m.png), [actual burn close-up](../../artifacts/asset_audit_20261002/burn_close.png)
- [Title](../../artifacts/asset_audit_20261002/title.png), [gameplay](../../artifacts/asset_audit_20261002/main.png)
- [Hearth 16:9](../../artifacts/asset_audit_20261002/hearth.png), [Hearth 4:3](../../artifacts/asset_audit_20261002/hearth_4x3.png)
- [Checkpoint](../../artifacts/asset_audit_20261002/checkpoint.png), [famine](../../artifacts/asset_audit_20261002/famine.png), [crackdown](../../artifacts/asset_audit_20261002/crackdown.png)
