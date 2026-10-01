class_name MainController
extends Node3D

@onready var fire_grid: FireGrid = $FireGrid
@onready var game_clock: GameClock = $GameClock
@onready var wind_manager: WindManager = $WindManager
@onready var drone: ForestryDrone = $ForestryDrone
@onready var satellite: SatelliteOverpass = $SatelliteOverpass
@onready var player: PlayerController = $Player
@onready var elder: CompanionController = $Elder
@onready var youth: CompanionController = $Youth
@onready var hud: GameHUD = $HUD
@onready var camera: Camera3D = $Camera3D
@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var world_environment: WorldEnvironment = $WorldEnvironment

const ESCAPE_BASE_PENALTY: float = 40.0
const CAMERA_BASE_PENALTY: float = 10.0

# In-game minutes since midnight for scheduled events (PRD §3.1, §6.2)
const DRONE_LAUNCH_MINUTE: int = 15 * 60
const DRONE_STAGGER_MINUTES: int = 30
const DRONE_RETURN_MINUTE: int = 18 * 60
const INVERSION_MINUTE: int = 18 * 60
const COUNTDOWN_MINUTE: int = 19 * 60 + 45
const PASS_MINUTE: int = 20 * 60

const PHASES = [
	{"start": 14 * 60, "title": "ระยะ 1 · ถางแนวกันไฟ (14:00–15:30)", "goal": "ถางแนวกันไฟรอบแปลง อ่านทิศลม แล้วจุดไฟย้อนลมเป็นแนวกันชน"},
	{"start": 15 * 60 + 30, "title": "ระยะ 2 · เผาใหญ่ (15:30–18:00)", "goal": "จุดไฟหัว คุมไฟที่วิ่งขึ้นเนิน ตบลูกไฟ และหลบโดรน"},
	{"start": 18 * 60, "title": "ระยะ 3 · อากาศผกผัน เร่งดับถ่านคุ (18:00–19:45)", "goal": "ฉีดน้ำดับตอไผ่และโคนรากที่ยังคุแดง"},
	{"start": 19 * 60 + 45, "title": "ระยะ 4 · นับถอยหลังดาวเทียม (19:45–20:00)", "goal": "ตามดับทุกจุดที่ร้อนตั้งแต่ %d TU ขึ้นไป!"},
]

var escaped_to_forest: bool = false
var latest_rice_yield: float = 0.0

# Campaign scrutiny when the plot began, plus everything this burn has added.
# GameState is only updated once, when the satellite pass resolves.
var starting_scrutiny: int = 0
var plot_scrutiny_gain: int = 0

var plot_cfg: PlotGenerator.PlotConfig
var rules: Escalation.YearRules
var plot_has_drone: bool = false
var park_strictness: float = 1.0
var drones: Array[ForestryDrone] = []
var drones_launched: int = 0
var thermal_cameras: Array[ThermalCamera] = []
var inversion_started: bool = false
var pass_started: bool = false
var current_phase: int = -1

var sky: SkyCycle
var _inversion_level: float = 0.0
var _last_burning_count: int = 0
var _ember_alert_cooldown: float = 0.0
var _thunder_timer: float = 20.0
var hut_position: Vector3

var latest_stamina: float = 100.0
var latest_max_stamina: float = 100.0
var latest_smoke: float = 0.0

