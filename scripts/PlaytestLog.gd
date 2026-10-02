class_name PlaytestLog
extends RefCounted

## One CSV row per finished burn in user://playtest_log.csv (P0-7), so balance
## can be tuned from real playtests (see HANDOFF.md §4 for the tunables).

const FILE = "playtest_log.csv"
const COLUMNS = [
	"campaign_id", "timestamp", "year", "plot",
	"first_ignition", "firebreak_player", "firebreak_crew",
	"ash_pct", "hotspots_2000", "spot_fires", "spot_fires_doused", "escaped",
	"scrutiny_satellite", "scrutiny_drone", "scrutiny_camera", "scrutiny_escape", "scrutiny_ranger",
	"drone_photos", "camera_trips", "ranger_sightings",
	"rice_change", "rice_after", "scrutiny_after", "game_over",
]

static var dir: String = "user://"

static func path() -> String:
	SaveGame.migrate_old_user_dir()
	return dir.path_join(FILE)

## `row` maps column names to values; missing columns are left empty
static func append(row: Dictionary) -> void:
	var p = path()
	var new_file = not FileAccess.file_exists(p)
	var f = FileAccess.open(p, FileAccess.READ_WRITE if not new_file else FileAccess.WRITE)
	if f == null:
		push_warning("PlaytestLog: cannot write %s" % p)
		return
	f.seek_end()
	if new_file:
		f.store_line(",".join(COLUMNS))
	var cells = PackedStringArray()
	for c in COLUMNS:
		var v = row.get(c, "")
		var text = ("%.1f" % v) if typeof(v) == TYPE_FLOAT else str(v)
		cells.append(text.replace(",", ";"))
	f.store_line(",".join(cells))

## Build the row for a burn that has just been committed to GameState
static func row_for(state: Node, extra: Dictionary) -> Dictionary:
	var b: Dictionary = state.last_breakdown
	var row = {
		"campaign_id": state.stats.get("campaign_id", ""),
		"timestamp": Time.get_datetime_string_from_system(),
		"year": state.current_year,
		"plot": state.current_plot_index,
		"ash_pct": state.last_burn_yield,
		"hotspots_2000": state.last_burn_hotspots,
		"spot_fires": b.get("spot_fires", 0),
		"spot_fires_doused": b.get("spot_fires_doused", 0),
		"escaped": 1 if state.last_burn_escaped else 0,
		"scrutiny_satellite": b.get("satellite", 0),
		"scrutiny_drone": b.get("drone", 0),
		"scrutiny_camera": b.get("camera", 0),
		"scrutiny_escape": b.get("escape", 0),
		"scrutiny_ranger": b.get("ranger", 0),
		"drone_photos": b.get("drone_photos", 0),
		"camera_trips": b.get("camera_trips", 0),
		"ranger_sightings": b.get("ranger_sightings", 0),
		"rice_change": state.last_rice_change,
		"rice_after": state.rice_barn,
		"scrutiny_after": state.state_scrutiny,
		"game_over": state.end_cause(),
	}
	for k in extra:
		row[k] = extra[k]
	return row
