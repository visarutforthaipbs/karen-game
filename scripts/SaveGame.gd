class_name SaveGame
extends RefCounted

## One autosave slot for the campaign (written whenever the Hearth refreshes)
## plus the best-run record. Files live in user:// so builds and the editor
## keep their own copies. Tests point `dir` at a scratch folder.

const VERSION: int = 1
const CAMPAIGN_FILE = "campaign.json"
const RECORDS_FILE = "records.json"

static var dir: String = "user://"

static func _path(file: String) -> String:
	migrate_old_user_dir()
	return dir.path_join(file)

## The game was renamed from "Satellite Shadow" to "Under Two Skies", and Godot
## names the user:// folder after the project. Copy the old folder's saves,
## records, settings and playtest log across once, so testers keep them.
const OLD_PROJECT_NAME = "Satellite Shadow"
static var _migrated: bool = false

static func migrate_old_user_dir() -> void:
	if _migrated or dir != "user://":
		return
	_migrated = true
	var old_dir = OS.get_data_dir().path_join("Godot/app_userdata").path_join(OLD_PROJECT_NAME)
	var new_dir = ProjectSettings.globalize_path("user://")
	if old_dir.simplify_path() == new_dir.simplify_path() or not DirAccess.dir_exists_absolute(old_dir):
		return
	for file in ["campaign.json", "records.json", "settings.cfg", "playtest_log.csv"]:
		var src = old_dir.path_join(file)
		var dst = new_dir.path_join(file)
		if FileAccess.file_exists(src) and not FileAccess.file_exists(dst):
			DirAccess.copy_absolute(src, dst)

static func exists() -> bool:
	return FileAccess.file_exists(_path(CAMPAIGN_FILE)) or FileAccess.file_exists(_path(CAMPAIGN_FILE) + ".bak")

static func save(state: Node) -> bool:
	if state == null or state.is_game_over():
		return false
	return write_atomic(_path(CAMPAIGN_FILE), JSON.stringify({"version": VERSION, "campaign": state.to_dict()}, "\t"))

## Crash-safe write (audit finding 3): write <file>.tmp, check it, keep the old
## file as <file>.bak, then move the new one into place. A crash at any point
## leaves either the old save, the backup or the new save intact.
static func write_atomic(path: String, text: String) -> bool:
	var tmp = path + ".tmp"
	var f = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: cannot write %s" % tmp)
		return false
	f.store_string(text)
	var err = f.get_error()
	f.close()
	if err != OK or FileAccess.get_file_as_string(tmp) != text:
		push_warning("SaveGame: write check failed for %s" % tmp)
		return false
	var g = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(g + ".bak")
		DirAccess.rename_absolute(g, g + ".bak")
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), g) == OK

## Loads the slot into `state`. Returns "" on success, or a reason: "missing",
## "corrupt" or "version" (the slot is then left alone so nothing is lost).
## Falls back to the backup when the main file is missing or damaged.
static func load_into(state: Node) -> String:
	if not exists():
		return "missing"
	var reason = _load_file(state, _path(CAMPAIGN_FILE))
	if reason != "" and reason != "version":
		var backup = _load_file(state, _path(CAMPAIGN_FILE) + ".bak")
		if backup == "":
			return ""
	return reason

static func _load_file(state: Node, path: String) -> String:
	if not FileAccess.file_exists(path):
		return "missing"
	var data = _read_json(path)
	if typeof(data) != TYPE_DICTIONARY or not data.has("campaign"):
		return "corrupt"
	if not _num(data.get("version")) or float(data.version) != VERSION:
		return "version"
	# Validate every field before touching the live state, so a damaged save
	# reports "corrupt" instead of erroring with the singleton half-loaded
	if not valid_campaign(data.campaign):
		return "corrupt"
	state.from_dict(data.campaign)
	return ""

## Damaged local files are an expected recovery path, not an engine error.
static func _read_json(path: String):
	var parser = JSON.new()
	return parser.data if parser.parse(FileAccess.get_file_as_string(path)) == OK else null

static func _num(v) -> bool:
	return (typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT) and is_finite(float(v))

