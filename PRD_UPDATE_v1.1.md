# PRD UPDATE v1.1 — Completion & Test-Readiness Requirements

**Project:** Satellite Shadow (เงาเมฆา / ไร่หมุนเวียน)
**Extends:** `PRD.md` v1.0.0 (still canonical for vision, mechanics and culture)
**Date:** 2026-10-02
**Goal:** Take the game from "systems work" to "complete and ready for an external playtest build."
**User decisions (2026-10-02):** the GitHub repo **stays public** for now. The **Ranger foot patrol (P1-2) is approved**.
**Audience:** The builder agent(s). Read `AGENT.md`, `PRD.md`, `HANDOFF.md` and this file before starting.

---

## 0. How to use this document

- Every requirement has an **ID**, a **priority**, an **owner** and **acceptance criteria**. Build in priority order.
  - **P0:** required for the first playtest build. Do all of these.
  - **P1:** required for a "complete" game. Do after P0.
  - **P2:** polish. Optional before the playtest.
- **Owners:**
  - **GAME:** game-code, UI and gameplay: `scripts/`, `ui/`, the two main scenes, `tests/test_all.gd`.
  - **CHAR:** characters and assets, following `SOP.md`, `ASSETS.md` and `tools/*_pipeline/`, with the style and Pgakenyaw authenticity gates from `tools/character_pipeline/character_direction_v3.1.md`.
  - A requirement marked **GAME + CHAR** needs both.
- **Rules that apply to every item:**
  1. All player-facing text is **Thai**: Kanit for village and people, Chakra Petch for state and surveillance readouts. Use `ui/UITheme.gd` builders. The fonts lack ○ ● ✓, so don't use them.
  2. The art direction is **stylized low-poly**: faceted, broad colour areas. Warm palette for people and land; cold white and infrared colours for the state (`character_direction_v3.1.md` §1). UI uses `FacetCard`, `LowPolyIcon` and `SegmentBar`.
  3. **Don't silently change balance numbers.** The tunables and their measured effects are in `HANDOFF.md` §4. After any change to fire rules, run `tests/balance_sim.gd`. After any change to the economy, re-check the campaign survival curve: a good player should survive Y2 about 90% and Y3 about 40%.
  4. **Testing:** `tests/test_all.gd` must pass, as must the smoke run (`--quit-after 120`). Add tests for every new rule or flow. Run visual checks through a 1280×720 SubViewport (see `HANDOFF.md` §2).
  5. **Two agents share this folder.** Check `git status` and diffs before editing shared files (`PlayerController.gd`, `CompanionController.gd`, `AGENT.md`, `PRD.md`). Commit only your own files unless the user asks otherwise. Update `HANDOFF.md` when you finish an item.

---

## 1. Current state (audit, 2026-10-02)

**Works end to end:**
- The loop: Village Hearth → burn (14:00–20:00) → satellite pass → report → next plot. After plot 5, the monsoon harvest leads into the next year. A crackdown or famine leads to "เริ่มแคมเปญใหม่" and a new campaign.
- Balanced fire, scrutiny and rice economy; a how-to-play card; compact HUD with a goal checklist; follow camera with zoom and turning; surrounding landscape.
- 66 automated checks.

**Characters:**
- Kha-nae, Ta-poh and Mu-naw are rigged and animated.
- Mu-naw's v3.1 redesign (young Pgakenyaw woman, white dress) is in progress (CHAR).

**Installed models:** E1–E3 (pine, bamboo, brush), S1 (field hut), S2 (water barrels), V1 (drone).

**Drawn in code, works:** E4/E5 (stumps), V2 (thermal camera), T1/T3–T5 (tools), fire/smoke/spark particles, all UI icons, all SFX and music.

**Recorded audio:** Ta-poh wind warnings (A1), radio voices (A3).

**Gaps that block "complete":**

| Gap | Where the PRD needs it |
|---|---|
| No **ranger**, anywhere on screen | PRD §8.1 crackdown raid, §8.2 escalation, radio narrative |
| Game over is only a text report; no raid or famine scene; no run summary | PRD §8.1 |
| No title screen, pause/quit menu, settings or save/continue | Basic product completeness |
| No export presets or builds; no Steam Deck verification | PRD platform target, Milestone 5 |
| Year 4+ checkpoints are invisible: they only add travel time | PRD §8.2 |
| The sprayer has the same 4 m reach as the knife | Gameplay feel, spot-fire response |
| The tool "มีดพร้าและคราด" shows only the rake; the knife (T2) is never used | Consistency |
| Companions don't take cover from drones | PRD §6.2 counterplay, fairness |
| No playtest telemetry | Needed to tune balance from the playtest |

