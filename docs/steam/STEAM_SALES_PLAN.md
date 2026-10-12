# Under Two Skies — Steam sales execution plan

Created 2026-10-03 following the owner's instruction to plan Steam sales. This is the active Steam preparation plan. It narrows the [distribution review](../DISTRIBUTION_MARKETING_PLAN_20261003.md); [SKU_PLAN.md](../../SKU_PLAN.md) remains the product reference. Dates and prices below are working targets, not publicly announced commitments. This request authorizes planning and preparation; no account purchase, submission, outreach or release was performed.

## Commercial baseline

| Item | Working choice |
| --- | --- |
| Store product | **Under Two Skies**, one premium base game |
| Release model | v1.0 full release after beta; do not use Early Access solely to fund unfinished work |
| US / Thailand list price | $9.99 / ฿199, independently configured regional prices; validate against final quality and player feedback |
| Launch offer | Proposed 10% discount for 7 days; verify regional rounding in Steamworks |
| Public release window | March 2027, after Next Fest; internal target March 9, subject to all gates |
| Public date before final review | “Coming soon”; no exact promise until release candidate and staffing are confirmed |
| Languages | Thai and reviewed English interface/subtitles; Thai voices where present; mark language columns accurately |
| Platforms | Windows and macOS after native-machine QA; add Linux only after native QA; Deck compatibility unclaimed until tested/reviewed |
| Demo | Free Year 1 with five plots and harvest result; initial scope reuses current campaign, approximate duration measured in playtests |
| Other products | No launch DLC/supporter bundle required; keep institutional work separate |
| Online features | Existing board optional; campaign playable without network, if verified |

