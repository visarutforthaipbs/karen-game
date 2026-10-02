// Under Two Skies — beta leaderboard API (Cloudflare Worker + D1).
// Design: LEADERBOARD_PLAN.md §3. Honor-system board for the beta: server-side
// sanity caps only, no real anti-cheat (the game is open source). Stores a
// display name and scores only — no email, no tracking (PDPA-minded).
// One best row per (client_id, mode, week); resubmits keep the better run.

const MODES = new Set(["endless", "weekly"]);
const RANK_ORDER = "plots DESC, avg_ash DESC, detections ASC, updated_at ASC";

const CORS = {
	"Access-Control-Allow-Origin": "*",
	"Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
	"Access-Control-Allow-Headers": "Content-Type",
};

function json(data, status = 200) {
	return new Response(JSON.stringify(data), {
		status,
		headers: { "Content-Type": "application/json; charset=utf-8", ...CORS },
	});
}

function bad(msg, status = 400) {
	return json({ ok: false, error: msg }, status);
}

function sanitizeName(raw) {
	let n = String(raw ?? "").trim().slice(0, 24).trim();
	// Strip control chars; keep Thai, Latin, digits, spaces and basic punctuation
	n = n.replace(/[\u0000-\u001f\u007f<>]/g, "");
	return n === "" ? "ขะแน" : n;
}

function validWeek(w) {
	return w === "" || /^\d{4}-W\d{2}$/.test(w);
}

function rowPublic(r, rank) {
	return {
		rank,
		name: r.name,
		plots: r.plots,
		year: r.year,
		avg_ash: Math.round(r.avg_ash * 10) / 10,
		detections: r.detections,
		cause: r.cause,
	};
}

// true when a outranks b (same order as the game's local board)
function outranks(a, b) {
	if (a.plots !== b.plots) return a.plots > b.plots;
	if (Math.abs(a.avg_ash - b.avg_ash) > 1e-6) return a.avg_ash > b.avg_ash;
	return a.detections < b.detections;
}

async function handleSubmit(req, env) {
	let body;
	try {
		body = await req.json();
	} catch {
		return bad("invalid json");
	}
	const client_id = String(body.client_id ?? "");
	if (!/^[0-9a-fA-F-]{16,64}$/.test(client_id)) return bad("bad client_id");
	const secret = String(body.secret ?? "").slice(0, 64);
	const mode = MODES.has(body.mode) ? body.mode : "endless";
	const week = String(body.week ?? "");
	if (!validWeek(week)) return bad("bad week");
	const plots = Math.trunc(Number(body.plots));
	const year = Math.trunc(Number(body.year));
	const avg_ash = Number(body.avg_ash);
	const detections = Math.trunc(Number(body.detections));
	if (!Number.isFinite(plots) || plots < 0 || plots > 150) return bad("bad plots");
	if (!Number.isFinite(year) || year < 1 || year > 40) return bad("bad year");
	if (!Number.isFinite(avg_ash) || avg_ash < 0 || avg_ash > 100) return bad("bad avg_ash");
	if (!Number.isFinite(detections) || detections < 0 || detections > 10000) return bad("bad detections");
	const name = sanitizeName(body.name);
	const cause = ["famine", "crackdown", ""].includes(body.cause) ? body.cause : "";
	const version = String(body.version ?? "").slice(0, 24);

	const existing = await env.DB.prepare(
		"SELECT * FROM scores WHERE client_id = ?1 AND mode = ?2 AND week = ?3"
	).bind(client_id, mode, week).first();

	if (existing) {
		if (existing.secret !== "" && secret !== existing.secret) return bad("wrong secret", 403);
		// Soft rate limit: one accepted write per client row per 20 s
		const age = Date.now() - Date.parse(existing.updated_at + "Z");
		if (Number.isFinite(age) && age < 20_000) return bad("too fast", 429);
		const next = outranks({ plots, avg_ash, detections }, existing)
			? { plots, year, avg_ash, detections, cause }
			: existing;
		await env.DB.prepare(
			"UPDATE scores SET name=?1, plots=?2, year=?3, avg_ash=?4, detections=?5, cause=?6, version=?7, updated_at=datetime('now') WHERE client_id=?8 AND mode=?9 AND week=?10"
		).bind(name, next.plots, next.year, next.avg_ash, next.detections, next.cause, version, client_id, mode, week).run();
	} else {
		await env.DB.prepare(
			"INSERT INTO scores (client_id, mode, week, name, plots, year, avg_ash, detections, cause, version, secret) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11)"
		).bind(client_id, mode, week, name, plots, year, avg_ash, detections, cause, version, secret).run();
	}

	const rank = await rankOf(env, client_id, mode, week);
	return json({ ok: true, rank });
}

