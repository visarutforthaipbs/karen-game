# Steam preparation package — Under Two Skies

Prepared 2026-10-03. Steamworks is **not set up yet**, per the owner. This package is local and reviewable; nothing was purchased, uploaded, submitted or announced.

## Start here

1. [Steam sales schedule and backlog](STEAM_SALES_PLAN.md)
2. [Account setup and submission worksheet](ACCOUNT_AND_SUBMISSION.md)
3. [Bilingual store copy](STORE_COPY.md)
4. [Artwork review sheet](package/artwork/review.png) — eight current-size capsule/library layout candidates composed from approved game identity
5. [Gameplay capture folder](package/screenshots/01_preparation.png) — five 1920×1080 production-scene candidates, captured with staged state and isolated saves
6. [Video and marketing drafts](VIDEO_AND_MARKETING.md) — storyboard, clip briefs, pitches and four-week campaign; gameplay-only silent review cut included
7. [Rights and AI/content disclosure worksheet](DISCLOSURE_AND_RIGHTS.md)
8. [QA and release checks](QA_AND_RELEASE_CHECKLIST.md)
9. [Demo/localization implementation handoff](IMPLEMENTATION_HANDOFF.md)

## Prepared versus pending

| Prepared locally | Pending before submission/sale |
| --- | --- |
| English/Thai store drafts and working price/schedule | Human proofreading, cultural review, final price/date |
| Eight dimension-checked artwork candidates and visual review sheet | Final owner art approval; hero/logo Steam placement preview |
| Five native 1080p real-scene screenshot candidates | Final selection/recapture from approved release; English captures after localization |
| Sixty-second gameplay-only silent review video cut | Full watch-through, fresh current-build trailer/audio/captions and encode approval |
| 304 source-asset hashes and provider/evidence hints | Per-asset commercial proof and actual exported-payload classification |
| 382 Thai quoted source candidates with file/line | Translation infrastructure, English implementation and human review |
| Local SteamPipe VDF generator with Preview mode and validation tests | Steamworks identity/bank/tax, base/demo/depot IDs, verified product payloads |
| Detailed demo boundary/build/save handoff | Actual bounded demo code and native QA |
| Release/QA and marketing materials | Fresh players, measured hardware, authorized outreach, final launch support |

The archive is an **internal preparation bundle**, not a public press kit or game installer. Rights/localization inventories and internal task notes should not be uploaded as Steam game content.

## Account information still needed

Owner completes Steamworks privately, chooses the public developer/publisher name and supplies a public support contact. No credentials or banking/identity documents belong here. After real IDs exist, generate/test upload files and connect the real store URL in the website/demo. Pending fields are kept empty; no fabricated App IDs.

## Reproduce and validate

```sh
python3 tools/steam/prepare_inventory.py
python3 tools/steam/test_upload.py
node tools/steam/render_artwork.cjs
godot --path . --script tools/steam/capture_store.gd -- docs/steam/package/screenshots
python3 tools/steam/validate_package.py
```

The artwork renderer requires Playwright/Chromium; this session used the bundled Node dependency path. No AI image generation/retouching was used for layout exports: approved logo artwork was placed on CSS faceted canvases. Capture uses the installed engine and writes only scratch data under its output directory. The video cut was made from source seconds 30–90; the original includes Discord/desktop imagery earlier and is excluded.

Official submission rules and dates are linked in the relevant worksheets; recheck Steamworks' actual checklist at submission time. Current source/build context is recorded in package/MANIFEST.json. Later game changes require a fresh screenshot, rights and localization inventory review.
