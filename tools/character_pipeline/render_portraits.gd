extends SceneTree
## Render matching portraits from the actual reviewed GLBs, rather than new faces.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for row in records:
		var view := SubViewport.new()
		view.size = Vector2i(256,256)
		view.transparent_bg = true
		view.own_world_3d = true
		view.msaa_3d = Viewport.MSAA_4X
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		assert(document.append_from_file(row.path,state) == OK)
		var model := document.generate_scene(state)
		view.add_child(model)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-30,-25,0)
		light.light_energy = .85
		view.add_child(light)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = .65
		view.add_child(env)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(row.get("size",.60))
		view.add_child(camera)
		camera.position = Vector3(.10,float(row.y),3)
		camera.look_at(Vector3(0,float(row.y),0))
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(view.get_texture().get_image().save_png(row.output) == OK)
		print("Portrait: ",row.output)
		view.queue_free()
		await process_frame
	quit()
