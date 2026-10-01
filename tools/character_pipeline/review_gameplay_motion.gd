extends SceneTree
## Review actual gameplay animators, with optional candidate GLBs before installation.
## args: output_dir [tapoh_candidate.glb munaw_candidate.glb [khanae_candidate.glb]]
var game: Node3D
var viewport: SubViewport
func _initialize() -> void:
	call_deferred("run")
func candidate(actor: Node3D, path: String, profile: String) -> void:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(path, state) == OK)
	actor.animator.free()
	var model := Node3D.new()
	model.set_script(load("res://scripts/SkeletalChibiAnimator.gd"))
	model.character_profile = profile
	model.add_child(doc.generate_scene(state))
	actor.add_child(model)
	actor.animator = model
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1440, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	game = load("res://scenes/Main.tscn").instantiate()
	viewport.add_child(game)
	for i in 3: await process_frame
	paused = true
	var actors := [game.get_node("Player"), game.get_node("Elder"), game.get_node("Youth")]
	if args.size() >= 2:
		candidate(actors[1], args[1], "tapoh")
	if args.size() >= 3:
		candidate(actors[2], args[2], "munaw")
	if args.size() >= 4:
		candidate(actors[0], args[3], "khanae")
		actors[0]._tool_rig.free()
		actors[0]._create_tool_rig()
		actors[0]._select_tool(0)
	game.get_node("HUD").hide()
	var center: Vector3 = actors[0].global_position + Vector3(0, 0, -2.5)
	for i in 3:
		actors[i].global_position = center + Vector3((i-1)*1.55, 0, 0)
		actors[i].global_position.y = game.fire_grid.get_ground_height_at_world_pos(actors[i].global_position)
	var camera: Camera3D = game.get_node("Camera3D")
	camera.fov = 40
	var label := Label.new()
	label.position = Vector2(25, 25)
	label.add_theme_font_size_override("font_size", 26)
	viewport.add_child(label)
	var kinds := [&"", &"ignite", &"rake", &"spray", &"move_work", &"cough", &"run"]
	for part in kinds.size():
		var kind: StringName = kinds[part]
		actors[0]._select_tool(0 if kind == &"ignite" else (1 if kind == &"rake" else 2))
		for actor in actors:
			if not actor.animator.has_method("set_work"):
				continue
			actor.animator.cancel_work()
			actor.animator.rotation = Vector3.ZERO
			actor.animator.set_environment(game.fire_grid, kind == &"cough")
			actor.animator.set_work(kind if kind != &"move_work" else &"spray", part > 0 and part < 5)
		for frame in 20:
			for actor in actors:
				var velocity := Vector3(3.6, 0, 0) if kind in [&"move_work", &"cough"] else (Vector3(0, 0, 6) if kind == &"run" else Vector3.ZERO)
				actor.animator.update_animation(1.0/30.0, velocity, Vector3.FORWARD * -1)
		for view in 4:
			var angle := view * PI/2.0
			camera.global_position = center + Vector3(sin(angle)*7, 3.3, cos(angle)*7)
			camera.look_at(center + Vector3(0, .85, 0))
			label.text = "KHA-NAE / TA-POH / MU-NAW  |  %s  |  view %d" % [kind if kind != &"" else &"idle", view]
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(output.path_join("%02d_%s_view%d.png" % [part, kind, view]))
	# Close-ups for each actor at maximum work and gait poses.
	for actor in actors:
		for other in actors: other.visible = other == actor
		var model = actor.animator
		for action in [&"rake", &"spray", &"run"]:
			model.cancel_work()
			model.set_work(action, action != &"run")
			if actor == actors[0]: actor._select_tool(1 if action == &"rake" else 2)
			model.set_work(action, action != &"run")
			for frame in 12: model.update_animation(1.0/30.0, Vector3(0, 0, 6) if action == &"run" else Vector3.ZERO, Vector3(0, 0, 1))
			for view in 4:
				var focus: Vector3 = actor.global_position + Vector3(0, .85, 0)
				var angle := view * PI/2.0
				camera.global_position = focus + Vector3(sin(angle)*3, .5, cos(angle)*3)
				camera.look_at(focus)
				label.text = "%s | %s | view %d" % [actor.name, action, view]
				for i in 3: await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(output.path_join("%s_%s_view%d.png" % [actor.name, action, view]))
	viewport.queue_free()
	paused = false
	await process_frame
	quit()