---

## 2. P0 — Required for the first playtest build

### P0-1 Title screen · GAME (+ CHAR for art)
- New scene `scenes/Title.tscn`, which becomes `run/main_scene`. Show the game title "เงาเมฆา" with the subtitle "Satellite Shadow".
- Buttons:
  - "เล่นต่อ" (continue; only when a save exists);
  - "เริ่มเกมใหม่" (new game; asks to confirm if a save exists);
  - "วิธีเล่น" (opens `ui/HowToPlay.gd`);
  - "ตั้งค่า" (settings);
  - "ออกจากเกม" (quit).
- Background: a slowly orbiting camera over the burn plot and `Landscape` at dusk, with a cold satellite streak crossing the sky. Use procedural art until U6 title art exists.
- Gamepad navigation works with focus on the first button. Esc/B returns from sub-panels.
- **Acceptance:** the game boots to the title. Continue resumes the saved campaign at the Hearth. A new game resets the campaign and shows how-to-play once.

### P0-2 Pause menu · GAME
- Esc or the gamepad Start button during a burn opens a pause overlay. `get_tree().paused = true`; the overlay uses `PROCESS_MODE_WHEN_PAUSED`.
- Buttons:
  - "เล่นต่อ" (resume);
  - "วิธีเล่น" (how to play);
  - "ตั้งค่า" (settings);
  - "ยอมแพ้แปลงนี้ · กลับหมู่บ้าน" (give up this plot and return to the village). Counts as a burn at the current state: run the 20:00 resolution immediately, so it can't be used to dodge penalties.
  - "ออกไปหน้าแรก" (quit to the title; autosaves the Hearth state from before this burn).
- Add an InputMap action `pause` (Esc, `JOY_BUTTON_START`). The how-to-play overlay's existing Esc handling must not conflict.
- **Acceptance:** the clock, fire, drones and companions all freeze while paused. Resuming continues exactly where it stopped. A test covers pause, then resume.

### P0-3 Save / continue · GAME
- One autosave slot at `user://campaign.json`, written on entering the Hearth (after each plot and after the harvest). Include a `version` field.
- Save the full `GameState` campaign: year, plot, rice, scrutiny, upgrades, ration, favours, season yields, hotspot log, pending harvest, forecast wind, `seen_how_to_play`.
- Never save mid-burn. Quitting mid-burn resumes at the Hearth before that burn.
- A corrupt or old-version file is ignored with a Thai notice, and the game falls back to a new campaign.
- **Acceptance:** save, quit, relaunch, continue restores identical Hearth numbers. Round-trip tests for `GameState.to_dict()` / `from_dict()`.

### P0-4 Settings · GAME
- Volume sliders for Master, Music, SFX, Voice and Ambience. Use the existing buses in `AudioManager.gd`; add buses where missing.
- Display: fullscreen or windowed; UI scale 0.85–1.3, applied to the HUD/Hearth root, with Steam Deck readability in mind.
- Gameplay: default camera zoom; show or hide the controls hint.
- "แสดงวิธีเล่นอีกครั้ง" (show how-to-play again).
- Stored in `user://settings.cfg` (ConfigFile) and applied on boot.
- **Acceptance:** settings persist across restarts; the sliders audibly change the buses.

### P0-5 Endings and run summary · GAME (+ CHAR assets from P1-1)
- **Crackdown ending** ("รัฐปราบปราม"). A 15–25 s in-engine scene at the field hut or village at night: cold white flashlights and a truck, rangers (P1-1) arrive, tools are taken, and Ta-poh is led away. Thai captions:
  - "เจ้าหน้าที่ป่าไม้บุกหมู่บ้าน";
  - "ยึดมีด คราด และถังพ่นน้ำ";
  - "ตาโพถูกควบคุมตัว".

  Until the ranger model exists, use silhouettes or flashlight beams only. Never block the build on art.
