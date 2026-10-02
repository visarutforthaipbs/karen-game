# Meshy cast delivery — 2026-10-02

**Kha-nae correction:** The user rejected the original Kha-nae likeness after
this delivery. His model and portrait have been replaced using the exact supplied
reference. See [KHANAE_LIKENESS_HANDOFF.md](KHANAE_LIKENESS_HANDOFF.md) for the current
source, tests and rollback. The other characters remain unchanged. The original
Kha-nae production/test details below are historical, not evidence for his new rig.

All requested character models are replaced in the game: **six rigged GLBs**
(five characters plus the ranger slate variant), **four static C6 GLBs**, and
**five matching portraits**. Existing scene paths, bone names, animation names
and equipment hooks are retained. C6 is registered with the `meshy` route; the local
prop CLI accepts its reviewed static GLB but refuses local image generation or
neural retexturing. Five asset-pipeline validation/install tests and the C6
routing check pass. No gameplay, UI or `tests/test_all.gd` edits
were made by this character-delivery work. Other tasks have concurrent changes
in those areas; this is not a clean-repository claim.

Exact installed paths, hashes, counts and Meshy task IDs are in
[installed_meshy_cast.json](installed_meshy_cast.json).
Evidence root: `artifacts/character_candidates/meshy_cast_20261002/` (called **B**
below). Raw downloads, rejected attempts and script snapshots are retained there.

## Installed inventory

| ID / character | Triangles | Height | Bones | Baked clips |
|---|---:|---:|---:|---|
| C1 Kha-nae (corrected reference) | 19,798 | 1.20 m | 19 | Idle, Walk, Run, ToolUse |
| C2 Ta-poh | 19,374 | 1.15 m | 19 | Idle, Walk, Run, ToolUse |
| C3 Mu-naw | 19,541 | 1.10 m | 21 | Idle, Walk, Run, ToolUse |
| C7 Mae-Lu | 19,436 | 1.15 m | 21 | Idle, Walk, Run, ToolUse, Talk, Granary |
| C5 ranger, olive and slate | 18,522 each | 1.25 m | 19 | Idle, Walk, Run, Scan, Photograph, Point, RadioTalk, Escort |
| C6 man / woman / elder / teenager | 2,785 / 2,784 / 2,785 / 2,786 | ~1.15 m | 0 | Static walking poses, as requested |

Principal models are `assets/models/<name>_rigged.glb`; the slate file is
`assets/models/ranger_slate_rigged.glb`. C6 is `assets/props/C6_villager_[a-d].glb`.
Portraits are `assets/ui/portraits/<name>_256.png`, 256×256 RGBA rendered from the
replacement geometry/materials, with framing and hashes in their manifest.

All models remain +Y up, +Z front, metre scale and base-centred. No new game
offsets are required. C6 woman measures 1.150784 m after preparation, a +0.784 mm
height deviation; other C6 heights are effectively 1.15 m. The existing S7 bundle
offset `(0, 0.40, -0.2)` was reviewed on all four replacements and retained.
Principal meshes have one textured surface and four normalized skin influences.
The two skirt bones keep Mu-naw's and Mae-Lu's closed hems off opposing leg weights.

## Production and rejected attempts

The source provider is official Meshy MCP 0.5.2, using `meshy-7` image-to-3D,
approved isolated v3.1 references, T-pose principals, triangle topology,
19,900 target triangles, 2K albedo, PBR off and remesh on. Meshy supplies the
finished surface and joint landmarks. Its raw skin was replaced with calibrated
local weights, and the established game clips were baked onto the game skeleton.
Free Meshy walk/run downloads remain available as source material; they are not
the delivered game clips. This preserves the existing semantic work layers.

Accepted versions are `<name>/final_v14/` for the four main characters and
`ranger/final_v15/`. Each contains GLB, Blender source and `rig_report.json`.
`B/pipeline_snapshot/` records the v14 build scripts; the ranger's v15 snapshot
is under `ranger/final_v15/pipeline_snapshot/`. The current adapter additionally
rejects source hashes outside this reviewed cast. New generations require fresh
landmark/weight calibration.

Corrections made during review:

- Removed unwanted emissive albedo and excessive specular from Meshy's rig export;
  retained matte flat facets and the generated albedo.
- Calibrated shoulders, sleeves, fingers, crotch and the full closed skirt hems.
  Mu-naw's earlier moving-spray skin and Kha-nae's cough seam were rejected.
- Kept the lowered-arm base when layering T-pose gestures, and bent elbows in
  their posed basis. Ranger RadioTalk now lifts the left hand toward the shoulder.
