# Under Two Skies — iOS / iPadOS port (work in progress)

Started 2026-10-12 at the owner's request ("another version for iPhone and iPad").
**Status: engineering candidate runs on a real iPhone with touch controls; NOT on
TestFlight, NOT on the App Store.** Desktop Beta 3 (0.3.0) is unaffected: every change
below is a no-op without a touchscreen / `mobile` feature / `--touch` test flag.

## What exists

| Piece | Commit | Evidence |
|---|---|---|
| Mobile renderer override (`rendering_method.mobile="mobile"`), landscape lock, iOS export preset (iPhone+iPad, iOS 17+, team `79QFYKTJMN`, bundle `io.github.visarutforthaipbs.undertwoskies`) | `cfa4d06` | headless export 0 engine errors |
| `tools/build_ios.sh` — export → Xcode archive → App Store Connect IPA + `source-manifest.json` (SHA-256) | `3adcc0c`, `3528f69` | full run from frozen `c69876a` snapshot |
| Explicit two-thumb touch controls (`scripts/TouchControls.gd`), mobile UI (safe area, 44 pt targets, Quit hidden, touch guide text TH/EN, auto-pause on app pause / focus loss on touch devices) | `c69876a` | `test_touch_controls` 67 checks, `test_mobile_ui` 31/30 checks (with/without `--touch`), all 22 CI suites green |
| Voice/radio suite teardown fix (pre-existing flaky "resources still in use at exit") | `781bc71` | 0 leaks in 16/16 runs; CI run 38270361899 success |
| iPhone playtest round 1 fixes: right-edge button stack clear of vitals/state cards, overlay hidden over report / pause / satellite pass, captions narrowed on touch | `1456fc8` | `test_touch_controls` 76 checks (4 playtest regressions); CI success |
| Dusk-inversion overview legibility (fog calibrated to camera distance, squared ratio) — affects desktop too | `39014d9` | reproduced + verified with in-engine stills on Mobile (Metal) and Forward+; `test_mobile_ui` 35/34; CI run 38280080276 success |

## Playtest round 1 (2026-10-12, iPhone 14 Pro via iPhone Mirroring, external tester)

Report: `~/.codex/visualizations/2026/10/12/01a130c2-bc4e-7953-afcf-654d142b489f/ios-playtest/REPORT.md`.
Findings and disposition:

| # | Finding | Fix |
|---|---|---|
| P1 | Touch cluster hid water / breath (vitals card) | 2x4 stack on the right edge fitted between state and vitals cards (`1456fc8`) |
| P1 | ~19:23 overview opaque brown | NOT renderer-specific (identical on Forward+), NOT the HUD sepia overlay; exponential + height fog saturate at the 72 m overview. `SkyCycle.depth_scale()` = clamp((44/d)^2, 0.3, 1) (`39014d9`) |
| P2 | Cluster drawn over the 20:00 report | Overlay hides when paused / report visible / pass started (`1456fc8`) |
| P2 | Voice captions over the top button row | `VoiceSubtitles.set_gameplay_side_inset()` on touch devices (`1456fc8`) |

Tester could not establish joystick movement through Mirroring (drag delivery unverified)
— physical two-thumb play on the device remains the open check.

## Scrolling audit (2026-10-13, iPhone 14 Pro, external tester + owner's finger)

Report: `.../ios-playtest/SCROLL_AUDIT.md`. No menu scrolled by touch; title Settings
below the fold; settings / village / guide content clipped.

Root cause (verified in `scene/gui/scroll_container.cpp` @ 4.7.2-stable): ScrollContainer
drag-scrolls from mouse events only (zero `InputEventScreenTouch/Drag`), so it depended on
mouse emulation, which this port disables for two-thumb gameplay.

| # | Finding | Fix (`82de79d`) |
|---|---|---|
| P1 | Village ration/workshop choices unreachable | `UITheme.install_touch_scroll()` on every ScrollContainer (node_added installer, touch devices only): finger drags scroll directly |
| P1 | Title Settings offscreen, menu doesn't scroll | 2x2 GridContainer menu on touch — all four actions fit 1280x720 with no swipe |
| P1 | Settings lower controls clipped | same touch-scroll installer |
| P2 | Guide text clipped | same |

