# Content disclosure and commercial-rights worksheet

Draft 2026-10-03. Not a legal clearance, signed declaration or submitted Steam survey. The source inventory hashes 304 source assets; it is not an assertion that every asset is exported or that all permissions are cleared.

## Draft pre-generated AI statement

> AI tools were used during development to create some of the game's 3D assets, visual reference/concept material, voices, sound effects and music. Outputs were selected, processed and integrated into the game's stylized presentation. The release team is reviewing the rights and provenance of the shipped assets before commercial distribution.

Use as an internal draft. For the final submitted statement, replace “reviewing” with truthful completed-review wording only after evidence exists, name specific shipped categories accurately, and include AI-assisted narrative/localization if it is retained in the shipped game. Do not imply a human cultural adviser endorsed AI outputs. Do not make an “all original” or “all commercially cleared” claim from this draft.

No runtime generative AI service was found in the source search performed for this package; the optional leaderboard is a network feature, not generative AI. Recheck release dependencies and code before answering the live-generated question. Procedural companion behaviour is distinct from generative content. Steam covers shipped player-consumed AI artwork, sound, narrative and localization; disclosure does not replace rights. [Content Survey](https://partner.steamgames.com/doc/gettingstarted/contentsurvey).

## Evidence still needed

| Category | Evidence found | Required human/account confirmation |
| --- | --- | --- |
| Character meshes | Installed Meshy registry has task IDs, paths and hashes | Generation account/plan and applicable terms; reference-image rights; commercial permission evidence |
| Props / logo island / satellite | Asset manifest and pipeline handoffs | Exact asset-to-provider mapping, terms at generation date, reference permission |
| Audio | ElevenLabs production/revision plans, prompts and selected voice IDs; installed WAVs | Account plan/terms, per-file provenance, voice-use permissions and any identity/clone consent; native listening |
| Music | Three complete loop tracks and pipeline record | Applicable music commercial/game distribution terms, generation plan evidence; separate soundtrack rights if sold later |
| Fonts | Bundled Kanit/Chakra Petch OFL text | Match actual font families/files; include appropriate notices in distributable payload |
| Concept/reference images | Source files, mixed pipeline records | Creator/source/permission; decide which should be excluded from release exports |
| Code and other dependencies | Public repo; no root LICENSE found in audit | Owner's code/asset licence choices; third-party engine/dependency notices and attribution |
| Cultural content | PRD and adviser contact recorded | Paid scope/review, wording changes, credit/name permission; no assumed endorsement |

For each inventory row: classify exported/not exported, resolve provider and source, attach commercial-rights evidence location, reviewer/date and clearance status. Keep invoices/account documents privately; repository records may contain a safe reference to private evidence, never payment details or credentials. If permission is unresolved, replace/exclude the asset rather than checking “cleared.”

## General/mature content review

Inspect fire/accidents, coughing/distress, famine/crackdown endings, patrols/arrests, radio dialogue and any unused content shipped in the build. Answer the survey from actual content, including inaccessible adult content if present; no age rating is predicted here. Document whether realistic violence/gore, substances, sexual content, gambling or purchases actually occur instead of guessing from the game's premise.

## Cultural review packet

Provide the adviser the gameplay build, English/Thai public copy, farming/fire rules, village/radio/character language and the game's simplified satellite model. Ask for concrete corrections and limits on claims. Record agreed review scope, compensation, credit wording/name permission and any revenue-share agreement separately. “Consultation requested” and “review complete” must remain distinct statuses.


## Localization implementation update — 2026-10-03

The game source now retains AI-assisted English translations in
`localization/messages.json` and `localization/voice_subtitles.json`, including
UI/tutorial/gameplay narrative and subtitles for 30 existing Thai speech clips.
These are pre-generated localization content; they do not introduce a runtime
AI service or new voice recordings. Include them in the shipped-content AI
inventory if retained in the release. Human English/cultural proofreading and
listening review are pending; automated source/format/UI tests do not constitute
that approval. See [localization handoff](../LOCALIZATION.md).

## English voice generation update — 2026-10-03

The subsequent owner-authorized ElevenLabs pass added 30 generated English
recordings in `assets/audio/en/`. These are retained, pre-generated audio assets,
with the same five voice identities used for Thai. Exact generation settings,
English texts, provider voice IDs, reviewed source hashes and installed hashes
are recorded in `tools/audio_pipeline/english_voice_plan.json` and
`tools/audio_pipeline/installed_english_voices.json`. Include the English WAVs in
the exported-asset AI/content inventory. Wording and technical playback checks
pass; acting, accent, pronunciation and commercial provenance signoff remain
human release-review items. See
[English voice handoff](../../tools/audio_pipeline/ENGLISH_VOICE_HANDOFF.md).
