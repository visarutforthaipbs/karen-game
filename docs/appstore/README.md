# App Store release preparation — Under Two Skies

Prepared 2026-10-13. **Update 14 October: version 0.3 (0.3.2) is publicly released. Thailand and US App Store pages verified live and Free.** See [submission receipt and saved configuration](SUBMISSION_20261013.md). The sections below preserve the earlier preparation audit and may describe superseded draft state.

**Update 16 October:** version/build **0.3.7** was submitted at **11:16 Bangkok**
with Thai/English update notes and the existing processed build. Apple confirms
**Waiting for Review**. Manual release remains selected. The crashing TestFlight
build 0.3.6 is expired. See [update receipt](SUBMISSION_20261016_0.3.7.md).

**Owner decisions confirmed:** free launch week, then ฿99 / US$2.99 one-time purchase (see `LAUNCH_PRICING.md`; launched 14 October; paid schedule saved for 21 October), offline-only, public version **0.3**, support **visarutsankham@gmail.com**. See `OFFLINE_HANDOFF.md` and the independently tested `OFFLINE_RELEASE.patch`. The patch is not applied to the working game; TestFlight 0.3.1 still contains the online feature. No App Store Connect fields were changed, no review was requested, and the app was not published. Support/privacy web pages are now live. Game runtime source is unchanged; new tooling only renders isolated screenshot candidates and validates this package. Existing README/SKU edits and Steam preparation files were preserved.

## What is prepared

- `STORE_METADATA.json`: Thai and English descriptions, subtitle, promotional text, keywords, recommended categories and version/release decisions. Lengths validated, including the **100 UTF-8-byte keyword limit**; no Steam price was silently reused.
- `PRIVACY_AND_REVIEW.md`: source-backed privacy-label mapping, age-rating worksheet, reviewer instructions and concrete implementation issues.
- `PRIVACY_POLICY_DRAFT.md`: historical draft for the leaderboard-enabled build; not the selected public release.
- `PRIVACY_POLICY_OFFLINE.md` and `web/`: bilingual policy/support pages for the chosen offline release, with the confirmed public contact. Published on the game Cloudflare account; live URLs are recorded in metadata and `WEB_DEPLOYMENT.json`.
- `SUPPORT_DRAFT.md`: bilingual support content and troubleshooting instructions.
- `../../tools/appstore/capture_candidates.gd`: reproducible isolated screenshot capture, production scenes, Mobile renderer on Mac, staged campaign/time/fire states.
- `../../artifacts/appstore-20261013/`: 20 raw screenshot candidates, two review contact sheets, logs and `validation.json`.

The screenshot set contains five scenes per language/device: plot overview, active fire, dusk, village and guide. iPhone medium: **2556×1179**; iPad 13-inch: **2752×2064**. These are accepted dimensions in Apple's current screenshot specification. They are **Mac-rendered candidates**, not device screenshots, not proof of an iPad playthrough, and not certified to match a future release binary. Do not simply upscale the previous 1080p Steam images. Final selection should lead with gameplay/fire, followed by dusk and village. The guide is an optional last image. An app-preview video is optional and has not been manufactured from these stills.

## Live account / release state checked

| Item | Observed state |
| --- | --- |
| App Store Connect session | Signed in and app accessible through Chrome; existing Xcode upload path already worked |
| App | Under Two Skies; Apple ID `6822175255`; bundle `io.github.visarutforthaipbs.undertwoskies`; SKU `UNDERTWOSKIES-IOS`; primary language Thai |
| Public release draft | **1.0, Prepare for Submission** |
| Metadata | Description, subtitle, keywords, support URL and copyright blank in inspected Thai fields; no selected build |
| App category / age rating / content rights | Not configured in inspected app information |
| App Privacy | Not started; policy and privacy-choices URLs empty |
| Review access | Sign-in-required checked by default, despite no required game login; reviewer contact/notes blank |
| Release behaviour | Automatic after approval selected; recommend manual release for the initial launch |
| Price / territories | No initial price or availability configured: the page offers Add Pricing and Set Up Availability |
| Other device availability | Apple Silicon Mac opt-in checked; Vision Pro opt-in checked but 1.0 is shown incompatible. Recommend disabling unqualified additional platforms for an iPhone/iPad launch, or testing them explicitly before advertising availability |
| DSA | Existing app page says developer identified as non-trader; do not silently change this legal declaration. Owner must reassess if intended activity/territories differ |
| TestFlight | Version **0.3**, builds **0.3.1** and 0.3.0 present, status “Ready to Submit”, both assigned to internal **Owner** group; 0.3.1 has 1 invitation. Installation/session/crash metrics display dashes, which are unavailable metrics, not zero-crash evidence |
| Native tooling | Xcode 27.0 (27A266a), Godot 4.7.2, working signed archive/upload evidence. No `asc` or `fastlane` executable found; neither is necessary to use the signed-in browser/Xcode workflow |
| API key | A local key file exists, but the repo records pending owner rotation. Not read, tested, copied, or used |

