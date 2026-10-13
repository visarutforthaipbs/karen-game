extends SceneTree
## Store screenshot candidates from production scenes; isolated saves, staged
## game state. These are Mac/Mobile-renderer captures, not iPhone/iPad QA proof.
var output: String
var vp: SubViewport
var active: Node
var holder: Node

func _initialize() -> void:
	call_deferred("run")

func frames(n: int = 12) -> void:
	for i in n:
		await process_frame

func clear_scene() -> void:
	var overlay = vp.get_node_or_null("TouchControls")
	if overlay:
		overlay.queue_free()
	if is_instance_valid(active):
		active.queue_free()
	await frames(5)

func snap(name: String) -> void:
	if paused and active.has_method("_on_clock_ticked"):
		active.hud.pause_menu.resume()
	if active.has_method("_on_clock_ticked"):
		active.hud.set_process(false)
		for panel in active.hud._fade_targets:
			panel.modulate.a = active.hud.PANEL_ALPHA
	await frames(15)
	await RenderingServer.frame_post_draw
	var img = vp.get_texture().get_image()
	var err = img.save_png(output.path_join(name + ".png"))
	print("CAPTURE ", name, " ", img.get_size(), " error=", err)

func run() -> void:
	var args = OS.get_cmdline_user_args()
	output = args[0]
	var device = args[1]
	var locale = args[2]
	DirAccess.make_dir_recursive_absolute(output)
	var scratch = output.path_join("fixture")
	DirAccess.make_dir_recursive_absolute(scratch)
	SaveGame.dir = scratch
	GameSettings.dir = scratch
	PlaytestLog.dir = scratch
	GameSettings.load_settings()
	GameSettings.ui_scale = 1.0
	GameSettings.online_board = false
	GameSettings.first_burn_tips = false
	GameSettings.intro_seen = true
	GameSettings.locale = locale
	root.get_node("Localization").set_language(locale)
	root.size = Vector2i(1280, 960) if device == "ipad13" else Vector2i(1560, 720)
	root.content_scale_size = root.size
	var state = root.get_node("GameState")
	state.reset_campaign()
	state.seen_how_to_play = true
	vp = SubViewport.new()
	vp.size = Vector2i(2752, 2064) if device == "ipad13" else Vector2i(2556, 1179)
	vp.size_2d_override = root.size
	vp.size_2d_override_stretch = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	holder = Node.new()
	root.add_child(holder)
	current_scene = holder
	holder.add_child(vp)
	active = load("res://scenes/Main.tscn").instantiate()
	vp.add_child(active)
	await frames(25)
	var overlay = holder.get_node_or_null("TouchControls")
	if overlay:
		overlay.reparent(vp)
	if paused:
		active.hud.pause_menu.resume()
	active.game_clock.is_running = false
	active.set_process(false)
	active.cam_rig.set_process(false)
	active.cam_rig.distance = active.cam_rig.zoom_max
	active.cam_rig._apply(true)
	await snap("01_plot")
	active.game_clock.current_sim_time_seconds = 16 * 3600 + 20 * 60
	active._on_clock_ticked("16:20", 16, 20)
	active.sky.apply_time(16.3333)
	for y in range(26, 32):
		for x in range(26, 32):
			active.fire_grid.ignite_cell(x, y)
	active.cam_rig.focus = active.fire_grid.get_cell_world_pos(28, 28)
	active.cam_rig.distance = active.cam_rig.ZOOM_DEFAULT
	active.cam_rig._apply(true)
	await frames(90)
	await snap("02_fire")
	active.game_clock.current_sim_time_seconds = 19 * 3600 + 23 * 60
	active._on_clock_ticked("19:23", 19, 23)
	active.sky.inversion_strength = 1.0
	active.sky.view_distance = active.cam_rig.zoom_max
	active.sky.apply_time(19.38333)
	active.cam_rig.distance = active.cam_rig.zoom_max
	active.cam_rig._apply(true)
	await snap("03_dusk")
	await clear_scene()
	state.reset_campaign()
	state.seen_how_to_play = true
	active = load("res://scenes/VillageHearth.tscn").instantiate()
	vp.add_child(active)
	await snap("04_village")
	await clear_scene()
	active = load("res://ui/HowToPlay.gd").new()
	vp.add_child(active)
	await snap("05_guide")
	await clear_scene()
	root.get_node("AudioManager").stop_all_loops()
	holder.queue_free()
	await frames(8)
	quit()
