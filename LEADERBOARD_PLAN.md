# LEADERBOARD PLAN — Under Two Skies

Drafted by the audit pass, 2026-10-02. Goal: let players compare runs and compete, first locally, then online during the beta. Design only — nothing here is implemented yet.

## 1. What a "score" is

The game is an endless roguelite judged per campaign. Keep the score legible, not a formula players can't check:

1. **Primary: plots survived** (`stats.plots_completed`) — already tracked and already the best-run metric.
2. **Tiebreak 1: average ash %** (`ash_sum / plots`) — rewards clean farming, not just hiding.
3. **Tiebreak 2: fewer total detections** (hotspots + drone photos + camera trips + ranger sightings) — rewards stealth.

Everything needed is already in `GameState.stats`; no new in-game tracking is required.

### Fair competition: the game is already seeded
Terrain is deterministic per year/plot (`terrain_seed = year*101 + plot*7`), so **all players already face identical hillsides**. Only the wind forecast and in-burn RNG differ. For head-to-head play, add a **weekly challenge mode**: seed the campaign RNG (wind forecasts, bamboo clumps, shift timings) from the ISO week number. Same week = same campaign for everyone; a separate weekly board resets every Monday. This is cheap (one seeded `RandomNumberGenerator` passed where `randf()` is used for forecasts) but touches balance-sensitive code — do it as its own tested change.

## 2. Local ranking board (ship with the beta)

Extend `records.json` from one best record to a **top-10 table**:

- Row: `{name, plots, year, avg_ash, detections, cause, date, version}`.
- Player name: asked once on the run summary (`EndingScene.show_summary`), kept in `settings.cfg`, editable in Settings. Default "ขะแน".
- Shown: a board card on the Title screen (replacing the single best-run line) and "อันดับของคุณ" on the run summary.
- Keep `SaveGame.write_atomic` for the records file (already used).
- Effort: ~half a day including tests.

## 3. Online board (beta, opt-in) — Cloudflare, matching the R2/Pages distribution plan

**Backend: one Cloudflare Worker + D1 (SQLite).**

- `POST /v1/scores` — body `{client_id, name, plots, year, avg_ash, detections, cause, mode, week, version}`; `client_id` is a random UUID generated on first launch and stored in `settings.cfg`; the Worker upserts the player's best row per mode/week.
- `GET /v1/top?mode=endless|weekly&week=&n=50` — top N.
- `GET /v1/around?client_id=&mode=` — the player's rank with 5 rows either side.
- `DELETE /v1/scores?client_id=&secret=` — self-serve removal (PDPA).
- Server-side sanity caps (plots ≤ 150, ash ≤ 100, name length ≤ 24, profanity list), per-IP and per-client rate limits.

**Client (Godot):** a small `Leaderboard.gd` autoload wrapping `HTTPRequest`; submits from `EndingScene` after `submit_record`; board UI tab on the Title screen. Fails silently offline.

**Consent and PDPA:** the online board is **off by default**. First submission shows a Thai consent line: display name + score only, no email, stored on the developer's server, removable in Settings. This is a design note, not legal advice.

**Anti-cheat honesty:** the repo is public and the save format is plain JSON, so scores are ultimately honor-system. Say so on the board ("กระดานเกียรติยศช่วงเบตา — ระบบเกียรติยศ"). Server caps catch absurdities; don't pretend more. If competition matters later (Steam), use Steam Leaderboards instead and let Steamworks handle identity.

**Effort:** Worker + D1 schema + deploy ~1 day (needs the owner's Cloudflare account); client + UI + tests ~1 day.

## 4. Build order

1. Local top-10 board + player name (no network, fully testable headless).
2. Weekly seeded challenge mode (balance-sensitive; re-run `balance_sim.gd`).
3. Cloudflare Worker + opt-in online board during beta.
4. On Steam release: migrate the online board to Steam Leaderboards; keep the local board.

## 5. Open decisions

- Board identity: free-text name vs. pick-a-proverb pseudonyms (safer for a public board).
- Whether weekly mode ships in the beta or after.
- Who deploys and owns the Worker (owner's Cloudflare account).