static func _nums(a) -> bool:
	if typeof(a) != TYPE_ARRAY:
		return false
	for v in a:
		if not _num(v):
			return false
	return true

## Shape check for GameState.from_dict: every field it reads must have the type it expects
static func valid_campaign(d) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false
	for k in ["current_year", "current_plot_index", "rice_barn", "state_scrutiny", "blade_upgrade_level",
			"sprayer_upgrade_level", "ration_level", "forecast_wind_angle", "last_burn_yield",
			"last_burn_hotspots", "last_rice_change", "last_barn_target", "last_scrutiny_relief"]:
		if d.has(k) and not _num(d[k]):
			return false
	if int(d.get("current_year", 1)) < 1 or int(d.get("current_plot_index", 1)) < 1 or int(d.get("current_plot_index", 1)) > 5:
		return false
	# Correct numeric types alone do not make safe enum/dictionary keys.
	for k in ["current_year", "current_plot_index", "ration_level", "blade_upgrade_level", "sprayer_upgrade_level"]:
		if d.has(k) and (not is_finite(float(d[k])) or float(d[k]) != floorf(float(d[k]))):
			return false
	if int(d.get("ration_level", 1)) not in [0, 1, 2]:
		return false
	for k in ["blade_upgrade_level", "sprayer_upgrade_level"]:
		if int(d.get(k, 0)) < 0 or int(d.get(k, 0)) > 3:
			return false
	for k in ["favours", "season_yields"]:
		if d.has(k) and not _nums(d[k]):
			return false
	for favour in d.get("favours", []):
		if not is_finite(float(favour)) or float(favour) != floorf(float(favour)) or int(favour) not in [0, 1, 2]:
			return false
	if typeof(d.get("hotspot_log", [])) != TYPE_ARRAY:
		return false
	for e in d.get("hotspot_log", []):
		if typeof(e) != TYPE_DICTIONARY:
			return false
		for k in ["year", "plot", "lat", "lon", "heat"]:
			if not _num(e.get(k)):
				return false
		if not _nums(e.get("cell")) or e.cell.size() != 2:
			return false
	var h = d.get("pending_harvest", {})
	if typeof(h) != TYPE_DICTIONARY:
		return false
	if not h.is_empty():
		for k in ["year", "average", "rice_delta", "scrutiny_relief", "next_year"]:
			if not _num(h.get(k)):
				return false
		if not _nums(h.get("yields")) or typeof(h.get("next_rules")) != TYPE_ARRAY:
			return false
	var st = d.get("stats", {})
	if typeof(st) != TYPE_DICTIONARY:
		return false
	for k in st:
		if k != "campaign_id" and not _num(st[k]):
			return false
	return true

static func delete() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var p = _path(CAMPAIGN_FILE) + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# ---------------------------------------------------------------------------
# Village board: records.json v2, a top-10 table of finished runs
# ---------------------------------------------------------------------------

const RECORDS_VERSION: int = 2
const BOARD_SIZE: int = 10
const NAME_MAX: int = 24
const DEFAULT_NAME = "ขะแน"

## Trim, cap at 24 characters, fall back to the default when nothing is left
static func sanitize_name(raw) -> String:
	var n = str(raw).strip_edges()
	if n.length() > NAME_MAX:
		n = n.substr(0, NAME_MAX).strip_edges()
	return n if n != "" else DEFAULT_NAME

## True when row `a` ranks strictly above row `b`: plots DESC, avg_ash DESC, detections ASC
static func _outranks(a: Dictionary, b: Dictionary) -> bool:
	if int(a.plots) != int(b.plots):
		return int(a.plots) > int(b.plots)
	if not is_equal_approx(float(a.avg_ash), float(b.avg_ash)):
		return float(a.avg_ash) > float(b.avg_ash)
	return int(a.detections) < int(b.detections)

