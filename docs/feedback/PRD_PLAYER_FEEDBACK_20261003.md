# Player feedback fixes for companion spray refill guidance and fire warnings

Date: 2026-10-03. Product: Under Two Skies. Status: source-audited implementation draft. Player confirmed the breath/coughing meter and “ลูกไฟ!” voice-warning interpretations on 2026-10-03.

This PRD turns three player observations into bounded fixes for the game-code and character agents. Audit baseline: local working tree at HEAD `2bc1818`, including existing uncommitted changes. Source behavior was inspected; this audit did not run the game, listen to recordings, or reproduce the reported experience. Before implementation, reread the referenced functions and their current diffs because other agents are working in the same checkout.

## Original review and interpretation

Preserved feedback:

> Effet ของ มูนอ ตอนรถน้ำ ไม่มีเหรอ?

> We should have some hi light on refill point for ไอ and น้ำ , now refill ไอ is confusing, what is it for?

> The sound effect that said ลุกไฟ is quit annoying when it happened at the same time

Player-confirmed meanings (2026-10-03): “ไอ” refers to the breath/coughing meter, and “ลุกไฟ” refers to the “ลูกไฟ!” voice warning. “รถน้ำ” is interpreted as watering/spraying (รดน้ำ); this action wording remains an inference. Original quotations above are preserved. No build version, timestamp, camera distance, or clip was supplied.

## Scope and priorities

| Item | Proposed priority | Player outcome | Audit result |
| --- | --- | --- | --- |
| PF-01 Companion spraying | P1 | Recognize when Mu-naw is spraying and which cell she affects | VFX exists; readability and origin placement require runtime review |
| PF-02 Refill and breath guidance | P1 | Find water and understand how to recover breath | Water refill exists; no dedicated breath refill point exists |
| PF-03 Fire voice bursts | P1 | Hear useful warnings without repetitive overlapping cues | Speech arbitration exists; related kinds have separate cooldowns and alarm SFX can accompany speech |

Priorities are proposals based on feedback, not measured severity. Keep farming rules, companion autonomy, water economy, smoke thresholds, and the 20:00 pass intact. This is a feedback/presentation change, not a rebalance. Use Kanit and UITheme for village guidance, faceted water/air icons, and established low-poly VFX. Do not introduce generic glowing quest pillars or a new oxygen resource.

## PF-01 Make Mu-naw spraying legible

### Source evidence

- `scripts/CompanionController.gd:549`, `_process_perform_task`: work accumulates, `douse_cell` is attempted, and successful dousing calls `_show_tool_feedback("spray")` at line 569 and a positional spray sound at line 571.
- `scripts/CompanionController.gd:586`, `_show_tool_feedback`: youth origin comes from the animator tool tip, with an animator-local fallback; the effect targets `target_world_pos`.
- `scripts/SkeletalChibiAnimator.gd:164`, `get_embedded_tool_tip`: separate equipment uses the carried tool; otherwise the tip is estimated using chest-bone transforms. Verify the installed Mu-naw model against this path.
- `scripts/CharacterToolFeedback.gd:9`: duration is 0.32 seconds. Lines 25–34 specify eight droplets with spray radius 0.025 m (0.05 m diameter); lines 46–53 move them from origin toward the target.
- `scripts/CompanionController.gd:150` drives work animation separately from successful cell feedback.
- `tests/test_gameplay_motion.gd:94` checks the real ordered douse reaches ASH. It does not assert VFX visibility or nozzle alignment.

Confirmed: the effect is implemented, so do not treat this as a missing call by default. Hypotheses: small size/brief duration, camera framing, origin misalignment, or seeing the work animation before the successful douse make spraying look absent. These are not yet reproduced causes.

### Required behavior

1. During actual spraying work, show a readable directional water cue from Mu-naw's nozzle toward the authoritative target cell. Work feedback may show preparation/spraying intent; only successful dousing may show a cooling/impact success cue.
2. Validate nozzle attachment with the current production rig, slope, and facing; derive the destination from the grid's current cell position if the supplied task position can be stale.
3. Tune broad faceted droplets/jet and a short impact cue for the normal camera and full-plot view. Exact dimensions and duration must follow visual comparison; the existing numbers above are evidence, not mandated replacement values.
4. Stop sustained cues on completion, invalid target, rally, flee/hide, coughing interruption where work stops, scene exit, and satellite transition. Avoid allocating a new sustained emitter every frame.
5. Preserve successful douse accounting and companion autonomy. Animation/VFX must never call `douse_cell` again or consume extra water.

### Acceptance and verification

