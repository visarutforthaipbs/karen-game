extends SceneTree
## Actual player sockets with candidate overrides; no game-code changes.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a:=OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(a[1])
	SaveGame.dir = a[1].path_join("review_save")
	GameSettings.dir = SaveGame.dir
	PlaytestLog.dir = SaveGame.dir
	root.get_node("GameState").reset_campaign()
	var records: Array=JSON.parse_string(FileAccess.get_file_as_string(a[0]))
	for row in records:
		var doc:=GLTFDocument.new()
		var state:=GLTFState.new()
		assert(doc.append_from_file(row.path,state)==OK)
		var node:=doc.generate_scene(state)
		var mesh:=ArrayMesh.new()
		assert(AssetLibrary._append_meshes(node,Transform3D.IDENTITY,mesh))
		node.free()
		AssetLibrary._cache[String(row.label).get_slice("_",0)]=[mesh]
	var vp:=SubViewport.new()
	vp.size=Vector2i(1280,720)
	vp.own_world_3d=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var game=load("res://scenes/Main.tscn").instantiate()
	vp.add_child(game)
	for i in 12:await process_frame
	paused=true
	game.get_node("HUD").hide()
	game.get_node("Elder").hide()
	game.get_node("Youth").hide()
	var actor=game.get_node("Player")
	var camera: Camera3D=game.get_node("Camera3D")
	if a.size()>2:
		for child in actor.animator.get_back_socket().get_children():
			if child is MeshInstance3D:child.position.y-=.23/actor.animator.base_scale
	for tool in 3:
		actor._select_tool(tool)
		for angle in [0.0,PI]:
			var target: Vector3=actor.global_position+Vector3(0,.70,0)
			camera.global_position=target+Vector3(sin(angle)*2+.75,1.0,cos(angle)*2.8)
			camera.look_at(target)
			for i in 8:await process_frame
			await RenderingServer.frame_post_draw
			assert(vp.get_texture().get_image().save_png(a[1].path_join("tool_%d_%s.png"%[tool,"front" if angle==0 else "back"]))==OK)
	vp.queue_free()
	paused=false
	for i in 4:await process_frame
	quit()
