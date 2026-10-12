extends Node

## On-device performance log for the iPhone / iPad port (and `--perf` on desktop).
## One CSV row per second into user://perf_log.csv; pull it with
##   xcrun devicectl device copy from --domain-type appDataContainer \
##     --domain-identifier io.github.visarutforthaipbs.undertwoskies \
##     --source Documents/perf_log.csv --destination .
## Spawned by MainController only when UITheme.is_mobile() or --perf is given, so
## desktop builds never write it.

const FILE_NAME := "perf_log.csv"
const HEADER := "run,t,hours,fps,frame_ms_avg,frame_ms_max,process_ms,physics_ms,draw_calls,primitives,objects,nodes,vram_mb,msaa,scale3d,detail,zoom"

static func wanted() -> bool:
	return UITheme.is_mobile() or OS.get_cmdline_user_args().has("--perf")

## Follows GameSettings.dir so test fixtures redirect it like saves and settings.
static func path() -> String:
	return GameSettings.dir.path_join(FILE_NAME)

var _run_id: String = ""
var _t: float = 0.0
var _acc: float = 0.0
var _frames: int = 0
var _max_dt: float = 0.0
var _file: FileAccess
var _main: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_parent()
	_run_id = Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "-")
	var fresh := not FileAccess.file_exists(path())
	_file = FileAccess.open(path(), FileAccess.READ_WRITE if not fresh else FileAccess.WRITE)
	if _file == null:
		push_warning("PerfLog: cannot open %s" % path())
		return
	if fresh:
		_file.store_line(HEADER)
	else:
		_file.seek_end()
	_file.store_line("# run %s device=%s model=%s os=%s renderer=%s" % [
		_run_id, OS.get_name(), OS.get_model_name(), OS.get_version(),
		RenderingServer.get_current_rendering_method()])
	_file.flush()

func _process(delta: float) -> void:
	_acc += delta
	_frames += 1
	_max_dt = maxf(_max_dt, delta)
	_t += delta
	if _acc < 1.0:
		return
	_write_row()
	_acc = 0.0
	_frames = 0
	_max_dt = 0.0

func _write_row() -> void:
	if _file == null:
		return
	var vp := get_viewport()
	var hours := 0.0
	var zoom := 0.0
	if _main:
		var clock = _main.get("game_clock")
		if clock and clock.has_method("get_hours"):
			hours = clock.get_hours()
		var rig = _main.get("cam_rig")
		if rig:
			zoom = float(rig.get("distance"))
	var row := [
		_run_id, "%.1f" % _t, "%.2f" % hours,
		"%.1f" % (float(_frames) / maxf(_acc, 0.001)),
		"%.2f" % (_acc / maxf(float(_frames), 1.0) * 1000.0),
		"%.2f" % (_max_dt * 1000.0),
		"%.2f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0),
		"%.2f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
		str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),
		str(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),
		str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))),
		str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))),
		"%.0f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		str(vp.msaa_3d if vp else -1),
		"%.2f" % (vp.scaling_3d_scale if vp else 1.0),
		GameSettings.landscape_detail,
		"%.0f" % zoom,
	]
	_file.store_line(",".join(row))
	_file.flush()

func _exit_tree() -> void:
	if _file:
		_file.flush()
		_file.close()