async function rankOf(env, client_id, mode, week) {
	const me = await env.DB.prepare(
		"SELECT * FROM scores WHERE client_id = ?1 AND mode = ?2 AND week = ?3"
	).bind(client_id, mode, week).first();
	if (!me) return null;
	const better = await env.DB.prepare(
		`SELECT COUNT(*) AS n FROM scores WHERE mode = ?1 AND week = ?2 AND (
			plots > ?3 OR (plots = ?3 AND avg_ash > ?4) OR (plots = ?3 AND avg_ash = ?4 AND detections < ?5)
			OR (plots = ?3 AND avg_ash = ?4 AND detections = ?5 AND updated_at < ?6))`
	).bind(mode, week, me.plots, me.avg_ash, me.detections, me.updated_at).first();
	return (better?.n ?? 0) + 1;
}

async function handleTop(url, env) {
	const mode = MODES.has(url.searchParams.get("mode")) ? url.searchParams.get("mode") : "endless";
	const week = url.searchParams.get("week") ?? "";
	if (!validWeek(week)) return bad("bad week");
	const n = Math.min(100, Math.max(1, Math.trunc(Number(url.searchParams.get("n") ?? 50))));
	const { results } = await env.DB.prepare(
		`SELECT * FROM scores WHERE mode = ?1 AND week = ?2 ORDER BY ${RANK_ORDER} LIMIT ?3`
	).bind(mode, week, n).all();
	return json({ ok: true, rows: results.map((r, i) => rowPublic(r, i + 1)) });
}

async function handleAround(url, env) {
	const client_id = String(url.searchParams.get("client_id") ?? "");
	const mode = MODES.has(url.searchParams.get("mode")) ? url.searchParams.get("mode") : "endless";
	const week = url.searchParams.get("week") ?? "";
	if (!validWeek(week)) return bad("bad week");
	const rank = await rankOf(env, client_id, mode, week);
	if (rank === null) return json({ ok: true, rank: null, rows: [] });
	const from = Math.max(0, rank - 6);
	const { results } = await env.DB.prepare(
		`SELECT * FROM scores WHERE mode = ?1 AND week = ?2 ORDER BY ${RANK_ORDER} LIMIT 11 OFFSET ?3`
	).bind(mode, week, from).all();
	return json({ ok: true, rank, rows: results.map((r, i) => rowPublic(r, from + i + 1)) });
}

async function handleDelete(url, env) {
	const client_id = String(url.searchParams.get("client_id") ?? "");
	const secret = String(url.searchParams.get("secret") ?? "");
	if (client_id === "") return bad("bad client_id");
	const res = await env.DB.prepare(
		"DELETE FROM scores WHERE client_id = ?1 AND (secret = '' OR secret = ?2)"
	).bind(client_id, secret).run();
	return json({ ok: true, deleted: res.meta.changes ?? 0 });
}

export default {
	async fetch(req, env) {
		const url = new URL(req.url);
		if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
		if (url.pathname === "/" || url.pathname === "/v1/health")
			return json({ ok: true, game: "Under Two Skies", board: "beta" });
		if (url.pathname === "/v1/scores" && req.method === "POST") return handleSubmit(req, env);
		if (url.pathname === "/v1/top" && req.method === "GET") return handleTop(url, env);
		if (url.pathname === "/v1/around" && req.method === "GET") return handleAround(url, env);
		if (url.pathname === "/v1/scores" && req.method === "DELETE") return handleDelete(url, env);
		return bad("not found", 404);
	},
};
