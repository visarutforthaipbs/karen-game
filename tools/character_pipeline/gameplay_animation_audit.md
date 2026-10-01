# Character rig and gameplay animation audit

Historical baseline, before the 2026-10-02 implementation. See
[the implementation and current limits](gameplay_motion.md) for current status.

Audited 2026-10-02 against installed GLBs, character scenes, PRD §5,
PlayerController, CompanionController, MainController and both animators.
This records current behavior and the proposed completion plan; missing motions
listed here have not been implemented.

## Installed status

| Character | Actual installed model | Skeleton / skin | Animation status |
| --- | --- | --- | --- |
| Kha-nae | `assets/models/khanae_rigged.glb` | One skin, 19 joints | Idle 2.4 s, Walk 0.8 s, generic ToolUse 0.7 s; hand and chest sockets |
| Ta-poh | `assets/models/tapoh_textured.glb` | No skin or joints | No embedded clips; whole-model bob, tilt and squash |
| Mu-naw | `assets/models/munaw_textured.glb` | No skin or joints | No embedded clips; whole-model bob, tilt and squash |

The character scenes select these exact assets. Only Kha-nae uses
`SkeletalChibiAnimator.gd`. Ta-poh and Mu-naw use `ChibiAnimator.gd`.
Thus one of three characters has a skeletal foundation; none has a complete,
role-specific gameplay animation set. A good static model is not a finished rig.

## Movement and actions required by the game

| Gameplay behavior | Current code | Motion needed |
| --- | --- | --- |
| Kha-nae movement | Camera-relative movement, 6 m/s; full rations 6.3; smoke/exhaustion multiplies speed by 0.6 | Readable brisk locomotion/run, slowed gait, turns, idle; calibrate stride at actual world scale |
| Ta-poh follow/work approach | 3.6 m/s; follows beyond 6 m, seeks downwind firebreaks, accepts brush pings | Deliberate elder gait, work approach, stop and face the brush |
| Mu-naw patrol/work approach | 5.2 m/s; patrols ash and hunts embers; fire pings assign tasks | Quick scout gait/run, target-facing spray stance, patrol idle |
| Ignition | Player can hold and drag across cells; default cooldown 0.15 s | Low torch carry/tilt, continuous ignition gesture compatible with movement |
| Firebreak clearing | Player holds rake tool; companion works while stationary | Two-hand rake/scrape cycle, ground contact and recovery; blade motion only if a distinct blade action is added |
| Water spraying | Player consumes water on successful douse; Mu-naw works a target | Wand aiming, sustained spray stance/loop and release, tank attachment; moving spray for player |
| Smoke | Player loses stamina and speed; companions slow and can flee | Readable cough/recovery overlay and slowed locomotion; locomotion must remain available |
| Flee / rally / new order | Companion AI can interrupt work; fleeing uses normal role speed, bypassing cough slowdown | Interruptible work, turn and move away, settle back to idle |
| Hillside traversal | Actor origin follows terrain height at up to 6 m/s vertically | Foot placement and pelvis adjustment on slopes/terraces; evaluate both feet, not just root height |
| 20:00 satellite pass | Player input disabled; companion physics processing stopped | Explicitly settle/stop animation when actors stop, including future companion AnimationPlayers |

Ration multipliers also affect companion movement (0.9 lean, 1.05 full).
There is no jump, dodge, climb or separate sprint input in these controllers.
PRD calls Mu-naw's ping response a sprint; code uses his ordinary 5.2 m/s speed.
Do not add a sprint mechanic solely to support a clip name.

Whistle currently emits a signal/SFX; refill is automatic within 3.5 m of barrels
at 5 L/s, even while moving; Thermal Eye is a periodic ring/highlight; Ta-poh's
wind warning is a HUD call. Optional whistle, refill and scan gestures must not
introduce a new movement lock or compulsory manual interaction.

## Integration gaps that must be resolved with the rigs

1. **Target-facing is not wired.** The skeletal animator accepts `face_dir`, but
   both controllers only pass velocity. Stationary characters can act toward a
   target without turning to it; moving Kha-nae faces travel rather than aim.
   Supply work/aim direction and support movement relative to it, either with
   directional locomotion or constrained upper-body aim.
