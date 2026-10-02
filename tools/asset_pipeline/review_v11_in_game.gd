extends SceneTree
## Asset-only review staging in existing game lighting; never changes game scenes.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	DirAccess.make_dir_recursive_absolute(args[1])
	var view := SubViewport.new()
	view.size = Vector2i(1280,720)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var game = load("res://scenes/Main.tscn").instantiate()
	view.add_child(game)
	for i in 8: await process_frame
	paused = true
	game.get_node("HUD").hide()
	for name in ["Player","Elder","Youth"]: game.get_node(name).hide()
	var center: Vector3 = game.get_node("Player").global_position+Vector3(0,0,-4)
	var cells: Array = []
	for x in range(-6,7):
		for z in range(-5,4): cells.append(game.get_node("FireGrid").get_cell_coord_at_world_pos(center+Vector3(x,0,z)))
	game.get_node("FireGrid").reserve_clearing(cells)
	for row in rows:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(row.path,state) == OK)
		var model := doc.generate_scene(state)
		if row.get("prop",false):
			var mesh := ArrayMesh.new()
			assert(AssetLibrary._append_meshes(model,Transform3D.IDENTITY,mesh))
			model.free()
			var prop := MeshInstance3D.new()
			prop.mesh=mesh
			model=prop
		game.add_child(model)
		var p := center+Vector3(float(row.x),0,float(row.z))
		p.y = game.get_node("FireGrid").get_ground_height_at_world_pos(p)
		model.global_position=p
		model.rotation.y=deg_to_rad(float(row.get("yaw",0)))
	var camera: Camera3D = game.get_node("Camera3D")
	for distance in [12.0,22.0,44.0]:
		camera.fov=48
		var target := center+Vector3(0,.7,0)
		camera.global_position=target+Vector3(.28,.50,.82).normalized()*distance
		camera.look_at(target)
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		assert(view.get_texture().get_image().save_png(args[1].path_join("assets_%dm.png" % distance)) == OK)
	view.queue_free()
	paused=false
	for i in 3: await process_frame
	quit()