Tests (`test_mobile_ui` 44/43): swipes scroll guide / settings / village on touch and not
on desktop; a swipe starting on a button does not activate it; title actions all inside
the viewport. The audit's larger recommendation (fit each task per screen, no scroll
dependency for essential actions in Village / Settings / How to Play) is NOT done — this
round makes scrolling work; a tabbed/paged mobile layout is a follow-up for the UI lane.

## Fix → build → Codex playtest loop (2026-10-13)

Driver: `~/.hermes/profiles/uts-ops/cache/scratch/ios-tester/` — `BRIEF_TEMPLATE.md` is
filled per cycle, `codex exec --sandbox danger-full-access` plays the installed dev build
through iPhone Mirroring (Codex Computer Use MCP) and writes `REPORT_cycleN.md`; the
on-device `PerfLog` CSV is pulled with `devicectl … copy from … Documents/perf_log.csv`.
Mirroring delivers taps and clicks but **not** finger drags / swipes, so joystick walking,
tap-to-ignite and finger scrolling are "unverifiable" in every report — only a real finger
closes them (the headless suites prove the code path: `test_touch_controls` 83 checks).

| Cycle | Build | fps median / p10 (burn) | >50 ms hitch s | draw calls | prims/frame | Fixes that followed |
|---|---|---|---|---|---|---|
| 1 | `75c0c0f` | 17.8 / 17.4 | 356/542 | 619 | 13.2 M | packed MultiMesh props (`19361f9`) |
| 2 | `19361f9` | 32.1 / 23.1 | 34/583 | 620 | 1.68 M | same-frame tap hold (`023a4f0`), dusk r2 (`b5972b6`) |
| 3 | `023a4f0` | 30.0 / 26.0 | 21/596 | 662 | 1.70 M | HUD draw batching (`8b7c799`), notch captions + dusk r3 (`dc2b759`) |
| 4 | `dc2b759` | **40.4** / 25.8 | **8**/568 | 311 | 1.63 M | village Launch caption, GPU profile (`e11c81d`) |
| 5 | `e11c81d` | 32.8 / 25.3 (more dusk time) | 24/577 | 329 | — | 85% scale = no gain → vertex-bound; 1 shadow cascade (`0d5bcc4`) |
| 6 | `0d5bcc4` | 42.3 idle / **33.2 real fire** | 9 / 10 | 359 / 319 | 1.09 M | first confirmed real burn via Mirroring; fewer fire lights/particles, cheaper dusk post (`c77dda4`) |
| 7 | `c77dda4` | **43.0 / 31.0 (real fire)** | **7**/559 | — | — | daytime-with-fire 46.6, dusk 31–33, overview 55 — loop closed |

**Loop closed at cycle 7.** Tester-confirmed on device: real ignition and spread, sprayer
steam + water consumption, dusk overview legible, all layout/caption/report items, backgrounding
auto-pause + Resume; no open game defect. Remaining "NOT READY" items are the two gestures
iPhone Mirroring cannot deliver (a held joystick drag, a finger swipe) and the clean-firebreak
observation that depends on them — **owner's finger check required** (see Release gate).
CI failed on `c77dda4` (pre-existing `test_ui_navigation` flake: a radio caption shrinking
the preparation body re-clamped the scroll under a focused choice) — fixed in `aef3780`
(12/12 clean), CI run 38320516977 success.
**Current TestFlight candidate: `e2fa4d5`** (2026-10-13: V1 tabbed mobile layouts, opening-film crop fix, text-only animated DOISAKET GAME LAB studio ident; `build/20261013-130815-e2fa4d5-ios-VK1amT/`, IPA 264,828,534 B, sha256 `aaf7aaf7dfc64bc1ee53af74afaf925adc909fde462ba9f6ea9459bf5c50c37d`, CI success; clean-installed on the paired iPhone and approved by the owner on device). Previous candidate: `aef3780`, `UnderTwoSkies.ipa` 264,827,760 bytes,
sha256 `3b7452f44d02f2a804d67c1f616bafaaef714244ddf9ddaacbcc7da8ac72e879`
(`build/20261013-061708-aef3780-ios-mdVGbp/`); the matching Debug app is installed on the
paired iPhone 14 Pro.