- **Famine ending** ("หมู่บ้านอดอยาก"). A dawn scene: families with bundles walk down the valley road away from the empty granary. Caption "ครอบครัวต้องลงไปเป็นแรงงานขัดหนี้ในพื้นราบ".
- **Run summary** after either ending:
  - years and plots survived;
  - average ash %;
  - total hotspots detected;
  - escapes;
  - drone photos;
  - the cause of the end.

  Store a **best record** (most plots survived) in `user://records.json` and show it on the title screen.
- Both endings can be skipped (any key or button after 2 s).
- **Acceptance:** each ending can be reached from a test that forces the state. The summary numbers match `GameState` tracking. Add per-campaign counters to `GameState` for escapes, photos and hotspots.

### P0-6 Tool reach and the knife · GAME (+ CHAR for T2 if needed)
- Reach per tool:

  | Tool | Reach |
  |---|---|
  | Knife & rake | 4.0 m (unchanged) |
  | Drip torch | 4.0 m |
  | **Sprayer** | **5.5 m** |

  Implement as a function of `current_tool` in `PlayerController`. Keep the red marker for out-of-reach cells.
- Show the **mida knife (T2)** with the rake: knife in the off hand or on the belt, rake in the hands. If that's awkward to animate, show the knife only in the HUD slot icon and rename the tool "คราดถางแนวกันไฟ" in all text (TOOL_LABELS, HowToPlay, HUD).
- **Acceptance:** a test spraying a smouldering cell 5 m away succeeds, while a 5 m knife cut is refused. The tool name matches what's on screen.

### P0-7 Playtest telemetry · GAME
- After every burn, append one CSV row to `user://playtest_log.csv`:
  - campaign id, year, plot, timestamp;
  - first ignition time (in-game);
  - firebreak cells cut by the player and by Ta-poh;
  - ash %, hotspots at 20:00, spot fires started and doused, escaped (yes/no);
  - scrutiny gained by source (satellite, drone, camera, escape);
  - rice change, scrutiny after the plot.
- Include a "เปิดโฟลเดอร์บันทึก" (open log folder) button in settings.
- **Acceptance:** one row per completed burn, opened correctly as CSV, with a header row.

### P0-8 Test builds · GAME
- `export_presets.cfg` with:
  - **macOS** (universal, for testers);
  - **Linux x86_64** (for the Steam Deck);
  - **Windows** x86_64 (optional).

  Include `internationalization/locale/include_text_server_data` (already on) so Thai line breaking works in exports.
- `tools/build.sh` exports all presets into `build/` (git-ignored), named with the date and commit.
- macOS: ad-hoc signing is acceptable for the playtest. Document how to open an unsigned build.
- **Acceptance:** each build launches, shows Thai text correctly, and plays a full plot.

### P0-9 Steam Deck verification · GAME (needs hardware)
Checklist to fill in:
- 1280×800 layout: no clipped UI; the HUD and Hearth are readable at UI scale 1.0.
- All actions work with Deck controls (see `InputBindings.gd`).
- Frame rate ≥ 40 fps during peak burn with the landscape visible. If not, add a "Landscape detail" low/high setting: fewer far trees, mist off.
- Suspend and resume work.

**Acceptance:** the checklist is completed with frame-rate numbers in `HANDOFF.md`.

### P0-10 Developer / tester tools · GAME
- Debug overlay (F3, hidden in release unless `--debug` or a settings toggle): FPS, cell under the cursor (type and heat), fuel dryness, scrutiny breakdown.
- Cheat keys for testers (debug only):
  - F5: skip +30 in-game minutes;
  - F6: jump to 19:45;
  - F7: set year/plot;
  - F8: fill water;
  - F9: force a spot fire;
  - F10: force a crackdown or famine ending.
- **Acceptance:** none of these are reachable in a normal release run.

### P0-11 Repository readiness · GAME
- `README.md`: what the game is, how to run it from source, controls, how to test, and links to PRD, HANDOFF and SOP.
- `LICENSE`: the repo **stays public** (user decision, 2026-10-02), but **which licence is still the user's call**. Propose separate terms for code (e.g. MIT) and art/cultural content (e.g. CC BY-NC-ND or all rights reserved), and ask before adding the file. Fonts stay OFL.
- GitHub Action `.github/workflows/test.yml` running `godot --headless … tests/test_all.gd` with Godot 4.7.
- **Acceptance:** CI goes green on push; the README lets a new tester run the game.

