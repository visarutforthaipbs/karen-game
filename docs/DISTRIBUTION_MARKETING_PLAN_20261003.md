# Under Two Skies — distribution, marketing and revenue review

Reviewed 2026-10-03. Companion to [SKU_PLAN.md](../SKU_PLAN.md). This is a recommendation, not an approved price, spending commitment or launch date. Official platform rules were checked on the review date; recheck before submission. No outreach, purchase or publication was performed for this review.

**Next step selected:** the owner requested Steam sale planning. Use the dated [Steam execution plan](steam/STEAM_SALES_PLAN.md) as the active schedule and source-backed backlog.

## Recommendation

Sell a polished PC game through Steam, with a free bounded demo and an itch.io mirror. Build the Coming Soon page before the main press campaign so interested people have somewhere to wishlist. Start with the Thai network for learning, then use reviewed English to reach strategy/survival players internationally. Test paid facilitated workshops as a separate revenue stream after cultural review. Delay supporter bundles until there is demand and a finished deliverable.

The strongest player promise is the actual decision loop: prepare a firebreak, coordinate your crew, burn for the next harvest, and cool the embers before the 20:00 satellite pass. Show it in motion. The cultural story gives this loop meaning; coverage about the issue alone is not proof people will buy a game.

## What the source and release evidence change

| Old assumption | Evidence now | Commercial consequence |
| --- | --- | --- |
| Rename pending | `HANDOFF.md` and `export_presets.cfg` record Under Two Skies and the new bundle identifier | Use one title/publisher identity everywhere; keep historical filenames |
| Only beta 1 is public | `docs/RELEASE_BETA2.md` and the latest handoff record beta 2 published | Market current footage/builds; label old beta versions clearly |
| Mac only ad-hoc signed | Latest handoff records Developer ID, accepted notarization and stapling | Retain signing verification for every new archive |
| No audio files | `assets/audio/` contains voice/SFX/music WAVs and `music_states.tres` | Soundtrack possible later, but needs rights and album work |
| Three presentation complaints need implementation | `docs/feedback/PLAYER_FEEDBACK_IMPLEMENTATION_20261003.md` records implemented spray/refill/breath/warning changes | Validate with fresh players; do not duplicate implementation |
| English/Deck ready for sale | Site `src/i18n/content.ts` says English planned and Linux/Deck untested | Advertise only verified language/platform support |
| Demo already exists as a limited product | `GameState.gd` advances years; no demo switch/limit found in scripts/UI/build/export search | Demo packaging and campaign limit are new work |
| Press kit must start from zero | `docs/pitch/` and sibling site's `PressKit.astro` already contain assets | Audit factual claims and reuse; capture only missing current footage |

This is a source/document audit, not a fresh hands-on gameplay or hardware certification. Beta availability/signing is supported by the release record; no new public installer hash verification was performed here.

## Products and money

| Offer | Proposed price/model | When it earns | What must exist first |
| --- | --- | --- | --- |
| Free demo | ฿0 | Creates a purchase/wishlist path; no direct sales | Clear complete burn loop, bounded content, end screen link |
| Standard | Test $9.99 US / ฿199 Thailand | Main recurring sales revenue | Stable paid build, reviewed English for international launch, accurate store claims |
| Optional itch support | Free demo with voluntary payment | Small supplementary income; no income assumed | Verified seller payout setup and honest support wording |
| Supporter extras | Test an additional $5 later | Higher spend from existing fans | Cleared artwork, album-quality audio, meaningful preview, fulfilment |
| Facilitated workshop | Quote one scoped pilot after budget/cost discovery | Potential earlier cash from institutions | Reviewed facilitator guide, playable session, adviser involvement, agreed deliverables |
| Sponsored educational adaptation | Fixed-price milestone contract | Potential project funding | Partner need and budget, separate scope/IP agreement, paid adviser time |

These prices are offers to test, not evidence of willingness to pay. Set Thai pricing independently, rather than converting dollars or presenting ฿199 as Valve's recommendation. Steam lets developers choose regional prices using its pricing tools. [Steam pricing](https://partner.steamgames.com/doc/store/pricing).