Root causes found, in order: (1) 29k zero-scale MultiMesh instances (17 of 18 prop layers
per cell) = 15 M primitives; (2) one draw call per `draw_colored_polygon` → HUD 587 draws;
(3) 4-cascade PSSM directional shadow = 67% of remaining primitives; (4) with fire: 8 omni
lights + 500 alpha particles (3 lights / 300 particles on phones); (5) dusk: mipmapped
screen copy in the inversion post-process. Script CPU is within noise (4.7 ms with 3D
hidden on the Mac).

Tester-confirmed on device by cycle 5: vitals card clear, buttons hidden over the report,
captions clear of the stack (incl. notch inset), 2×2 title, dusk overview legible, village
caption clear of Launch, background auto-pause + Resume.

Real-device evidence (iPhone 14 Pro, dev-signed Debug app from `c69876a`): installed via
`devicectl`, process alive 30 s after detached launch; app container shows
`shader_cache/SceneForwardMobileShaderRD/*.metal.cache` (Mobile renderer on Metal rendered
the 3D scene) and `Documents/campaign.json` + `settings.cfg` (`locale=th`, online board off).

Latest IPA (not uploaded): `UnderTwoSkies.ipa` 264,820,373 bytes,
sha256 `c0d3e0e93c405ceed86f99e1ee2ee6eefd56070c271484b34fb3f49504e78fbd`, Apple
Distribution, profile "iOS Team Store Provisioning Profile: io.github.visarutforthaipbs.undertwoskies",
`beta-reports-active=true`. Built by `tools/build_ios.sh --dev-app` from `82de79d`
(`build/20261013-003800-82de79d-ios-zQtB88/`); the matching Debug app is installed on the
paired iPhone 14 Pro. Note: Godot's clean import occasionally SIGSEGVs in threaded font
reimport (`propagate_notification` from a worker thread); the script refuses the build —
just re-run it.

## Known limits (state honestly)

- Safe-area insets are machine-verified only for the zero branch; notch / home-indicator
  geometry has not been checked by eye on the device yet.
- Button cluster / joystick layout untested on iPad aspect (4:3) on hardware.
- Official 4.7.2 templates ship an x86_64-only simulator slice: no simulator path; a paired
  physical device is the only test target.
- Hover-only HUD affordances (panel fade under pointer) do nothing on touch; panels fade on
  player position instead. Settings "F3/F5–F10" tester note still keyboard-worded.
- **TestFlight (2026-10-13):** App Store Connect app record created by the owner (Apple ID
  `6822175255`, bundle `io.github.visarutforthaipbs.undertwoskies`, primary language Thai).
  Build `0.3.0` from `e2fa4d5` (IPA sha256 `aaf7aaf7…c50c37d`) uploaded via
  `xcodebuild -exportArchive` destination=upload with the Xcode-signed-in Apple ID (the ASC API
  key is pending owner rotation, not used): "Upload succeeded", EXPORT SUCCEEDED.
  Still missing: store metadata, iPhone 6.9"/iPad screenshots, age rating, privacy label
  (OnlineBoard opt-in sends name + score), privacy policy URL, `ITSAppUsesNonExemptEncryption`.

- **Quit-time watchdog kill (0x8BADF00D), fixed in `002bed8` (build 0.3.1, uploaded to TestFlight 2026-10-13 14:28 — "Upload succeeded", IPA sha256 `1aa45f49…42b0c0`):**
  two crash logs on 2026-10-13 (dev build 13:19, TestFlight build 13:51 — binary UUID
  `4E345FED` = the uploaded archive). iOS asked the running app to quit (uninstall /
  TestFlight reinstall); Godot's `applicationWillTerminate:` -> `Main::cleanup` freed
  ShaderMaterials that wait on in-flight Metal pipeline compiles, past the 5 s budget.
  Fix: `ios/plugins/quick_exit` (Godot iOS plugin) swaps that method for `_exit(0)`;
  device console shows `[QuickExit] installed: GDTApplicationDelegate=1 GDTAppDelegateService=1`.
  Verified: hook installed on device, no new crash logs over 10 quit/reinstall cycles.
  NOT verified: an A/B reproduction — the old build did not crash on demand either (the
  hang needs uncached first-launch Metal compiles in flight); TestFlight crash stats on
  0.3.1 are the real-world check.

