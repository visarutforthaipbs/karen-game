extends SceneTree
## Isolated real-scene presentation review, never writes player saves.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var output := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	SaveGame.dir = output.path_join("review_save")
	GameSettings.dir = SaveGame.dir
	PlaytestLog.dir = SaveGame.dir
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280,720)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var game = load("res://scenes/Main.tscn").instantiate()
	vp.add_child(game)
	for i in 4: await process_frame
	game.set_process(false)
	game.fire_grid.simulation_paused = true
	game.game_clock.set_process(false)
	for actor in [game.player, game.elder, game.youth]: actor.set_physics_process(false)
	var rig = game.cam_rig
	rig.set_process(false)
	var p = game.player
	p.global_position = p.refill_point + Vector3(1,0,1)
	p.water = 5
	game.hud.update_water(p.water,p.water_capacity)
	rig.focus = p.global_position
	rig.distance = rig.ZOOM_DEFAULT
	rig._apply(true)
	game.hud.update_stamina(45,100,6)
	game.hud.update_stamina(44,100,5)
	for height in [720,800]:
		vp.size = Vector2i(1280,height)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(output.path_join("refill_%d.png" % height))
	vp.size = Vector2i(1280,720)
	p.water = 0
	game.hud.update_water(0,p.water_capacity)
	rig.focus = game.fire_grid.get_cell_world_pos(35,35)
	p.global_position = rig.focus
	rig.distance = rig.ZOOM_MIN
	rig._apply(true)
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(output.path_join("empty_tank_direction.png"))
	game.hud.hide()
	var coord := Vector2i(20,20)
	var pos: Vector3 = game.fire_grid.get_cell_world_pos(20,20)
	for y in range(16,25):
		for x in range(16,25):
			game.fire_grid.cell_types[game.fire_grid._coord_to_index(x,y)] = game.fire_grid.CellType.ASH
	game.youth.global_position = game.fire_grid.get_cell_world_pos(20,21)
	game.youth.target_coord = coord
	game.youth.current_state = game.youth.State.PERFORMING_TASK
	game.fire_grid.cell_types[game.fire_grid._coord_to_index(20,20)] = game.fire_grid.CellType.SMOLDERING
	game.fire_grid._update_visuals()
	for zoom in [rig.ZOOM_DEFAULT, rig.zoom_max]:
		rig.focus = pos
		rig.distance = zoom
		rig._apply(true)
		game.youth.animator.set_work(&"spray",true)
		for frame in 24:
			game.youth.animator.update_animation(1.0/24.0,Vector3.ZERO,pos-game.youth.global_position)
			game.youth._update_spray_cue()
			game.youth._spray_cue._process(1.0/24.0)
			await process_frame
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(output.path_join("spray_%s_%02d.png" % ["normal" if zoom == rig.ZOOM_DEFAULT else "full",frame]))
	# A replay of the prior successful-douse effect, with identical scene/camera.
	game.youth._stop_spray_cue()
	for zoom in [rig.ZOOM_DEFAULT, rig.zoom_max]:
		rig.focus = pos
		rig.distance = zoom
		rig._apply(true)
		var old = load("res://artifacts/player_feedback_20261003/legacy_feedback.gd").spawn(game,game.youth._spray_origin(),pos,&"spray")
		old.set_process(false)
		for frame in 24:
			old.elapsed = float(frame)/24.0
			old.visible = old.elapsed < old.DURATION
			old._update_particles()
			await process_frame
			await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png(output.path_join("before_%s_%02d.png" % ["normal" if zoom == rig.ZOOM_DEFAULT else "full",frame]))
		old.queue_free()
	# Live smoke at the target, with existing fire particle emitters.
	game.youth._update_spray_cue()
	rig.focus = pos
	rig.distance = rig.ZOOM_DEFAULT
	rig._apply(true)
	for y in range(19,22):
		for x in range(19,22): game.fire_grid.cell_types[game.fire_grid._coord_to_index(x,y)] = game.fire_grid.CellType.SMOLDERING
	game.fire_grid._update_visuals()
	for frame in 36:
		game.youth._update_spray_cue()
		game.youth._spray_cue._process(1.0/24.0)
		await process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(output.path_join("smoke_%02d.png" % frame))
	game.queue_free()
	await process_frame
	quit()
