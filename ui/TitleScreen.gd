class_name TitleScreen
extends Control

## Title screen (P0-1): the game boots here. A live dusk view of the hillside
## (the real burn plot and Landscape) slowly orbits behind the menu while a
## satellite crosses the sky. Continue / new game / how to play / settings / quit.

const HEARTH_SCENE = "res://scenes/VillageHearth.tscn"

var continue_button: Button
var new_button: Button
var notice_label: Label
var board: VBoxContainer
var _menu: VBoxContainer
var menu_scroll: ScrollContainer
var quit_button: Button
var _camera: Camera3D
var _orbit: float = 0.6
# The satellite pass: big, low and slow, its shadow sweeping the plot (V3)
const PASS_SECONDS: float = 10.0
const PASS_CYCLE: float = 16.0
const SAT_ALTITUDE: float = 22.0
const SAT_SCALE: float = 1.3       # Swath and footprint size
const MODEL_SCALE: float = 1.7     # The satellite itself, staged huge
# Fixed title framing: the plot sits right of the menu, the satellite crosses the
# frame left to right over the fire line, so the sweep reveals white-hot heat
const CAM_POS = Vector3(58.0, 26.0, 46.0)
const PLOT_FOCUS = Vector3(4.0, 7.0, 12.0)
const PASS_CENTER = Vector3(4.0, 0.0, 20.0)
var _pass_from: Vector3
var _pass_to: Vector3
var _grid: FireGrid
var _satellite: Node3D
var _shadow: Decal
var _strobe: OmniLight3D
var _pass_t: float = 2.0
var _logo: TitleLogo
var _scan_tick: float = 0.0
var _pinged: bool = false
var _was_scanning: bool = false
var _overlay: Control
var _overlay_scope: ModalFocusScope
var _confirmation_open: bool = false

func _ready() -> void:
	theme = UITheme.get_theme()
	GameSettings.apply(get_tree())
	_build_backdrop()
	_build_menu()
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
		AudioManager.instance.play_hearth_music(true)

# ---------------------------------------------------------------------------
# Live backdrop
# ---------------------------------------------------------------------------

func _build_backdrop() -> void:
	var container = SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	var vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	container.add_child(vp)

	var env = Environment.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.14, 0.3)
	sky_mat.sky_horizon_color = Color(0.85, 0.5, 0.32)
	sky_mat.ground_horizon_color = Color(0.5, 0.36, 0.3)
	sky_mat.ground_bottom_color = Color(0.1, 0.12, 0.12)
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.52, 0.38)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.4
	var we = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, -70, 0)
	sun.light_color = Color(1.0, 0.66, 0.4)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	vp.add_child(sun)

	var grid = FireGrid.new()
	vp.add_child(grid)
	grid.simulation_paused = true
	grid.configure_plot(PlotGenerator.get_plot_config(1, 1))
	# 16:00 on a burn day: a fire line along the bottom, embers and ash behind it.
	# The satellite's footprint shows them in thermal colours as it passes.
	for x in range(5, 35):
		if randf() < 0.7:
			grid.ignite_cell(x, 31)
		for y in range(32, 36):
			var i = grid._coord_to_index(x, y)
			if grid.cell_types[i] == FireGrid.CellType.VEGETATION or grid.cell_types[i] == FireGrid.CellType.BAMBOO:
				grid.cell_types[i] = FireGrid.CellType.SMOLDERING if y < 34 or randf() < 0.3 else FireGrid.CellType.ASH
				grid.cell_heat[i] = 44.0 if grid.cell_types[i] == FireGrid.CellType.SMOLDERING else 10.0
	grid._update_visuals()
	_grid = grid
	var land = Landscape.new()
	land.fire_grid = grid
	land.world_environment = we
	vp.add_child(land)

	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.far = 4000.0
	vp.add_child(_camera)
	_place_camera()

	_build_satellite(vp)

	# Darken the left side so the menu reads over the scene
	var shade = TextureRect.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(0.03, 0.04, 0.07, 0.86))
	grad.set_color(1, Color(0.03, 0.04, 0.07, 0.0))
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.0, 0.5)
	tex.fill_to = Vector2(0.62, 0.5)
	shade.texture = tex
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

