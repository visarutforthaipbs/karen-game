# Player feedback implementation — 2026-10-03

Local source installed against HEAD `2bc1818` plus existing shared character, village and audio changes. User authorized implementation after review of `PRD_PLAYER_FEEDBACK_20261003.md`. No model generation, credits, release build, commit or deployment.

## PF-02: water and breath guidance

HUD anchors a faceted drop and เติมน้ำ label to the actual player refill point. Empty tanks get an eight-direction screen-edge cue when the barrels project outside the usable screen area. Reserved margins avoid the top alerts and bottom controls. Near the existing horizontal 3.5 m radius, enabled input shows กำลังเติมน้ำ and actual current/upgraded capacity; a full tank shows น้ำเต็มแล้ว. Elsewhere, incomplete tanks show an approach hint. Minimal HUD and the satellite sweep hide the marker.

Breath has a ลมหายใจ label. Above the cough threshold, the hint explains leaving smoke. Falling exposure while still coughing says ควันลดลง · ยังไออยู่; stamina recovery is shown only below the cough threshold. FirstBurnTips and HowToPlay distinguish water refilling from exposure-based recovery. No safe-air station was introduced. Player smoke, stamina, refill radius/rate and water accounting remain unchanged.

Functions: HUD `_build_vitals_card`, `_process`, `set_minimal`, `update_stamina`, `_update_refill_guidance`, `show_satellite_sweep_ui`; first-burn and how-to-play strings.

## PF-01: readable companion spraying

One reusable `CompanionSprayCue` per active spraying companion draws 16 faceted droplets from the production nozzle and a hollow target ring. Droplet radius adapts to projected camera size (0.085–0.4 m). Target uses the current grid cell position; the working controller refreshes its task position before successful feedback. The ring indicates intent, not success. Existing successful dousing alone creates the broader transient impact cue; VFX never mutates a cell or charges water.

The controller updates the cue after animation so the nozzle follows the current pose. Rally/order cancellation immediately hides and queues the cue for deletion. Completion, invalid cells, fleeing and other nonperforming states stop it; satellite cancellation uses the existing explicit work cancellation. The emitter is owned by its actor and is destroyed with it. Existing coughing slowdown remains; there is no invented interruption if gameplay continues working.

Functions: CompanionController `_physics_process`, `_process_perform_task`, `cancel_animation_work`, `_spray_origin`, `_update_spray_cue`, `_stop_spray_cue`; CharacterToolFeedback impact rendering. No sockets or rig/model geometry changed.

## PF-03: fire warning family

AudioManager coalesces ember and protected-forest voice warnings within eight real-time seconds. An explicit severity mapping permits one forest-fire escalation over an active generic ember line; it cannot interrupt another equally urgent unrelated line. Duplicate critical requests are dropped without restarting speech. Only accepted lines update the family timestamp. Existing per-kind and speech-priority protection remains. Spot-fire alarms share an eight-second burst interval and mix at -8 dB rather than -3 dB. World pop/landing and spray SFX remain independently scheduled.

Scene reset clears family state. Main's delayed bamboo landing callback now checks scene audio epoch and satellite state; no old scene cue can revive after a transition. HUD danger alerts remain independent of accepted speech. No recordings regenerated or global volume changed. Opt-in diagnostics record bounded kind/time/position/accepted events.

Functions: AudioManager `_play_speech`, `play_spot_fire`, `stop_all_loops`, `_log_fire`; MainController `_on_bamboo_exploded` delayed callback.

## Verification

Evidence root: `artifacts/player_feedback_20261003/`.

- `test_all.gd`: OK, zero failures.
- `test_gameplay_motion.gd`: zero failures, including real ordered/autonomous success, current nozzle and grid origin/destination, emitter reuse, completion/rally/flee/invalid target/satellite cleanup and unchanged one-dose player accounting.
- New `test_player_guidance.gd`: zero failures; original refill radius/rate/input/capacity, coughing/exposure decay versus stamina recovery, full breath, empty-tank edge cue, minimal and satellite visibility.
- `test_audio_upgrade.gd`: zero failures; 20 generic requests accept one voice, forest escalation accepts once, repeat suppression persists after a clip ends, alarm coalescing, expiry, scene cleanup and pre-existing priority/bus regressions.
- `test_equipment_motion.gd`: zero failures; existing nozzle/hand/hose alignment checks preserved.
- Required 120-frame headless smoke run: exit 0, no script errors. Some focused/full suites retain existing ObjectDB exit warnings; not claiming all suites are warning-free.
- `git diff --check`: passes.

Native Forward+ Metal review captures: `refill_720.png`, `refill_800.png`, `empty_tank_direction.png`; animated `spray_normal_*.png`, `spray_full_*.png`, `smoke_*.png`; reconstructed prior transient effect `before_normal_*.png` and `before_full_*.png`. The comparison uses a deterministic real Main scene with an ash patch; it is not a recorded live player navigation session. Smoke uses the game's emitter, not a guarantee of legibility through all dense-smoke/canopy situations. `spray_preview.gif` previews the new effect.

`fire_burst_before.wav` and `fire_burst_after.wav` record real AudioManager mixer output under a deterministic burst, with unchanged master gain. The before harness emulates prior scheduling instead of reverting shared production files. JSON diagnostics accompany each. Original tester listening preference, first-time discoverability and native Thai wording review still need human playtest; these subjective acceptance items are not established by headless checks.

Reproduce rendered captures with `tools/character_pipeline/capture_player_feedback.gd`; mixer comparison with `capture_feedback_audio.gd`. Visual capture isolates SaveGame/GameSettings/PlaytestLog in evidence-local `review_save` and does not touch the player's campaign.