Keep monetization simple: one paid base game. Avoid adding ads, consumable purchases or subscriptions to this offline campaign. Do not promise new modes, Pgakenyaw voice localization, multiplayer or weekly challenges to justify price before they exist. Endless years alone do not prove replay value; test whether changing wind/surveillance and village decisions make players want another year.

The already public full beta is part of the product history. Clearly distinguish the versioned test build from the maintained paid release. Do not promise that existing downloads will stop working or that paid ownership is required retroactively. The public repository can remain public; document code/asset permissions and sell the maintained release, installation convenience and support. No licence has been chosen here.

For educational income, sell facilitation, preparation and a reviewed teaching experience before developing an expensive institution-only edition. Candidate buyers to investigate are university classes, museums/cultural centres and organizations working on land, farming or environmental education. These are prospect categories, not verified buyers. First ask about intended learners, session length, learning goal, equipment and available budget; do not count an interview as a sale. Pay cultural advisers for their work. Any community revenue share needs the owner's and partner's agreement, with a clearly defined base and reporting process.

## Reach players with the game itself

Primary audience hypothesis: players who enjoy tactical survival, systems, tense time limits and small-team coordination. Secondary hypothesis: Thai players interested in a locally grounded indie game. Educational audiences need a separate explanation of learning value. Do not lead the player campaign with generic “cozy farming” language: the fire and surveillance pressure must be visible.

Use this descriptive store pitch as a candidate, not a new title slogan:

> Lead a farming crew through a dangerous burn day. Prepare the firebreak, control the flames and cool the embers before the satellite passes—while keeping the village fed.

| Channel experiment | Concrete material | Next action | Evidence to record |
| --- | --- | --- | --- |
| Owner's Thai indie group | 20-second gameplay clip, beta link, three focused questions | Playtest beta 2 | Unassisted understanding, completion, intent to continue |
| Facebook / Shorts / TikTok | Three captioned clips: spreading flame, crew rescue, last ember before scan | Wishlist; demo as supporting link | Tracked store visits, wishlist additions, qualitative responses |
| Small strategy/survival creators | Short personal pitch, 60-second trailer, working demo and facts sheet | Try the demo | Actual plays/coverage, attributed interest; no guarantee |
| Prachatai contact | Playable demo, reviewed cultural explainer, adviser permissions, real screenshots | Story plus demo/wishlist link | Traffic and player interest separately from article reach |
| International niche communities | English gameplay explanation and reviewed demo | Wishlist/play | Relevant engagement and returning players |
| Institutions | Session outline and example gameplay discussion | Discovery interview, then paid pilot proposal | Specific need, decision maker, budget and pilot commitment |

Prepare a shortlist of 10–20 relevant smaller creators based on recent coverage of similar mechanics, not follower count alone. Follow community promotion rules. A future outreach task must inspect live channels and obtain authorization to send messages. No names or outreach lists were invented in this review.

Produce three 8–15 second vertical gameplay clips and one 45–60 second trailer. Show player input and consequences in the opening seconds; introduce village stakes, fire coordination and the orbital deadline. Keep current faceted art, game fonts and real sound. Separate concept images from playable footage. Capture at a legible HUD scale. English captions need a human review.

Site handoff: when a real Steam page exists, add its verified URL to both languages, the press page and demo end screen. Make “Wishlist on Steam” the main commercial action and keep beta/demo access easy to find. Until then retain honest beta actions; do not add a fake store link or inactive wishlist button. Reuse current site media before creating more art.

## Validate before scaling

Proposed first cohort: 12 fresh players, including players outside the developer circle. Record tester familiarity, machine, build and language. Observe the first five minutes without coaching, then ask what the goals and meters mean. Proposed gate: at least 10/12 can explain the two objectives and water/breath distinction; no observed crash/save-loss blocker; most want another burn or year. This small sample guides fixes; it does not establish market demand.

