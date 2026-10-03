extends SceneTree
## Asset review with real actors, rotor mounts and warning lens; no runtime edits.
func _initialize() -> void: call_deferred("run")
func candidate_mesh(path: String) -> ArrayMesh:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	assert(doc.append_from_file(path,state)==OK)
	var model := doc.generate_scene(state)
	var mesh := ArrayMesh.new()
	assert(AssetLibrary._append_meshes(model,Transform3D.IDENTITY,mesh))
	model.free()
	return mesh
func run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size()==3,"Expected drone.glb camera.glb output_dir")
	DirAccess.make_dir_recursive_absolute(args[2])
	var view := SubViewport.new()
	view.size=Vector2i(1280,720)
	view.own_world_3d=true
	view.msaa_3d=Viewport.MSAA_4X
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var world := Node3D.new()
	view.add_child(world)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.10,.12,.15)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.65
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-40,-35,0)
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	var drone = load("res://scripts/ForestryDrone.gd").new()
	world.add_child(drone)
	drone.set_process(false)
	drone.visible=true
	drone.drone_body.mesh=candidate_mesh(args[0])
	var rotor_y: float=drone.drone_body.mesh.get_aabb().end.y+.015
	for rotor in drone._rotors: rotor.position.y=rotor_y
	drone.searchlight_mesh.hide()
	var post = load("res://scripts/ThermalCamera.gd").new()
	world.add_child(post)
	post.set_process(false)
	var housing: MeshInstance3D
	for node in post.get_children():
		if node is MeshInstance3D and abs(node.position.y-2.58)<.001: housing=node
	assert(housing!=null,"Missing actual housing hook")
	housing.mesh=candidate_mesh(args[1])
	var report := {"rotor_centres":[],"rotor_height":rotor_y,"mount_clearance":.015,"warning_lens_actor_point":[.145,2.735,.255]}
	for rotor in drone._rotors:
		report.rotor_centres.append([rotor.position.x,rotor.position.y,rotor.position.z])
		assert(abs(abs(rotor.position.x)-.48)<.0001 and abs(abs(rotor.position.z)-.48)<.0001)
	for id in ["drone","camera"]:
		drone.visible=id=="drone"
		post.visible=id=="camera"
		var center := Vector3(0,.03,0) if id=="drone" else Vector3(0,2.72,0)
		var distance: float=1.9 if id=="drone" else .85
		for angle in [0.0,45.0,90.0]:
			var direction := Vector3(sin(deg_to_rad(angle)),.40,cos(deg_to_rad(angle))).normalized()
			camera.look_at_from_position(center+direction*distance,center)
			for i in 12: await process_frame
			await RenderingServer.frame_post_draw
			assert(view.get_texture().get_image().save_png(args[2].path_join("%s_%d.png"%[id,angle]))==OK)
	FileAccess.open(args[2].path_join("mounts.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	view.queue_free()
	for i in 3: await process_frame
	quit()