- In a 1280×720 real-scene capture at the normal zoom and full-plot zoom, a reviewer can identify Mu-naw spraying and the target cell without relying on the status text. Compare before/after recordings, including a bright daytime plot and smoke.
- Ordered and autonomous dousing each show the appropriate cue; completion transitions the cell exactly once. A failed/invalid douse never shows a success impact.
- Rally, interrupted work, and satellite transition leave no active spray emitter; replaying work does not leak nodes.
- Extend `tests/test_gameplay_motion.gd` with meaningful lifecycle/origin checks and run `tests/test_equipment_motion.gd` if sockets/equipment change. Headless checks alone cannot establish visual readability.

Ownership: game-code agent for task/VFX lifecycle; character agent for nozzle sockets and installed-rig alignment. Coordinate edits to CompanionController and SkeletalChibiAnimator.

## PF-02 Explain and highlight water refill and breath recovery

### Source evidence

- `scripts/MainController.gd:228`, `_build_field_hut`: creates a hut and water barrels, then assigns the barrel position to `player.refill_point` at line 253. This function contains no refill marker or label.
- `scripts/PlayerController.gd:51`: refill radius is 3.5 m, rate 5 L/s. `_update_refill` at line 222 automatically fills while input is enabled, the player is within horizontal range, and water is below capacity; it emits water changes and runs the refill sound.
- `scripts/MainController.gd:618`: empty-tank alert says to go to the barrels beside the hut, but supplies no directional/location cue.
- `scripts/PlayerController.gd:195`, `_update_smoke_and_stamina`: smoke density above 0.15 adds exposure; lower density reduces exposure by 1.5 per second. At exposure >=4, stamina drains at 18/s; below that threshold it recovers at 12/s times `stamina_regen_multiplier`, capped by `max_stamina`.
- `ui/HUD.gd:489`: vitals are icon/number rows. `update_stamina` at line 729 replaces the value with “ไอ! %d%%” while coughing; it does not explain recovery.
- `tests/test_all.gd:157` tests water increasing near the barrels. It does not test discoverability or understandability.

Confirmed: water is replenished at a fixed location; breath recovery is smoke/exposure based, not a refill station. Leaving smoke does not necessarily stop coughing immediately because accumulated exposure must decay first. Do not mark the hut as a guaranteed safe-air zone: actual smoke conditions govern recovery.

### Required behavior

1. Add a restrained, faceted water-drop marker and Thai label “เติมน้ำ” anchored to the actual barrel refill location. Keep it visible from the default camera; provide a screen-edge direction cue when water is empty and barrels are offscreen. Color alone cannot identify the service.
2. Within refill range, show “กำลังเติมน้ำ” plus the real current/capacity values while filling, and “น้ำเต็มแล้ว” when complete. Outside range, show an approach hint rather than claiming refill is active. Preserve the automatic interaction and current radius/rate.
3. Label the breath meter “ลมหายใจ”. While coughing, explain “ออกจากควันเพื่อฟื้นลมหายใจ”. When exposure is falling but still above the cough threshold, communicate recovery is underway without claiming coughing has ended.
4. Clarify water versus breath in first-burn guidance: water fills at barrels; breath recovers as smoke exposure falls. Candidate Thai copy requires proofreading.
5. If displaying a recovery-area marker, compute it from live smoke/exposure conditions and verify its reachability; otherwise use HUD guidance only. A permanently marked breath refill station is out of scope.
6. Prevent overlapping labels and new per-frame alerts. Support Thai text at 1280×720 and 1280×800 with controller navigation and HUD hiding/settings.

### Acceptance and verification

- A first-time tester with an empty tank can locate the barrels using the cue and sees water increase on entering the existing refill radius, stop on exit, and cap at capacity. Check capacity upgrades too.
- The marker corresponds to the real refill point on multiple plots/camera rotations. Offscreen arrows stay inside the viewport and do not conflict with surveillance alerts.
- Enter smoke, cough, then leave: the UI distinguishes coughing, exposure decay, and restored breath. Staying in dense smoke does not display a false “safe” recovery marker.
- After the first-burn guidance, a tester can explain where water refills and how breath recovers. This is a usability acceptance check, not a claim that it already passes.
- Extend the existing refill test for radius/input/capacity behavior as needed; add tests for UI state transitions and exposure-threshold recovery. Verify screenshots and a short guided playtest.

Likely files: MainController, PlayerController (state exposure, only if needed), HUD, FirstBurnTips, HowToPlay. Prefer deriving indicators from existing state over duplicating gameplay calculations.

## PF-03 Reduce fire-warning bursts while preserving urgent information

### Source evidence