Steam permits an optional launch discount of 7–14 days; the proposed 10%/7-day offer fits its current rules. Recheck cooldowns before scheduling the next sale. Do not promise an immediate second discount. [Discount rules](https://partner.steamgames.com/doc/marketing/discounts).

Use Year 1 as the first demo implementation because it preserves the complete farming/harvest loop and reduces new balancing work. Measure actual duration and completion. If it takes too long or players disengage before the payoff, prototype the shorter 15–25 minute slice from the distribution review before demo freeze. Do not simply remove the harvest result or promise a fixed playtime without evidence.

## Calendar and dependencies

| Internal date | Deliverable | Dependency / exit evidence |
| --- | --- | --- |
| Oct 16, 2026 | Fresh beta-2 test report; commercial asset inventory started | 12 fresh players proposed; build/specs, first-five-minute observations, crashes/save issues recorded |
| Oct 30 | Cultural/rights review for public store claims; bilingual store draft and asset package | Adviser permission/compensation agreed; any unclear shipped assets replaced or cleared |
| Nov 2 | Store package ready for Valve review | Legal publisher identity, bank/tax onboarding, base App ID and owner-authorized fee; complete store checklist |
| Nov 10 | Coming Soon page target | Valve approval; readable art; accurate launch scope. Slip this target if dependencies fail |
| Nov–Dec | Weekly gameplay campaign and English localization; demo engineering | Real Steam URL, measured campaigns, human text review |
| Jan 4, 2027 | Internal Next Fest readiness decision | Public base page, demo candidate, credible full-release plan and remaining workload |
| Jan 7 | Internal registration target | Leaves margin before official Jan 10 deadline; owner confirms submission |
| Jan 18 | Internal demo/store review submission target | Demo QA and assets complete; margin before Jan 25 press-preview submission deadline |
| Feb 1 | Demo public target after approval | Clean account installation and demo limit verified; creator/press material ready |
| Feb 8 | Official required-review submission deadline | Fallback deadline, not a planned start date |
| Feb 22–Mar 1 | Next Fest | Demo live and approved; monitor feedback and support daily |
| Mar 2 | Release decision | Full build passes release gates, final price approved, hotfix coverage available |
| Mar 9 | Internal paid-launch target | Approved base build/page, Steam timing requirements satisfied; release owner present |
| Launch +7 days | End launch discount; review results | Sales/refunds/support report, no speculative expansion commitments |
| Launch +30 days | Commercial review | Actual proceeds/costs, bug priorities, next update and eligible discount timing |

Official February Fest is February 22–March 1, 2027; registration closes January 10 at 11:59pm PST, press-preview submission is January 25, and required review submission is February 8. A title may participate once and must release after the event. Those dates use Valve's Pacific timezone; internal targets above are calendar days in Bangkok, deliberately earlier. [Event dates and eligibility](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027).

Valve recommends submitting the store page at least seven business days before intended publication. Review approval does not publish or launch automatically. Allow resubmission time and check the account's actual release checklist. [Review process](https://partner.steamgames.com/doc/store/review_process).

If the January readiness decision fails, do not spend the one Fest opportunity on an unreliable demo. Replan the date explicitly. If the owner needs earlier income, evaluate an earlier paid launch against the loss of February participation; workshops or donations are not assumed funding for the wait.

## Source-backed agent backlog

Preparation completed in this session is indexed in [Steam package README](README.md). ST-02 has a hashed source inventory and disclosure worksheet; ST-07 has artwork/screenshot candidates and copy; ST-09 has drafts/storyboard. ST-05 has locally tested Preview-only upload tooling, without IDs or upload. ST-06 has an engine smoke, without native-platform certification. Demo/localization implementation and human/account gates remain pending. Existing PF-01/02/03 implementation is already recorded. Role names describe handoffs; no new agent/chat has been created. Inspect current source and shared changes before editing.

| ID / role | Source entry points and work | Done when |
| --- | --- | --- |
| ST-01 Owner / release | Steamworks onboarding; record real base/demo App IDs and publisher name in release metadata, not fabricated placeholders | Owner identity/bank/tax verification complete; fee authorized/paid; account access and checklist confirmed |
| ST-02 Rights / product | `ASSETS.md`, `tools/character_pipeline/installed_meshy_cast.json`, `assets/audio/`, `assets/fonts/`, `SOP.md`; inventory each shipped asset/tool/account licence and disclosure | Rights ledger has evidence and no unresolved commercial-use blocker; cultural review and naming permissions recorded; Steam survey prepared accurately |
| ST-03 Localization | `scripts/`, `ui/`, `scripts/GameSettings.gd`, `ui/SettingsPanel.gd`; string inventory, Godot translations, persisted locale, subtitles | Reviewed Thai/English selectable; tutorials/HUD/hearth/endings/settings covered; Thai voice subtitles readable; no English-layout clipping |
| ST-04 Demo engineering | `scripts/GameState.gd:170` (`advance_to_next_plot`), `:178` (`_complete_year`), `scripts/SaveGame.gd`, `ui/TitleScreen.gd`, `tools/build.sh`, `export_presets.cfg` | Explicit demo build flag; Year 1 harvest shown before blocking Year 2; Continue/reload cannot bypass limit; restart allowed; separate demo save/settings identity; existing full/beta saves untouched; end screen links to verified base store |
| ST-05 Steam packaging | `tools/build.sh`, `export_presets.cfg`, `tools/notarize_mac.sh`; add reproducible Steam upload/configuration documentation and separate demo/base artifacts | Exact commit/hashes/depot/launch options recorded; clean Steam account install runs; reinstall/update preserves intended saves; demo/full switches tested; Mac archive signing verified |
| ST-06 QA | `tests/`, `docs/RELEASE_BETA2.md`, `docs/feedback/PLAYER_FEEDBACK_IMPLEMENTATION_20261003.md` | Native Windows/Mac report; proposed representative minimum-spec test at 1280×720 targets stable 30 fps through worst burn; full-year and multi-year saves/reloads; offline board failure handled; fresh players confirm PF fixes |
| ST-07 Store/media | `assets/ui/logo/`, `docs/pitch/`, sibling site's `public/media/` and `src/components/PressKit.astro`; draft copy in `STORE_COPY.md` | Current gameplay trailer/screenshots, capsule/library package, accurate features/languages/specs and survey pass review; concepts excluded from gameplay screenshot slots |
| ST-08 Site / marketing | Sibling site `src/i18n/content.ts`, Steam links, demo end screen | Verified App ID URL replaces temporary beta-only commercial path; both languages and press page work; UTM links tested; beta remains explicitly versioned |
| ST-09 Marketing | Three real gameplay clips/week, weekly progress post, shortlist of relevant creators, Prachatai package | Materials reviewable, audience/source recorded; owner authorizes external outreach before sending; weekly tracked visits/wishlists and player responses reported |
| ST-10 Release / support | Release checklist, approved build and community notices | Final price/date confirmed; install smoke immediately before release; support owner and rollback/hotfix instructions ready; no unresolved launch blocker |

ST-03, ST-04 and ST-05 are product engineering tasks, not changes implemented by this document. GDScript/scene edits must follow `AGENT.md` headless validation and meaningful tests. Demo tests must cover end-of-year, reload/Continue bypass, save isolation and full-build regression, rather than merely checking the flag exists. Optional Steam achievements/Cloud integration are separate tasks if chosen; do not advertise them now.

## Store and media acceptance

Prepare the following current Steam dimensions, then recheck the upload checklist before export:

| Asset | Size | Direction |
| --- | --- | --- |
| Header | 920×430 | Faceted crew/fire/satellite relationship and legible title |
| Small capsule | 462×174 | Title readable at small generated display sizes |
| Main capsule | 1232×706 | Same art direction, composed for this aspect ratio |
| Vertical capsule | 748×896 | Clear silhouettes, readable title |
| Library capsule | 600×900 | Consistent key art/title |
| Library header | 920×430 | Consistent identity |
| Library hero | 3840×1240 | Art only; important content inside central safe area |
| Library logo | 1280 wide and/or 720 tall | Transparent title/logo, no extra marketing text |

Capsules should contain the title/logo rather than sale badges, review quotes or invented awards. Reuse the approved game identity; compose each format deliberately instead of stretching screenshots. [Store assets](https://partner.steamgames.com/doc/store/assets/standard), [library assets](https://partner.steamgames.com/doc/store/assets/libraryassets).

Internal package: six current 1920×1080 gameplay screenshots, one 45–60 second trailer, and three vertical clips. Screenshots should show preparation, crew action, spreading fire, cooling, scan result and village/harvest. Capture actual gameplay in each promised language where useful. A trailer opens with gameplay in the first three seconds, explains the stakes, then shows the harvest/scan payoff. Do not use title-logo animation as the entire opening. No filmmaker/editor tool screenshots in store media.

Proposed discovery tags: Strategy, Simulation, Survival, Singleplayer, Atmospheric, Nature. Validate available tags and their order with the Steam tag wizard and player perception. Do not label it multiplayer or cozy without corresponding experience. List controller support only at the level verified across gameplay and all menus.

## Marketing cadence and measurement

Before the store page is public, focus on beta learning and capture. After publication, every gameplay campaign gets one clear wishlist destination. Proposed weekly workload: three clips and one progress post; one of the posts should show a concrete improvement or decision, rather than another logo reveal. English captions broaden the test audience while Thai remains the original voice.

November: test preparation/crew/satellite hooks. December: show meaningful campaign consequences and the demo loop. January: invite demo feedback and prepare approved creator material. February: promote the playable demo and Fest, respond to issues daily. Launch week: show the maintained full campaign, price and current platform/language support. Following month: fixes and useful gameplay updates; request honest reviews without incentives or asking specifically for positive ratings.

Track Steam campaign source/content consistently and report new wishlists, eligible tracked visits, demo engagement and qualitative feedback separately. UTM cannot attribute every cross-device/app visit and does not count demo downloads as base-game conversions. Do not combine raw social views with store visitors. [UTM documentation](https://partner.steamgames.com/doc/marketing/utm_analytics).

Use organic marketing first. A paid test is optional and capped at ฿2,000 only if separately approved after the demo/store are working. A creator/press shortlist is research; sending messages requires the owner's instruction. Existing contacts are opportunities, not guaranteed coverage or sales.

## Budget, revenue and final release gate

Minimum known platform outlay: $100 USD or equivalent Steam Direct fee for the base product, recoupable at $1,000 adjusted gross revenue; account workflow determines associated demo setup. Remaining costs need quotes: cultural advisers, English review, target-machine QA, trailer editing and support. No currency conversion or total budget is invented. [App fee](https://partner.steamgames.com/doc/gettingstarted/appfee).

Use the distribution review's illustrative ฿112 proceeds/copy only for scenarios, not a forecast. A retained 500/1,000 copies produces hypothetical ฿56,000/112,000 before remaining costs/taxes. Count launch discounts, refunds, taxes, platform share, bank/exchange costs and any agreed community share in the real model. Record committed spend before calculating break-even.

Release requires: cleared shipped assets and accurate AI/content survey; completed cultural review; reviewed languages; measured advertised hardware/platforms; no unresolved crash/save-loss blocker; correct demo/full boundaries; clean install/update checks; approved store/build; finalized regional prices; working support contact; and seven days of assigned launch support. Steam Cloud, Deck Verified, native Linux support and achievements cannot appear as promised features until verified.

Steam's onboarding documentation currently lists a 21-day fee-to-release wait for initial titles and at least two weeks of public Coming Soon visibility. Confirm the account checklist before a public date. [Onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding).

At Mar 2 go/no-go, review quality, observed demand, remaining workload, budget and support capacity together. Wishlists help reach interested people; there is no universal wishlist count guaranteeing sales. If quality fails, move the date and communicate plainly. If demand is weak but quality passes, revise targeting/price/cost expectations rather than silently forecasting thousands of purchases.
