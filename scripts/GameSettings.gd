class_name GameSettings
extends RefCounted

## Player settings in user://settings.cfg, applied on boot (Title screen) and
## whenever the settings panel changes them. Static so any scene can read them.

const FILE = "settings.cfg"
## Mixer buses the player can set; names match AudioManager's buses
const VOLUME_BUSES = [
	["Master", "เสียงรวม"],
	["Music", "ดนตรี"],
	["SFX", "เสียงเอฟเฟกต์"],
	["Ambience", "เสียงบรรยากาศ"],
	["RadioVoice", "เสียงพูดและวิทยุ"],
]

static var dir: String = "user://"
static var volumes: Dictionary = {}
static var fullscreen: bool = false
static var ui_scale: float = 1.0
static var camera_zoom: float = 44.0
static var show_hints: bool = true
static var first_burn_tips: bool = true
## "high" or "low" (Steam Deck): fewer far trees, no valley mist
static var landscape_detail: String = "high"
## Tester tools (F3 overlay, F5-F10 cheats); always on in debug builds
static var debug_tools: bool = false
## Name shown on the village board (records.json rows)
static var player_name: String = "ขะแน"
## Opt-in online board (beta): off by default; anonymous id + secret
static var online_board: bool = false
static var client_id: String = ""
static var client_secret: String = ""
static var _loaded: bool = false

static func _path() -> String:
	SaveGame.migrate_old_user_dir()
	return dir.path_join(FILE)

static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()

static func load_settings() -> void:
	_loaded = true
	volumes.clear()
	for b in VOLUME_BUSES:
		volumes[b[0]] = 1.0
	var cfg = ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	for b in VOLUME_BUSES:
		volumes[b[0]] = clampf(float(cfg.get_value("audio", b[0], 1.0)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", false))
	ui_scale = clampf(float(cfg.get_value("display", "ui_scale", 1.0)), 0.85, 1.3)
	landscape_detail = str(cfg.get_value("display", "landscape_detail", "high"))
	camera_zoom = clampf(float(cfg.get_value("gameplay", "camera_zoom", 44.0)), 26.0, 64.0)
	show_hints = bool(cfg.get_value("gameplay", "show_hints", true))
	first_burn_tips = bool(cfg.get_value("gameplay", "first_burn_tips", true))
	debug_tools = bool(cfg.get_value("debug", "tools", false))
	player_name = SaveGame.sanitize_name(cfg.get_value("player", "name", SaveGame.DEFAULT_NAME))
	online_board = bool(cfg.get_value("online", "board", false))
	client_id = str(cfg.get_value("online", "client_id", ""))
	client_secret = str(cfg.get_value("online", "client_secret", ""))

static func save_settings() -> void:
	var cfg = ConfigFile.new()
	for b in VOLUME_BUSES:
		cfg.set_value("audio", b[0], volumes.get(b[0], 1.0))
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "ui_scale", ui_scale)
	cfg.set_value("display", "landscape_detail", landscape_detail)
	cfg.set_value("gameplay", "camera_zoom", camera_zoom)
	cfg.set_value("gameplay", "show_hints", show_hints)
	cfg.set_value("gameplay", "first_burn_tips", first_burn_tips)
	cfg.set_value("debug", "tools", debug_tools)
	cfg.set_value("player", "name", SaveGame.sanitize_name(player_name))
	cfg.set_value("online", "board", online_board)
	cfg.set_value("online", "client_id", client_id)
	cfg.set_value("online", "client_secret", client_secret)
	cfg.save(_path())

## Push the current values to the mixer, window and UI scale
static func apply(tree: SceneTree) -> void:
	ensure_loaded()
	for bus in volumes:
		var idx = AudioServer.get_bus_index(bus)
		if idx != -1:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.001, volumes[bus])))
	if DisplayServer.get_name() != "headless":
		var want = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
	if tree and tree.root:
		tree.root.content_scale_factor = ui_scale

static func debug_enabled() -> bool:
	ensure_loaded()
	return debug_tools or OS.is_debug_build() and OS.has_feature("editor") or OS.get_cmdline_user_args().has("--debug-tools")
