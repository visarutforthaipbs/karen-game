extends SceneTree
## Candidate-only overrides in this review process; production files untouched.
## Args: array of {id,path}, scene resource, output path, mode (title/crowd/hearth).
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a:=OS.get_cmdline_user_args()
	var records: Array=JSON.parse_string(FileAccess.get_file_as_string(a[0]))
	for row in records:
		var doc:=GLTFDocument.new()
		var state:=GLTFState.new()
		assert(doc.append_from_file(row.path,state)==OK)
		var node:=doc.generate_scene(state)
		var mesh:=ArrayMesh.new()
		assert(AssetLibrary._append_meshes(node,Transform3D.IDENTITY,mesh))
		node.free()
		if not AssetLibrary._cache.has(row.id):AssetLibrary._cache[row.id]=[]
		AssetLibrary._cache[row.id].append(mesh)
	var vp:=SubViewport.new()
	vp.size=Vector2i(1280,720)
	vp.own_world_3d=true
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	SaveGame.dir=ProjectSettings.globalize_path("res://artifacts/asset_update_v12/review_save")
	DirAccess.make_dir_recursive_absolute(SaveGame.dir)
	root.get_node("GameState").seen_how_to_play=true
	var game=load(a[1]).instantiate()
	vp.add_child(game)
	for i in 30: await process_frame
	if a[3]=="hearth":
		var todo: Array[Node]=[game]
		while not todo.is_empty():
			var n: Node=todo.pop_back()
			if n is HearthBackdrop:
				n._painting=ImageTexture.create_from_image(Image.load_from_file(a[4]))
				n.queue_redraw()
			for c in n.get_children():todo.append(c)
		for dimensions in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(960,720)]:
			vp.size=dimensions
			game.size=dimensions
			for i in 20:await process_frame
			await RenderingServer.frame_post_draw
			assert(vp.get_texture().get_image().save_png(a[2].replace(".png","_%dx%d.png"%[dimensions.x,dimensions.y]))==OK)
	elif a[3]=="title":
		game.set_process(false)
		for t in [3.0,5.0,7.0]:
			game._pass_t=t
			game._update_satellite(0.0)
			for i in 5: await process_frame
			await RenderingServer.frame_post_draw
			assert(vp.get_texture().get_image().save_png(a[2].replace(".png","_%d.png"%t))==OK)
	else:
		for i in 90:await process_frame
		await RenderingServer.frame_post_draw
		assert(vp.get_texture().get_image().save_png(a[2])==OK)
	vp.queue_free()
	for i in 4:await process_frame
	quit()