func _build_satellite(vp: SubViewport) -> void:
	# Cross the frame along the camera's right vector, through the fire line
	var right = _camera.global_basis.x
	var dir = Vector3(right.x, 0.0, right.z).normalized()
	_pass_from = PASS_CENTER - dir * 85.0
	_pass_to = PASS_CENTER + dir * 85.0
	_satellite = Node3D.new()
	vp.add_child(_satellite)
	var body = MeshInstance3D.new()
	body.mesh = SatelliteModel.mesh()
	body.scale = Vector3.ONE * MODEL_SCALE * SatelliteModel.fit_scale(body.mesh)
	# Wings along the flight path so the full span reads as it crosses the frame
	body.rotation.y = PI * 0.5
	# Tip the flat solar wings toward the camera so they read as panels, not lines
	body.rotate_object_local(Vector3.RIGHT, 0.55)
	# Centre on the mesh's bounds, so a ground-centred pipeline V3 flies like the placeholder
	body.position = -(body.transform.basis * body.mesh.get_aabb().get_center())
	_satellite.add_child(body)
	# Cool fill from the camera side, on its own render layer: the warm backlit haze
	# otherwise flattens the gold foil and blue panels to one brown silhouette
	body.layers = 2
	var fill = DirectionalLight3D.new()
	fill.light_cull_mask = 2
	fill.light_color = Color(0.85, 0.9, 1.0)
	fill.light_energy = 1.4
	vp.add_child(fill)
	fill.look_at_from_position(CAM_POS, PASS_CENTER + Vector3(0, SAT_ALTITUDE + 4.0, 0), Vector3.UP)
	_strobe = OmniLight3D.new()
	_strobe.light_color = Color(1.0, 0.2, 0.15)
	_strobe.omni_range = 6.0
	_strobe.position = Vector3(0, 1.6, -2.0)
	_satellite.add_child(_strobe)

	# VIIRS swath: a faint cold sheet from the scanner down to the ground
	var half_w = 12.0 * SAT_SCALE
	var top = Vector3(0, -2.2 * MODEL_SCALE, 0.0)
	var bottom_y = -SAT_ALTITUDE - 2.0
	var verts = PackedVector3Array([
		top + Vector3(-0.4, 0, 0), top + Vector3(0.4, 0, 0), Vector3(half_w, bottom_y, 0.0),
		top + Vector3(-0.4, 0, 0), Vector3(half_w, bottom_y, 0.0), Vector3(-half_w, bottom_y, 0.0),
	])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var swath = ArrayMesh.new()
	swath.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var swath_mat = StandardMaterial3D.new()
	swath_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	swath_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	swath_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	swath_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	swath_mat.albedo_color = Color(0.45, 0.85, 1.0, 0.08)
	swath.surface_set_material(0, swath_mat)
	var swath_node = MeshInstance3D.new()
	swath_node.mesh = swath
	swath_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_satellite.add_child(swath_node)

	# The satellite's shadow: a crisp cold silhouette projected onto the hillside
	_shadow = Decal.new()
	_shadow.texture_albedo = SatelliteModel.shadow_texture()
	_shadow.modulate = Color(0.01, 0.03, 0.1, 0.88)
	_shadow.size = Vector3(18.0 * MODEL_SCALE, 40.0, 4.6 * MODEL_SCALE)
	_shadow.upper_fade = 0.05
	_shadow.lower_fade = 0.05
	vp.add_child(_shadow)
	_update_satellite(0.0)

func _update_satellite(delta: float) -> void:
	_pass_t = fmod(_pass_t + delta, PASS_CYCLE)
	if _logo:
		_logo.phase = _pass_t / PASS_CYCLE # The title's own satellite glides with the pass
	var u = _pass_t / PASS_SECONDS
	var flying = u <= 1.0
	_satellite.visible = flying
	_shadow.visible = flying
	var dir = (_pass_to - _pass_from).normalized()
	var yaw = atan2(dir.x, dir.z)
	var ground = _pass_from.lerp(_pass_to, clampf(u, 0.0, 1.0))
	_satellite.position = ground + Vector3(0, SAT_ALTITUDE + 4.0, 0)
	_satellite.rotation = Vector3(0, yaw, sin(_pass_t * 0.6) * 0.03)
	_shadow.position = ground + Vector3(0, 4.0, 0)
	_shadow.rotation = Vector3(0, yaw + PI * 0.5, 0) # Matches the turned model
	_strobe.light_energy = 3.0 if fmod(_pass_t, 1.2) < 0.12 else 0.0

	# Where the shadow falls, the state sees: the plot shows its heat
	var over_plot = flying and Vector2(ground.x, ground.z).length() < 46.0
	_grid.scan_active = over_plot
	_grid.scan_center = Vector2(ground.x, ground.z)
	# The VIIRS swath is wider than the silhouette: heat shows around the shadow
	_grid.scan_half = Vector2(12.0, 6.5) * SAT_SCALE
	_grid.scan_heading = yaw
	_scan_tick += delta
	if (over_plot and _scan_tick >= 0.05) or (_was_scanning and not over_plot):
		_scan_tick = 0.0
		_grid._update_visuals()
	_was_scanning = over_plot
	if over_plot and not _pinged and Vector2(ground.x, ground.z).length() < 30.0:
		_pinged = true
		if AudioManager.instance and AudioManager.instance.has_method("play_satellite_ping"):
			AudioManager.instance.play_satellite_ping()
	if not flying:
		_pinged = false