- **Build 0.3.2 — App Store offline variant (`c8a43ad`), uploaded to TestFlight 2026-10-13 19:50**
  ("Upload succeeded"; IPA 264,831,794 B, sha256 `25175276…e93747ff`). Owner decision:
  offline-only first release. Packaged-binary proof: `project.binary` in the pck carries
  `_custom_features = appstore_offline` (absent in 0.3.1); Info.plist CFBundleVersion 0.3.2,
  `ITSAppUsesNonExemptEncryption=false`; QuickExit present in the release binary.
  Leaderboard: every network path goes through `OnlineBoard._make_request`, gated off.
  Not yet done: on-device check of Settings → ข้อมูล · ช่วยเหลือ links (phone was locked),
  TestFlight install of 0.3.2, iPad hardware QA.

- **0.3.3 — phone UX update (`e971194` fixes, `431cbd7` version), uploaded to TestFlight
  2026-10-15 22:46** ("Upload succeeded"; IPA 264,836,320 B, sha256 `34f022e5…dded94374`).
  0.3 (build 0.3.2) is already public (since 14 Oct, see docs/appstore) and its train is
  closed, so this ships as version 0.3.3. Fixes from the 2026-10-13 iPhone playtest audit:
  touch-worded first-burn tips + phase-1 goal; outlined, always-on-top target marker;
  "too far" / "no brush here" / "no work for the crew here" alerts; tap skips checkpoint
  and ending; Orders button สั่งงาน explains itself; phone Settings hides F-key tester
  tools + log-folder button. Gate 18/18 incl. new test_mobile_feedback (25 checks).
  Packaged proof: CFBundleShortVersionString/CFBundleVersion 0.3.3, appstore_offline in
  project.binary, QuickExit in the binary, touch tips in the pck. NOT yet: owner finger
  check on device; App Review submission of the 0.3.3 update (owner decision).

- **0.3.4 — readable Thai on phones (`ebe94d6`), uploaded to TestFlight 2026-10-15 23:13**
  ("Upload succeeded"; IPA 264,839,483 B, sha256 `f39377e5…7066e30b9`). Owner feedback on
  0.3.3: marker too contrasty, text too small. Measured 0.546 pt per canvas px on a landscape
  iPhone (Small text was 7.1 pt). Device-aware `UITheme.text_scale()` (phones x1.55 max;
  tablets/desktop unchanged) → Small 11 pt, body/buttons 12.6 pt; Thai number+unit kept
  together (U+00A0); no "…" cuts on phone HUD; pages re-fitted and measured at 1280x720 and
  iPhone 14 Pro 1561x720 + notch insets. Marker: soft fill + light cream rim. Gate 18/18.
  0.3.3 superseded (never submitted). NOT yet: owner on-device look; App Review submission.

- **0.3.5 — hide-panels button + HUD de-clutter (`a91e99e`), uploaded to TestFlight
  2026-10-15 23:33** ("Upload succeeded"; IPA 264,843,061 B, sha256 `5fe23a60…0e914f7bb`).
  Owner playtest IMG_3056: button stack covered the vitals card (it re-fitted only in its
  first 3 frames; now re-fits on every HUD card change, 3x3 fallback), voice caption was a
  mid-field slab (now one compact row, max 760 px, only lifted by cards under its width),
  crew chips cut with "…" (width scales), and no way to hide panels (new ซ่อนแผง/แสดงแผง
  button = desktop Tab minimal mode). Gate 18/18. 0.3.4 superseded (never submitted).

### 0.3.7 — 2026-10-16 (hotfix for 0.3.6 title-screen crash)

- **0.3.6 crashed at the title screen on device** (SIGSEGV, `PackedScene::instantiate`,
  crash logs 10:42 and 10:43). The 0.3.6 export excluded `assets/ui/logo/island_0.jpg`
  as unreferenced; it is the texture inside `island.glb` (title-logo island), so the
  model failed to load. Reproduced on the Mac by running the exported **pack** headless
  (`--main-pack`), not the project. Do not promote 0.3.6 — expire it in TestFlight.
- Fix `33f17f0`: file re-included; new `tools/check_pack_loads.gd` loads every exported
  resource from the pck (198) and `tools/build_ios.sh` fails the build on any null.
- IPA 110,004,870 B, sha256 `57f17d0758e8d2a1404baf786dc6287c5ba0c329c47bc8b7170c8fe410a64822`;
  device: alive 25 s after launch, no new crash logs; TestFlight upload 2026-10-16 10:50.

