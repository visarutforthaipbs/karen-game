# Steam account and submission worksheet

Status 2026-10-03: owner says **Steamworks not set up yet**. No payment/submission has occurred. Never put passwords, identity documents, bank numbers or tax identifiers in this repository.

## Owner account steps

1. Use the owner's own Steam account to begin [Steamworks onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding). Decide whether the agreement is signed as an individual or an existing business; use the exact matching legal and bank identity. This document does not select a legal entity.
2. Complete identity, bank and tax verification through Steamworks. Resolve requested information there, not in chat or source control. Authorize the $100 USD/equivalent base app fee when ready. [Fee policy](https://partner.steamgames.com/doc/gettingstarted/appfee).
3. Create the base game and associated demo through the base game's Add Demo workflow. Record verified IDs in the local account worksheet/configuration. [Demo setup](https://partner.steamgames.com/doc/store/application/demos).
4. Set developer/publisher display name and a public support email. These were asked for but are still unanswered. Do not substitute a personal email found in historical build logs.
5. If adding collaborators, give only the needed Steamworks permissions. Use a dedicated build account where appropriate. Credentials/Steam Guard prompts stay local.

## Public/account field worksheet

| Field | Prepared value / status |
| --- | --- |
| Product title | Under Two Skies |
| Thai subtitle | ไร่หมุนเวียนใต้เงาดาวเทียม |
| Legal contracting identity | Owner supplies privately in Steamworks |
| Developer display name | Pending owner |
| Publisher display name | Pending owner |
| Public support email | Pending owner |
| Base App ID / demo App ID | Pending Steamworks setup |
| Windows / Mac / Linux depot IDs | Pending Steamworks setup; only enable verified OS |
| Release date | Coming soon; internal March 2027 target |
| Price | Working $9.99 US / ฿199 TH; owner final confirmation and regional pricing review |
| Release discount | Working 10% / 7 days; verify in dashboard |
| Interface/subtitles | Thai current; English implementation/review pending |
| Full audio language | Audit actual coverage; Thai voices do not imply every line voiced |
| Controller support | Check menu/gameplay/platform coverage; no certification claim |
| Minimum requirements | Pending native-machine measurements |
| Support URL | Use verified public site contact/help page once available |
| AI/content survey | Draft in DISCLOSURE_AND_RIGHTS.md; final responses pending full shipped-content review |

## Store review package

- Copy: STORE_COPY.md, English/Thai short descriptions and About text.
- Art: package/artwork/ contains eight size-checked layout candidates and review sheet.
- Screenshots: package/screenshots/ contains deterministic production-scene capture candidates; inspect each against current build and remove any misleading/debug presentation.
- Video: supplied footage is a development gameplay sample, not a finished release trailer; use VIDEO_AND_MARKETING.md for edit/capture plan.
- Rights: source-level hashes in package/ASSET_RIGHTS_INVENTORY.json; commercial proof and actual exported-resource audit remain required.
- QA: QA_AND_RELEASE_CHECKLIST.md; no assumed hardware certifications.

Before selecting “Mark as ready for review,” resolve all pending field/review items, confirm screenshots and trailer show launch content, and keep copies of submitted files and exact build provenance. Valve approval and public publication are separate actions. [Review requirements](https://partner.steamgames.com/doc/store/review_process).

## SteamPipe preparation

`tools/steam/generate_upload.py` generates VDF files only, in Preview mode, and never invokes SteamCMD. Copy package/upload-config.example.json to an ignored local configuration, enter actual IDs and product-specific reviewed payload directories, and set build_verified only after QA.

Run from the game repository:

```sh
python3 tools/steam/generate_upload.py /absolute/path/local-upload.json --out /absolute/path/steam-preview
```

Never give it a ZIP, the whole repository or an asset-pipeline output. Stage Windows executable/PCK payload, Linux executable/PCK payload, or the notarized macOS .app parent. Use separate base/demo configurations and real depot IDs. Do not reuse a full beta payload as a demo. Review OS depot assignment, executable/working directory/launch option and required redistributables in Steamworks. Mac launch configuration requires account-specific testing.

After Steamworks setup, obtain the SDK/SteamCMD from Valve and use its documented preview/upload workflow. Remove Preview only for an explicitly approved upload; do not set a public branch automatically. Authenticate interactively/local securely, never through a checked-in password. [SteamPipe upload documentation](https://partner.steamgames.com/doc/sdk/uploading).
