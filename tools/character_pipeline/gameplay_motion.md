# Gameplay character motion — 2026-10-02

All three installed character scenes now use individually calibrated 19-bone
skins and the shared skeletal gameplay animator. The accepted source geometry,
textures, faceted silhouette and cultural details are preserved. No neural
regeneration was used for this work.

## Controller contract

- `set_work(kind, active)`: ignition, rake/clearing, or spray state. Repeated held
  updates do not restart a wind-up. Lower-body locomotion continues during work.
- `update_animation(delta, velocity, face_dir)`: Idle/Walk/Run selection and
  speed scaling, aim-facing, directional foot targets and work layers.
- `set_environment(grid, coughing)`: bounded foot correction plus a small
  chest/head cough layer. This never alters movement speed or stamina itself.
- `cancel_work()`: immediate cancellation on tool changes, orders, rally/flee
  and satellite stopping. It resets to idle, including when AI processing stops.

Kha-nae has distinct torch, two-hand rake and wand holds, supplied by hand targets.
Ta-poh uses the blade already in his source mesh for clearing. His borrowed
sprayer adds a chest tank and left-hand wand while keeping the blade in his right
hand. Mu-naw keeps his authored two-hand wand/hose hold and aims with the upper
body; his arms do not swing through the fused equipment during running.

Successful cell changes emit short faceted water/dirt/ember feedback. Effects
are visual only: controller cooldowns, reach, work progress, water accounting,
upgrades and smoke rules retain their existing gameplay values. Companion tasks
still finish according to work progress rather than an animation timer.

## Pipeline changes and calibration findings

`run_rig.py` now names outputs after the selected character. Profiles exist for
Kha-nae, Ta-poh and Mu-naw. Builds export Idle, Walk, Run and legacy ToolUse, with
30 fps sampled deformation checks. The generic clip is retained for backwards
compatibility; actual tool work uses runtime layers, so exporting a GLB alone
does not export the complete gameplay behavior.

Mu-naw's anatomical midline is X=-0.075 m. His projecting equipment shifts the
mesh bounds away from the body centre. Using X=0 to split weights stretched one
leg severely. A trial that cut faces was rejected; the accepted rig keeps all
source geometry and corrects the anatomical calibration instead.

Kha-nae's basket rim was partly captured by the old arm envelope. Deep two-hand
work exposed that error although the old small generic swing passed. The arm
weight region now follows the sloping underside of the A-pose, with a broader
blend above the basket. Runtime layer testing is required as well as baked-clip
metrics; never raise a threshold to hide a failed pose.

Bone poses reset before every manually advanced base animation, preventing
runtime overlays from accumulating on constant tracks removed by import
optimization. Directional foot targets replace sharp pelvis twists that damaged
the tunic. Both hand sockets and the chest attachment preserve rigid equipment.

## Evidence and limitations

Evidence lives in `artifacts/character_motion_20261002/`: source views, candidate
builds/reports, rejected trials, rollback files, installed views and runtime
validation results. `review_gameplay_motion.gd` renders the real scene, while
`test_motion_deformation.gd` measures current skinned poses with the real renderer.
Headless rendering cannot bake those poses.

These are gameplay rigs, not cinematic or universal retargeting rigs. Fingers
and faces remain unrigged; the hands do not have animated finger closure.
Mu-naw's fused equipment limits independent arm reposing. Terrain correction is
bounded to protect joints; large terrace steps, fast stride/contact polish and
deep bends remain visual limitations. Whistle, refill and Thermal Eye retain
existing gameplay/SFX/VFX without new compulsory gesture or movement locks.

Run the tests and keep their logs; do not equate a passing integration test with
perfect visual contact. The full gameplay suite currently includes a separate
drone test expecting `on_station`, which the current drone script lacks.
