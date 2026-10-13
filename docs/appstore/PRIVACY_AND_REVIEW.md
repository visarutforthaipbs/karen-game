# Privacy, age rating, and App Review preparation

Prepared 2026-10-13 from source at `308ef56`, existing archive `002bed8`, live App Store Connect, and Apple documentation. Draft answers require owner confirmation of actual operational practices; no declarations were published.

## Selected public release: offline-only

Owner selected free/offline/public version 0.3, contact visarutsankham@gmail.com. `OFFLINE_RELEASE.patch` is prepared and tested in an isolated copy but not applied or packaged. After verifying that final binary cannot transmit to the leaderboard, propose Data Not Collected for that iOS variant; reconcile Apple’s all-platform label scope and any diagnostics. The mapping below documents the older leaderboard-enabled baseline, not the selected offline release. `PRIVACY_POLICY_OFFLINE.md` supersedes the legacy policy draft for publication.

## Privacy mapping for the current optional leaderboard

Do not select “Data Not Collected” merely because the leaderboard is off by default. Apple permits omission of optional collection only when all of its criteria are met; recurring gameplay-score submission does not obviously qualify. [Apple privacy details](https://developer.apple.com/app-store/app-privacy-details/).

| Source-backed data | Proposed Apple type | Purpose | Linked to identity | Tracking |
| --- | --- | --- | --- | --- |
| Player-selected public display name | Name, under Contact Info (confirm final taxonomy in ASC) | App Functionality | Yes, linked to persistent client identifier and public score row | No evidence of tracking |
| Random persistent `client_id` | User ID, under Identifiers | App Functionality | Yes; pseudonymous does not mean unlinked | No evidence of tracking |
| Plots, year, average ash, detection count, ending cause, mode/week | Gameplay Content | App Functionality | Yes, same client row | No evidence of tracking |
| Game-version string, timestamps, authentication secret | Document as functional metadata/credential accompanying the above; confirm whether any further ASC type applies | App Functionality | Associated with client row | No evidence of tracking |
| IP/HTTP metadata at Cloudflare | Operational configuration not verified: check Workers observability/access logging, retention, IP-based use, and subprocessors | Confirm purpose before declaration | Unknown until account check | Do not infer location collection merely from network transport |
| Local saves, settings, playtest/performance CSVs | Not sent by game source in the examined paths | Local operation | Local files only | No |

Evidence: `scripts/OnlineBoard.gd` constructs payloads and gates every request on opt-in; `scripts/GameSettings.gd` defaults online off; `server/leaderboard/worker.js` stores public name/results plus client ID, secret, game version and timestamps in Cloudflare D1. The public endpoint does not return client IDs or secrets. No advertising/analytics SDK integration was found in these source paths. TestFlight/Apple diagnostics are distinct from the game's local CSV files; reconcile any actual diagnostic collection with Apple's form.

“Delete my scores” deletes the client's rows using its locally stored identifier and secret. Turning online OFF stops further requests; it does not delete rows. No automatic retention expiry is implemented in the checked worker. Uninstalling the app removes local deletion credentials, potentially preventing self-service deletion of old rows. The privacy policy must explain an alternate support route and the operator must establish how to validate such requests. Do not promise automatic expiry, guaranteed backup erasure, or a fixed response deadline without an operational policy.

## Concrete pre-submission issues

1. **Public names / moderation:** public leaderboard aliases are user-entered content. `sanitizeName()` strips controls and angle brackets but is not an objectionable-name filter. No report/block/moderation workflow was found. Treat Apple guideline 1.2 as an App Review risk requiring a release decision: implement the necessary controls, or produce an explicitly offline first-release build that removes online submission/display and related settings. Default-off alone does not remove the feature. [App Review Guidelines 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content).
2. **Privacy policy link in the app:** no in-app policy link was found in current Settings. Apple requires the policy in App Store metadata and within the app. Publish a truthful policy and have the fixing agent add an easily accessible link, then verify it on-device. [Guideline 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy).
3. **Support/retention:** choose a monitored public contact and establish retention, deletion escalation, and Cloudflare logging practices before publishing the policy. Credentials appear in the score-deletion URL; ensure logs do not retain them unnecessarily. This is an implementation/operational finding, not a claim that a leak has occurred.
4. **Account deletion applicability:** the app has no user login/account registration UI, but creates a persistent pseudonymous identity for the board. Document that mechanism and its deletion behaviour for review. Do not claim blanket exemption from Apple's account-deletion requirement without resolving what is retained and how it is deleted. [Apple account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/).
5. **Privacy manifest:** archive contains `PrivacyInfo.xcprivacy`, `NSPrivacyTracking=false`, and file-timestamp/boot-time/disk-space API reasons. It does not itself establish that collection disclosures are complete. Reconcile the final binary, any SDKs, privacy report, and ASC label. Do not add unused API reasons or copy unrelated declarations.

## Age-rating worksheet

Apple calculates the rating from the current questionnaire. Do not predeclare “4+”, “9+”, or “12+”. The live rating setup is incomplete. [Set an age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating).

| Topic | Draft answer / evidence to review |
| --- | --- |
| Parental controls / age assurance | None found; not a Kids Category submission |
| Unrestricted web access | No in-app general-purpose browser found; a support link does not by itself imply unrestricted browsing |
| User-generated content | YES if the current public alias leaderboard remains in the release |
| Messaging/chat/social feed | No chat or messaging feature found; leaderboard is not a messaging system |
| Ads | None found in examined game source |
| Profanity, sexual content, nudity, drugs | No such intended content identified in the reviewed premise/copy; final audiovisual pass required, including public names if retained |
| Horror/fear | Review tense surveillance, fire/smoke danger and punitive endings; do not automatically answer None |
| Cartoon/fantasy or realistic violence | Review ranger encounters and crackdown narrative/visuals; simulated fire is present, but a frequency answer requires viewing all relevant scenes |
| Weapons | Review ranger models/props and any weapon depictions before answering |
| Contests | Leaderboard compares scores; review Apple's descriptor examples before choosing an answer |
| Gambling, simulated gambling, loot boxes | No gambling, paid chance mechanics, or loot boxes found |
| Medical/wellness claims | None intended; fictional farming simulation, not training/safety advice |

## Reviewer notes draft (English)

Under Two Skies is a single-player tactical farming/survival game. No account or sign-in is required for core gameplay. The default language is Thai; choose Settings > Display/Language selector to switch to English (the language selector sits above the category tabs).

From the title, choose New Game. After the introductory film, prepare at the village and start a burn. The virtual joystick on the left moves the player. Touch nearby plot cells to use the selected torch, blade or sprayer. The right-side controls select tools, rally/order the crew, zoom, rotate, and pause. A plot runs from 14:00 to the 20:00 satellite result. Existing campaign progress is saved at the village; an interrupted in-progress plot is not a resumable mid-burn save.

The game fictionalises surveillance and simplifies fire/farming systems. It is not practical burning instruction or a factual satellite schedule. Thai and English UI, subtitles and recorded speech are included. There are no in-app purchases or advertising integrations found in this release source.

If the online leaderboard is retained: it is optional and disabled by default. Settings > Online / Info enables it; the same category offers score deletion. The privacy policy describes the submitted data. Final notes must describe the resolved moderation and deletion workflow; do not send this conditional paragraph unchanged.

Before submission, replace build/version references with the final verified binary, attach a real-device demonstration if requested, provide private reviewer contact details directly in ASC, and uncheck “Sign-in required”. Do not add personal contact details to this public repo.
