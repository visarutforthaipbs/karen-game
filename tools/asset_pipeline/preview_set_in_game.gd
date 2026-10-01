extends SceneTree
## Review a set through the actual scene and its configured renderer.
## godot --path . --script tools/asset_pipeline/preview_set_in_game.gd -- build_results.json|installed output_dir

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected build_results.json|installed output_dir")
		quit(1)
		return
	if args[0] != "installed":
		var entries = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
		for entry in entries:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			if document.append_from_file(str(entry.candidate).path_join(entry.file), state) != OK:
				quit(1)
				return
			var imported := document.generate_scene(state)
			var mesh := ArrayMesh.new()
			var found := AssetLibrary._append_meshes(imported, Transform3D.IDENTITY, mesh)
			imported.free()
			if not found:
				quit(1)
				return
			if not AssetLibrary._cache.has(entry.id):
				AssetLibrary._cache[entry.id] = []
			AssetLibrary._cache[entry.id].append(mesh)
	DirAccess.make_dir_recursive_absolute(args[1])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var game = load("res://scenes/Main.tscn").instantiate()
	viewport.add_child(game)
	for i in 10:
		await process_frame
	paused = true
	game.get_node("HUD").hide()
	var camera: Camera3D = game.get_node("Camera3D")
	for shot in ["field", "clearing", "drone"]:
		var center: Vector3 = game.hut_position
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		if shot == "field":
			center += Vector3(0, 1, -7)
			camera.size = 20
			camera.position = center + Vector3(10, 16, 15)
		elif shot == "clearing":
			center += Vector3(0, 1.2, -.7)
			camera.size = 10
			camera.position = center + Vector3(5, 5, -9)
		else:
			var drone: ForestryDrone = game.get_node("ForestryDrone")
			drone.visible = true
			drone.global_position = center + Vector3(0, 4, -3)
			drone.rotation = Vector3.ZERO
			drone.drone_body.rotation = Vector3.ZERO
			drone.searchlight_mesh.hide()
			center = drone.global_position
			camera.size = 3.2
			camera.position = center + Vector3(2, 1.6, 3)
		camera.look_at(center)
		for i in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		if viewport.get_texture().get_image().save_png(args[1].path_join(shot + ".png")) != OK:
			quit(1)
			return
	viewport.queue_free()
	paused = false
	AssetLibrary.reload()
	for i in 3:
		await process_frame
	print("Set game preview: ", args[1])
	quit(0)
