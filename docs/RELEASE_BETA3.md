# Under Two Skies — beta 3 / 0.3.0

Prepared 2026-10-03 at the owner's request; published 2026-10-04 (Asia/Bangkok).
**Status: public beta 3 is live; installers and distribution have passed release
verification.** Older beta1/beta2 URLs remain available for rollback.

## What ships

Thai/English UI, subtitles and recorded speech; the first-New-Game context film
with Pause, Skip, replay and background audio; consistent menu/controller focus
and clearer preparation/gameplay feedback. Cultural representations, character
identity and the 14:00–20:00 burn rules are preserved.

## Audit and confirmed repairs

Three Codex workstreams reviewed gameplay/saves, UI/localization and packaging.
An additional Claude review could not authenticate; no findings are attributed
to it. The manager independently reproduced and integrated fixes.

- First-use film Back triggered a detached-viewport script error during the
  immediate transition to preparation. Consume the event before closing.
- New campaigns retained previous last-burn summary fields. Reset them at the
  campaign boundary; profile-level opening completion remains persistent.
- Damaged numeric/enum save values could load before a later dictionary error.
  Validate finite numbers and legal choices before changing live state. Malformed
  versions remain untouched; valid version-1 saves keep their format.
- Scoreboard crash recovery ignored its atomic backup. Recover missing/damaged
  tables, preserve intentional empty ones, retain legacy migration.
- Exports included development materials and omitted font notices. Exclude
  internal paths/rejected takes and include current localization/licenses.
- Build/import and signed-boot scripts could accept errors with engine exit 0.
  Check logs and outputs; require committed runtime source and unique build paths.
  Export a frozen Git snapshot and reject checkout/HEAD changes during export.
- The online-score version still identified beta1. It now identifies beta3.
- Radio recordings announced drones, patrols, checkpoints or storms that were
  absent from the current plot. Filter broadcasts against the current campaign
  configuration in both languages, preserving the approved audio and captions.
- Radio captions covered preparation choices. Dynamically reserve space above
  the pinned launch action while a subtitle is visible; recover the scroll space
  when it clears or a modal hides it.
- Clean imports loaded the global project font before generating its font data.
  Supply fonts through the existing shared UI theme and apply it explicitly to
  persistent captions; clean imports and Thai-glyph caption checks now pass.

Two main-suite failures were stale scratch scoreboard backups between fixture
phases, not a second game defect. Fixtures now clear their own main/temp/backup
files. No test edits touch player saves or submit scores.

## Qualification evidence

Evidence root: `artifacts/release_beta3_audit_20261003/`.

- Gameplay/save agent: 102 recovery/version/boundary checks, no script errors.
- UI agent: 92 opening, 86 menu and 18 localization checks; remaining integration
  suites total 1,038 checks (167 localized UI, 540 gameplay UI, 37 navigation,
  49 voice captions, 245 localized gameplay). Final caption checks increased
  to 51 with explicit theme and Thai-glyph coverage. No failures or script errors.
- Existing gameplay, animation/equipment/ranger/asset/audio/guidance/shortcut
  suites and 120-frame smoke pass; the final integrated main suite passed again.
- Catalog: 418 entries, 30 spoken event mappings, 405 source literals; no issues.
- Build safeguards: 10 unit regressions. PCK validator: 15 byte/payload regressions.
- Preparation captions: 101 geometry, focus, growth and lifecycle checks across
  two languages, window heights and UI scales.
- Radio: 446 context checks, plus 107 locale, 49 subtitle and 20 audio checks.
- Download Worker: 14 handler checks, including preserved older-release routes,
  HEAD, Range, conditional requests, malformed URLs and bilingual release copy.
- Packaging audit pack: all 713 entries intact, 76 approved voices exact, three
  catalogs and two font licenses included. All three final archives passed this.

Synthetic/isolated probes do not substitute for native target-device playtesting.
Some scene-heavy fixtures retain 2–24 ObjectDB references on engine shutdown;
these are test teardown warnings, not observed gameplay exceptions. Native
Windows/Linux/Steam Deck device QA, fresh-player testing, English proofreading
and Karen cultural/listening review remain limits for a later paid Steam release.

## Published release and provenance

