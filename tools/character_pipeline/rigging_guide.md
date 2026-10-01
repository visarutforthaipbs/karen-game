# Character Rigging & Animation Guide

## Current implementation

Kha-nae uses an implemented, calibrated Blender rig. `rig_character.py` builds
it and `run_rig.py` orchestrates the remote build. The profile is
`rig_profiles/khanae.json`, with Y-up, +Z-front landmarks in metres and approved
source hashes. This replaces the earlier unimplemented `scripts/auto_rigify.py`
proposal. Ta-poh and Mu-naw still use procedural animation.

```bash
python3 tools/character_pipeline/run_rig.py \
  --input artifacts/khanae_refined_pipeline_validation/candidate/khanae_40000tris.glb \
  --profile tools/character_pipeline/rig_profiles/khanae.json
```

Outputs: `khanae_rigged.glb`, editable `khanae_rig.blend`, `rig_report.json`,
`run.json`, build log and input/script/profile snapshots. Previous outputs are
never overwritten. The runner does not install candidates automatically.

## Skeleton and weights

The 19 bones are Root, Hips, Spine, Chest, Neck, Head, Bag; paired UpperArm,
Forearm and Hand; and paired Thigh, Shin and Foot. There are no finger or facial
bones. Bone positions are calibrated for the refined 1.20 m Kha-nae mesh.

Weights use anatomical regions with smooth transitions and at most four
normalized influences. A global nearest-bone assignment is unsuitable here:
the large hat sits close to the shoulders, the arms are short, and the basket is
fused to the clothing. The head and hat vertices above 0.705 m are assigned fully
to Head. The basket core follows Bag/Hips; its fused clothing boundary is blended
so a rigid discontinuity does not stretch the adjacent trouser triangles.

On each new mesh, inspect shoulders, elbows, wrists, crotch, knees and ankle
regions. Check palms in lowered-arm poses, not just the A-pose. The first trial
anchored some low hand vertices to the torso; pose renders exposed and corrected
that error. Maximum edge-stretch metrics help identify local weighting problems
that triangle count and finite-coordinate checks cannot catch.

Do not reuse the current region thresholds for another character without
calibration. Ta-poh's turban should follow Head; Mu-naw's tank should follow Chest.
An accessory fused into the body may need separation or a carefully blended join.

## Clips and runtime

- **Idle:** 2.4 seconds, subtle chest/head movement, lowered arms, looping.
- **Walk:** 0.8 seconds, alternating thighs, knees and arm swing, looping in place.
- **ToolUse:** 0.7 seconds, a generic arm/forearm action and torso lean, one shot.

The clips are sampled at 30 fps, include grounding adjustment and are exported
as separate GLB actions. Bone rotations are transformed from the character's
rest axes to each bone's local basis. The build checks finite deformed vertices,
normalized weights, rigid head assignment and grounding across sampled poses.

`SkeletalChibiAnimator.gd` retains the controller interface used by the game,
crossfades locomotion, prevents held-input events from restarting ToolUse, and
returns to locomotion after the action. It does not apply the legacy whole-model
squash/stretch. The Hand.R socket follows the palm; Chest carries the tank.

## Acceptance and remaining polish

Run `tests/test_skeletal_character.gd` and the material/game regression checks
listed in [SOP](../../SOP.md). Render Idle, opposing walk phases, and the action
peak from front/45°/side/back. Then inspect the installed player with its real
tools using `preview_rig_in_game.gd`.

This is an initial gameplay rig. It does not include finger closure, facial
expressions, tool-specific contact choreography, terrain foot IK or universal
retargeting. In-place walk speed is adjusted by the runtime controller; foot
sliding at gameplay speeds and uneven terrain still needs polish. The neural
mesh is triangulated, not a manually retopologized animation mesh; deeper bends
may need topology work beyond weight tuning.
