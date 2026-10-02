extends SceneTree
## Review candidate atlases using actual FireGrid materials in the game world.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args := OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(args[1])
	SaveGame.dir = args[1].path_join("review_save")
	GameSettings.dir = SaveGame.dir
	PlaytestLog.dir = SaveGame.dir
	root.get_node("GameState").reset_campaign()
	var vp := SubViewport.new()
	vp.size=Vector2i(1280,720)
	vp.own_world_3d=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var game = load("res://scenes/Main.tscn").instantiate()
	vp.add_child(game)
	for i in 8: await process_frame
	game.get_node("HUD").hide()
	game.process_mode=Node.PROCESS_MODE_DISABLED
	var grid = game.get_node("FireGrid")
	var center: Vector3 = game.get_node("Player").global_position+Vector3(0,0,-4)
	var cells: Array=[]
	for x in range(-4,5):
		for z in range(-3,4): cells.append(grid.get_cell_coord_at_world_pos(center+Vector3(x,0,z)))
	grid.reserve_clearing(cells)
	# Independent emitters: same material, ramp and motion as the live game.
	for spec in [[grid.flame_particles,"flame_sheet.png",4,true],[grid.smoke_particles,"smoke_sheet.png",2,false]]:
		var particles: CPUParticles3D = spec[0].duplicate()
		particles.process_mode=Node.PROCESS_MODE_ALWAYS
		game.add_child(particles)
		particles.mesh=particles.mesh.duplicate()
		var mat: StandardMaterial3D=particles.mesh.material.duplicate()
		mat.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(args[0].path_join(spec[1])))
		mat.particles_anim_h_frames=spec[2]
		mat.particles_anim_v_frames=spec[2]
		mat.particles_anim_loop=spec[3]
		particles.anim_speed_min=1 if spec[3] else 0
		particles.anim_speed_max=particles.anim_speed_min
		particles.anim_offset_max=1
		particles.mesh.material=mat
		particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_POINTS
		var points:=PackedVector3Array()
		for x in range(-2,3):
			for z in range(-1,2):
				var p:=center+Vector3(x,0,z)
				p.y=grid.get_ground_height_at_world_pos(p)+.15
				points.append(p)
		particles.emission_points=points
		particles.emitting=true
		particles.preprocess=3
	var camera: Camera3D=game.get_node("Camera3D")
	camera.set_process(false)
	for distance in [12.0,22.0,44.0]:
		var target:=center+Vector3(0,1.4,0)
		camera.global_position=target+Vector3(.28,.5,.82).normalized()*distance
		camera.look_at(target)
		for i in 60: await process_frame
		await RenderingServer.frame_post_draw
		assert(vp.get_texture().get_image().save_png(args[1].path_join("vfx_%dm.png" % distance))==OK)
	# Temporal samples in the actual day / inversion / night lighting.
	var target:=center+Vector3(0,1.1,0)
	camera.global_position=target+Vector3(.28,.5,.82).normalized()*22
	camera.look_at(target)
	for hour in [14.0,18.5,19.8]:
		game.sky.inversion_strength=1.0 if hour>=18 else 0.0
		game.sky.apply_time(hour)
		for sample in 8:
			for frame in 8:await process_frame
			await RenderingServer.frame_post_draw
			assert(vp.get_texture().get_image().save_png(args[1].path_join("flame_%04d_%02d.png"%[roundi(hour*100),sample]))==OK)
	# Installed mist and ash hooks: actual burst creation and material paths.
	game.sky.inversion_strength=0
	game.sky.apply_time(14)
	camera.global_position=target+Vector3(.28,.5,.82).normalized()*8
	camera.look_at(target)
	for child in game.get_children():
		if child is CPUParticles3D:child.visible=false
	var douse_pos:=center
	douse_pos.y=grid.get_ground_height_at_world_pos(douse_pos)
	grid._spawn_douse_burst(douse_pos,true)
	var paths:Array=[]
	for child in grid.get_children():
		if child is CPUParticles3D and child.one_shot:
			child.process_mode=Node.PROCESS_MODE_ALWAYS
			paths.append(child.mesh.material.albedo_texture.resource_path)
	if not paths.has("res://assets/vfx/mist_sheet.png") or not paths.has("res://assets/vfx/ash_flake.png"):
		push_error("Missing douse hooks: "+str(paths))
		quit(1)
		return
	FileAccess.open(args[1].path_join("douse_hooks.json"),FileAccess.WRITE).store_string(JSON.stringify(paths))
	for sample in 8:
		for frame in 6:await process_frame
		await RenderingServer.frame_post_draw
		assert(vp.get_texture().get_image().save_png(args[1].path_join("douse_%02d.png"%sample))==OK)
	vp.queue_free()
	for i in 3: await process_frame
	quit()
