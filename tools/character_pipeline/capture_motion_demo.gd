extends SceneTree
## Deterministic in-place pose reel of installed rigs in the real scene.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var output := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var game = load("res://scenes/Main.tscn").instantiate()
	viewport.add_child(game)
	for i in 3: await process_frame
	paused = true
	game.get_node("HUD").hide()
	var actors := [game.player, game.elder, game.youth]
	var center: Vector3 = game.player.global_position + Vector3(0, 0, -2.5)
	for i in 3:
		actors[i].global_position = center + Vector3((i-1)*1.4, 0, 0)
		actors[i].global_position.y = game.fire_grid.get_ground_height_at_world_pos(actors[i].global_position)
		actors[i].animator.rotation = Vector3.ZERO
	var camera: Camera3D = game.get_node("Camera3D")
	camera.global_position = center + Vector3(0, 2.4, 6.8)
	camera.look_at(center + Vector3(0, .8, 0))
	camera.fov = 40
	var label := Label.new()
	label.position = Vector2(22, 20)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	viewport.add_child(label)
	var stages := [&"idle", &"rake", &"ignite", &"spray", &"run", &"moving_work", &"cough"]
	for part in stages.size():
		var stage: StringName = stages[part]
		game.player._select_tool(0 if stage == &"ignite" else (1 if stage == &"rake" else 2))
		for actor in actors: actor.animator.cancel_work()
		for frame in 36:
			for actor in actors:
				var working := stage in [&"rake", &"ignite", &"spray", &"moving_work"]
				var kind: StringName = stage if actor == game.player else (&"rake" if actor == game.elder else &"spray")
				if stage == &"moving_work" and actor == game.player: kind = &"spray"
				var speed: float = 6.0 if stage == &"run" else (3.6 if stage in [&"moving_work", &"cough"] else 0.0)
				actor.animator.set_work(kind, working)
				actor.animator.set_environment(game.fire_grid, stage == &"cough")
				actor.animator.update_animation(1.0/24.0, Vector3(speed, 0, 0) if stage == &"moving_work" else Vector3(0, 0, speed), Vector3(0, 0, 1))
			label.text = "KHA-NAE / TA-POH / MU-NAW  |  %s\nInstalled rigs · in-place animation review" % stage
			await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % (part*36+frame)))
	viewport.queue_free()
	paused = false
	await process_frame
	quit()
