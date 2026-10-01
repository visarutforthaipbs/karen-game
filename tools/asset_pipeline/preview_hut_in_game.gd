extends SceneTree
## Preview a candidate through the real asset loader and game scene without installing it.
## godot --path . --script tools/asset_pipeline/preview_hut_in_game.gd -- candidate.glb output_dir
## Use 'installed' instead of a path to inspect the current game assets.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected candidate.glb|installed output_dir")
		quit(1)
		return
	if args[0] != "installed":
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		if doc.append_from_file(args[0], state) != OK:
			quit(1)
			return
		var model := doc.generate_scene(state)
		var mesh := ArrayMesh.new()
		var found := AssetLibrary._append_meshes(model, Transform3D.IDENTITY, mesh)
		model.free()
		if not found:
			quit(1)
			return
		AssetLibrary._cache["S1"] = [mesh]
	DirAccess.make_dir_recursive_absolute(args[1])
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
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
	var camera: Camera3D = game.get_node("Camera3D")
	var center: Vector3 = game.hut_position + Vector3(-1.2, 1.4, 0)
	for shot in ["gameplay", "closeup"]:
		if shot == "closeup":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.position = center + Vector3(5, 3, -8)
			camera.fov = 42
			camera.look_at(center)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		if viewport.get_texture().get_image().save_png(args[1].path_join(shot + ".png")) != OK:
			quit(1)
			return
	viewport.queue_free()
	paused = false
	for i in 3:
		await process_frame
	print("Hut game preview: ", args[1])
	quit(0)
