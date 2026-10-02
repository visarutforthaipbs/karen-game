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
| **Demo** | Year 1 only (5 plots, about 45 min); no content past Y1 | Free | itch.io, then a Steam demo (separate Steam app) | 1 |
| **Standard v1.0** | Full endless campaign, Thai and English, Win/Mac/Linux and Steam Deck | $9.99–$12.99, regional pricing (about ฿149–199 in Thailand) | itch.io, then Steam | 1 |
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
5. Cultural consultation with Pgakenyaw advisers before charging money. **DECISION:** whether to commit a revenue share to a community organisation, and with whom.
6. Store assets: trailer, screenshots, capsule art, description. The blue-hour title art in progress is a start.
7. Steam Deck verification (`PRD_UPDATE_v1.1.md` P0-9, needs the device).
8. Title conflict checked (see §0): trademark search or a decision to change the name.
9. Audit findings in `AUDIT_BRIEF.md` triaged, especially the save robustness and year-end famine items.

## 5. Phasing

1. **Playtest (now).** Private or password-protected itch.io page, builds uploaded with `butler`. Testers produce `playtest_log.csv`.
2. **Localise and fix.** English, audit findings, licence and provenance decisions.
3. **Demo then Standard on itch.io.** Gather feedback and tune balance.
4. **Steam.** Store page, demo app, then the full release.
5. **Phase 2 SKUs** (Supporter, Educator) once the base game is stable.

## 6. Open decisions summary

- Price and monetisation model.
- Revenue share and community partner.
- Educator edition: yes or no.
- English translation: who drafts it and who proofreads it.
- Repo licence or visibility.