- Preserved geometry, skin and animation bytes when creating the slate palette;
  only the embedded albedo changed. The UV bake is retained in ranger v13, with
  the final texture-transfer hashes in ranger v15.
- Rejected the first four text-only crowd candidates for long-legged, inconsistent
  proportions. Generated four coordinated reference images with built-in imagegen,
  then used Meshy image-to-3D at a 2,800 target without a T-pose override. Exact
  prompts, style references and image paths: `B/crowd_reference_prompts.json`.

Saved API task results record **415 credits consumed across 22 tasks**, including
the rejected crowd batch. Final read-only balance snapshot: **1,619 credits**.
The account received other credit changes during the run; do not infer cost from
the initial/final balance difference. See `B/observed_credit_ledger.json`.

## Validation and reviews

Installation batches: C6, then four main characters/portraits, then both ranger
variants/portrait. `tests/test_all.gd` returned **RESULT: OK (0 failures)** after
each batch: `crowd_install_gameplay.log`, `crew_install_gameplay.log`, and
`ranger_install_gameplay.log` under B. The full-suite exit still reports the same
two ObjectDB leaks seen in the pre-install baseline; they are not new failures.

The existing asset-specific tests had exact counts for the old local meshes.
Only those numeric fixtures were updated to the reviewed replacement counts in
`test_skeletal_character.gd`, `test_v31_assets.gd` and `test_ranger_assets.gd`.
Their skin, clips, controller, attachment and material assertions were retained.

| Check | Result / evidence under B |
|---|---|
| Principal GLB geometry, UVs, embedded textures, finite values, normalized weights, bones, clips, height/grounding and no emission | All six pass; `final_delivery_validation_accepted.json` |
| C6 static geometry, budgets, scale and materials | Four pass; `crowd_delivery_validation.log` |
| Actual semantic work layers, velocity 0 and ±X/±Z at 6 m/s | Four pass; `final14_runtime_flat.json` |
| Same actions on 20% grade with cough | Four pass; `final14_runtime_slope.json` |
| Ranger olive/slate: all eight clips, 13 real-renderer samples each | Pass; `final15_ranger_deformation.json` |
| Actual controller work/cancellation/companion behavior | `installed_motion_test.log`: 0 failures |
| Kha-nae articulation, repeated input, root motion and real player hand socket | `installed_skeletal_final.log`: pass |
| All four installed skins/UVs/clips/equipment | `installed_cast_test.log`: 0 failures |
| Both ranger scenes, timed clips, patrol beam attachment, portrait alpha | `installed_ranger_test.log`: pass |
| Mae-Lu live village Granary gesture | `maelu_village_review.log`: pass |

Worst sampled runtime stretch for edges longer than 3 mm: Kha-nae **2.647**,
Ta-poh **3.004**, Mu-naw **3.314**, Mae-Lu **2.362**, below the unchanged **3.5**
gate. Both ranger palettes peak at **3.117**; sampled clip grounding error stays
below **0.15 mm**. These are bounded samples, not a guarantee for arbitrary poses.

Visual evidence, inspected after rendering in Godot:

- `final14_cast_review.png`: five-character four-angle lineup (ranger appearance
  is unchanged in v15; only RadioTalk changed).
- `final14_motion_review.png`: actual rake/spray layers and village/ranger gestures.
- `ranger/final_v15/review.png`: final Photograph and RadioTalk with equipment.
- `crowd_installed_review.png`: four C6 models using the actual ending's S7 hook.
- `gameplay_review/`: installed crew in Main with ignition, rake, spray, moving
  work, cough and run, from four directions and close-ups.
- `maelu_granary.png`: installed Mae-Lu in the village UI.
- `meshy_cast_gameplay.mp4`: 10.5-second, 24 fps in-place pose reel in the actual
  game scene. This demonstrates animations and work layers, not movement AI.

## Remaining limits and rollback

These are gameplay rigs. There are no facial or individual finger bones; hands
use the existing open-hand grip convention. Tight finger closure, close-up prop
contact, cloth collision and arbitrary deep crouches are not certified. The
supplied/generated costume references still lack documentary cultural validation,
as recorded in the previous SOP. None of these is represented as completed work.
No incompatible game hook was found in the tested paths.

Rollback copies and SHA-256 inventory are in `B/rollback/`. To revert a delivered
file, copy its matching relative path from that directory back into the project,
reimport with Godot, and rerun the full gameplay suite. Do not use a blanket git
reset: other tasks have independent work in this shared checkout. Update the
installed inventory and matching portraits/count fixtures if rolling back.
