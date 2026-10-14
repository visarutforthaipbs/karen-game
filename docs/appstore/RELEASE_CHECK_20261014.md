# Public App Store release check — 14 October 2026

**Outcome: released and publicly listed.** The owner clicked manual release. App Store Connect's current version is 0.3, build 0.3.2, Ready for Distribution / พร้อมสำหรับการจัดจำหน่าย.

- [Thai App Store page](https://apps.apple.com/th/app/under-two-skies/id6822175255?l=th): loads, Thai subtitle/description displayed, Free, screenshots, 13+, Strategy, Data Not Collected.
- [U.S. App Store page](https://apps.apple.com/us/app/under-two-skies/id6822175255): loads, English copy, Free, screenshots, 13+, Strategy, Data Not Collected.
- Public requirements: iPhone/iPad, iOS/iPadOS 17+, A12 Bionic or newer; public download size shown as 319 MB. The earlier 264,831,794-byte upload IPA size is not the storefront download size.
- Public policy link points to the deployed offline policy.
- Distribution availability shows 174 available territories, one unavailable. Mac and Vision Pro opt-in boxes remain unchecked.
- Owner chose **Move to 21 October** when asked about preserving seven launch days. Replaced the old 27 October global paid change. Final review confirmed THB 99.00 and USD 2.99. After reload, upcoming row starts 21 October 2026 with no end; current free pricing ends that day. Storefront-local cutoff timing applies.

## Non-blocking issue for the fixing agent

**P2: public Languages field lists English only.** Thai store copy exists and the game supports Thai, but both product pages' binary-language field shows English. In the shipped archive Info.plist, CFBundleDevelopmentRegion is `en` and CFBundleLocalizations is absent. Likely export metadata omission; no runtime language fix was made.

Acceptance: next exported/reviewed binary declares its real supported localizations (`th`, `en`), the actual Thai/English in-game switch still works, and Apple's published Languages field includes both after processing. Check the engine's supported export/localization workflow rather than blindly patching source or an already signed IPA.

## Evidence limits

Read-only public listing and account verification plus authorized pricing change. This check does not prove an App Store install, save upgrade, physical joystick feel, iPad playthrough or crash-free gameplay. Do not describe prior cable/TestFlight observations as a newly tested public App Store binary.
