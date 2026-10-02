class_name TitleScreen
extends Control

## Title screen (P0-1): the game boots here. A live dusk view of the hillside
## (the real burn plot and Landscape) slowly orbits behind the menu while a
## satellite crosses the sky. Continue / new game / how to play / settings / quit.

const HEARTH_SCENE = "res://scenes/VillageHearth.tscn"

var continue_button: Button
var new_button: Button
var notice_label: Label
var record_label: Label
var _menu: VBoxContainer
var _camera: Camera3D
var _orbit: float = 0.6
var _overlay: Control

func _ready() -> void:
	theme = UITheme.get_theme()
	GameSettings.apply(get_tree())
	_build_backdrop()
	_build_menu()
	if AudioManager.instance:
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
	# A slow line of fire along the bottom of the plot, as at 16:00 on a burn day
	for x in range(8, 30):
		if randf() < 0.6:
			grid.ignite_cell(x, 33)
	var land = Landscape.new()
	land.fire_grid = grid
	land.world_environment = we
	vp.add_child(land)

	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.far = 4000.0
	vp.add_child(_camera)
	_place_camera()

	var streak = SatelliteStreak.new()
	streak.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(streak)

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

func _place_camera() -> void:
	var r = 95.0
	_camera.position = Vector3(cos(_orbit) * r, 46.0, sin(_orbit) * r)
	_camera.look_at(Vector3(0, 2, -6), Vector3.UP)

func _process(delta: float) -> void:
	if _camera:
		_orbit += delta * 0.025
		_place_camera()

# ---------------------------------------------------------------------------
# Menu
# ---------------------------------------------------------------------------

func _build_menu() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 64)
	margin.add_theme_constant_override("margin_bottom", 48)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var col = UITheme.vbox(10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.custom_minimum_size = Vector2(440, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	margin.add_child(col)

	var title = UITheme.outlined(UITheme.label("เงาเมฆา", "Title", UITheme.STRAW), 8)
	title.add_theme_font_override("font", UITheme.font("bold"))
	title.add_theme_font_size_override("font_size", 84)
	col.add_child(title)
	var sub = UITheme.outlined(UITheme.label("SATELLITE SHADOW · ไร่หมุนเวียนใต้เงาดาวเทียม", "Kicker", UITheme.CREAM), 4)
	sub.add_theme_font_size_override("font_size", 16)
	col.add_child(sub)
	var lead = UITheme.wrap(UITheme.outlined(UITheme.label("เผาไร่ให้เป็นเถ้าระหว่าง 14:00–20:00 แล้วดับถ่านให้หมด ก่อนดาวเทียมโคจรผ่าน", "Body", UITheme.CREAM), 4))
	lead.custom_minimum_size = Vector2(440, 0)
	col.add_child(lead)

	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	col.add_child(gap)

	_menu = UITheme.vbox(10)
	col.add_child(_menu)
	continue_button = _menu_button("เล่นต่อ", _on_continue, "PrimaryButton")
	continue_button.visible = SaveGame.exists()
	new_button = _menu_button("เริ่มเกมใหม่", _on_new_game, "Button" if SaveGame.exists() else "PrimaryButton")
	_menu_button("วิธีเล่น", _on_how_to_play)
	_menu_button("ตั้งค่า", _on_settings)
	_menu_button("ออกจากเกม", func(): get_tree().quit())

	notice_label = UITheme.wrap(UITheme.outlined(UITheme.label("", "Small", UITheme.EMBER), 4))
	notice_label.custom_minimum_size = Vector2(440, 0)
	col.add_child(notice_label)
	record_label = UITheme.outlined(UITheme.label(_record_text(), "Small", UITheme.MUTED), 4)
	col.add_child(record_label)

	(continue_button if continue_button.visible else new_button).grab_focus()

func _menu_button(text: String, action: Callable, variation: String = "Button") -> Button:
	var b = Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(340, 48)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(action)
	b.focus_entered.connect(func():
		if AudioManager.instance and AudioManager.instance.has_method("play_ui_focus"):
			AudioManager.instance.play_ui_focus())
	_menu.add_child(b)
	return b

func _record_text() -> String:
	var best = SaveGame.best_record()
	if best.is_empty():
		return ""
	return "สถิติดีที่สุด: รอด %d แปลง (ถึงปีที่ %d) · เถ้าเฉลี่ย %.0f%%" % [int(best.plots_completed), int(best.year), float(best.avg_ash)]

func _on_continue() -> void:
	var why = SaveGame.load_into(GameState.instance)
	if why != "":
		notice_label.text = "โหลดเกมที่บันทึกไว้ไม่ได้ (%s) · เริ่มเกมใหม่แทนได้" % ("ไฟล์เสียหาย" if why == "corrupt" else "เวอร์ชันเก่า" if why == "version" else "ไม่พบไฟล์")
		continue_button.visible = false
		new_button.grab_focus()
		return
	_go_to_hearth()

func _on_new_game() -> void:
	if SaveGame.exists() and _overlay == null:
		_confirm("เริ่มเกมใหม่จะลบเกมที่บันทึกไว้ ยืนยันไหม?", _start_new_campaign)
		return
	_start_new_campaign()

func _start_new_campaign() -> void:
	GameState.instance.reset_campaign()
	GameState.instance.seen_how_to_play = false
	SaveGame.delete()
	_go_to_hearth()

func _go_to_hearth() -> void:
	if AudioManager.instance:
		AudioManager.instance.stop_all_loops()
	get_tree().change_scene_to_file(HEARTH_SCENE)

func _on_how_to_play() -> void:
	var h = HowToPlay.new()
	h.closed.connect(func(): _menu.get_child(0 if continue_button.visible else 1).grab_focus())
	add_child(h)

func _on_settings() -> void:
	var s = SettingsPanel.new()
	s.closed.connect(func(): _menu.get_child(0 if continue_button.visible else 1).grab_focus())
	s.how_to_play_requested.connect(func():
		s.close()
		_on_how_to_play())
	add_child(s)

func _confirm(question: String, on_yes: Callable) -> void:
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
	yes.theme_type_variation = "PrimaryButton"
	yes.pressed.connect(func():
		_overlay.queue_free()
		_overlay = null
		on_yes.call())
	row.add_child(yes)
	var no = Button.new()
	no.text = "ยกเลิก"
	no.pressed.connect(func():
		_overlay.queue_free()
		_overlay = null
		new_button.grab_focus())
	row.add_child(no)
	no.grab_focus()