2. **Tool effects and animation are independent.** Player effects apply before
   `_swing()`. Held input can affect a new cell every 0.15 s (faster with blade
   upgrades), while ToolUse lasts 0.7 s and ignores triggers during playback.
   Use explicit tool start/hold/stop state, per-tool motion and synchronized
   contact/VFX. Do not simply delay every effect by a full clip or restart the
   wind-up on every tick; preserve continuous line painting and water rules.
3. **Actions replace locomotion.** The generic clip keys the full body, and
   `_action_playing` prevents locomotion selection although the player still
   moves. Separate lower-body gait from upper-body work where appropriate.
   Any planted rake action needs an explicit movement/contact policy.
4. **Walk speed is not calibrated to actual gait.** Playback is `speed / 2.0`,
   capped at 2.5, while base player speed is 6 m/s. The same short Walk serves all
   movement. Measure foot travel at the 1.35 model scale and tune walk/run blends
   and stride to avoid sliding; passing a bone-motion test does not establish this.
5. **Companion work needs semantic actions and sockets.** Its trigger has no
   clear/spray parameter and there is no companion runtime tool attachment or
   tool-switching implementation. Embedded props cannot substitute for hand
   grips. Ta-poh's borrowed-sprayer favor also needs a visible equipment/action
   change. Preserve rigid turban/tank parts and review any fused tool/hand mesh.
6. **Companion task time is not animation time.** Work completes at progress 1.4,
   at baseline efficiency 1.6 for Ta-poh and 1.3 for Mu-naw (about 0.875 s and
   1.077 s). Upgrades, rations and coughing change this. Current action triggers
   use a modulo test every 0.4 units of work progress, not a robust clip clock.
   Drive work loops and completion/cancellation explicitly from task state.
7. **Reach is an artistic/gameplay constraint.** Player effects reach 4 m;
   companions stop within 2.2 m. Spray may span distance; rake/torch ground
   contact cannot be assumed. Review contact points against the affected cell
   area at gameplay camera distance and document any proposed reach change.

PRD/code balance discrepancy to resolve separately: PRD lists elder/youth work
efficiency as 150%/140%; code sets 160%/130%. This audit uses actual code values
and does not change game balance.

## Recommended implementation order

1. Finish Kha-nae as the integration reference: semantic tool state, target aim,
   locomotion during work, two-hand rake grip and three distinct tool motions.
   Keep input responsive and effects consistent with existing gameplay tests.
2. Calibrate Ta-poh's own rig/weights, review turban/beard/garment and any fused
   tools, then integrate walk, rake and borrowed-sprayer actions with AI state.
3. Calibrate Mu-naw's own rig/weights, preserve the tank, then integrate fast
   locomotion, aimed spray, patrol and flee transitions.
4. Review the whole cast together: stride and slope feet, smoke reactions,
   interruptions, accessories, then optional whistle/scan personality gestures.

Every stage retains the approved stylized low-poly appearance. Do not smooth
away facets, replace cultural details or regenerate accepted meshes merely to
add bones. Fingers and facial animation remain optional for this camera.

## Acceptance and evidence

- Review front/side/back and maximum bends; no hand/torso pulling, crossed leg
  influences, collapsing joints or stretching rigid props. Preserve UVs/materials.
- Capture actual gameplay at normal and close camera distance: all directions,
  aim away from travel, stationary work, held work across cells, tool changes,
  empty water tank, slopes, smoke slowdown, rally/flee/new-order cancellation.
- Exercise upgrades/rations and 20:00 stopping. Ensure work effects occur once
  according to gameplay rules and invalid actions do not leave a stuck work pose.
- Keep profile, exact source hash, exported rig, pose review and gameplay video.
  Render using the project's default renderer so colours match the game.

Verification on 2026-10-02: directly inspected all three installed GLB JSON
headers for skins/joints/animations; ran `tests/test_skeletal_character.gd`
(passed) and `tests/test_all.gd` (zero failures; 12 ObjectDB instances reported
leaked at exit). The skeletal test checks Kha-nae's 19 bones, normalized skin,
texture preservation, leg articulation, action completion and tool attachment.
These tests do not certify companion rigs, target-facing, contact choreography,
terrain foot placement or visual quality of moving tool use. No new visual
acceptance or completed rig is claimed by this audit.
