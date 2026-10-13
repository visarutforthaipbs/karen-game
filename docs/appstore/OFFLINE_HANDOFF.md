# Owner-approved first App Store release

Confirmed 2026-10-13:

- **Free** first release.
- Public marketing version **0.3**.
- **Offline-only**: remove leaderboard access rather than merely defaulting its toggle off.
- Public support contact: **visarutsankham@gmail.com**.

## Prepared code patch — not applied to the working game

`OFFLINE_RELEASE.patch` applies cleanly to the current runtime source at `308ef56`. It has been applied and tested only in `/tmp/uts-offline-review/project`.

The patch:

1. Sets iOS custom feature `appstore_offline` and proposes fresh build **0.3.2**, preserving marketing version **0.3**. Existing 0.3.1 is not an offline-only release.
2. Adds `OnlineBoard.available()` and gates both identity creation and the HTTP request factory. Even an old installation with online opted in cannot start leaderboard communication. The desktop/default build keeps existing behaviour.
3. Removes the opt-in/deletion online controls in the offline variant, replaces the last tab with Data / Help, and adds privacy/support actions. The local-record player name remains local and is labelled accordingly.
4. Includes Thai/English translations for the new text.
5. Includes `ios/` in the clean-source guard for `tools/build_ios.sh`, covering the native QuickExit plugin.
6. Adds `tests/test_appstore_offline.gd` for the offline variant.

Policy/support URLs in the patch are **published and verified**:

- `https://undertwoskies-ios-support.undertwoskies-game.workers.dev/privacy/`
- `https://undertwoskies-ios-support.undertwoskies-game.workers.dev/support/`

The static site under `web/` was deployed using the re-authenticated `undertwoskies-game` profile and the existing game account. Metadata now contains these URLs. Live HTTP content hashes match the source; see `artifacts/appstore-20261013/WEB_DEPLOYMENT.json`. Pages deliberately identify the scope as the planned offline release so they do not misdescribe earlier TestFlight/desktop builds.

## Validation

- `git apply --check docs/appstore/OFFLINE_RELEASE.patch` passed against the current game checkout.
- Isolated offline regression: **7 assertions passed**, exit 0, no SCRIPT ERROR / ERROR in log. Verifies disabled legacy opt-in, no identity creation, blocked HTTP factory, no online deletion control, and privacy/support actions.
- Baseline mobile-page regression: **70 checks passed**, exit 0. Offline 120-frame headless smoke: exit 0, no engine errors. Logs are copied to `artifacts/appstore-20261013/offline-checks/`. These focused checks are not a full release/device QA gate.
- The patch has **not** been merged/committed into the primary checkout, built as an IPA, installed, or uploaded. No live App Store Connect values were changed.

## Fixing/release agent sequence

1. Review the patch and current working tree; preserve existing edits. Apply it, run the offline test with `-- --touch --appstore-offline`, and run the existing mobile/gameplay/localization suites. Add the new offline test to CI and adapt broader tests if run with the release flag.
2. Verify `appstore_offline` is actually present in the exported iOS build. A test command flag alone does not establish the packaged binary's behaviour. Test upgrade from 0.3.1 with a legacy opt-in and confirm no leaderboard request occurs. Do not delete the user's existing server rows or local credentials automatically; earlier beta data needs its own support/deletion route.
3. Hosting is complete and metadata URLs are set. Verify both links from the final app on the physical device and keep site hosting/logging practices consistent with the policy.
4. Freeze/commit the release source, build 0.3 (0.3.2 or another unused build number), and verify QuickExit, signatures, Info.plist, privacy manifest and hash. Install the exact new build through TestFlight and complete physical iPhone/iPad QA.
5. Change the live public draft from 1.0 to **0.3**, set a zero-price tier, choose launch territories explicitly, use the prepared Thai/English metadata and final screenshots, uncheck review sign-in-required, and select manual release.
6. Privacy-label proposal for this offline binary: **Data Not Collected**, only after verifying no game/SDK transmission or diagnostic upload occurs from the final binary. Optional email support/external browser hosting is explained separately in the policy; reconcile with Apple's current disclosure rules. Do not apply this answer to earlier leaderboard-enabled builds or other platforms without checking the all-platform scope of Apple's label.
7. Age questionnaire: public aliases/UGC and leaderboard contests are absent in this release. Other descriptors still require viewing the fire/surveillance/ranger/endings content; Apple determines the resulting rating. Retain rights/cultural review and actual supported-device checks.
8. Show the complete submission to the owner before Submit for Review; manual public release remains a separate final action.

## Remaining owner / operational items

Launch territories, private App Review contact phone/name, rights clearance, final age descriptors, and whether to opt out of unqualified Mac/Vision Pro availability. The existing non-trader DSA declaration must remain an informed owner statement; free pricing does not determine trader status by itself.

## Hosting connection check

The owner re-authenticated the named `undertwoskies-game` profile. Access to the existing game worker succeeded, and the separate static support worker was deployed in the game account. No leaderboard worker or database was modified. Public pages and bundled font/license are served over HTTPS; HTTP 200 and SHA-256 content matches are recorded with the deployed version in `WEB_DEPLOYMENT.json`.
