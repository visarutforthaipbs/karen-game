# SKU PLAN — Under Two Skies : ไร่หมุนเวียนใต้เงาดาวเทียม

Draft 2026-10-02, updated with the new title. **Audience: general public.** Everything here is a recommendation for the owner to confirm. Items marked **DECISION** are open.

## 0. Title

Working title (owner's choice, 2026-10-02): **Under Two Skies : ไร่หมุนเวียนใต้เงาดาวเทียม**. The repo and code still say "Satellite Shadow" / "เงาเมฆา" until the rename is done.

- **Meaning:** two skies, one that watches (satellites, drones) and one that shelters (the forest canopy). The game already plays this split: crew under bamboo or forest are hidden from drones, and the 20:00 thermal view is the open sky seeing everything else.
- **Thai subtitle** (already in the game): "ไร่หมุนเวียนใต้เงาดาวเทียม", which tells a general audience what the game is. English rendering: "Rotational farming under the satellite's shadow".
- **No slogan** (owner's decision). Final lockup: title **Under Two Skies**, subtitle **ไร่หมุนเวียนใต้เงาดาวเทียม**.
- **Pgakenyaw naming:** keep "Karen" / "Pgakenyaw" out of the title. Any mention in the subtitle is agreed with Pgakenyaw advisers.
- **Name conflict, accepted by the owner as a risk:** a visual novel / point-and-click called *Under Two Skies* is in development by Memória BIT (https://www.memoriabit.com.br/en/under-two-skies-visual-novel/). Same medium, so expect shared search results and possible confusion or a trademark complaint. Other uses of the name exist in other media (1892 story collection by E.W. Hornung, a 2005 documentary, a 2013 music track). Storefront searches were inconclusive. A trademark search or lawyer is the real check; this is not legal advice. Fallbacks if it has to change: "Beneath the Watching Sky" (not yet searched), "Beneath Two Skies" (close to the existing game), or use "ใต้สองฟ้า" as the Thai title only.
- **Rename scope** (do last): `project.godot` name, Title screen, Hearth header, how-to-play, README, `export_presets.cfg` and bundle id (`io.github.visarutforthaipbs.satelliteshadow`), docs. Reserve the store page names early.
- **Game consequence:** forest cover is now the central metaphor. Make drone and ranger follow one cover rule (audit finding 5 in `AUDIT_BRIEF.md`).

## 1. Blocker for every SKU: language

All player-facing text is Thai and lives as string literals in GDScript. A general audience needs at least English first.

- Move strings to Godot's translation system (`tr()` with a PO or CSV file).
- Add an in-game language switch; English is a first-class language, Thai remains the original voice.
- Recorded Thai voices (radio, Ta-poh) stay, with English subtitles.
- Native Thai proofread and Pgakenyaw review of names, proverbs and the radio script (see `PRD_UPDATE_v1.1.md` P2-6).
- The English title "Under Two Skies" leads on store pages; the Thai subtitle stays on the title screen.

## 2. SKUs

| SKU | Contents | Price | Channel | Phase |
|---|---|---|---|---|
| **Demo** | Year 1 only (5 plots, about 45 min); no content past Y1 | Free | itch.io first (easy), then a Steam demo (separate Steam app) | 1 |
| **Standard v1.0** | Full endless campaign, Thai and English, Win/Mac/Linux and Steam Deck | $9.99–$12.99, regional pricing (about ฿149–199 in Thailand) | **Steam is the main public channel**; itch.io as a secondary page | 1 |
| **Supporter bundle** | Standard plus soundtrack and art/wallpapers | $15–$20 | itch.io | 2 |
| **Educator edition** | Same game, free for classrooms, plus a teacher guide (swidden agriculture, burn bans, satellite fire monitoring) | Free or institutional licence | itch.io page, direct download | 2 |

**DECISION:** price and model (paid, free, or pay-what-you-want); whether to do Phase 2 SKUs at all.

## 3. Platform packaging

- Windows x86_64, Linux x86_64 (also the Steam Deck build) and macOS universal: `tools/build.sh` already exports all three.
- No web build: the project uses Forward+, which Godot's web export does not support.
- macOS needs Developer ID signing and notarisation for a paid product (Apple developer account, $99/year). Current builds are ad-hoc signed only.
- Steam: $100 per app; the demo is a second app.
- Soundtrack SKU needs the procedural music rendered to files (the game has no music files today).

## 4. Release gates (paid release)

1. English text and a native Thai proofread.
2. **AI-asset provenance.** Meshes, voices and concept art came from AI tools and models. Confirm each licence permits commercial sale, and prepare the AI-content disclosure Steam requires. Not yet verified.
3. Repo licence. The repo is public with no `LICENSE` (all rights reserved by default). For a commercial release, choose between keeping code and art all-rights-reserved or making the repo private. **DECISION.**
4. Age rating via the IARC questionnaire (fire, state violence, arrests); expected to rate low.
5. Cultural consultation with Pgakenyaw advisers before charging money or approaching press. Owner has a contact, พฤ โอโดเชา; their role, what they will review, and permission to be named publicly are not yet confirmed. **DECISION:** whether to commit a revenue share to a community organisation, and with whom.
6. Store assets: trailer, screenshots, capsule art, description. The blue-hour title art in progress is a start.
7. Steam Deck verification (`PRD_UPDATE_v1.1.md` P0-9, needs the device).
8. Title conflict checked (see §0): trademark search or a decision to change the name.
9. Audit findings in `AUDIT_BRIEF.md` triaged, especially the save robustness and year-end famine items.

## 5. Thai audience and channels

Owner context (2026-10-02): new to game distribution; has a Thai indie game group and a contact at Prachatai who can help produce news about the game. Facts about the Thai market below are general knowledge, not verified data; check them with the indie group.

- **Steam** is the main PC store for Thai players and supports Thai language and baht pricing. itch.io is developer-friendly but less known to ordinary Thai gamers, and (unverified) may lack PromptPay. Use itch.io for the playtest and free demo, Steam for the public release.
- **Discovery** happens mostly on Facebook, YouTube and TikTok. The owner's existing Facebook pages are a launch asset.
- **Mobile** is where most Thai gaming happens, but this is a PC game; a mobile port is out of scope.
- **Hardware:** many players have mid-range laptops. Set a minimum spec, test on a low-end machine, and use the "landscape detail: low" setting.
- **Direct download** on the owner's own site with a PromptPay donation option, for players who avoid Steam.
- **Trust:** unsigned Windows and Mac builds trigger security warnings; Steam avoids this for non-technical players.

### Using the owner's network
- **Thai indie game group:** playtesters (5 to 10 people), advice on Steam in Thailand (payments, tax, launching), and introductions to streamers and developers who have shipped.
- **Prachatai:** the angle is the rights story (rotational farming, burn bans, satellite hotspot data) with the game as a new way to tell it. Time the story for when the free demo is live, not before. Prepare a press kit: screenshots, a one-page explainer, title and subtitle, and a 1 to 2 minute trailer if possible.
- **พฤ โอโดเชา (Pgakenyaw contact):** consult before press. A rights-focused outlet will ask who was consulted, and the game's simplifications of rotational farming need checking.

### Before any press
1. Pgakenyaw input and permission to name advisers.
2. Fact-check the game and press kit (how rotational farming works, the bans, how satellite detection works); say plainly that the game is a simplified model.
3. Keep the state fictional: no real agency names, ranks, insignia or people in the game or press material. Have a Thai lawyer who knows media and the Computer Crimes Act review before launch. This is not legal advice.
4. Fix the audit findings and play a full year, so press traffic does not meet a crash or a lost save.

## 6. Beta (current stage, 2026-10-02)

Owner decision: the game is considered feature-complete for now and goes to user beta test.

- **Format:** downloadable PC build (Windows and macOS; Linux/Steam Deck optional). No browser build: Forward+ is not supported by Godot's web export, the game is heavy for a browser, and it is built for mouse, keyboard or gamepad.
- **Distribution:** one download link (Google Drive or similar) for the first Thai round, or a restricted password-protected itch.io page with `butler` once updates are frequent.
- **Testers:** Thai indie game group first (for example the Facebook group "AI Game Dev Thailand"), 5 to 10 people. Post in the same format those developers use: short description, what this version lets testers do, a bug warning, numbered feedback questions, and an honest line on how the game was made, including AI tools.
- **Tell testers:** PC only, needs mouse and keyboard; the Windows "protected your PC" screen means More info, then Run anyway; on Mac, right-click then Open; send `playtest_log.csv` (Settings button opens its folder).
- **Feedback questions:** understood the goal within 5 minutes? where stuck? controls (rake, torch line, spray)? fire, wind and the 17:16 rule clear? drones and rangers fair? any crash, freeze or lost save, with PC specs? would you play another year?
- **Before sending:** test the exported builds on another machine; decide whether the beta ships as "Satellite Shadow" or already as "Under Two Skies" and tell testers which; triage the save robustness item from `AUDIT_BRIEF.md`.
- **Not in the beta:** press, Steam page, Prachatai story, paid sales.
- **Exit criteria:** most testers finish a full year without help, no crash or save loss reports, and the playtest log supports a first balance pass.

## 7. Phasing

1. **Beta (now):** see section 6. Thai indie group, 5 to 10 players, collect `playtest_log.csv`.
2. **Fix and localise:** act on beta feedback, then English and Thai text and audit items.
3. **Consult:** Pgakenyaw advisers, using what the playtest showed.
4. **Free demo** on itch.io, launched together with the Prachatai story and Facebook posts.
5. **Steam:** store page, demo app, then the full release.
6. **Phase 2 SKUs** (Supporter, Educator) once the base game is stable.

## 8. Open decisions summary

- Price and monetisation model.
- Revenue share and community partner.
- Educator edition: yes or no.
- English translation: who drafts it and who proofreads it.
- Repo licence or visibility.
- Which Thai indie group and what role พฤ โอโดเชา takes (advice, review, named adviser).
