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

Real-device evidence (iPhone 14 Pro, dev-signed Debug app from `c69876a`): installed via
`devicectl`, process alive 30 s after detached launch; app container shows
`shader_cache/SceneForwardMobileShaderRD/*.metal.cache` (Mobile renderer on Metal rendered
the 3D scene) and `Documents/campaign.json` + `settings.cfg` (`locale=th`, online board off).

Latest IPA (not uploaded): `UnderTwoSkies.ipa` 264,817,456 bytes,
sha256 `e4278347d554fa9f09272d840cbbfe092f31ac821a09dc39f3d7e6296f889bf0`, Apple
Distribution, profile "iOS Team Store Provisioning Profile: io.github.visarutforthaipbs.undertwoskies",
`beta-reports-active=true`. Built by `tools/build_ios.sh --dev-app` from `39014d9`
(`build/20261012-235010-39014d9-ios-1Rw5c0/`); the matching Debug app is installed on the
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
- No App Store Connect app record, no TestFlight build, no store metadata/screenshots in
  iPhone/iPad sizes, no age rating / privacy label answered yet.

## Release gate for this port

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