func _place_camera() -> void:
	# Low and close enough that the satellite passes huge overhead; a gentle
	# drift keeps the shot alive. Aim left of the plot so it sits right of the menu.
	var drift = Vector3(sin(_orbit * 0.7) * 2.5, sin(_orbit * 0.5) * 0.8, cos(_orbit * 0.6) * 2.0)
	_camera.position = CAM_POS + drift
	var to_cam = (CAM_POS - PLOT_FOCUS)
	var left = Vector3(-to_cam.z, 0.0, to_cam.x).normalized() * 16.0
	_camera.look_at(PLOT_FOCUS + left, Vector3.UP)

func _process(delta: float) -> void:
	if _camera:
		_orbit += delta * 0.3
		_place_camera()
	if _satellite:
		_update_satellite(delta)

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------

func _build_menu() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	menu_scroll.follow_focus = true
	menu_scroll.custom_minimum_size.x = minf(780.0, get_viewport().get_visible_rect().size.x - 100.0)
	menu_scroll.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(menu_scroll)
	var compact_menu = get_viewport().get_visible_rect().size.y < 680.0
	var col = UITheme.vbox(8 if compact_menu else 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(440, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu_scroll.add_child(col)

	_logo = TitleLogo.new()
	_logo.size_px = 40.0 if compact_menu else 66.0
	col.add_child(_logo)
	var logo_gap = Control.new()
	logo_gap.custom_minimum_size = Vector2(0, 0)
	col.add_child(logo_gap)
	var lead = UITheme.wrap(UITheme.outlined(UITheme.label("เผาไร่ให้เป็นเถ้าระหว่าง 14:00–20:00 แล้วดับถ่านให้หมด ก่อนดาวเทียมโคจรผ่าน", "Body", UITheme.CREAM), 4))
	lead.custom_minimum_size = Vector2(560, 0)
	col.add_child(lead)

	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	col.add_child(gap)

	_menu = UITheme.vbox(6 if compact_menu else 10)
	col.add_child(_menu)
	continue_button = _menu_button("เล่นต่อ", _on_continue, "PrimaryButton")
	continue_button.visible = SaveGame.exists()
	new_button = _menu_button("เริ่มเกมใหม่", _on_new_game, "Button" if SaveGame.exists() else "PrimaryButton")
	_menu_button("วิธีเล่น", _on_how_to_play)
	_menu_button("ตั้งค่า / Settings", _on_settings)
	quit_button = _menu_button("ออกจากเกม", func(): InputBindings.request_exit())

	notice_label = UITheme.wrap(UITheme.outlined(UITheme.label("", "Small", UITheme.EMBER), 4))
	notice_label.custom_minimum_size = Vector2(440, 0)
	notice_label.visible = false
	col.add_child(notice_label)
	# Village board (top 5) sits in the bottom-right corner, out of the menu column
	board = UITheme.vbox(2)
	add_child(board)
	_fill_board()
	if OnlineBoard.enabled():
		OnlineBoard.fetch_top(self, 5, _fill_online_board)
	board.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	board.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	board.grow_vertical = Control.GROW_DIRECTION_BEGIN
	board.offset_right = -24.0
	board.offset_bottom = -16.0

	(continue_button if continue_button.visible else new_button).grab_focus()

func _menu_button(text: String, action: Callable, variation: String = "Button") -> Button:
	var b = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(340, 44 if get_viewport().get_visible_rect().size.y < 680.0 else 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(action)
	_menu.add_child(b)
	return b

## Header plus one line per run for the top 5; an empty board shows nothing
func _fill_board() -> void:
	var rows = SaveGame.runs()
	if rows.is_empty():
		return
	var head = UITheme.outlined(UITheme.label("กระดานเกียรติยศหมู่บ้าน", "Kicker", UITheme.MUTED), 4)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board.add_child(head)
	for i in mini(5, rows.size()):
		var r = rows[i]
		var line = UITheme.outlined(UITheme.label(L10n.format("%d. %s · %d แปลง · ปีที่ %d · เถ้า %.0f%%", [i + 1, r.name, int(r.plots), int(r.year), float(r.avg_ash)], false), "Small", UITheme.MUTED), 4)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		board.add_child(line)

## Appends the opt-in online top 5 under the local board (async, silent on failure)
func _fill_online_board(rows: Array) -> void:
	if not is_instance_valid(board) or rows.is_empty():
		return
	var head = UITheme.outlined(UITheme.label("กระดานออนไลน์ (เบตา)", "Kicker", UITheme.MUTED), 4)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	board.add_child(head)
	for r in rows.slice(0, 5):
		if not (r is Dictionary):
			continue
		var line = UITheme.outlined(UITheme.label(L10n.format("%d. %s · %d แปลง · ปีที่ %d · เถ้า %.0f%%", [int(r.get("rank", 0)), SaveGame.sanitize_name(r.get("name", "")), int(r.get("plots", 0)), int(r.get("year", 0)), float(r.get("avg_ash", 0))], false), "Small", UITheme.MUTED), 4)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		board.add_child(line)

func _on_continue() -> void:
	if is_instance_valid(_overlay):
		return
	var why = SaveGame.load_into(GameState.instance)
	if why != "":
		notice_label.show()
		notice_label.text = L10n.format("โหลดเกมที่บันทึกไว้ไม่ได้ (%s) · เริ่มเกมใหม่แทนได้", ("ไฟล์เสียหาย" if why == "corrupt" else "เวอร์ชันเก่า" if why == "version" else "ไม่พบไฟล์"))
		continue_button.visible = false
		new_button.grab_focus()
		return
	_go_to_hearth()

func _on_new_game() -> void:
	if is_instance_valid(_overlay):
		return
	if SaveGame.exists():
		_confirm("เริ่มเกมใหม่จะลบเกมที่บันทึกไว้ ยืนยันไหม?", _start_new_campaign)
		return
	_start_new_campaign()

func _start_new_campaign() -> void:
	GameState.instance.reset_campaign()
	# Context film + contextual first-burn tips replace the automatic dense guide.
	# The complete manual remains available from Help, even after skipping.
	GameState.instance.seen_how_to_play = true
	SaveGame.delete()
	GameSettings.ensure_loaded()
	if not GameSettings.intro_seen:
		var opening = OpeningFilm.new()
		opening.remember_completion = true
		_overlay = opening
		opening.closed.connect(func():
			_overlay = null
			_go_to_hearth())
		add_child(opening)
		return
	_go_to_hearth()

func _go_to_hearth() -> void:
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
	get_tree().change_scene_to_file(HEARTH_SCENE)

func _on_how_to_play() -> void:
	if is_instance_valid(_overlay):
		return
	var h = HowToPlay.new()
	_overlay = h
	h.closed.connect(func(): _overlay = null)
	add_child(h)

func _on_settings() -> void:
	if is_instance_valid(_overlay):
		return
	var s = SettingsPanel.new()
	_overlay = s
	s.closed.connect(func(): _overlay = null)
	s.how_to_play_requested.connect(func():
		s.close()
		_on_how_to_play())
	add_child(s)

func _confirm(question: String, on_yes: Callable) -> void:
	if is_instance_valid(_overlay):
		return
	_confirmation_open = true
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.7)
	_overlay.add_child(dim)
	var card = UITheme.card(Color(UITheme.PANEL, 0.98), UITheme.EMBER, 520)
	card.padding = Vector4(26, 20, 26, 22)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(520, 0)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_overlay.add_child(card)
	var box = UITheme.vbox(14)
	card.add_child(box)
	box.add_child(UITheme.wrap(UITheme.label(question, "Title")))
	var row = UITheme.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var yes = Button.new()
	yes.text = "ยืนยัน เริ่มใหม่"
	yes.pressed.connect(func():
		_dismiss_confirmation()
		on_yes.call())
	var no = Button.new()
	no.text = "ยกเลิก"
	no.theme_type_variation = "PrimaryButton"
	no.pressed.connect(func():
		_dismiss_confirmation())
	row.add_child(no)
	row.add_child(yes)
	_overlay_scope = ModalFocusScope.begin(_overlay)
	no.grab_focus()

func _dismiss_confirmation() -> void:
	if _overlay_scope:
		_overlay_scope.release()
		_overlay_scope = null
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_confirmation_open = false

func _unhandled_input(event: InputEvent) -> void:
	if _confirmation_open and event.is_action_pressed("ui_cancel"):
		_dismiss_confirmation()
		get_viewport().set_input_as_handled()
