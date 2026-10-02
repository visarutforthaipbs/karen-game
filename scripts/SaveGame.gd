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
	return dir.path_join(file)

static func exists() -> bool:
	return FileAccess.file_exists(_path(CAMPAIGN_FILE))

static func save(state: Node) -> bool:
	if state == null or state.is_game_over():
		return false
	var f = FileAccess.open(_path(CAMPAIGN_FILE), FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: cannot write %s" % _path(CAMPAIGN_FILE))
		return false
	f.store_string(JSON.stringify({"version": VERSION, "campaign": state.to_dict()}, "\t"))
	return true

## Loads the slot into `state`. Returns "" on success, or a reason: "missing",
## "corrupt" or "version" (the slot is then left alone so nothing is lost).
static func load_into(state: Node) -> String:
	if not exists():
		return "missing"
	var text = FileAccess.get_file_as_string(_path(CAMPAIGN_FILE))
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY or not data.has("campaign"):
		return "corrupt"
	if int(data.get("version", 0)) != VERSION:
		return "version"
	state.from_dict(data.campaign)
	return ""

static func delete() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(CAMPAIGN_FILE)))

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
	var f = FileAccess.open(_path(RECORDS_FILE), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(rec, "\t"))
	return true
