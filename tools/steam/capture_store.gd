extends SceneTree
## Real production scenes at native 1080p, deterministic review states.
## Isolated saves; no images are retouched and no footage is claimed as playtest.
var output: String
var vp: SubViewport
func _initialize() -> void:
	call_deferred("run")
func snap(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(output.path_join(name + ".png"))
func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	SaveGame.dir = output.path_join("capture_save")
	GameSettings.dir = SaveGame.dir
	PlaytestLog.dir = SaveGame.dir
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	root.get_node("GameState").reset_campaign()
	vp = SubViewport.new()
	vp.size = Vector2i(1920,1080)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var game = load("res://scenes/Main.tscn").instantiate()
	vp.add_child(game)
	for i in 15: await process_frame
	game.game_clock.is_running = false
	game.set_process(false)
	game.cam_rig.set_process(false)
	game.cam_rig.focus = game.player.global_position
	game.cam_rig.distance = game.cam_rig.ZOOM_DEFAULT
	game.cam_rig._apply(true)
	await snap("01_preparation")
	game.cam_rig.distance = game.cam_rig.zoom_max
	game.cam_rig._apply(true)
	await snap("02_plot_overview")
	game.game_clock.current_sim_time_seconds = 16 * 3600 + 20 * 60
	game._on_clock_ticked("16:20",16,20)
	var center := Vector2i(30,30)
	for y in range(27,33):
		for x in range(27,33): game.fire_grid.ignite_cell(x,y)
	game.cam_rig.focus = game.fire_grid.get_cell_world_pos(center.x,center.y)
	game.cam_rig.distance = game.cam_rig.ZOOM_DEFAULT
	game.cam_rig._apply(true)
	for i in 120: await process_frame
	await snap("03_controlled_burn")
	game.game_clock.current_sim_time_seconds = 19 * 3600 + 45 * 60
	game._on_clock_ticked("19:45",19,45)
	game.fire_grid.set_thermal_view(true, game.rules.satellite_threshold)
	await snap("04_thermal_view")
	game.queue_free()
	for i in 8: await process_frame
	root.get_node("GameState").reset_campaign()
	root.get_node("GameState").seen_how_to_play = true
	var hearth = load("res://scenes/VillageHearth.tscn").instantiate()
	vp.add_child(hearth)
	await snap("05_village")
	root.get_node("AudioManager").stop_all_loops()
	quit()
