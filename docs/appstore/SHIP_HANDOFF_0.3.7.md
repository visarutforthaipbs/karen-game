# Ship handoff — iOS 0.3.7 (2026-10-16)

**Ready to submit from App Store Connect. Do not rebuild.** Everything below is verified,
not self-reported; the build to use is the one already processed on ASC.

## The build
| | |
|---|---|
| Marketing version / build | **0.3.7 / 0.3.7** (CFBundleShortVersionString = CFBundleVersion) |
| Source | `33f17f0` (docs follow-up `8fa36e4`); `main` == `origin/main` |
| CI | green on `33f17f0` (run 38847238033) and `8fa36e4` (38847552453, rerun after a known-flaky UI-scale check) |
| IPA | 110,004,870 B, sha256 `57f17d0758e8d2a1404baf786dc6287c5ba0c329c47bc8b7170c8fe410a64822` |
| Local copy | `build/20261016-104705-33f17f0-ios-ecocd3/ipa/UnderTwoSkies.ipa` (gitignored) |
| TestFlight upload | 2026-10-16 10:50 "Upload succeeded" via xcodebuild -exportArchive (app-store-connect, team 79QFYKTJMN) |
| Device check | iPhone 14 Pro: installed, alive 25 s after launch, no crash logs |
| Pack check | `tools/check_pack_loads.gd`: 198 resources, 0 failures |
| Gate | `GATE: pass=18 fail=0`, `test_all RESULT: OK (0 failures)` |

## Do NOT ship
- **0.3.6** (uploaded 10:38) crashes at the title screen on device. **Expire it in
  TestFlight** before/when submitting 0.3.7. Cause and fix in `docs/IOS_PORT.md` → "0.3.7".
- 0.3.3–0.3.5 are superseded.

## What is in 0.3.7 (since the public 0.3 / 0.3.2)
- Phone UX: touch tutorial, visible dig marker, hide-panels button, larger Thai text,
  tap-to-skip screens (0.3.3–0.3.5).
- Reviewer round 2: forest-fire edge arrows, lose-screen lament, elder voice for Ta-poh.
- Mobile perf: download 253 → 110 MB, GPU memory −38 %, triangles −20 %, 60 fps cap,
  loading hint. Details: `docs/IOS_PORT.md` → "0.3.6" and "0.3.7".

## Owner decisions still open for the store listing (not build blockers)
- App Review contact, age rating, "What's New" text (TH + EN).
- Mac / Vision Pro availability (recommended off).
- Device note: **no measurement below iPhone 14 Pro**; suggest "ทำงานได้ดีที่สุดบน iPhone 12 ขึ้นไป".
- Store metadata decisions already recorded: `docs/appstore/STORE_METADATA.json`
  (free, all territories except China mainland; offline, "Data Not Collected").

## If a rebuild is ever needed
`GODOT="$HOME/godot/Godot.app/Contents/MacOS/Godot" tools/build_ios.sh --dev-app`
from a clean committed tree. The 0.3 train is closed on ASC: bump both version keys in
`export_presets.cfg` first (next free = 0.3.8). Upload = copy `upload-options.plist`
into the build dir, then `env PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive …`
(see `docs/IOS_PORT.md`). Submission to App Review is the owner's call.