func _ready() -> void:
	# Assign references
	player.fire_grid = fire_grid
	for c in [elder, youth]:
		c.player = player
		c.fire_grid = fire_grid
	elder.apply_role(CompanionController.Role.ELDER)
	youth.apply_role(CompanionController.Role.YOUTH)
	wind_manager.fire_grid = fire_grid
	satellite.fire_grid = fire_grid
	satellite.main_camera = camera

	# Campaign state, this plot's hillside and this year's surveillance
	var state = GameState.instance
	starting_scrutiny = state.state_scrutiny
	plot_cfg = state.plot_config()
	rules = plot_cfg.rules
	park_strictness = plot_cfg.national_park_strictness

	fire_grid.configure_plot(plot_cfg)
	_build_field_hut()
	_place_crew_at_hut()
	wind_manager.configure(state.forecast_wind_direction(), plot_cfg.wind_base_speed, plot_cfg.wind_shift_interval)

	# Mutual aid exchange: favours arrive at the cost of a late start
	var delay = state.labour_delay_minutes()
	game_clock.set_start_time(14, delay)
	_apply_crew_preparation(state)
	_setup_drones()
	_setup_thermal_cameras()

	satellite.thermal_threshold = rules.satellite_threshold
	satellite.hotspot_penalty = rules.hotspot_penalty

	# Each burn gets its own Environment so lighting / fog changes never leak into the next plot
	world_environment.environment = world_environment.environment.duplicate(true)
	sky = SkyCycle.new()
	sky.sun = sun
	sky.world_environment = world_environment
	sky.storm_front = plot_cfg.storm_front
	sky.inversion_ceiling = fire_grid.max_elevation * 0.5 + 2.0
	add_child(sky)

	# Connect FireGrid signals
	fire_grid.rice_yield_changed.connect(_on_rice_yield_changed)
	fire_grid.hotspot_count_changed.connect(_on_hotspot_count_changed)
	fire_grid.fire_escaped_to_forest.connect(_on_forest_escape)
	fire_grid.bamboo_exploded.connect(_on_bamboo_exploded)
	fire_grid.ember_jumped.connect(_on_ember_jumped)

	# Connect GameClock signals
	game_clock.time_ticked.connect(_on_clock_ticked)
	game_clock.satellite_window_closing.connect(_on_satellite_closing)
	game_clock.satellite_pass_triggered.connect(_on_satellite_pass)

	# Connect Wind signals
	wind_manager.wind_shift_warning.connect(_on_wind_shift_warning)
	wind_manager.wind_shifted.connect(_on_wind_shifted)

	# Connect Satellite signals
	satellite.sweep_completed.connect(_on_satellite_sweep_completed)

	# Connect Player signals
	player.tool_changed.connect(_on_tool_changed)
	player.order_pinged.connect(_on_order_pinged)
	player.whistle_blown.connect(_on_whistle_blown)
	player.stamina_changed.connect(_on_stamina_changed)
	player.smoke_exposure_changed.connect(_on_smoke_exposure_changed)
	player.water_changed.connect(hud.update_water)
	player.tank_empty.connect(_on_tank_empty)

	for c in [elder, youth]:
		c.status_changed.connect(func(who, text): hud.update_crew_status(who.display_name(), text))
		c.started_coughing.connect(_on_companion_coughing)

	# Initialize HUD displays
	hud.update_wind(wind_manager.current_direction, wind_manager.current_speed)
	hud.update_scrutiny(get_current_scrutiny())
	hud.update_tool(PlayerController.TOOL_LABELS[player.current_tool])
	hud.update_water(player.water, player.water_capacity)
	hud.update_crew_status("ตาโพ", "เดินตาม")
	hud.update_crew_status("มูนอ", "เดินตาม")
	sky.apply_time(game_clock.get_hours())

	var intro = "%s · ปีที่ %d" % [plot_cfg.name, state.current_year]
	if delay > 0:
		intro += "\nเช้านี้ทีมไปเอาแรงช่วยหมู่บ้านอื่น เริ่มเผาช้าไป %d นาที" % delay
	hud.show_alert(intro, 5.0)

	if AudioManager.instance:
		AudioManager.instance.set_music_intensity(0)