- `tools/audio_pipeline/voice_plan.json` records “ลูกไฟ! ระวังแนวป่า” and “ลูกไฟข้ามแนวแล้ว!” for `bark_embers`, plus “ไฟตกในป่า! รีบดับก่อนลาม” for `bark_spot_fire`. The player confirmed that the feedback concerns the “ลูกไฟ!” warning. The exact recording variant heard remains unidentified.
- `scripts/MainController.gd:492`: every bamboo explosion requests an `embers` bark; `_on_ember_jumped` at line 518 gates its own event for 8 seconds, then requests the same kind. `_on_spot_fire` at line 509 requests `play_spot_fire`.
- `scripts/AudioManager.gd:465`, `play_bark`: embers and spot_fire both receive urgent priority 3.
- `_play_speech` at line 478 already enforces a 4-second cooldown per kind, rejects equal/lower-priority speech while crew speech is active, stops speech/radio before accepted playback, and drops rather than queues stale warnings.
- `play_spot_fire` at line 696 separately requests an alarm SFX with a 2-second interval and a spoken bark. Voice arbitration does not make that alarm mutually exclusive with speech or other sound effects.
- `tests/test_audio_upgrade.gd:19` covers priority/channel protection and line 31 covers delayed scene callbacks. It lacks burst tests across related fire cue kinds.

Confirmed: “no speech overlap protection” would be an incorrect diagnosis. Likely causes are recurring warnings after a clip ends, different warning kinds bypassing a shared semantic cooldown, or alarm/voice stacking. Simultaneous recorded speech and exact annoyance remain unverified in the current build; compare with the player's build if available.

### Required behavior

1. Reproduce a burst of bamboo explosions, ember jumps, and protected-forest spot fires. Log requested kind, accepted/dropped decision, event position/time, and actual played cue in a temporary diagnostic.
2. Centralize a fire-danger warning family so related events coalesce instead of each kind independently repeating its spoken warning. Keep individual world effects positional and distinct from speech.
3. Proposed tuning: after an accepted fire-danger voice, suppress equivalent family speech for 8 real-time seconds. This is a starting value for playtest, not an existing rule. Drop stale reminders rather than queueing them.
4. A newly ignited protected-forest spot fire may supersede a lower-urgency generic ember warning once. Duplicate spot-fire events must not repeatedly interrupt or restart that line. Prioritize danger using explicit event semantics rather than string-name coincidence.
5. Keep the HUD danger location/response guidance timely even when speech is suppressed. Coalesce alarm SFX within a burst; preserve a first critical cue, water-spray SFX, wind warnings, volume settings, and radio/scene cleanup.
6. Scene transitions invalidate pending warning work. Do not regenerate recordings or simply reduce global volume without first checking scheduling and mix behavior.

### Acceptance and verification

- A burst of 20 equivalent events in one second yields at most one accepted spoken fire warning, one burst alarm, and no stale speech backlog. World pop/landing sounds retain their existing independent limits.
- Mixed generic-ember and new protected-forest events yield at most one generic line and one justified urgent replacement; repeated urgent events do not restart it.
- Duplicate equivalent warnings inside the configured interval are suppressed; a fresh threat after it can speak. HUD alerts remain actionable throughout.
- No two speech players are audible concurrently; a blocked request does not silence an active critical line. Resetting the scene cancels pending work.
- Add deterministic burst/priority/cleanup regression coverage to `tests/test_audio_upgrade.gd`; capture and listen to a real gameplay burst before/after at equal volume. Ask the original tester whether repetition is improved.

Likely files: AudioManager for arbitration/cooldown family and alarm mix; MainController only where event context is needed. Preserve existing protected speech pools and regression checks.

## Implementation handoff and completion evidence

Implement PF-02 first for immediate onboarding clarity; PF-01 and PF-03 can be independently scoped after confirming their runtime symptoms. This order is proposed; it does not authorize concurrent edits to shared files.

Before editing: follow AGENT.md and HANDOFF.md, check `git status`, diffs and modification times, and preserve ongoing character/audio work. Record the actual audited revision and changed functions in the implementation summary. Run relevant existing suites plus meaningful new regressions, then the required smoke run after GDScript changes:

```sh
godot --headless --path . --fixed-fps 60 --script res://tests/test_all.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_gameplay_motion.gd
godot --headless --path . --fixed-fps 60 --script res://tests/test_audio_upgrade.gd
godot --headless --path . --fixed-fps 60 --quit-after 120
```

Run equipment tests if equipment/socket behavior changes. Follow HANDOFF.md's SubViewport capture workflow for visual verification. Deliver source changes, relevant test results, before/after VFX and UI captures, an audio comparison, and a result per acceptance criterion. A fix is not complete on code inspection alone.

## Player follow-up

The player confirmed both meanings on 2026-10-03; no further wording confirmation is needed for PF-02 or PF-03. If possible, capture the player's build/date and when Mu-naw's effect disappeared, including zoom and ordered versus autonomous work. Those details refine reproduction; source-confirmed refill guidance can proceed without inventing an air station.