---

## 3. P1 — Complete experience

### P1-1 The Ranger (C5) · CHAR (model, rig, animation) + GAME (integration)
**Who:** a forest-protection ranger of the state, the human face of the surveillance layer.

**Design brief for CHAR:**
- A **fictional** uniform: no real Royal Forest Department insignia, badges, flags or real names. Muted grey-green or olive, with a cold-white reflective accent. A cap or bush hat; boots; a radio on the shoulder; a flashlight; a tablet or camera for evidence. Not armed in the field-patrol variant. In the raid variant, keep any long gun stylized and secondary.
- Adult, neutral posture. Depict them as **an impersonal arm of the state, not a caricatured villain**. They're doing a job under a decree. The game's critique is aimed at policy, not at individual people.
- Same chibi proportions and faceted style as the crew, around 1.25 m (slightly taller and squarer than Kha-nae), cold palette.
- Rig compatible with the existing 19-bone setup.
- **Animations:** idle, walk, run, look around/scan, photograph (raising a camera or tablet), point/order, radio talk, escort (for the raid scene).
- Two texture variants for crowd variety, e.g. cap vs. bush hat.

**Uses (GAME):**
1. The crackdown ending (P0-5).
2. **Ranger patrol, Year 3+** (new mechanic, P1-2).
3. A radio-channel portrait in the Hearth (2D render).

**Acceptance:**
- It passes the SOP style gate and visual review next to the crew.
- No real insignia appears anywhere on it.
- An entry is added to `ASSETS.md` (C5).

### P1-2 Ranger foot patrol (Year 3+) · GAME · **APPROVED by the user (2026-10-02)**

It depends on P1-1 for the final model. **Don't wait for it:** build and tune the patrol with a placeholder (a low-poly capsule in the ranger's cold palette, with a flashlight cone) and swap in the C5 model when CHAR installs it.
- From Year 3, one ranger walks a path through the forest belt or park edge outside the plot between **15:30 and 18:30**. Two rangers from Year 4.
- Vision: a 70° cone, 12 m long, shown as a faint cold-white ground wedge. It sees **open flames** and **crew standing beside flames** (same rule as the drone). Smoke blocks vision; bamboo hides the crew.
- When the ranger spots something, they stop, radio it in and log it **once per patrol pass**: +15 scrutiny × `penalty_mult`. Show a HUD banner in Chakra Petch.
- The patrol is announced by a footsteps-and-radio-chatter audio cue and a banner ("เจ้าหน้าที่เดินตรวจแนวป่า"). The ranger never enters the plot and never attacks.
- Add the patrol to `Escalation.YearRules` (`ranger_count`) and the radio headlines. Tune with the campaign Monte Carlo so the survival curve stays within rule 3 of §0.
- **Acceptance:** tests for spotting a flame (+15 once per pass) and for no spotting through bamboo or smoke. A short balance note in `HANDOFF.md`.

### P1-3 Year 4+ checkpoint · GAME (+ CHAR for S5 and an optional soldier C6)
- Marching to a plot in Year 4+ triggers a short scene: the crew stops at a road checkpoint (S5 roadblock, one soldier or ranger) and is waved through after a delay. This matches the existing "favours cost more time" rule.
- In the Hearth, the exchange text references the checkpoint.
- **Acceptance:** the scene plays once per plot in Year 4+, can be skipped, and the delay matches `labour_delay_minutes()`.

### P1-4 Companions take cover · GAME
- When a drone is on station within 15 m, or a ranger's cone is near: companions that are *not* dousing a spot fire move to the nearest bamboo or forest-border cell within 6 cells and wait until it passes. Their status shows "หลบใต้ร่มไผ่".
- **Acceptance:** a test with the drone overhead moves an idle companion onto bamboo. Spot-fire response still takes priority.

### P1-5 Hold-to-cut feedback · GAME
- While a cut is in progress, the targeted cell shows a progress ring or filling marker, and a dust puff plays when it completes.
- **Acceptance:** the progress is visible in a screenshot during a cut.