## Rations, workshop upgrades and borrowed equipment take effect for this burn
func _apply_crew_preparation(state: Node) -> void:
	elder.work_efficiency += state.blade_upgrade_level * 0.35
	youth.work_efficiency += state.sprayer_upgrade_level * 0.35
	player.blade_cooldown_multiplier = 1.0 - 0.2 * state.blade_upgrade_level
	player.water_per_douse = 1.0 - 0.15 * state.sprayer_upgrade_level

	var capacity = 15.0 + (10.0 if state.has_favour(GameState.Favour.WATER) else 0.0)
	player.set_water_capacity(capacity)
	elder.can_douse = state.has_favour(GameState.Favour.SPRAYER)

	match state.ration_level:
		GameState.Ration.LEAN:
			player.max_stamina = 70.0
			player.current_stamina = 70.0
			for c in [elder, youth]:
				c.work_efficiency *= 0.85
				c.speed_multiplier = 0.9
		GameState.Ration.FULL:
			player.stamina_regen_multiplier = 1.5
			player.speed_multiplier = 1.05
			for c in [elder, youth]:
				c.work_efficiency *= 1.15
				c.speed_multiplier = 1.05

## Karen field hut on the south edge of the plot; its water barrels refill the sprayer
func _build_field_hut() -> void:
	var w = fire_grid.grid_width
	var h = fire_grid.grid_height
	var yard: Array = []
	# Include the crew's starting area five metres uphill from the hut.
	for y in range(h - 7, h):
		for x in range(w / 2 - 3, w / 2 + 3):
			yard.append(Vector2i(x, y))
	fire_grid.reserve_clearing(yard)

	var a = fire_grid.get_cell_world_pos(w / 2 - 1, h - 2)
	var b = fire_grid.get_cell_world_pos(w / 2, h - 1)
	hut_position = (a + b) * 0.5
	hut_position.y = maxf(a.y, b.y) + FireGrid.GROUND_TOP_OFFSET

	var hut = MeshInstance3D.new()
	hut.mesh = AssetLibrary.mesh_or("S1", LowPoly.field_hut())
	hut.rotation.y = PI # Ladder faces up the plot
	add_child(hut)
	hut.global_position = hut_position + Vector3(-1.2, 0, 0)

	var barrels = MeshInstance3D.new()
	barrels.mesh = AssetLibrary.mesh_or("S2", LowPoly.water_barrels())
	add_child(barrels)
	barrels.global_position = hut_position + Vector3(2.4, 0, 0)
	player.refill_point = barrels.global_position

func _place_crew_at_hut() -> void:
	var start = hut_position + Vector3(0, 0, -5.0)
	player.global_position = start
	elder.global_position = start + Vector3(-2.5, 0, 0)
	youth.global_position = start + Vector3(2.5, 0, 0)
	for c in [player, elder, youth]:
		c.global_position.y = fire_grid.get_ground_height_at_world_pos(c.global_position)

## One drone per year rule, flying above this hillside; Year 3+ adds a mirrored second route
func _setup_drones() -> void:
	plot_has_drone = plot_cfg.drone_count > 0
	var crew: Array[Node3D] = [player, elder, youth]
	drones.clear()
	drones.append(drone)
	for i in range(1, plot_cfg.drone_count):
		var extra = ForestryDrone.new()
		add_child(extra)
		drones.append(extra)
	for i in drones.size():
		var d = drones[i]
		d.fire_grid = fire_grid
		d.player = player
		d.crew = crew
		d.configure(fire_grid.max_elevation + 8.0, rules.drone_speed_mult, i % 2)
		d.drone_spotted_target.connect(_on_drone_spotted)
	if not plot_has_drone:
		drone.visible = false
		drone.set_physics_process(false)

## Year 3+: thermal camera posts along the most protected edge of the park
func _setup_thermal_cameras() -> void:
	if rules.ground_cameras <= 0:
		return
	var w = fire_grid.grid_width
	var row = maxi(0, fire_grid.border_depth.north - 1)
	for k in rules.ground_cameras:
		var x = int(float(k + 1) * w / float(rules.ground_cameras + 1))
		var cam = ThermalCamera.new()
		cam.fire_grid = fire_grid
		add_child(cam)
		cam.global_position = fire_grid.get_cell_world_pos(x, row) + Vector3(0, FireGrid.GROUND_TOP_OFFSET, 0)
		cam.heat_detected.connect(_on_camera_heat)
		thermal_cameras.append(cam)

