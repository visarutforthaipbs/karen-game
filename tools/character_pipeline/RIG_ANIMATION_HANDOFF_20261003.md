# Rig and animation improvement — 2026-10-03

Installed locally following the user's request to improve the rigs and all animation, with an approved 300-credit ceiling. Spent **12** credits; verified balance **996**. All five previously purchased Meshy rigs already include walking/running, so no new rigging jobs or character regeneration were needed. The two ranger palettes share motion sources.

## Changes

Six character GLBs (four crew, olive/slate ranger) have refined skin weights. Eight adjacency iterations at 0.2 strength smooth joint transitions, restricted to each vertex's existing carrier bones. The top four influences remain normalized. Head, Bag, Hand and Foot dominant carriers above 0.90 retain their original weight distributions. Opposing leg/garment influences are not newly introduced. This changes the skin weights intentionally; it does **not** change rest geometry, UVs, albedo, material definitions or skeleton landmarks. Independent preservation reports pass for all six.

All 34 named clips were inspected and sampled. **22 clip records changed**; 12 others retain their prior records and benefit from the refined skin:

| Character | Changed clips |
|---|---|
| Kha-nae | Walk, Run, Idle |
| Ta-poh | Walk, Run |
| Mu-naw | Walk, Run |
| Mae-Lu | Walk, Run, Granary |
| Ranger, both palettes | Walk, Run, Escort, Point, RadioTalk, Photograph |

The new gait route transfers bind-relative limb rotations onto the approved anatomy, retains approved hips/root/cloth pose tracks, and recomputes root grounding from evaluated skin. Limb gain is 0.65, arm gain half that; Ta-poh's Run uses 0.35 for a restrained elder gait. Root translation from the provider is never copied. The last 10% smoothly closes the loop. Exact validated candidates and intermediate/rejected trials are retained.

Kha-nae Idle adds restrained chest/head breathing. Mae-Lu's Granary has a restrained basket-handling gesture; no new gameplay account or field AI is introduced. Ranger Point/RadioTalk retain authored hands, with restrained torso/head movement from provider gestures. Photograph uses local arm-chain solving to raise and extend the tablet clear of the torso; this is a local correction, not a provider-generated photo preset.

Gameplay work stays semantic/procedural. Rake stroke depth increases from 0.018 to 0.035 m while the two palms retain shaft contact. Spray adds a small side sweep. Walk/Run changes preserve normalized step phase and use 4.6/4.2 m/s hysteresis to avoid boundary flicker. Ranger walking/running/escort cadence responds to velocity; one-shot gestures reset to normal playback speed and clear omitted constant bone poses. Gameplay speeds, task timing, water accounting and action reach are unchanged.

## Import fidelity and acceptance

The new motion is authored at 60 fps. Importing it at 30 fps caused ranger foot errors up to 3.86 mm through resampling. The six production `.glb.import` files now use `animation/fps=60`. Candidate inspectors use `GLTFDocument.generate_scene(state, 60.0)` to match production. This fixes sampling fidelity; the existing rejection limits remain **3.5× edge stretch over 3 mm** and **2 mm grounding error**. The all-clip checker now records per-clip results and checks grounding for every character, in addition to finite skin vertices.

| Character | Clips | Before: worst stretch | Installed: worst stretch | Max ground error (mm) |
|---|---:|---:|---:|---:|
| khanae | 4 | 2.375× | 1.456× | 0.684 |
| maelu | 6 | 2.531× | 2.009× | 0.738 |
| munaw | 4 | 3.393× | 1.668× | 0.938 |
| ranger | 8 | 3.117× | 2.636× | 1.541 |
| ranger_slate | 8 | 3.117× | 2.636× | 1.541 |
| tapoh | 4 | 3.202× | 2.252× | 0.169 |

Before measurements are the immediately preceding installed rigs sampled using the former 30 fps import. Installed measurements use the documented 60 fps production import. These are pipeline comparison measurements, not an isolated weight-only experiment or a guarantee for arbitrary poses.