static func _clean_row(r) -> Dictionary:
	if typeof(r) != TYPE_DICTIONARY or not _num(r.get("plots")):
		return {}
	return {
		"name": sanitize_name(r.get("name", DEFAULT_NAME)),
		"plots": int(r.plots),
		"year": int(r.get("year", 1)) if _num(r.get("year", 1)) else 1,
		"avg_ash": float(r.get("avg_ash", 0.0)) if _num(r.get("avg_ash", 0.0)) else 0.0,
		"detections": int(r.get("detections", 0)) if _num(r.get("detections", 0)) else 0,
		"cause": str(r.get("cause", "")),
		"date": str(r.get("date", "")),
		"campaign_id": str(r.get("campaign_id", "")),
	}

## Insert keeping the table sorted; equal rows keep the older one first
static func _insert_sorted(rows: Array, row: Dictionary) -> void:
	var at = rows.size()
	for i in rows.size():
		if _outranks(row, rows[i]):
			at = i
			break
	rows.insert(at, row)

static func _write_runs(rows: Array) -> bool:
	return write_atomic(_path(RECORDS_FILE), JSON.stringify({"version": RECORDS_VERSION, "runs": rows}, "\t"))

## The sorted board (best first). A v1 file (one bare best-run dict) is migrated
## to a one-row v2 table on first read. Recover .bak after an interrupted write;
## a valid empty main table stays empty rather than resurrecting old records.
static func runs() -> Array:
	var p = _path(RECORDS_FILE)
	var data = null
	for candidate in [p, p + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var loaded = _read_json(candidate)
		if typeof(loaded) != TYPE_DICTIONARY:
			continue
		if (loaded.has("runs") and typeof(loaded.runs) == TYPE_ARRAY) or (loaded.has("plots_completed") and _num(loaded.plots_completed)):
			data = loaded
			break
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var rows: Array = []
	if data.has("runs"):
		if typeof(data.runs) != TYPE_ARRAY:
			return []
		for r in data.runs:
			var c = _clean_row(r)
			if not c.is_empty():
				_insert_sorted(rows, c)
		return rows.slice(0, BOARD_SIZE)
	if data.has("plots_completed") and _num(data.plots_completed):
		rows.append(_clean_row({
			"name": DEFAULT_NAME,
			"plots": data.plots_completed,
			"year": data.get("year", 1),
			"avg_ash": data.get("avg_ash", 0.0),
			"detections": 0,
			"cause": data.get("cause", ""),
			"date": data.get("date", ""),
			"campaign_id": "",
		}))
		_write_runs(rows)
	return rows

## Best run in the v1 shape (TitleScreen and old tests read these keys); {} when empty
static func best_record() -> Dictionary:
	var rows = runs()
	if rows.is_empty():
		return {}
	var top = rows[0]
	return {
		"plots_completed": top.plots,
		"year": top.year,
		"avg_ash": top.avg_ash,
		"cause": top.cause,
		"date": top.date,
	}

## Adds this campaign to the board (top 10 kept). Returns true when it has
## strictly more plots than the previous best, i.e. a new record.
static func submit_record(state: Node) -> bool:
	GameSettings.ensure_loaded()
	var st: Dictionary = state.stats
	var plots = int(st.get("plots_completed", 0))
	var rows = runs()
	var is_record = rows.is_empty() or plots > int(rows[0].plots)
	var row = {
		"name": sanitize_name(GameSettings.player_name),
		"plots": plots,
		"year": int(state.current_year),
		"avg_ash": float(st.get("ash_sum", 0.0)) / maxf(1.0, plots),
		"detections": int(st.get("hotspots_detected", 0)) + int(st.get("drone_photos", 0)) + int(st.get("camera_trips", 0)) + int(st.get("ranger_sightings", 0)),
		"cause": state.end_cause(),
		"date": Time.get_date_string_from_system(),
		"campaign_id": str(st.get("campaign_id", "")),
	}
	_insert_sorted(rows, row)
	_write_runs(rows.slice(0, BOARD_SIZE))
	return is_record

## Renames this campaign's row, if it is still on the board
static func rename_run(campaign_id: String, name: String) -> void:
	if campaign_id == "":
		return
	var rows = runs()
	for r in rows:
		if r.campaign_id == campaign_id:
			r.name = sanitize_name(name)
			_write_runs(rows)
			return