func get_current_scrutiny() -> int:
	return min(100, starting_scrutiny + plot_scrutiny_gain)

func _add_scrutiny(amount: int) -> void:
	plot_scrutiny_gain += amount
	hud.update_scrutiny(get_current_scrutiny())

func _penalty(base: float) -> int:
	return roundi(base * rules.penalty_mult)

func _process(delta: float) -> void:
	var hours = game_clock.get_hours()

	# The satellite view is a clean false-colour image: no sky / fog updates
	if pass_started:
		return
	
	if inversion_started:
		_inversion_level = move_toward(_inversion_level, 1.0, delta / 5.0)
	sky.inversion_strength = _inversion_level
	sky.apply_time(hours)

	# 19:45 countdown to the orbital pass
	var minutes_now = hours * 60.0
	if minutes_now >= COUNTDOWN_MINUTE:
		var secs_left = maxi(0, int((PASS_MINUTE - minutes_now) * 60.0))
		hud.update_countdown("VIIRS ผ่านใน %02d:%02d" % [secs_left / 60, secs_left % 60])

	_ember_alert_cooldown = maxf(0.0, _ember_alert_cooldown - delta)

	if AudioManager.instance:
		AudioManager.instance.set_fire_intensity(_last_burning_count / 60.0)
		var hum = 0.0
		for d in drones:
			hum = maxf(hum, d.get_hum_level(player.global_position))
		AudioManager.instance.set_drone_proximity(hum)

	# Pre-monsoon storm front: thunder and lightning as the evening comes on
	if plot_cfg.storm_front and hours >= 17.0:
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			_thunder_timer = randf_range(18.0, 40.0)
			sky.flash()
			if AudioManager.instance:
				AudioManager.instance.play_thunder()

func _on_clock_ticked(time_str: String, hour: int, minute: int) -> void:
	hud.update_clock(time_str)
	var now = hour * 60 + minute
	_update_phase(now)

	# Drone patrols 15:00 - 18:00 (PRD §6.2), staggered launches for multiple drones
	while drones_launched < plot_cfg.drone_count and now >= DRONE_LAUNCH_MINUTE + drones_launched * DRONE_STAGGER_MINUTES and now < DRONE_RETURN_MINUTE:
		drones[drones_launched].start_patrol()
		drones_launched += 1
		var which = "" if plot_cfg.drone_count == 1 else " ลำที่ %d" % drones_launched
		hud.show_drone_alert("โดรนป่าไม้%s ขึ้นบินแล้ว — หลบใต้ร่มไผ่ หรือดับเปลวไฟที่สูง!" % which, false)

	# Drones return as the light goes
	if now >= DRONE_RETURN_MINUTE:
		var any_returned = false
		for d in drones:
			if d.is_active_patrol:
				d.end_patrol()
				any_returned = true
		if any_returned:
			hud.show_drone_alert("โดรนบินกลับฐาน — แสงน้อยจนกล้องถ่ายไม่ชัด", false)

	# 18:00 Atmospheric Inversion
	if not inversion_started and now >= INVERSION_MINUTE:
		inversion_started = true
		fire_grid.set_inversion_active(true)
		hud.trigger_inversion_visual(5.0)
		hud.show_alert("18:00 พระอาทิตย์ตก — อากาศผกผันกดควันไว้ติดพื้น ระวังลมหายใจ!", 6.0)

	# Siren and a beep each minute through the final countdown
	if now >= COUNTDOWN_MINUTE and now < PASS_MINUTE and AudioManager.instance:
		AudioManager.instance.set_siren(true)
		AudioManager.instance.play_countdown_beep()

