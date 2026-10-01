extends SceneTree
## Render a raw GLB from four directions at its authored scale.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(args[0], state) == OK)
	var world := Node3D.new()
	root.add_child(world)
	var model := doc.generate_scene(state)
	world.add_child(model)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.20, 0.23)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -30, 0)
	world.add_child(light)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.45
	world.add_child(cam)
	root.size = Vector2i(800, 800)
	DirAccess.make_dir_recursive_absolute(args[1])
	for part in 4:
		var angle := part * PI / 2.0
		cam.position = Vector3(sin(angle) * 3, 0.6, cos(angle) * 3)
		cam.look_at(Vector3(0, 0.6, 0))
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(args[1].path_join("view_%d.png" % part))
	world.queue_free()
	await process_frame
	quit()