Four crew also pass actual work/slope/cough runtime layering: maximum sampled stretch 2.450× (Kha-nae), 1.902× (Ta-poh), 1.682× (Mu-naw), 1.871× (Mae-Lu). Moving-hose fitting error is below 0.0001 m; rake palms stay approximately 0.249 m apart, with maximum sampled shaft error 1.076 mm.

## Paid sources

| Source | Preset ID | Task ID | Credits |
|---|---:|---|---:|
| Mae-Lu basket handling | 278 | `01a10025-bf4e-75b6-a778-6e2cb27a7630` | 3 |
| Ranger conversation | 312 | `01a10025-c229-73e9-826e-22bef0c61974` | 3 |
| Ranger right-hand gesture | 314 | `01a10025-c4c0-739d-b586-6b3aed0e5967` | 3 |
| Kha-nae breathing | 31 | `01a10025-c690-7473-9df9-7e57d4d783e0` | 3 |

Sources were checked against the [official Meshy preset library](https://docs.meshy.ai/en/api/animation-library). Godot's [generate_scene bake_fps parameter](https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html#class-gltfdocument-method-generate-scene) documents the matching import control. Provider success alone does not grant installation approval.

## Reproduction and evidence

Evidence root: `artifacts/animation_upgrade_20261003/` (kept outside resource scans). `installation.json` records all installed hashes; `rollback/` contains the prior six GLBs **and import settings**. Restoring a rig also requires restoring its `.import` and reimporting.

Reusable builders:

```sh
/Volumes/Blender/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 \
  --python tools/character_pipeline/retarget_meshy_motion.py -- \
  --source walking_source.glb --target approved.glb --output candidate.glb \
  --clip Walk --gain 0.65

/Volumes/Blender/Blender.app/Contents/MacOS/Blender -b --python-exit-code 1 \
  --python tools/character_pipeline/refine_skin_weights.py -- \
  candidate.glb weighted_candidate.glb approved.glb
```

The final positional argument supplies the original approved weight reference, avoiding cumulative smoothing across repeated passes. Source/reference positions, nodes and skins must match. These tools produce candidates; they do not install. Run contract/preservation, all-clip, runtime work/slope, ranger grounding, equipment, transition and game tests and inspect actual rendered poses. Use the 60 fps import setting for this route. The separate quiet overlay helper remains available for conservative Idle/Talk/Scan transfer.

Passing evidence:

- `accepted_contract.json`, `*_preservation.json`: bone/clip/material/geometry/UV contracts.
- `installed_clips.json`: all 34 installed named clips, per-clip deformation and grounding.
- `accepted_runtime.json`: work, all movement directions, slope/cough layering.
- `accepted_ranger_ground.json`: both palettes, all eight ranger clips, strict grounding.
- `test_all_final.log`: full game suite, **0 failures**.
- `skeletal.log`, `transitions_final.log`, `equipment_installed.log`, `gameplay_installed.log`, `village_installed.log`: actual imported-model and game integration checks, **0 failures**.
- `gait_review.png`, `gesture_review_0.png`, `gesture_review_1.png`, `photo_review.png`: multi-angle reviews. Earlier equipment review showing a buried tablet is a rejected state.
- `installed_motion.mp4` / `installed_motion.gif`: 10.5-second **in-place** review in the real game of work, run, moving-work and cough. This is not a player-navigation recording. Tests separately exercise real movement and water/task effects.
- `credit_ledger.json`, `gesture_jobs.json`, `provider_sources.json`, `raw/`: sources, task records and local downloads. Do not publish transient signed URLs.

The old 0.65-gain Ta-poh running trial exceeded 3.5× before weight refinement and was rejected; the installed elder uses the restrained 0.35 candidate. The old full-body idle transfer remains rejected. No acceptance limit was relaxed.

## Limits

These are gameplay rigs and sampled approvals. Fingers and faces are still unrigged. Fast stylized navigation can still slide feet; the bounded terrain solver does not certify arbitrary deep crouches or tall terrace steps. The review reel is in place. Cultural signoff and low-end/Steam Deck performance measurement remain pending. Godot still reports some exit-time ObjectDB/resource leaks in otherwise passing tests. No release rebuild, Git push or website deployment was performed.