### P1-6 First-burn guidance · GAME
- In the first burn of a new campaign only, show short contextual tips at the right moments:
  - 14:00: "ถางแนวกันไฟรอบแปลงก่อน";
  - 15:30: "เชื้อไฟแห้งแล้ว จุดไฟเป็นแนวที่ตีนเนิน";
  - the first spot fire;
  - 17:16;
  - 18:00 (start spraying).

  They can be turned off in settings.
- **Acceptance:** the tips appear once per campaign and are never repeated after the first burn.

### P1-7 Crew portraits (U3) · CHAR + GAME
- 256 px faceted portraits of Kha-nae, Ta-poh, Mu-naw (v3.1) and the ranger. Use them in the HUD crew chips, Ta-poh's wind banner, the radio panel (ranger) and the ending captions.
- **Acceptance:** they match the current models (Mu-naw v3.1) and pass the style gate.

### P1-8 Title / key art (U6) · CHAR
- A 1920×1080 faceted painting: hillside swidden at blue hour, crew silhouettes, a satellite streak.
- **Acceptance:** used on the title screen and as the README image.

### P1-9 Crew barks (A2) · CHAR (audio)
- Short Thai lines (S'gaw Karen optional, with cultural review):
  - Mu-naw: "ไฟตกในป่า!" (spot fire), "ดับแล้ว" (out);
  - Ta-poh: answering the whistle;
  - coughing for each character;
  - the ranger's radio call.
- OmniVoice-Thai on gpu01 (see project memory); no non-commercial-licensed models.
- **Acceptance:** wired through `AudioManager` with procedural fallbacks.

---

## 4. P2 — Polish

| ID | Item | Owner |
|---|---|---|
| P2-1 | Set dressing on and around the plot: rocks, terrace walls on plot 5, logs, grass tufts (E6–E9) | CHAR + GAME |
| P2-2 | Flame, smoke, spark, steam, water-mist and ash sprites (X1–X6), replacing the soft-dot particles | CHAR + GAME |
| P2-3 | Satellite model (V3) crossing the sky in the 20:00 pass cinematic | CHAR + GAME |
| P2-4 | Recorded SFX (A4/A5) and layered music (A7, ACE-Step MIT or commissioned; no non-commercial licences) | CHAR |
| P2-5 | Drip-torch fuel: one can lights about 60 cells, refill at the hut. Makes torch lines a resource; tune with `balance_sim.gd` | GAME |
| P2-6 | Native Thai review of all text, and Pgakenyaw review of names, proverbs and the radio script | User / reviewer |
| P2-7 | Accessibility: colour-blind-safe hot/cold indicators (shape as well as colour), subtitles for all voice lines | GAME |
| P2-8 | 3D Village Hearth (S3 granary, S4 houses) replacing the 2D screen | CHAR + GAME |

---

## 5. Definition of "ready to test"

The playtest build is ready when **all P0 items** are done and:

1. A tester can install a build, see the title, start, learn from how-to-play, play a full year (5 plots plus the harvest), quit, and continue.
2. Both endings and the run summary can be reached; the best record persists.
3. Pause, settings and save work on keyboard/mouse and gamepad.
4. `tests/test_all.gd` passes, CI is green, and the smoke run is clean. The balance survival curve has been re-checked after any balance change.
5. The Steam Deck checklist is filled in (or explicitly deferred by the user).
6. `playtest_log.csv` records every burn.
7. `HANDOFF.md` is updated with what was built, new tunables, and known issues.

P1-1 (the ranger) and P1-2 (the approved patrol) should be in the playtest build if at all possible: the state's human presence is currently missing from the story, and the patrol is the planned Year 3+ threat. The patrol can ship with the placeholder.

---

## 6. Suggested build order

1. P0-11 (README, CI)
2. P0-3 (save)
3. P0-1 (title)
4. P0-2 (pause)
5. P0-4 (settings)
6. P0-6 (tool reach)
7. P0-7 (telemetry)
8. P0-10 (dev tools)
9. P0-5 (endings, with placeholder ranger silhouettes)
10. P0-8 (builds)
11. P0-9 (Steam Deck)
12. **P1-2 ranger patrol with a placeholder (approved)** → P1-4 (companions take cover) → P1-3 (checkpoint)
13. In parallel from day one, CHAR builds P1-1 (the ranger model, rig and animations). GAME swaps it into the patrol and the crackdown ending when installed.
14. Remaining P1 → P2
