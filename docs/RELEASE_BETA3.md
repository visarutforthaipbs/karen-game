# Under Two Skies — beta 3 / 0.3.0

Prepared 2026-10-03 at the owner's request. **Status: release candidate in
qualification; public downloads remain beta2 until final installer verification.**

## What ships

Thai/English UI, subtitles and recorded speech; the first-New-Game context film
with Pause, Skip, replay and background audio; consistent menu/controller focus
and clearer preparation/gameplay feedback. Cultural representations, character
identity and the 14:00–20:00 burn rules are preserved.

## Audit and confirmed repairs

Three Codex workstreams reviewed gameplay/saves, UI/localization and packaging.
An additional Claude review could not authenticate; no findings are attributed
to it. The manager independently reproduces and integrates fixes.

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
- The online-score version still identified beta1. It now identifies beta3.

Two main-suite failures were stale scratch scoreboard backups between fixture
phases, not a second game defect. Fixtures now clear their own main/temp/backup
files. No test edits touch player saves or submit scores.

## Qualification evidence

Evidence root: `artifacts/release_beta3_audit_20261003/`.

- Gameplay/save agent: 102 recovery/version/boundary checks, no script errors.
- UI agent: 92 opening, 86 menu and 18 localization checks; remaining integration
  suites total 1,038 checks (167 localized UI, 540 gameplay UI, 37 navigation,
  49 voice captions, 245 localized gameplay). No failures or script errors.
- Existing gameplay, animation/equipment/ranger/asset/audio/guidance/shortcut
  suites and 120-frame smoke pass; final integrated main suite is repeated.
- Catalog: 418 entries, 30 spoken event mappings, 405 source literals; no issues.
- Build safeguards: 7 unit regressions. PCK validator: 15 byte/payload regressions.
- Packaging audit pack: all 713 entries intact, 76 approved voices exact, three
  catalogs and two font licenses included. Actual final archives must repeat this.

Synthetic/isolated probes do not substitute for native target-device playtesting.
Some scene-heavy fixtures retain 4–24 ObjectDB references on engine shutdown;
these are test teardown warnings, not observed gameplay exceptions. Windows and
Steam Deck device QA, fresh-player testing, English proofreading and Karen
cultural/listening review remain limits for a later paid Steam release.

## Build and publication procedure

1. Commit qualified runtime sources/assets and run `tools/build.sh`.
2. Inspect all ZIPs and actual payloads with `tools/release/validate_pack.py`.
3. Run the exported Mac executable from an empty directory with the external
   `tools/release/qualify_native.gd` and an absolute scratch output directory.
4. Sign/notarize with `tools/notarize_mac.sh`; require Accepted, clean log, stapled
   ticket and Gatekeeper “Notarized Developer ID”. Only use the keychain profile.
5. Generate `release-manifest.json` and `SHA256SUMS.txt` from the final archives.
6. Upload under R2 `beta3/`, keep beta2 untouched, add beta3 routes to the download
   Worker and verify full download hashes plus HTTP HEAD/Range.
7. Update promo/download copy and actual ZIP sizes together; publish promo through
   its verified GitHub→Cloudflare workflow. Check both languages and four routes.

No Steam app IDs, release date or paid edition are invented by this beta update.