- Qualified game commit: `6f15bd65cd9a96e86379a82168507d302a6bc74c`.
  [Game CI](https://github.com/visarutforthaipbs/karen-game/actions/runs/37139923039)
  passed. The build uses an immutable `git archive` snapshot; all 810 tracked
  runtime/config/asset/build/notary files match that commit's Git blobs.
- Final local build: `build/20261004-001641-6f15bd6-3vfTbR/`. Exported packs each
  contain 713 integrity-checked entries and 76 exact approved voices; ZIP integrity,
  executable architecture/permissions and cold import/export logs passed.
- Actual Mac exported-PCK scene qualification: 29 checks, zero failures, native
  renderer and isolated saves. Covers title/settings, both languages, first-use
  opening/music/ambience, pause/back, preparation/radio/captions, gameplay, clock
  pause/resume and Continue. Separate signed application boot passed with no
  engine errors; the release executable is not claimed to run `--script` tests.
- Apple submission `e225ea22-89e4-44d0-8a9a-157f139494cc`: **Accepted**, `issues: null`,
  tickets for arm64 and x86_64. Staple/validate passed. Gatekeeper reports
  **Notarized Developer ID**. The final ZIP payload matches the qualified PCK.
- R2 bucket `undertwoskies-beta`, prefix `beta3/`: all three final installers,
  release manifest and SHA256SUMS installed. Download Worker version
  `55b9dfe0-c7a2-4207-8697-1aee36db3450` serves them in the verified
  Under Two Skies - Game Cloudflare account.
- All three full public downloads match their qualified archive's SHA-256 and
  exact byte count. HEAD 200, Range 206 and ETag 304 behavior passed. Live Thai,
  `/th/` and English download pages show beta 3 / 0.3.0 and the final sizes.
  Older beta1/beta2 Mac routes still return 200.

| Public archive | Bytes | SHA-256 |
| --- | ---: | --- |
| UnderTwoSkies-Windows.zip | 275531657 | `7a4c004aa10aa0b9f380e0e6881fd237ae5895f59014f9aaa1646b3e5eed872f` |
| UnderTwoSkies-macOS.zip | 297680164 | `32a53ae080d887fe90151d220a3c8bc491937ff41978cde543b4000ea5f88618` |
| UnderTwoSkies-Linux.zip | 265860887 | `7230600bf76a6a252ab52f1ff19fbbc1d892ece2fce0886ae6f86503f5377254` |

The Mac public filename aliases the local `UnderTwoSkies-macOS-notarized.zip`.
Displayed sizes use rounded decimal MB: 276 / 298 / 266. Durable copies:
[release manifest](releases/beta3-manifest.json) and
[public download verification](releases/beta3-distribution-validation.json).
Public [downloads](https://undertwoskies-download.undertwoskies-game.workers.dev/),
[manifest](https://undertwoskies-download.undertwoskies-game.workers.dev/beta3/release-manifest.json)
and [checksums](https://undertwoskies-download.undertwoskies-game.workers.dev/beta3/SHA256SUMS.txt).

Promo source `fdcd5b080e9da491d5b6ea6aa661135f055633fd` updates all four routes
with bilingual beta 3 coverage, first-use film behavior, current feedback fields
and verified archive sizes. The
[automatic deployment](https://github.com/visarutforthaipbs/undertwoskies-website-promote/actions/runs/37140603517)
and [site verification](https://github.com/visarutforthaipbs/undertwoskies-website-promote/actions/runs/37140603544)
both succeeded. All four live routes return 200 and are byte-identical to the
locally verified production build (with production `SITE_URL`): English/Thai
homepages and press pages. Each includes the current build feedback fields,
bilingual coverage and correct localized download link. See
[promo distribution verification](releases/beta3-promo-validation.json).
The promotion site remains automatically deployed after verified main pushes.

## Reproduce the release checks

1. Commit qualified runtime sources/assets and run `tools/build.sh`.
2. Inspect ZIPs and actual payloads with `tools/release/validate_pack.py`.
3. Run Godot against the actual Mac PCK from an empty directory with
   `--main-pack`, external `tools/release/qualify_native.gd` and an absolute
   scratch output directory. Test the signed release app separately with explicit
   boot logs; release templates ignore `--script`.
4. Sign/notarize with `tools/notarize_mac.sh`; require Accepted, clean log, stapled
   ticket and Gatekeeper “Notarized Developer ID”. Only use the keychain profile.
5. Generate `release-manifest.json` and `SHA256SUMS.txt` from final archives;
   upload under a new versioned R2 prefix, preserving previous releases.
6. Run `tools/release/verify_downloads.py` against the public origin and final
   manifest. Update both websites' release copy and actual sizes together.
7. Publish promo through GitHub→Cloudflare and check both languages/four routes.

No Steam app IDs, paid-release date or paid edition are invented by this beta update.