Test the original ~45-minute Year 1 demo against a shorter 15–25-minute complete loop. Keep the shorter version only if it demonstrates preparation, burning, cooling and a meaningful result; do not cut the central payoff for an arbitrary duration. A demo end screen should show what the paid campaign adds and offer one wishlist/purchase link. Demo saves should remain separate unless upgrade migration is deliberately implemented and tested.

Track weekly: new wishlists, Steam tracked visits, tracked wishlist additions by campaign, demo starts/finishes where supported, repeat-play feedback, actual sales/refunds after launch, and support time. Use `utm_source`, `utm_medium`, `utm_campaign` and `utm_content` consistently. No real App ID was found or created for this plan. Steam's attribution counts eligible logged-in conversions within 72 hours; cross-app behaviour and privacy settings can undercount. Demo downloads are not base-game UTM conversions. [Steam UTM analytics](https://partner.steamgames.com/doc/marketing/utm_analytics).

Wishlists are useful for release notifications, but do not assume a magic threshold or algorithm boost. Valve says purchasing/playing matters and raw traffic alone does not determine visibility. Treat wishlists as an interested audience, not booked revenue. [Steam visibility](https://partner.steamgames.com/doc/marketing/visibility).

Start with organic tests. Only propose ads after a playable demo, accurate store page and repeated signs of relevant interest. Optional first ad experiment: capped ฿2,000 total, two gameplay creatives, clear target audience, same measurement period. No spending is approved. Do not scale from view counts, and do not treat low reported UTM conversion alone as failure when most visitors are untracked. Compare comparable cohorts and player responses.

## Revenue arithmetic, not a forecast

There is no measured audience size, sales history or reliable conversion baseline yet. The following model is deliberately hypothetical and can be replaced with actual store statements:

- Eligible average sale revenue after discounts, refunds and transaction-tax adjustments: **฿160** (assumption, not the list price).
- Developer fraction after platform share: **70%** (planning assumption; verify the signed agreement).
- Developer proceeds per retained paid copy: `160 × 0.70 = ฿112`.

| Retained paid copies | Illustrative proceeds |
| ---: | ---: |
| 100 | ฿11,200 |
| 500 | ฿56,000 |
| 1,000 | ฿112,000 |
| 3,000 | ฿336,000 |

These are proceeds before income tax/withholding, exchange/bank costs, community share, development costs and ongoing support—not profit. International sales will change the average. At ฿112/copy, a hypothetical incremental ฿30,000 launch cost requires `ceil(30000 / 112) = 268` copies just to cover that cost; ฿60,000 requires 536. Include adviser, translation, trailer, QA, platform fees and support hours in the real budget. Do not spend against the 3,000-copy row as if those sales were secured.

For a sensitivity check, 500 copies at eligible averages of ฿120/160/200 yield ฿42,000/56,000/70,000 under the same 70% assumption. The average revenue and units both matter. For institutions, calculate a pilot quote from adviser/facilitator time, preparation, travel and hardware/support costs plus a margin; compare written commitments rather than speculative sponsorship amounts.

Steam Direct costs $100 USD or equivalent for the base product and is recouped after $1,000 adjusted gross revenue. Budget the payment upfront rather than assuming immediate return. [Steam fee](https://partner.steamgames.com/doc/gettingstarted/appfee). itch.io lets sellers choose the platform percentage, but processor fees still apply and payout mode affects responsibilities. Verify the owner's eligible payout method before enabling support payments. [itch payments](https://itch.io/docs/creators/payments).

## Timing and agent-ready work

| Stage | Deliverable / owner role | Exit condition |
| --- | --- | --- |
| Next 2 weeks | Game/QA: fresh beta-2 tests, first-five-minute review, save/restart and target hardware checks | Findings captured with build/specs; blockers addressed |
| In parallel | Owner/advisers: consultation, asset rights, compensation and naming permission; localization agent: string audit | Rights ledger and reviewed public claims; English plan agreed |
| Weeks 2–4, subject to gates | Store/site agent: Coming Soon package, current trailer/capsules, bilingual copy, real URL handoff | Owner authorizes fee/submission; page reviewed and public |
| Weeks 4–8, subject to gates | Game agent: bounded demo build; marketing agent: captioned clips and creator shortlist | Demo independently playable; measurement links tested |
| After demo readiness | Owner: approved outreach/press and institutional interviews | Evidence about player interest and a costed release choice |
| Release choice | Owner/product: compare earlier paid launch against February Fest | Written budget/runway and quality gate; no fixed date assumed |

Steam's live onboarding documentation currently states a **21-day** fee-to-release wait for first titles, a Coming Soon page public for at least two weeks, and page/build review. Older advice often says 30 days; verify the account checklist before setting a date. [Steam onboarding](https://partner.steamgames.com/doc/gettingstarted/onboarding).

October 2026 Next Fest runs October 19–26; normal registration closed August 31 and required review submission was September 28. As of this review those deadlines have passed. Do not build the plan around a late exception. [October event](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/2026october).

February 2027 is a candidate, not a commitment: February 22–March 1; registration January 10 at 11:59pm PST; press-preview review submission January 25; required review submission February 8. The paid release must follow the event's conclusion, and a game gets one Next Fest. Dates here use Valve's published Pacific timezone. [February event and eligibility](https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest/feb_2027).

Do not delay to March solely for the event if the owner needs earlier income or maintenance costs outweigh the opportunity. An earlier launch sacrifices that future Next Fest route. Decide after budget and demo evidence; no assumed festival sales justify the wait.

Before submission, inventory shipped models, art, voices, music and fonts, including generation account/plan, tool terms and evidence of commercial rights. Complete Steam's AI-content disclosure for relevant shipped content; disclosure is not a substitute for rights. [Steam Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey). Cultural review, English proofreading and hardware testing remain concrete work, not claims to put in a press kit prematurely.

Immediate recommendation to the owner: keep beta free; validate player understanding; prepare Steam Coming Soon after consultation/rights review; test $9.99 / ฿199 as the paid offer; investigate one paid educational pilot without building an educator SKU first. Final price, cash budget, release timing and partner terms remain open.

## Press coverage log

| Date (คริสต์ศักราช / พ.ศ.) | Outlet | Link | Content | Integrity check | Follow-ups |
| --- | --- | --- | --- | --- | --- |
| 2026-10-07 / 7 ต.ค. 2569 | ประชาไท (Prachatai) | https://prachatai.com/journal/2026/10/119031 | Long-form Thai feature: hotspot/PM2.5 policy context, ไร่หมุนเวียน explained as traditional rotational agriculture, game loop (14:00–20:00 window, 20:00 satellite pass, ความเพ่งเล็งของรัฐ), year-by-year escalation, Beta 3 free download facts (0.3.0, 2026-10-04, Win/macOS/Linux, TH+EN, ~63s opening film, leaderboard opt-in), contact links | PASS — no "slash and burn" framing anywhere; ไร่หมุนเวียน described as ระบบเกษตรกรรมดั้งเดิม for rice/food planting; explicit disclaimer that ตัวละคร ชุมชน หน่วยงาน are all fictional and the 14:00–20:00 evasion rule is game design inspired partly by real situations; no real agency insignia; GISTDA/VIIRS cited only as factual data-source journalism context; hero image captioned as Generative AI, not actual gameplay | (1) Article links to www.under2sky.site with no UTM — measure this hit via referrer only; next placements should carry `utm_source=prachatai&utm_medium=press&utm_campaign=beta3`. (2) Prachatai site content is CC BY-NC: do not reuse article screenshots/hero image in commercial Steam or store materials without written permission. (3) Per the channel table, record traffic and player interest separately from article reach. First measured read (uts-ops, aggregate only, 2026-10-07 ICT): Thai landing hits 08:00 (2), 12:00 (7 — only clear bump), 21:00 (2); article last updated 16:47, so the midday bump is the likely go-live wave. Referrer/UTM attribution for this hit is unrecoverable (Cloudflare token lacks Logs Read / zone analytics scope) — retroactive attribution pending the owner's choice: scoped API token (preferred) vs worker-side referrer tally. Future placements to be handed a pre-made tracked link, not a bare URL. |