func _update_phase(now: int) -> void:
	var idx = 0
	for i in PHASES.size():
		if now >= PHASES[i].start:
			idx = i
	if idx == current_phase:
		return
	current_phase = idx
	var goal: String = PHASES[idx].goal
	if goal.contains("%d"):
		goal = goal % roundi(rules.satellite_threshold)
	hud.update_phase(PHASES[idx].title, goal)
	if idx > 0:
		hud.show_alert(PHASES[idx].title + "\n" + goal, 4.0)
	if AudioManager.instance:
		AudioManager.instance.set_music_intensity(idx)

func _on_drone_spotted(_world_pos: Vector3, is_flame: bool) -> void:
	var penalty = _penalty(20.0 if is_flame else 15.0)
	_add_scrutiny(penalty)

	var msg = "แฟลชโดรน! ถ่ายภาพเปลวไฟได้ · ความเพ่งเล็ง +%d" % penalty if is_flame else "แฟลชโดรน! ถ่ายภาพทีมกลางที่โล่งได้ · ความเพ่งเล็ง +%d" % penalty
	hud.show_drone_alert(msg, true)
	if AudioManager.instance:
		AudioManager.instance.play_camera_alarm()

func _on_camera_heat(_cam: ThermalCamera, _world_pos: Vector3) -> void:
	var penalty = _penalty(CAMERA_BASE_PENALTY)
	_add_scrutiny(penalty)
	hud.show_drone_alert("กล้องความร้อนที่แนวเขตอุทยานจับได้! · ความเพ่งเล็ง +%d" % penalty, true)
	if AudioManager.instance:
		AudioManager.instance.play_camera_alarm()

func _on_wind_shift_warning(new_dir: Vector2, new_speed: float, _time_left: float) -> void:
	hud.show_elder_wind_warning(new_dir, new_speed)
	if AudioManager.instance:
		AudioManager.instance.play_tapoh_warning()

func _on_wind_shifted(direction: Vector2, speed: float) -> void:
	hud.update_wind(direction, speed)
	hud.show_alert("ลมเปลี่ยนทิศแล้ว! ตรวจแนวกันไฟรอบแปลงอีกครั้ง", 3.0)
	if AudioManager.instance:
		AudioManager.instance.play_wind_gust()

func _on_bamboo_exploded(_coord: Vector2i, _world_pos: Vector3, _landing: Vector2i) -> void:
	if AudioManager.instance:
		AudioManager.instance.play_bamboo_pop()
	hud.show_alert("ปล้องไผ่ระเบิด! แรงไอน้ำดีดลูกไฟไปตามลม", 3.5)

func _on_ember_jumped(_from: Vector2i, _landing: Vector2i) -> void:
	if _ember_alert_cooldown > 0.0:
		return
	_ember_alert_cooldown = 8.0
	hud.show_alert("ลมแรง — ลูกไฟกระโดดข้ามแนวกันไฟ!", 3.0)
	if AudioManager.instance:
		AudioManager.instance.play_ember_jump()

func _on_satellite_closing(mins_remaining: int) -> void:
	if mins_remaining % 10 == 0 or mins_remaining <= 5:
		hud.show_alert("อีก %d นาที ดาวเทียม VIIRS จะโคจรผ่าน!" % mins_remaining, 3.0)

func _on_satellite_pass() -> void:
	pass_started = true
	# 20:00 is final: freeze the hillside so nothing changes under the report
	game_clock.pause_clock()
	fire_grid.simulation_paused = true
	wind_manager.set_process(false)
	player.set_input_enabled(false)
	elder.set_physics_process(false)
	youth.set_physics_process(false)
	for d in drones:
		if d.is_active_patrol:
			d.end_patrol()
	for cam in thermal_cameras:
		cam.set_active(false)

	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
		AudioManager.instance.play_satellite_ping()
	world_environment.environment.fog_enabled = false
	world_environment.environment.glow_enabled = false
	hud.update_phase("ระยะ 5 · ดาวเทียมโคจรผ่าน (20:00)", "VIIRS กำลังสแกนความร้อนทั้งแปลง")
	hud.show_satellite_sweep_ui(rules.satellite_threshold)
	satellite.trigger_orbital_pass()