### 0.3.6 — 2026-10-16 (reviewer round 2 + mobile perf pass)

- Source `d5f9765` (code in `018b136`). IPA 104,220,360 B, sha256
  `a4f039944ec759bae12e7d8b3bad4e9930d3ef2e78ccc73a1d762d41d17e8994`; pck 93.8 MB
  (0.3.5: 253 MB IPA / 239 MB pck). TestFlight upload 2026-10-16 10:38 ("Upload succeeded").
- Reviewer items: #3 forest-fire edge arrows (`ui/ForestFireArrows.gd`), #5 lose theme
  (`assets/audio/music_lament.mp3`, ElevenLabs Music), #6 Ta-poh re-voiced with the
  Voice-Design elder voice (12 lines, `tools/audio_pipeline/installed_tapoh_elder_20261016.json`).
  Declined by owner: #1 replay, #2 mid-campaign continue, #4 minimap.
- Mobile perf (Mac, mobile renderer, `--touch`): 45 model/prop textures Lossless WebP ->
  VRAM compressed @1024: GPU mem burn 295 -> 184 MB, village 98 -> 49 MB. Understory props
  no shadow on mobile: prims/frame 998 k -> 794 k. Burn load 1094 -> 800 ms. `MobileRuntime`
  autoload pins `max_fps` 60 on mobile. Export drops unreferenced `_textured`/`_lowpoly`
  models, `island_0.jpg`, blue-hour title PNGs. Phones paint "กำลังเตรียมแปลง…" before the
  hillside builds (desktop launch unchanged).
- Still open: no fps measurement below the iPhone 14 Pro (iOS 17 floor = A12). Store copy
  should say "best on iPhone 12 and newer" until a tester with an older phone reports.
- Gate: `GATE: pass=18 fail=0`; `test_all RESULT: OK (0 failures)`; MOBILE FEEDBACK 46 checks.

## Release gate for this port

0. **Owner finger check (3 minutes, the only thing Mirroring can't do):** on the installed
   build — (a) title → How to Play: swipe up on the text, does it scroll? (b) Village: swipe
   the briefing; (c) burn: hold the left thumb and move — does Khanae walk? (d) blade: tap
   3 brush cells next to her — do they turn to bare clay? If all four pass, the port is
   play-ready for a TestFlight beta.
1. `tools/build_ios.sh --dev-app` from a committed, CI-green commit.
2. Install the Debug app on the paired device; play a full burn with touch; check notch/home
   indicator, iPad layout, background→foreground (auto-pause) and a phone call.
3. Upload the IPA to TestFlight (owner decision — creates the App Store Connect record and
   the public app name); internal testers first, then the Thai indie group.
4. Public App Store submission is an owner escalation (SKU_PLAN §4 gates apply: cultural
   review, asset rights, age rating, privacy label, title conflict check).

## Reproduce

```bash
export GODOT=~/godot/Godot.app/Contents/MacOS/Godot   # 4.7.2.stable + export templates
tools/build_ios.sh --dev-app
xcrun devicectl device install app --device <UDID> build/<run>-ios/xcode/dd/Build/Products/Debug-iphoneos/UnderTwoSkies.app
xcrun devicectl device process launch --device <UDID> io.github.visarutforthaipbs.undertwoskies
# headless gate for the port
$GODOT --headless --path . --fixed-fps 60 --script res://tests/test_touch_controls.gd -- --touch
$GODOT --headless --path . --script res://tests/test_mobile_ui.gd -- --touch
$GODOT --headless --path . --script res://tests/test_mobile_ui.gd
```

Engineering notes and Xcode pitfalls: `godot-game-development` skill,
`references/ios-port-playbook.md` (uts-ops profile).

## First public App Store submission — 2026-10-13 20:45

Version **0.3**, build **0.3.2** (`c8a43ad`) submitted through App Store Connect.
Verified status **Waiting for Review / กำลังรอการตรวจดู**, submission
`88f51f8e-61f7-43be-ae47-e94991e46070`. Free, offline-only, 174 territories
(China mainland excluded), iPhone/iPad only, Data Not Collected, calculated age
13+ with regional equivalents. Thai/English metadata and 20 screenshots uploaded.
**Manual release**: submission is not approval or public availability.
Details and remaining hardware-QA limits: `docs/appstore/SUBMISSION_20261013.md`.
