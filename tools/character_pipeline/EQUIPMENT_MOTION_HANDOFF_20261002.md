# Player hose, rake contact and Ta-poh belt carry — 2026-10-02

The three reported issues are fixed in the current game. This follow-up implements
the user's equipment/motion request after the asset-only polish pass. Approved
character GLBs, textures, portraits and imported animations are unchanged.

## Behaviour

- **Player hose:** `scripts/SprayerHose.gd` draws a matte six-sided rubber tube
  between the actual T4 outlet and T5 inlet. It follows the prop transforms while
  turning, walking, running and spraying, with a curved route below the tank and
  around the hip. It appears when the sprayer is selected and hides for the torch
  and rake. It has 288 triangles and no gameplay or water-accounting logic.
- **Kha-nae rake:** targets now describe palm centres instead of wrist joints.
  The supporting palm is 25cm farther along a diagonal shaft, keeping the elbows
  and hands on their respective sides. The player's tool offset also accounts
  for the 1.35 character display scale: `-0.22 / animator.base_scale`, preventing
  the previous 7.7cm shift between the palm and the authored handle grip.
- **Ta-poh knife:** one existing T2 knife is attached to a hip/belt socket inside
  a simple dark leather sheath during idle, walking, running and spraying. It
  moves to the right hand only while clearing vegetation, then returns to the
  belt. Cancelling work sheathes it immediately. The knife is not duplicated.

Touched runtime files: `PlayerController.gd`, `SkeletalChibiAnimator.gd`, and the
new `SprayerHose.gd`. No changes to `CompanionController.gd`, UI, game rules,
`tests/test_all.gd` or the separately authored Mu-naw equipment path in this pass.
The borrowed companion hose is outside these three requested fixes.

## Validation

Evidence: `artifacts/equipment_motion_fix_20261002/`.

- `tests/test_equipment_motion.gd`: **0 failures** across moving/turning spray,
  switches to torch/rake, multiple stationary/moving rake cycles, and knife
  idle/walk/run/clear/cancel/spray transitions. Minimum palm separation **24.93cm**;
  maximum supporting-palm distance from the shaft **0.82mm**. Hose endpoints
  coincide with both fitting transforms within floating-point tolerance.
- `tests/test_gameplay_motion.gd`: **0 failures**, including actual dousing/water
  accounting, companion orders and satellite interruption.
- `tests/test_skeletal_character.gd`, `tests/test_v31_assets.gd`: pass.
- `tests/test_all.gd`: **RESULT: OK (0 failures)**.
- 120-frame headless smoke: pass. Four-angle runtime review: 64 images.
- Some test exits report audio resource leaks. A verbose focused run identifies
  four `AudioStreamWAV` / `AudioStreamPlaybackWAV` instances, not hose/knife nodes.
  These are recorded in `test_equipment_verbose.log`; audio was not edited here.

The first contact test sampled BoneAttachment transforms before their deferred
update; it now waits a scene frame before comparing the actual prop and palm.
The corrected test uses the rendered shaft transform, not a duplicate target
formula. No threshold was relaxed to pass it.

Individual finger closure remains limited by the approved rigs, which have no
finger joints. These changes fix the reported crossed-arm hold and equipment
attachments, without regenerating faces or costumes.

## Review images

- [Rake front](../../artifacts/equipment_motion_fix_20261002/review/Player_rake_view0.png)
- [Rake side](../../artifacts/equipment_motion_fix_20261002/review/Player_rake_view1.png)
- [Hose side](../../artifacts/equipment_motion_fix_20261002/review/Player_spray_view3.png)
- [Hose tank connection](../../artifacts/equipment_motion_fix_20261002/review/Player_spray_view2.png)
- [Ta-poh belt carry while running](../../artifacts/equipment_motion_fix_20261002/review/Elder_run_view3.png)
- [Ta-poh knife drawn for clearing](../../artifacts/equipment_motion_fix_20261002/review/Elder_rake_view0.png)

Initial shared-script snapshots are retained in the evidence root. The isolated
review script is `review.gd`; it refreshes the hose explicitly when the scene is
paused for deterministic captures. Review saves/settings/logs are isolated.
