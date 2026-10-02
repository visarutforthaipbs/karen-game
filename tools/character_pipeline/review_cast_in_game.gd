extends SceneTree
## Static candidate review in the real terrain/lighting. Does not install or certify rigs.
## godot --path . --script tools/character_pipeline/review_cast_in_game.gd -- manifest.json output_dir
var viewport: SubViewport

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected manifest.json output_dir")
		quit(1)
		return
	var records = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not records is Array or records.size() != 4:
		push_error("Expected the four-character cast")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[1])
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var game = load("res://scenes/Main.tscn").instantiate()
	viewport.add_child(game)
	for i in 8:
		await process_frame
	paused = true
	game.get_node("HUD").hide()
	var center: Vector3 = game.get_node("Player").global_position + Vector3(0, 0, -4.0)
	for actor in ["Player", "Elder", "Youth"]:
		game.get_node(actor).hide()
	var grid = game.get_node("FireGrid")
	var positions: Array[Vector3] = []
	for i in records.size():
		var doc = GLTFDocument.new()
		var state = GLTFState.new()
		if doc.append_from_file(records[i].path, state) != OK:
			push_error("Cannot load candidate: " + records[i].path)
			quit(1)
			return
		var model = doc.generate_scene(state)
		game.add_child(model)
		var p = center + Vector3((i - 1.5) * 1.5, 0, 0)
		p.y = grid.get_ground_height_at_world_pos(p)
		model.global_position = p
		positions.append(p)
	var camera: Camera3D = game.get_node("Camera3D")
	var original_fov = camera.fov
	var canvas = CanvasLayer.new()
	viewport.add_child(canvas)
	var label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	for shot in ["close", "near_22m", "default_44m"]:
		var focus = center + Vector3(0, 0.55, 0)
		if shot == "close":
			camera.fov = 42
			camera.global_position = focus + Vector3(0, 2.5, 6.0)
		else:
			camera.fov = original_fov
			var distance = 22.0 if shot == "near_22m" else 44.0
			var pitch = deg_to_rad(38.5)
			camera.global_position = focus + Vector3(sin(PI/4)*cos(pitch), sin(pitch), cos(PI/4)*cos(pitch))*distance
		camera.look_at(focus)
		label.text = "v3.1 STATIC CANDIDATES | Kha-nae / Ta-poh / Mu-naw / Mae-Lu\n%s | Actual game terrain and lighting; rigs and equipment pending" % shot
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		if viewport.get_texture().get_image().save_png(args[1].path_join(shot + ".png")) != OK:
			quit(1)
			return
		var projected = []
		for p in positions:
			projected.append({"feet":str(camera.unproject_position(p)), "head":str(camera.unproject_position(p+Vector3.UP*1.15))})
		var file = FileAccess.open(args[1].path_join(shot + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"fov":camera.fov,"camera":str(camera.global_transform),"projected":projected,"static_review_only":true}, "  "))
	viewport.queue_free()
	paused = false
	for i in 3:
		await process_frame
	print("Static cast game review: ", args[1])
	quit()