func _on_satellite_sweep_completed(detected_hotspots: int, scrutiny_increase: int) -> void:
	plot_scrutiny_gain += scrutiny_increase

	# Commit this burn to the campaign once, then report the resulting state
	var state = GameState.instance
	state.log_hotspots(satellite.detected_cells, satellite.detected_heat)
	state.record_plot_results(latest_rice_yield, detected_hotspots, escaped_to_forest, plot_scrutiny_gain)
	hud.update_scrutiny(state.state_scrutiny)
	hud.show_resolution_report(latest_rice_yield, detected_hotspots, escaped_to_forest, state, rules.hotspot_penalty, _gis_lines(state))

## GISTDA-style hotspot log lines for this plot's detections
func _gis_lines(state: Node) -> PackedStringArray:
	var lines = PackedStringArray()
	var shown = 0
	for entry in state.hotspot_log:
		if entry.year != state.current_year or entry.plot != state.current_plot_index:
			continue
		shown += 1
		if shown <= 6:
			lines.append("#%02d  %.5f°N  %.5f°E  %d TU" % [shown, entry.lat, entry.lon, roundi(entry.heat)])
	if shown > 6:
		lines.append("... และอีก %d จุด" % (shown - 6))
	return lines

func _on_rice_yield_changed(new_yield: float) -> void:
	latest_rice_yield = new_yield
	hud.update_rice_yield(new_yield)

func _on_hotspot_count_changed(count: int) -> void:
	hud.update_hotspots(count)
	_last_burning_count = fire_grid.active_burning_indices.size()

func _on_forest_escape() -> void:
	escaped_to_forest = true
	var penalty = _penalty(ESCAPE_BASE_PENALTY * park_strictness)
	_add_scrutiny(penalty)
	hud.show_alert("อันตราย! ไฟลามเข้าป่าอนุรักษ์แล้ว · ความเพ่งเล็ง +%d" % penalty, 6.0)

func _on_tool_changed(tool_name: String) -> void:
	hud.update_tool(tool_name)

func _on_tank_empty() -> void:
	hud.show_alert("น้ำในถังพ่นหมด! ไปเติมที่ถังน้ำข้างเถียงนา", 3.0)

func _on_companion_coughing(who: CompanionController) -> void:
	if AudioManager.instance:
		AudioManager.instance.play_cough()
	hud.show_alert("%s สำลักควัน! เป่านกหวีดเรียกกลับมา" % who.display_name(), 3.0)

func _on_stamina_changed(curr: float, max_val: float) -> void:
	latest_stamina = curr
	latest_max_stamina = max_val
	hud.update_stamina(latest_stamina, max_val, latest_smoke)

func _on_smoke_exposure_changed(exposure: float) -> void:
	latest_smoke = exposure
	hud.update_stamina(latest_stamina, latest_max_stamina, latest_smoke)

func _on_whistle_blown() -> void:
	if AudioManager.instance:
		AudioManager.instance.play_whistle()
	elder.rally_to_player()
	youth.rally_to_player()
	hud.show_alert("เป่านกหวีด — เรียกทีมมารวมที่ตัวเรา!", 2.5)

func _on_order_pinged(coord: Vector2i, world_pos: Vector3) -> void:
	var idx = fire_grid._coord_to_index(coord.x, coord.y)
	var type = fire_grid.cell_types[idx]

	if type == FireGrid.CellType.VEGETATION or type == FireGrid.CellType.BAMBOO:
		elder.receive_ping_order(coord, world_pos)
		hud.show_alert("ส่งตาโพไปถางแนวกันไฟ", 2.0)
	elif type == FireGrid.CellType.SMOLDERING or type == FireGrid.CellType.BURNING:
		youth.receive_ping_order(coord, world_pos)
		hud.show_alert("ส่งมูนอไปดับจุดความร้อน", 2.0)
