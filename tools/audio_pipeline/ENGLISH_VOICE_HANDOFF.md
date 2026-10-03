# English spoken dialogue — 2026-10-03

**Current delivery:** the owner-approved Eleven v4 pass supersedes these v3
recordings in both languages. See [`VOICE_V4_HANDOFF.md`](VOICE_V4_HANDOFF.md)
and `installed_voices_v4.json`. The following records the original English pass;
its raw evidence is retained, but its recordings must not be reinstalled.

The owner requested ElevenLabs English voice recordings for the in-game language
switch. All 30 current dialogue/radio lines now have English counterparts in
`assets/audio/en/`, with the same basenames and five voice identities as Thai.
The original 30 Thai WAVs remain byte-identical.

| Role | Voice | Voice ID | Clips |
| --- | --- | --- | --- |
| Ta-poh | Toto — Warm Thai Storyteller | RJIgSLB4fDJZtYZRUxqo | 6 |
| Mu-naw | Anna — Thailand Female | brM9iIbwDREZaWL8luun | 6 |
| Mae-Lu | Onnie Thai — Soft, Smooth | OSCkDOqeWrrCkMiFPGB3 | 2 |
| Forestry/ranger radio | Daniel — Steady Broadcaster | onwK4e9ZLuTAKqWW03F9 | 10 |
| Weather radio | Air — Friendly & Professional Thai Teacher | wMBr6SfqQVuOqplK01NE | 6 |

`english_voice_plan.json` records exact English text, model (`eleven_v3`), settings
and installation targets. Its pilot subset shares a durable ledger so expansion
skips the five completed samples. No new voice clones were created.

## Review and runtime

Scribe reviewed all 30 generated clips with `eng` and an exact normalized wording
gate. Twenty-nine match after case/punctuation normalization. One reviewed
equivalence accepts “3:00 this afternoon” for “three this afternoon” (15:00).
The prosecution line was corrected before generation; forest reserve and
Director-General terminology was also refined. Generated text matches the
English subtitles exactly.

Installation converts speech to mono 44.1 kHz PCM16, removes DC, applies a low
high-pass and short edge fades, and targets -19 dBFS RMS with a -3.1 dBFS peak
ceiling. Total installed speech duration is 113.22 seconds. Original raw outputs,
prepared WAVs and review decisions are retained for audit/rollback.

AudioManager resolves English only after an event's normal priority/rate-limit
decision. Subtitles follow the selected clip and its actual duration. Live locale
changes stop radio/2D/3D speech and captions immediately, even in paused Settings;
subsequent events use the new language. Work loops, coughs, music and ambience
retain their state. Missing English files fall back per clip to Thai.

## Evidence and acceptance

Manager decision: **GO for bilingual voice testing.** Both voice regression
suites pass, including all 30 exact English/Thai resource selections, actual
2D/3D/radio playback, paused switching, matching captions, natural completion,
cooldown reset, preserved work/music and fallback. Existing 149 gameplay checks,
audio regressions and a 120-frame production smoke pass. An exported-resource
probe from an empty working directory resolves all 30 English recordings and
plays English radio from the PCK.

The pipeline's 19 offline tests pass. Accepted speech decisions are now bound to
the expected text, language and source hash before any installation; stale or
unbound approvals fail clearly. See `README.md` for review migration and commands.

Exact installed provenance: `installed_english_voices.json`.
Local evidence: `artifacts/audio_english_20261003/verification.json`, `ledger.json`,
`speech_review.json`, test logs and `english-voice-export.pck`.
Preview: `artifacts/audio_english_20261003/english_voice_preview.wav` contains
Ta-poh, Mu-naw, Mae-Lu, forestry and weather, separated by half-second pauses.

ASR verifies wording, not acting, accent or pronunciation. Human headphone review
of the prepared English takes remains open, especially Chiang Mai–Mae Hong Son.
Commercial provenance/cultural review and the actual uploaded Steam build's
language declarations remain release gates. This task has not rebuilt, signed,
notarized, published or replaced public installers.
