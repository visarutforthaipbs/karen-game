extends SceneTree
## Exercise the actual cover-crop drawing independently of the UI's minimum size.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var a:=OS.get_cmdline_user_args()
	var vp:=SubViewport.new()
	vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg:=HearthBackdrop.new()
	bg._painting=ImageTexture.create_from_image(Image.load_from_file(a[0]))
	vp.add_child(bg)
	for dimensions in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(960,720)]:
		vp.size=dimensions
		bg.size=dimensions
		for i in 10:await process_frame
		await RenderingServer.frame_post_draw
		assert(vp.get_texture().get_image().save_png(a[1].path_join("crop_%dx%d.png"%[dimensions.x,dimensions.y]))==OK)
	vp.queue_free()
	for i in 3:await process_frame
	quit()
