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
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or not data.has("campaign"):
		return "corrupt"
	if int(data.get("version", 0)) != VERSION:
		return "version"
	# Validate every field before touching the live state, so a damaged save
	# reports "corrupt" instead of erroring with the singleton half-loaded
	if not valid_campaign(data.campaign):
		return "corrupt"
	state.from_dict(data.campaign)
	return ""

static func _num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT

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
	for k in ["favours", "season_yields"]:
		if d.has(k) and not _nums(d[k]):
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
# Best run
# ---------------------------------------------------------------------------

static func best_record() -> Dictionary:
	var p = _path(RECORDS_FILE)
	if not FileAccess.file_exists(p):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(p))
	return data if typeof(data) == TYPE_DICTIONARY else {}

## Stores this campaign if it survived more plots than the best so far.
## Returns true when it is a new record.
static func submit_record(state: Node) -> bool:
	var plots = int(state.stats.get("plots_completed", 0))
	var best = best_record()
	if not best.is_empty() and plots <= int(best.get("plots_completed", 0)):
		return false
	var rec = {
		"plots_completed": plots,
		"year": state.current_year,
		"avg_ash": state.stats.ash_sum / maxf(1.0, plots),
		"cause": state.end_cause(),
		"date": Time.get_date_string_from_system(),
	}
	return write_atomic(_path(RECORDS_FILE), JSON.stringify(rec, "\t"))