Local upload evidence: `build/20261013-135628-002bed8-ios-w21NkO/upload.log` records “Upload succeeded” at **14:28:55** and EXPORT SUCCEEDED. `source-manifest.json` records commit `002bed888facf8f0aca19d4d4f3f5683f4b195b9`, IPA 264,830,204 bytes and SHA-256 `1aa45f497f5ee260ca18097f640016483f3f68a0095929eecc19cb6e5842b0c0`. Archive Info.plist has marketing version `0.3`, build `0.3.1`, encryption flag false. This evidence does not qualify a new 1.0 build.

## Required decisions / missing facts

1. **Price confirmed:** free first release.
2. **Public support contact confirmed:** visarutsankham@gmail.com. Support/privacy hosting is verified; private reviewer phone/name should be entered directly in ASC.
3. **Leaderboard scope confirmed:** offline-only. The prepared patch gates networking and identity creation and removes the online controls; it still needs application, packaging and device verification.
4. **Version confirmed:** public `0.3`. Change the existing ASC draft from 1.0 to 0.3 and use a fresh offline build, proposed 0.3.2. Do not submit the existing online-enabled 0.3.1 as offline-only.
5. **Territories and legal status:** choose launch markets, reassess existing non-trader declaration if necessary, and review regional game licences/ratings. Vietnam, mainland China and Korea may need additional compliance depending on the game and distribution; do not enable every territory by default without checking the applicable requirements.
6. **Rights/cultural review:** confirm the existing per-asset provenance/permissions and any paid-release cultural-review gates. `docs/steam/DISCLOSURE_AND_RIGHTS.md` and `docs/steam/package/ASSET_RIGHTS_INVENTORY.json` provide a starting inventory, not clearance. A root open-source licence is a separate decision from permission to distribute third-party assets. Do not assume AI generation guarantees commercial rights or invent adviser endorsement.

## Ordered path to a reviewable release

1. Review/apply `OFFLINE_RELEASE.patch` in the fixing lane and verify the exported offline feature, including upgrade from a legacy opted-in installation. Keep the confirmed policy/support entries accessible.
2. Support/privacy pages are published and their HTTPS content hashes verified. Both render without horizontal overflow at a narrow browser viewport. Verify the links on the physical device and in the final app; a policy link is required both in metadata and in-app.
3. Set matching version/build values and freeze/commit release runtime files. `tools/build_ios.sh` exports a git-archive snapshot. **Its current SOURCE_PATHS clean-source guard omits `ios/` even though the native QuickExit plugin now lives there**; the fixing lane should include plugin sources/binaries in that guard and verify the rebuilt library matches its source before qualifying a new binary.
4. Run meaningful release suites: gameplay, mobile UI/pages, touch, navigation, localization, opening and pause/save. Complete physical joystick/continuous firebreak checks on iPhone, iPad 4:3 playthrough, supported larger UI/text, both landscape orientations, background/foreground and a real call interruption. Check saves across updating the existing TestFlight installation. QuickExit's documented ten checks are useful but not a deterministic A/B proof or several days of crash-free use.
5. Build/archive/sign, verify identifiers/version/entitlements/privacy manifest and IPA hash; upload through the established Xcode signed-in account path. Record processing status and install the exact new TestFlight build. Never call a source checkout or upload-success message an installed/review-approved build.
6. Recapture or compare all chosen screenshots against the exact release build, especially iPad and notch layout. Candidates here have zero safe-area insets and staged state. Confirm PNG dimensions, opacity, localization and that no UI/claims differ. Use the built app icon (existing 1024 master) and a genuine demo video only if required/requested by App Review. Check Apple Silicon Mac and Vision Pro distribution toggles explicitly; they currently default to opted-in despite the requested focus on iPhone/iPad.
7. Populate Thai + English ASC app/version information. Select Games > Strategy / Simulation if those choices remain available. Set price/territories, content-rights declaration, age questionnaire, privacy label and URL, reviewer notes/contact, correct build, encryption response and accessibility answers based only on tested support. No sign-in required. Prefer manual release.
8. Review the complete ready-to-submit page with the owner. Only then request approval for **Submit for Review**. Apple distinguishes “Add for Review” (draft submission) from the final “Submit for Review”. Final public release is a separate action if manual release is selected.

## Sources researched on 2026-10-13

- [Submission workflow](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [Required app/version fields](https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties/)
- [Platform metadata limits](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [App Privacy details and data types](https://developer.apple.com/app-store/app-privacy-details/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Age-rating setup](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating)
- [DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements)
- [Choose the uploaded build](https://developer.apple.com/help/app-store-connect/manage-builds/choose-a-build-to-submit/)
- [Manual release option](https://developer.apple.com/help/app-store-connect/manage-your-apps-availability/select-an-app-store-version-release-option/)

## Revalidate local artifacts

```sh
python3 tools/appstore/validate_preparation.py
```

This checks metadata limits and 20 screenshot files/dimensions/opacity/hashes. `submission_ready` intentionally stays false until the real release gates above are closed. Each final screenshot job exited 0 with two ObjectDB teardown leaks; no SCRIPT ERROR/ERROR lines in final capture logs. This is screenshot-tool validation, not a new full game QA pass.
