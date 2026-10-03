# Installed v3.1 gameplay motion — 2026-10-02

All four selected v3.1 meshes now have calibrated, installed gameplay rigs.
Kha-nae and Ta-poh use 19 core bones; Mu-naw and Mae-Lu add two garment controls.
Each exports Idle, Walk, Run and ToolUse. Mae-Lu additionally exports Talk and
Granary; her live village portrait gestures when a ration is selected, without
changing ration accounting or introducing field AI.

The three field characters keep their controller contracts and game speeds.
Kha-nae uses a two-hand rake and independent torch/wand. Ta-poh carries a separate
one-hand clearing blade. Mu-naw has free arms, a separate faceted tank/wand and a
procedural flexible hose routed around her side. Her dress never splits its hem
onto opposing legs. `separate_equipment` selects these behaviors; legacy rigs
retain their existing behavior when it is false. Working steps have shorter
visual stride reach to accommodate aim-facing and backward foot placement.

All four pass baked deformation and real-renderer role-action sampling, including
stationary/forward/backward/sideways work, a 20% slope and coughing. Maximum
sampled edge stretch over 3 mm: Kha-nae 3.096, Ta-poh 3.137, Mu-naw 3.207,
Mae-Lu 1.762; unchanged rejection limit 3.5. Exported skin/material tests, actual
moving spray/water accounting, ordered companion douse, interruptions, satellite
stop, full gameplay suite and the 120-frame headless run pass. Exit-time ObjectDB
leak warnings remain in the logs. No finger/facial rig or arbitrary deep-crouch
certification is claimed; long terrace steps still need contact polish.

Evidence: `artifacts/character_rigs_v31/`. The MP4 is an in-place pose review in
the real scene, not a player-navigation recording. Controller movement is covered
by integration tests. Cultural documentary reference verification remains open.

---

The following is the historical pre-v3.1 implementation record.

# Gameplay character motion — 2026-10-02

**Scope:** the validation below describes the installed, pre-v3.1 cast. It does
not certify the new four-character candidates. In particular, references to
Mu-naw's fused equipment and male appearance describe the legacy model only.
The v3.1 character is a young adult woman in an ivory dress, with separate tools.

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
blend above the basket, followed by localized surface-neighbour skin-weight
smoothing. Hand targets also follow the base gait’s grounding offset. Runtime layer testing is required as well as baked-clip
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

## Validation result

Character integration, skin/material preservation and the 120-frame headless run
passed. Runtime skin checks sampled idle/work, forward/backward/sideways motion
at 6 m/s; maximum edge stretch over 3 mm was 3.374 (Kha-nae), 2.874 (Ta-poh),
and 3.477 (Mu-naw), below the existing 3.5 rejection limit. These are sampled
stress metrics, not a guarantee for arbitrary poses. Tests also exercise actual
player movement with held spray, exact water use and an ordered companion douse.

The full gameplay suite failed a ground-camera duplicate-log assertion and then
stopped on its drone `on_station` expectation. Those failures remain separate
from this character pass. Shutdown ObjectDB leak warnings are recorded in the
logs (including the otherwise successful headless run).

`character_motion.mp4` is a 10.5-second **in-place pose review**, not a recording
of player navigation. Controller movement is covered by the integration test;
terrain-edge/stride polish remains explicitly listed in PRD.

## v3.1 motion handoff — pending new mesh calibration

The current controllers establish the following requirements. These are animation
targets, not permission to change gameplay speeds or task accounting.

| Character | Existing gameplay demand | New-model requirement |
|---|---|---|
| Kha-nae | Player movement at 6 m/s before modifiers; held ignition, clearing and spray | Free arms, independent rigid tools, work layered over locomotion, directional foot placement |
| Ta-poh | Elder companion at 3.6 m/s before modifiers; clearing and optional borrowed sprayer | Deliberate shorter gait; independent staff/blade and borrowed wand; no baked-in hand tool |
| Mu-naw | Youth companion at 5.2 m/s before modifiers; suppression, ordered work, rally/flee | Purposeful adult movement; free arms; separate backpack, hose and nozzle; dress that does not stretch across opposing legs |
| Mae-Lu | No runtime actor/controller exists yet | Village idle, restrained conversation and granary gestures; do not assign burn-field AI merely to reuse another character's controller |

Companion work completes after `REQUIRED_TASK_WORK = 1.4`, scaled by efficiency
and coughing, rather than after an animation clip. Player speed falls to 60% under
the current smoke condition. Runtime animation selects Run at 4.6 m/s and must
still support work, stopping and turning at that rate. These values were read
from the current controllers on 2026-10-02 and must be rechecked before integration.

Do not reuse the old Mu-naw profile's X=-0.075 anatomical midline, locked-carry
setting, or old source hashes for her new mesh. Measure landmarks on each accepted
candidate. Inspect dress bends and left/right leg influence separately; a closed
static skirt can still fail walking and crouching. Hoses must bend independently
without pulling on the garment or forearm. Preserve the same edge-stretch and
grounding limits, and review real rendered poses as well as numeric reports.

Before installation, exercise actual controllers for held work while moving,
tool changes, ordered task completion, rally/flee cancellation, smoke/coughing,
slopes and terrace transitions, and satellite stopping. Refill and whistle are
currently gameplay/SFX events; any added gesture must not impose a new movement
lock. Final v3.1 rig calibration remains after the visual/cultural lock required
by the supplied direction.

## Current complete-cast upgrade — 2026-10-03

Joint weights refined for all six character files; 34 clips reviewed and 22 records replaced. Walk/Run transitions now preserve phase, rake/spray motion has restrained polish, and the ranger tablet clears the torso. Actor speeds and work accounting are unchanged. Imported animations bake at 60 fps; all-clip deformation/grounding and runtime/equipment checks pass. [Delivery and remaining contact/finger/face limits](RIG_ANIMATION_HANDOFF_20261003.md).
